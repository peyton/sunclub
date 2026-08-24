import CoreLocation
import Foundation
import Network
import Observation
import os
import WeatherKit

@MainActor
protocol LiveUVWeatherProviding: AnyObject {
    func uvBundle(for location: CLLocation, referenceDate: Date) async throws -> SunclubUVForecastBundle
    func attributionMarkup() async throws -> SunclubWeatherAttribution
}

struct SunclubWeatherAttribution: Equatable, Sendable {
    let serviceName: String
    let legalPageURL: URL
    let lightMarkURL: URL?
    let darkMarkURL: URL?
}

@MainActor
final class WeatherKitLiveUVWeatherProvider: LiveUVWeatherProviding {
    private static let logger = Logger(subsystem: "com.sunclub", category: "WeatherKit")
    private let service = WeatherService.shared

    func uvBundle(for location: CLLocation, referenceDate: Date) async throws -> SunclubUVForecastBundle {
        let (current, hourly, daily) = try await service.weather(
            for: location,
            including: .current, .hourly, .daily
        )

        let hourlyWindow = hourly.forecast.prefix(36)
        let hours: [SunclubUVHourForecast] = hourlyWindow.map { hour in
            SunclubUVHourForecast(
                date: hour.date,
                index: hour.uvIndex.value,
                sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
            )
        }

        let days: [SunclubUVDayForecast] = daily.forecast.prefix(10).map { day in
            SunclubUVDayForecast(
                day: Calendar.current.startOfDay(for: day.date),
                maxIndex: day.uvIndex.value
            )
        }

        return SunclubUVForecastBundle(
            generatedAt: referenceDate,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            currentIndex: current.uvIndex.value,
            hourly: hours,
            daily: days
        )
    }

    func attributionMarkup() async throws -> SunclubWeatherAttribution {
        let attribution = try await service.attribution
        return SunclubWeatherAttribution(
            serviceName: attribution.serviceName,
            legalPageURL: attribution.legalPageURL,
            lightMarkURL: attribution.combinedMarkLightURL,
            darkMarkURL: attribution.combinedMarkDarkURL
        )
    }
}

@MainActor
@Observable
final class UVIndexService {
    nonisolated static let verifiedDataMaxAge = SunclubUVDataFreshness.verifiedMaxAge
    nonisolated static let lastKnownDataMaxAge = SunclubUVDataFreshness.lastKnownMaxAge
    private static let logger = Logger(subsystem: "com.sunclub", category: "LiveUV")

    private(set) var currentReading: UVReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var liveUVAccessState: LiveUVAccessState = .disabled
    private(set) var lastBundle: SunclubUVForecastBundle?
    private(set) var attribution: SunclubWeatherAttribution?
    private(set) var status: SunclubUVStatus = .unavailable
    private(set) var protectionWindow: SunclubUVProtectionWindow?
    private(set) var fallbackLatitude: Double?

    private let locationService: SharedLocationManaging
    private let weatherProvider: any LiveUVWeatherProviding
    private let cache: SunclubUVForecastCache
    private let budget: SunclubWeatherKitBudget
    private let networkPathProvider: () -> NWPath?
    private var inFlightTask: Task<Void, Never>?
    private var inFlightRequest: FetchRequest?

    private struct FetchRequest: Equatable {
        let prefersLiveData: Bool
        let selectedPlace: SunclubSelectedUVPlace?
        let allowPermissionPrompt: Bool
    }

    init(
        locationService: SharedLocationManaging? = nil,
        weatherProvider: (any LiveUVWeatherProviding)? = nil,
        cache: SunclubUVForecastCache? = nil,
        budget: SunclubWeatherKitBudget? = nil,
        networkPathProvider: @escaping () -> NWPath? = { SharedNetworkPathMonitor.shared.currentPath }
    ) {
        self.locationService = locationService ?? SharedLocationManager.shared
        self.weatherProvider = weatherProvider ?? WeatherKitLiveUVWeatherProvider()
        self.cache = cache ?? SunclubUVForecastCache()
        self.budget = budget ?? SunclubWeatherKitBudget()
        self.networkPathProvider = networkPathProvider
        self.lastBundle = self.cache.lastBundle()
        self.fallbackLatitude = self.lastBundle?.latitude
    }

