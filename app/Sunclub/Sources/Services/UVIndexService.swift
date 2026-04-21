import CoreLocation
import Foundation
import Observation

@MainActor
protocol LiveUVWeatherProviding: AnyObject {
    func currentUVIndex(for location: CLLocation) async throws -> Int
    func hourlyUVForecast(
        for location: CLLocation,
        referenceDate: Date,
        calendar: Calendar
    ) async throws -> [SunclubUVHourForecast]
}

@MainActor
final class WeatherKitLiveUVWeatherProvider: LiveUVWeatherProviding {
    func currentUVIndex(for location: CLLocation) async throws -> Int {
        _ = location
        throw UVIndexServiceError.liveUVUnavailable
    }

    func hourlyUVForecast(
        for location: CLLocation,
        referenceDate: Date,
        calendar: Calendar
    ) async throws -> [SunclubUVHourForecast] {
        _ = location
        _ = referenceDate
        _ = calendar
        throw UVIndexServiceError.liveUVUnavailable
    }
}

@MainActor
@Observable
final class UVIndexService {
    private(set) var currentReading: UVReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var liveUVAccessState: LiveUVAccessState = .disabled

    private let locationService: SharedLocationManaging
    private let weatherProvider: any LiveUVWeatherProviding

    init(
        locationService: SharedLocationManaging? = nil,
        weatherProvider: (any LiveUVWeatherProviding)? = nil
    ) {
        self.locationService = locationService ?? SharedLocationManager.shared
        self.weatherProvider = weatherProvider ?? WeatherKitLiveUVWeatherProvider()
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
            _ = allowPermissionPrompt
            _ = locationService
            _ = weatherProvider
            liveUVAccessState = .unavailable
            errorMessage = UVIndexServiceError.liveUVUnavailable.localizedDescription
        } else {
            liveUVAccessState = .disabled
        }

        currentReading = UVReading(index: estimateUVFromTimeAndSeason(), source: .heuristic)
    }

    private func canReuse(
        currentReading: UVReading,
        prefersLiveData: Bool
    ) -> Bool {
        _ = prefersLiveData
        return currentReading.source == .heuristic
    }

    private func estimateUVFromTimeAndSeason() -> Int {
        Self.estimatedUVIndex(at: Date())
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
    case liveUVUnavailable

    var errorDescription: String? {
        switch self {
        case .liveUVUnavailable:
            return "Live UV is unavailable in this release."
        }
    }
}
