import CoreLocation
import Foundation
import Observation
#if canImport(WeatherKit)
import WeatherKit
#endif

@MainActor
@Observable
final class UVIndexService {
    private(set) var currentReading: UVReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var liveUVAccessState: LiveUVAccessState = .disabled

    private let locationService: SharedLocationManaging
    private var lastKnownLatitude: Double?
    #if canImport(WeatherKit)
    private let weatherService = WeatherService()
    #endif

    init(locationService: SharedLocationManaging? = nil) {
        self.locationService = locationService ?? SharedLocationManager.shared
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
                ? await locationService.requestWhenInUseAuthorizationIfNeeded()
                : locationService.authorizationStatus

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
        let location = try await locationService.currentLocation()
        lastKnownLatitude = location.coordinate.latitude
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
        Self.estimatedUVIndex(at: Date(), latitude: lastKnownLatitude)
    }

    nonisolated static func estimatedUVIndex(
        at date: Date,
        calendar: Calendar = .current,
        latitude: Double? = nil
    ) -> Int {
        let hour = calendar.component(.hour, from: date)
        let rawMonth = calendar.component(.month, from: date)

        // Shift months by 6 for Southern Hemisphere to invert seasonal mapping
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
