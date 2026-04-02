import CoreLocation
import Foundation
import Observation
#if canImport(WeatherKit)
import WeatherKit
#endif

enum UVLevel: Equatable {
    case low
    case moderate
    case high
    case veryHigh
    case extreme
    case unknown

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        case .extreme: return "Extreme"
        case .unknown: return "Unknown"
        }
    }

    var shortAdvice: String {
        switch self {
        case .low: return "Minimal protection needed."
        case .moderate: return "Wear sunscreen if outside for extended periods."
        case .high: return "Sunscreen strongly recommended today."
        case .veryHigh: return "Stay protected — UV is very high."
        case .extreme: return "Avoid midday sun. Reapply sunscreen frequently."
        case .unknown: return ""
        }
    }

    var symbolName: String {
        switch self {
        case .low: return "sun.min"
        case .moderate: return "sun.max"
        case .high: return "sun.max.fill"
        case .veryHigh: return "exclamationmark.triangle"
        case .extreme: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var shouldShowBanner: Bool {
        switch self {
        case .moderate, .high, .veryHigh, .extreme: return true
        default: return false
        }
    }

    var homeHeadline: String? {
        switch self {
        case .moderate: return "UV is moderate today"
        case .high: return "UV is high today"
        case .veryHigh: return "UV is very high today"
        case .extreme: return "UV is extreme today"
        default: return nil
        }
    }

    var reapplyAdvanceMinutes: Int {
        switch self {
        case .high:
            return 30
        case .veryHigh, .extreme:
            return 60
        default:
            return 0
        }
    }

    var strongerReapplyMessage: String? {
        switch self {
        case .high:
            return "UV is high today, so reapply sooner if you're outside."
        case .veryHigh:
            return "UV is very high today, so reapply sooner and stay covered."
        case .extreme:
            return "UV is extreme today, so reapply as early as you can and minimize direct sun."
        default:
            return nil
        }
    }

    var reapplyLabelPrefix: String? {
        switch self {
        case .high:
            return "High UV today"
        case .veryHigh:
            return "Very high UV today"
        case .extreme:
            return "Extreme UV today"
        default:
            return nil
        }
    }

    static func from(index: Int) -> UVLevel {
        switch index {
        case 0...2: return .low
        case 3...5: return .moderate
        case 6...7: return .high
        case 8...10: return .veryHigh
        case 11...: return .extreme
        default: return .unknown
        }
    }
}

enum UVReadingSource: Equatable {
    case heuristic
    case weatherKit

    var statusLabel: String {
        switch self {
        case .heuristic:
            return "Estimated locally"
        case .weatherKit:
            return "Live WeatherKit UV"
        }
    }
}

enum LiveUVAccessState: Equatable {
    case disabled
    case live
    case needsPermission
    case denied
    case unavailable
}

struct UVReading: Equatable {
    let index: Int
    let level: UVLevel
    let timestamp: Date
    let source: UVReadingSource

    init(
        index: Int,
        timestamp: Date = Date(),
        source: UVReadingSource = .heuristic
    ) {
        self.index = index
        self.level = UVLevel.from(index: index)
        self.timestamp = timestamp
        self.source = source
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }
}

@MainActor
@Observable
final class UVIndexService {
    private(set) var currentReading: UVReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var liveUVAccessState: LiveUVAccessState = .disabled

    private var locationProviderStorage: CurrentLocationProvider?
    #if canImport(WeatherKit)
    private let weatherService = WeatherService()
    #endif

    private var locationProvider: CurrentLocationProvider {
        if let locationProviderStorage {
            return locationProviderStorage
        }

        let provider = CurrentLocationProvider()
        locationProviderStorage = provider
        return provider
    }

    func fetchUVIndex(
        prefersLiveData: Bool,
        allowPermissionPrompt: Bool = false
    ) async {
        guard !isLoading else {
            return
        }

        if let currentReading,
           !currentReading.isStale,
           canReuse(currentReading: currentReading, prefersLiveData: prefersLiveData) {
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if prefersLiveData {
            let authorizationStatus = allowPermissionPrompt
                ? await locationProvider.requestAuthorizationIfNeeded()
                : locationProvider.authorizationStatus()

            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                do {
                    currentReading = try await fetchWeatherKitReading()
                    liveUVAccessState = .live
                    return
                } catch {
                    liveUVAccessState = .unavailable
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            case .notDetermined:
                liveUVAccessState = .needsPermission
            case .denied, .restricted:
                liveUVAccessState = .denied
            @unknown default:
                liveUVAccessState = .unavailable
            }
        } else {
            liveUVAccessState = .disabled
        }

        currentReading = UVReading(index: estimateUVFromTimeAndSeason(), source: .heuristic)
    }

    private func canReuse(
        currentReading: UVReading,
        prefersLiveData: Bool
    ) -> Bool {
        if prefersLiveData {
            return currentReading.source == .weatherKit
        }

        return currentReading.source == .heuristic
    }

    private func fetchWeatherKitReading() async throws -> UVReading {
        #if canImport(WeatherKit)
        let location = try await locationProvider.currentLocation()
        let weather = try await weatherService.weather(for: location)
        return UVReading(
            index: weather.currentWeather.uvIndex.value,
            source: .weatherKit
        )
        #else
        throw UVIndexServiceError.weatherKitUnavailable
        #endif
    }

    private func estimateUVFromTimeAndSeason() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let month = calendar.component(.month, from: now)

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

private enum UVIndexServiceError: LocalizedError {
    case weatherKitUnavailable
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .weatherKitUnavailable:
            return "WeatherKit is unavailable on this build."
        case .locationUnavailable:
            return "Sunclub could not determine your location for live UV."
        }
    }
}

@MainActor
private final class CurrentLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func authorizationStatus() -> CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .restricted
        }

        let status = manager.authorizationStatus
        guard status == .notDetermined else {
            return status
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw UVIndexServiceError.locationUnavailable
        }

        if let location = manager.location,
           abs(location.timestamp.timeIntervalSinceNow) < 1800 {
            return location
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume(returning: manager.authorizationStatus)
        authorizationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(throwing: UVIndexServiceError.locationUnavailable)
            locationContinuation = nil
            return
        }

        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