    /// Fetches a UV bundle (current + hourly + daily).
    /// - Parameters:
    ///   - prefersLiveData: when true, current location is preferred.
    ///   - selectedPlace: saved coordinates used when current location is disabled or unavailable.
    ///   - allowPermissionPrompt: only true on explicit user action (tapping "Enable Live UV").
    ///   - now: injected for tests.
    /// This is the single entry point — it returns fast if the cache is fresh for the
    /// current location. Background launches and widget refreshes should NOT call this;
    /// they should read `lastBundle` only.
    func fetchUVIndex(
        prefersLiveData: Bool,
        selectedPlace: SunclubSelectedUVPlace? = nil,
        allowPermissionPrompt: Bool = false,
        now: Date = Date()
    ) async {
        let request = FetchRequest(
            prefersLiveData: prefersLiveData,
            selectedPlace: selectedPlace,
            allowPermissionPrompt: allowPermissionPrompt
        )

        while let inFlightTask {
            let isSameRequest = inFlightRequest == request
            await inFlightTask.value
            if isSameRequest {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            defer {
                if self.inFlightRequest == request {
                    self.inFlightTask = nil
                    self.inFlightRequest = nil
                }
            }
            await self.performFetch(
                prefersLiveData: prefersLiveData,
                selectedPlace: selectedPlace,
                allowPermissionPrompt: allowPermissionPrompt,
                now: now
            )
        }
        inFlightTask = task
        inFlightRequest = request
        await task.value
    }

    private func performFetch(
        prefersLiveData: Bool,
        selectedPlace: SunclubSelectedUVPlace?,
        allowPermissionPrompt: Bool,
        now: Date
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if let selectedPlace {
            fallbackLatitude = selectedPlace.latitude
        }

        if !prefersLiveData, let selectedPlace {
            await fetchWeather(
                for: CLLocation(latitude: selectedPlace.latitude, longitude: selectedPlace.longitude),
                source: .selectedPlace(displayName: selectedPlace.displayName),
                now: now
            )
            return
        }

        guard prefersLiveData else {
            applyFallback(
                accessState: .disabled,
                source: nil,
                location: nil,
                now: now,
                errorMessage: nil
            )
            return
        }

        if allowPermissionPrompt {
            _ = await locationService.requestWhenInUseAuthorizationIfNeeded()
        }

        guard let resolvedLocation = await preferredLocation(selectedPlace: selectedPlace, now: now) else {
            return
        }
        await fetchWeather(
            for: resolvedLocation.location,
            source: resolvedLocation.source,
            now: now
        )
    }

    private func preferredLocation(
        selectedPlace: SunclubSelectedUVPlace?,
        now: Date
    ) async -> (location: CLLocation, source: SunclubUVLocationSource)? {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            if let selectedPlace {
                return selectedLocation(for: selectedPlace)
            }
            applyFallback(
                accessState: .denied,
                source: nil,
                location: nil,
                now: now,
                errorMessage: "Location access is off, so Sunclub is using a local UV estimate."
            )
            return nil
        case .notDetermined:
            if let selectedPlace {
                return selectedLocation(for: selectedPlace)
            }
            applyFallback(
                accessState: .needsPermission,
                source: nil,
                location: nil,
                now: now,
                errorMessage: "Location access is not set, so Sunclub is using a local UV estimate."
            )
            return nil
        default:
            break
        }

        do {
            return (try await locationService.currentLocation(), .liveLocation)
        } catch {
            if let selectedPlace {
                return selectedLocation(for: selectedPlace)
            }
            applyFallback(
                accessState: .unavailable,
                source: nil,
                location: nil,
                now: now,
                errorMessage: error.localizedDescription
            )
            return nil
        }
    }

    private func selectedLocation(
        for place: SunclubSelectedUVPlace
    ) -> (location: CLLocation, source: SunclubUVLocationSource) {
        (
            CLLocation(latitude: place.latitude, longitude: place.longitude),
            .selectedPlace(displayName: place.displayName)
        )
    }

