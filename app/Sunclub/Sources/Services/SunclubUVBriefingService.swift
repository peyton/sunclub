import CoreLocation
import Foundation
#if canImport(WeatherKit)
import WeatherKit
#endif

@MainActor
final class SunclubUVBriefingService {
    private let locationService: SharedLocationManaging
    #if canImport(WeatherKit)
    private let weatherService = WeatherService()
    #endif

    init(locationService: SharedLocationManaging? = nil) {
        self.locationService = locationService ?? SharedLocationManager.shared
    }

    func forecast(
        prefersLiveData: Bool,
        allowPermissionPrompt: Bool = false,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) async -> SunclubUVForecast {
        if prefersLiveData {
            let authorizationStatus = allowPermissionPrompt
                ? await locationService.requestWhenInUseAuthorizationIfNeeded()
                : locationService.authorizationStatus

            switch authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                if let liveForecast = await liveForecast(referenceDate: referenceDate, calendar: calendar) {
                    return liveForecast
                }
            default:
                break
            }
        }

        return heuristicForecast(referenceDate: referenceDate, calendar: calendar)
    }

    func notificationForecast(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> SunclubUVForecast {
        heuristicForecast(referenceDate: referenceDate, calendar: calendar)
    }

    private func heuristicForecast(
        referenceDate: Date,
        calendar: Calendar
    ) -> SunclubUVForecast {
        let hours = dayHours(for: referenceDate, calendar: calendar).map { hourDate in
            SunclubUVHourForecast(
                date: hourDate,
                index: UVIndexService.estimatedUVIndex(at: hourDate, calendar: calendar),
                sourceLabel: "Estimated"
            )
        }

        return SunclubUVForecast(
            generatedAt: referenceDate,
            sourceLabel: "Estimated locally",
            hours: hours,
            peakHour: hours.max(by: { $0.index < $1.index }),
            recommendation: recommendation(for: hours.max(by: { $0.index < $1.index })?.level ?? .unknown)
        )
    }

    private func dayHours(for date: Date, calendar: Calendar) -> [Date] {
        let dayStart = calendar.startOfDay(for: date)
        return (6...18).compactMap { hour in
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)
        }
    }

    #if canImport(WeatherKit)
    private func liveForecast(
        referenceDate: Date,
        calendar: Calendar
    ) async -> SunclubUVForecast? {
        do {
            let location = try await locationService.currentLocation()
            let weather = try await weatherService.weather(for: location)
            let dayStart = calendar.startOfDay(for: referenceDate)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let hours = weather.hourlyForecast.forecast
                .filter { $0.date >= dayStart && $0.date < nextDay && $0.isDaylight }
                .map {
                    SunclubUVHourForecast(
                        date: $0.date,
                        index: $0.uvIndex.value,
                        sourceLabel: "WeatherKit"
                    )
                }

            return SunclubUVForecast(
                generatedAt: referenceDate,
                sourceLabel: "Live WeatherKit UV",
                hours: hours,
                peakHour: hours.max(by: { $0.index < $1.index }),
                recommendation: recommendation(for: hours.max(by: { $0.index < $1.index })?.level ?? .unknown)
            )
        } catch {
            return nil
        }
    }
    #endif

    private func recommendation(for level: UVLevel) -> String {
        switch level {
        case .low:
            return "Low UV today. Light coverage is usually enough unless you are outside for hours."
        case .moderate:
            return "Moderate UV today. Log sunscreen before extended outdoor time."
        case .high:
            return "High UV today. Apply early and plan a faster reapply window."
        case .veryHigh:
            return "Very high UV today. Stay covered and avoid the brightest midday window."
        case .extreme:
            return "Extreme UV today. Treat this as a high-alert protection day."
        case .unknown:
            return "Use Sunclub's daily check-in to stay protected."
        }
    }
}
