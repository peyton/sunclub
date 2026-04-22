import CoreLocation
import Foundation

#if DEBUG
@MainActor
struct UITestLiveUVFixture {
    let locationService: UITestLiveUVLocationService
    let weatherProvider: UITestLiveUVWeatherProvider

    static func make(arguments: [String]) -> UITestLiveUVFixture? {
        guard RuntimeEnvironment.isUITesting,
              let currentIndex = integerArgument("UITEST_LIVE_UV_INDEX=", from: arguments) else {
            return nil
        }

        let latitude = doubleArgument("UITEST_LIVE_UV_LATITUDE=", from: arguments) ?? 34.116
        let longitude = doubleArgument("UITEST_LIVE_UV_LONGITUDE=", from: arguments) ?? -118.150
        let authorizationStatus = authorizationStatusArgument(from: arguments)
        let peakIndex = integerArgument("UITEST_LIVE_UV_PEAK_INDEX=", from: arguments)
            ?? min(12, max(currentIndex, currentIndex + 2))

        return UITestLiveUVFixture(
            locationService: UITestLiveUVLocationService(
                authorizationStatus: authorizationStatus,
                location: CLLocation(latitude: latitude, longitude: longitude)
            ),
            weatherProvider: UITestLiveUVWeatherProvider(
                currentIndex: currentIndex,
                peakIndex: peakIndex,
                shouldFail: arguments.contains("UITEST_LIVE_UV_FAIL"),
                shouldReturnEmptyForecast: arguments.contains("UITEST_LIVE_UV_EMPTY_FORECAST")
            )
        )
    }

    private static func integerArgument(_ prefix: String, from arguments: [String]) -> Int? {
        argument(prefix, from: arguments).flatMap(Int.init)
    }

    private static func doubleArgument(_ prefix: String, from arguments: [String]) -> Double? {
        argument(prefix, from: arguments).flatMap(Double.init)
    }

    private static func argument(_ prefix: String, from arguments: [String]) -> String? {
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }

        return String(argument.dropFirst(prefix.count))
    }

    private static func authorizationStatusArgument(from arguments: [String]) -> CLAuthorizationStatus {
        switch argument("UITEST_LIVE_UV_AUTH=", from: arguments) {
        case "denied":
            return .denied
        case "restricted":
            return .restricted
        case "notDetermined":
            return .notDetermined
        case "always":
            return .authorizedAlways
        default:
            return .authorizedWhenInUse
        }
    }
}

@MainActor
final class UITestLiveUVLocationService: SharedLocationManaging {
    var authorizationStatus: CLAuthorizationStatus
    var eventHandler: ((SharedLocationEvent) -> Void)?

    private let location: CLLocation

    init(
        authorizationStatus: CLAuthorizationStatus,
        location: CLLocation
    ) {
        self.authorizationStatus = authorizationStatus
        self.location = location
    }

    func requestWhenInUseAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        authorizationStatus
    }

    func requestAlwaysAuthorizationIfNeeded() async -> CLAuthorizationStatus {
        authorizationStatus
    }

    func currentLocation() async throws -> CLLocation {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return location
        case .denied, .restricted:
            throw SharedLocationError.permissionDenied
        case .notDetermined:
            throw SharedLocationError.locationUnavailable
        @unknown default:
            throw SharedLocationError.locationUnavailable
        }
    }

    func monitoredRegion(withIdentifier identifier: String) -> CLCircularRegion? {
        nil
    }

    func startMonitoring(region: CLCircularRegion) {}

    func stopMonitoring(regionIdentifier: String) {}

    func requestState(for region: CLRegion) {}
}

@MainActor
final class UITestLiveUVWeatherProvider: LiveUVWeatherProviding {
    private let currentIndex: Int
    private let peakIndex: Int
    private let shouldFail: Bool
    private let shouldReturnEmptyForecast: Bool

    init(
        currentIndex: Int,
        peakIndex: Int,
        shouldFail: Bool = false,
        shouldReturnEmptyForecast: Bool = false
    ) {
        self.currentIndex = currentIndex
        self.peakIndex = peakIndex
        self.shouldFail = shouldFail
        self.shouldReturnEmptyForecast = shouldReturnEmptyForecast
    }

    func uvBundle(for location: CLLocation, referenceDate: Date) async throws -> SunclubUVForecastBundle {
        if shouldFail {
            throw UITestLiveUVError.unavailable
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let hourlyIndexes: [(hour: Int, index: Int)] = shouldReturnEmptyForecast
            ? []
            : [
                (hour: 9, index: max(0, currentIndex - 2)),
                (hour: 10, index: currentIndex),
                (hour: 12, index: peakIndex),
                (hour: 15, index: max(0, currentIndex - 1))
            ]

        let hours: [SunclubUVHourForecast] = hourlyIndexes.compactMap { hour, index in
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) else {
                return nil
            }
            return SunclubUVHourForecast(
                date: date,
                index: index,
                sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
            )
        }

        let days: [SunclubUVDayForecast] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: dayStart) else {
                return nil
            }
            let index = offset == 0 ? peakIndex : max(0, peakIndex - offset)
            return SunclubUVDayForecast(day: date, maxIndex: index)
        }

        return SunclubUVForecastBundle(
            generatedAt: referenceDate,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            currentIndex: currentIndex,
            hourly: hours,
            daily: days
        )
    }

    func attributionMarkup() async throws -> SunclubWeatherAttribution {
        SunclubWeatherAttribution(
            serviceName: UVReadingSource.weatherKit.forecastLabel,
            legalPageURL: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!,
            lightMarkURL: nil,
            darkMarkURL: nil
        )
    }
}

private enum UITestLiveUVError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "UITest live UV fixture is unavailable."
    }
}
#endif