    private func fetchWeather(
        for location: CLLocation,
        source: SunclubUVLocationSource,
        now: Date
    ) async {
        fallbackLatitude = location.coordinate.latitude

        if let cached = cache.bundle(
            for: location,
            now: now,
            maximumAge: Self.verifiedDataMaxAge
        ) {
            applyWeatherBundle(
                cached,
                readingSource: .cachedWeatherKit,
                locationSource: source,
                freshness: .fresh,
                accessState: .live,
                now: now,
                errorMessage: nil
            )
            return
        }

        if let path = networkPathProvider(), path.isConstrained {
            applyFallback(
                accessState: .unavailable,
                source: source,
                location: location,
                now: now,
                errorMessage: "Apple Weather is paused in Low Data Mode."
            )
            return
        }

        switch budget.check(now: now) {
        case .allow:
            budget.recordFetch(at: now)
        case .deny(let reason):
            applyFallback(
                accessState: .unavailable,
                source: source,
                location: location,
                now: now,
                errorMessage: reason
            )
            return
        }

        do {
            let bundle = try await weatherProvider.uvBundle(for: location, referenceDate: now)
            cache.store(bundle)
            applyWeatherBundle(
                bundle,
                readingSource: .weatherKit,
                locationSource: source,
                freshness: .fresh,
                accessState: .live,
                now: now,
                errorMessage: nil
            )

            if attribution == nil {
                attribution = try? await weatherProvider.attributionMarkup()
            }
        } catch {
            Self.logger.error("Apple Weather UV request failed: \(error.localizedDescription, privacy: .public)")
            applyFallback(
                accessState: .unavailable,
                source: source,
                location: location,
                now: now,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func applyWeatherBundle(
        _ bundle: SunclubUVForecastBundle,
        readingSource: UVReadingSource,
        locationSource: SunclubUVLocationSource?,
        freshness: SunclubUVFreshness,
        accessState: LiveUVAccessState,
        now: Date,
        errorMessage: String?
    ) {
        let index = readingSource == .weatherKit
            ? bundle.currentIndex ?? bundle.index(at: now)
            : bundle.index(at: now)
        guard let index else {
            applyLocalEstimate(
                accessState: accessState == .live ? .unavailable : accessState,
                source: locationSource,
                location: CLLocation(latitude: bundle.latitude, longitude: bundle.longitude),
                now: now,
                errorMessage: errorMessage ?? "Apple Weather returned no usable UV value."
            )
            return
        }

        lastBundle = bundle
        fallbackLatitude = bundle.latitude
        currentReading = UVReading(
            index: index,
            timestamp: bundle.generatedAt,
            source: readingSource
        )
        liveUVAccessState = accessState
        self.errorMessage = errorMessage
        status = SunclubUVStatus(
            availability: .available,
            source: locationSource,
            freshness: freshness,
            updatedAt: bundle.generatedAt
        )
        protectionWindow = bundle.protectionWindow(for: now)
    }

    private func applyFallback(
        accessState: LiveUVAccessState,
        source: SunclubUVLocationSource? = nil,
        location: CLLocation? = nil,
        now: Date,
        errorMessage: String? = nil
    ) {
        let cached = location.flatMap { location in
            cache.bundle(
                for: location,
                now: now,
                maximumAge: Self.lastKnownDataMaxAge
            )
        }

        if let cached, cached.index(at: now) != nil {
            let freshness: SunclubUVFreshness = cached.isFresh(
                now: now,
                ttl: Self.verifiedDataMaxAge
            ) ? .fresh : .stale
            applyWeatherBundle(
                cached,
                readingSource: .cachedWeatherKit,
                locationSource: source,
                freshness: freshness,
                accessState: accessState,
                now: now,
                errorMessage: errorMessage
            )
            return
        }

        applyLocalEstimate(
            accessState: accessState,
            source: source,
            location: location,
            now: now,
            errorMessage: errorMessage
        )
    }

    private func applyLocalEstimate(
        accessState: LiveUVAccessState,
        source: SunclubUVLocationSource?,
        location: CLLocation?,
        now: Date,
        errorMessage: String?
    ) {
        let latitude = location?.coordinate.latitude ?? fallbackLatitude ?? cache.lastBundle()?.latitude
        fallbackLatitude = latitude
        let index = SunclubUVEstimator.estimatedIndex(at: now, latitude: latitude)
        let estimatedHours = SunclubUVEstimator.hourlyForecast(
            for: now,
            latitude: latitude
        )
        let estimatedBundle = SunclubUVForecastBundle(
            generatedAt: now,
            latitude: latitude ?? 0,
            longitude: location?.coordinate.longitude ?? 0,
            currentIndex: index,
            hourly: estimatedHours,
            daily: []
        )

        liveUVAccessState = accessState
        self.errorMessage = errorMessage
        currentReading = UVReading(index: index, timestamp: now, source: .localEstimate)
        lastBundle = nil
        protectionWindow = estimatedBundle.protectionWindow(for: now)
        status = SunclubUVStatus(
            availability: .available,
            source: source,
            freshness: .estimated,
            updatedAt: now
        )
    }

    func setForTestingCurrentReading(_ reading: UVReading?) {
        currentReading = reading
    }

}
