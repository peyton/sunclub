import CoreLocation
import Foundation
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
                sourceLabel: "Apple Weather"
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
    private(set) var currentReading: UVReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var liveUVAccessState: LiveUVAccessState = .disabled
    private(set) var lastBundle: SunclubUVForecastBundle?
    private(set) var attribution: SunclubWeatherAttribution?

    private let locationService: SharedLocationManaging
    private let weatherProvider: any LiveUVWeatherProviding
    private let cache: SunclubUVForecastCache
    private var inFlightTask: Task<SunclubUVForecastBundle?, Never>?

    init(
        locationService: SharedLocationManaging? = nil,
        weatherProvider: (any LiveUVWeatherProviding)? = nil,
        cache: SunclubUVForecastCache? = nil
    ) {
        self.locationService = locationService ?? SharedLocationManager.shared
        self.weatherProvider = weatherProvider ?? WeatherKitLiveUVWeatherProvider()
        self.cache = cache ?? SunclubUVForecastCache()
        self.lastBundle = self.cache.lastBundle()
        if let cachedIndex = self.lastBundle?.currentIndex {
            self.currentReading = UVReading(
                index: cachedIndex,
                timestamp: self.lastBundle?.generatedAt ?? Date(),
                source: .weatherKit
            )
        }
    }

    /// Fetches a UV bundle (current + hourly + daily).
    /// - Parameters:
    ///   - prefersLiveData: user setting; when false, falls back to heuristic.
    ///   - allowPermissionPrompt: only true on explicit user action (tapping "Enable Live UV").
    ///   - now: injected for tests.
    /// This is the single entry point — it returns fast if the cache is fresh for the
    /// current location. Background launches and widget refreshes should NOT call this;
    /// they should read `lastBundle` only.
    func fetchUVIndex(
        prefersLiveData: Bool,
        allowPermissionPrompt: Bool = false,
        now: Date = Date()
    ) async {
        guard !isLoading else {
            return
        }

        if !prefersLiveData {
            liveUVAccessState = .disabled
            currentReading = UVReading(
                index: Self.estimatedUVIndex(at: now),
                timestamp: now,
                source: .heuristic
            )
            return
        }

        if let cached = lastBundleIfLive(now: now) {
            applyBundle(cached)
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if allowPermissionPrompt {
            _ = await locationService.requestWhenInUseAuthorizationIfNeeded()
        }

        let status = locationService.authorizationStatus
        switch status {
        case .denied, .restricted:
            liveUVAccessState = .denied
            currentReading = UVReading(
                index: Self.estimatedUVIndex(at: now),
                timestamp: now,
                source: .heuristic
            )
            return
        case .notDetermined:
            liveUVAccessState = .needsPermission
            currentReading = UVReading(
                index: Self.estimatedUVIndex(at: now),
                timestamp: now,
                source: .heuristic
            )
            return
        default:
            break
        }

        do {
            let location = try await locationService.currentLocation()

            if let fresh = cache.freshBundle(for: location, now: now) {
                applyBundle(fresh)
                return
            }

            let bundle = try await weatherProvider.uvBundle(for: location, referenceDate: now)
            cache.store(bundle)
            applyBundle(bundle)
            liveUVAccessState = .live

            if attribution == nil {
                attribution = try? await weatherProvider.attributionMarkup()
            }
        } catch {
            liveUVAccessState = .unavailable
            errorMessage = error.localizedDescription
            currentReading = UVReading(
                index: Self.estimatedUVIndex(at: now),
                timestamp: now,
                source: .heuristic
            )
        }
    }

    private func lastBundleIfLive(now: Date) -> SunclubUVForecastBundle? {
        guard let lastBundle else {
            return nil
        }
        return lastBundle.isFresh(now: now, ttl: 60 * 30) ? lastBundle : nil
    }

    private func applyBundle(_ bundle: SunclubUVForecastBundle) {
        lastBundle = bundle
        if let index = bundle.currentIndex {
            currentReading = UVReading(
                index: index,
                timestamp: bundle.generatedAt,
                source: .weatherKit
            )
        }
        liveUVAccessState = .live
    }

    func setForTestingCurrentReading(_ reading: UVReading?) {
        currentReading = reading
    }

    nonisolated static func estimatedUVIndex(
        at date: Date,
        calendar: Calendar = .current,
        latitude: Double? = nil
    ) -> Int {
        let hour = calendar.component(.hour, from: date)
        let rawMonth = calendar.component(.month, from: date)

        let isSouthernHemisphere = latitude.map { $0 < 0 } ?? false
        let month = isSouthernHemisphere ? ((rawMonth + 5) % 12) + 1 : rawMonth

        let seasonalBase: Int
        switch month {
        case 6, 7, 8:
            seasonalBase = 8
        case 5, 9:
            seasonalBase = 6
        case 4, 10:
            seasonalBase = 4
        case 3, 11:
            seasonalBase = 3
        default:
            seasonalBase = 2
        }

        let timeMultiplier: Double
        switch hour {
        case 0...5: timeMultiplier = 0.0
        case 6: timeMultiplier = 0.1
        case 7: timeMultiplier = 0.2
        case 8: timeMultiplier = 0.4
        case 9: timeMultiplier = 0.6
        case 10: timeMultiplier = 0.8
        case 11, 12, 13: timeMultiplier = 1.0
        case 14: timeMultiplier = 0.9
        case 15: timeMultiplier = 0.7
        case 16: timeMultiplier = 0.5
        case 17: timeMultiplier = 0.3
        case 18: timeMultiplier = 0.1
        default: timeMultiplier = 0.0
        }

        return max(0, Int(Double(seasonalBase) * timeMultiplier))
    }
}
