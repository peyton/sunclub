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
    nonisolated static let verifiedDataMaxAge: TimeInterval = 2 * 60 * 60

    private(set) var currentReading: UVReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var liveUVAccessState: LiveUVAccessState = .disabled
    private(set) var lastBundle: SunclubUVForecastBundle?
    private(set) var attribution: SunclubWeatherAttribution?
    private(set) var status: SunclubUVStatus = .unavailable
    private(set) var protectionWindow: SunclubUVProtectionWindow?

    private let locationService: SharedLocationManaging
    private let weatherProvider: any LiveUVWeatherProviding
    private let cache: SunclubUVForecastCache
    private let budget: SunclubWeatherKitBudget
    private let networkPathProvider: () -> NWPath?
    private var inFlightTask: Task<SunclubUVForecastBundle?, Never>?

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
        guard !isLoading else {
            return
        }

        errorMessage = nil

        if !prefersLiveData, let selectedPlace {
            isLoading = true
            defer { isLoading = false }
            await fetchWeather(
                for: CLLocation(latitude: selectedPlace.latitude, longitude: selectedPlace.longitude),
                source: .selectedPlace(displayName: selectedPlace.displayName),
                now: now
            )
            return
        }

        guard prefersLiveData else {
            applyUnavailable(accessState: .disabled)
            return
        }

        isLoading = true
        defer { isLoading = false }

        if allowPermissionPrompt {
            _ = await locationService.requestWhenInUseAuthorizationIfNeeded()
        }

        guard let resolvedLocation = await preferredLocation(selectedPlace: selectedPlace) else {
            return
        }
        await fetchWeather(
            for: resolvedLocation.location,
            source: resolvedLocation.source,
            now: now
        )
    }

    private func preferredLocation(
        selectedPlace: SunclubSelectedUVPlace?
    ) async -> (location: CLLocation, source: SunclubUVLocationSource)? {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            if let selectedPlace {
                return selectedLocation(for: selectedPlace)
            }
            applyUnavailable(accessState: .denied, source: .liveLocation)
            return nil
        case .notDetermined:
            if let selectedPlace {
                return selectedLocation(for: selectedPlace)
            }
            applyUnavailable(accessState: .needsPermission, source: .liveLocation)
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
            applyUnavailable(
                accessState: .unavailable,
                source: .liveLocation,
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
        if let cached = cache.freshBundle(for: location, now: now),
           cached.isFresh(now: now, ttl: Self.verifiedDataMaxAge) {
            applyBundle(cached, source: source, now: now)
            return
        }

        if let path = networkPathProvider(), path.isConstrained {
            applyUnavailable(
                accessState: .unavailable,
                source: source,
                location: location,
                errorMessage: "UV data is unavailable in Low Data Mode."
            )
            return
        }

        switch budget.check(now: now) {
        case .allow:
            break
        case .deny(let reason):
            applyUnavailable(
                accessState: .unavailable,
                source: source,
                location: location,
                errorMessage: reason
            )
            return
        }

        do {
            let bundle = try await weatherProvider.uvBundle(for: location, referenceDate: now)
            budget.recordFetch(at: now)
            cache.store(bundle)
            applyBundle(bundle, source: source, now: now)

            if attribution == nil {
                attribution = try? await weatherProvider.attributionMarkup()
            }
        } catch {
            applyUnavailable(
                accessState: .unavailable,
                source: source,
                location: location,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func applyBundle(
        _ bundle: SunclubUVForecastBundle,
        source: SunclubUVLocationSource,
        now: Date
    ) {
        lastBundle = bundle
        if let index = bundle.currentIndex {
            currentReading = UVReading(
                index: index,
                timestamp: bundle.generatedAt,
                source: .weatherKit
            )
        } else {
            currentReading = nil
        }
        liveUVAccessState = .live
        errorMessage = nil
        status = SunclubUVStatus(
            availability: .available,
            source: source,
            freshness: .fresh,
            updatedAt: bundle.generatedAt
        )
        protectionWindow = bundle.protectionWindow(for: now)
    }

    private func applyUnavailable(
        accessState: LiveUVAccessState,
        source: SunclubUVLocationSource? = nil,
        location: CLLocation? = nil,
        errorMessage: String? = nil
    ) {
        let cached = cache.lastBundle()
        let matchesLocation: Bool
        if let cached, let location {
            let cachedLocation = CLLocation(latitude: cached.latitude, longitude: cached.longitude)
            matchesLocation = cachedLocation.distance(from: location) <= 5_000
        } else {
            matchesLocation = false
        }
        if !matchesLocation {
            cache.clear()
        }

        liveUVAccessState = accessState
        self.errorMessage = errorMessage
        currentReading = nil
        lastBundle = nil
        protectionWindow = nil
        status = SunclubUVStatus(
            availability: .unavailable,
            source: source,
            freshness: matchesLocation ? .stale : .unavailable,
            updatedAt: matchesLocation ? cached?.generatedAt : nil
        )
    }

    func setForTestingCurrentReading(_ reading: UVReading?) {
        currentReading = reading
    }

}
