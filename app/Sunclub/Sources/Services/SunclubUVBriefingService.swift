import CoreLocation
import Foundation

@MainActor
final class SunclubUVBriefingService {
    private let locationService: SharedLocationManaging
    private let weatherProvider: any LiveUVWeatherProviding

    init(
        locationService: SharedLocationManaging? = nil,
        weatherProvider: (any LiveUVWeatherProviding)? = nil
    ) {
        self.locationService = locationService ?? SharedLocationManager.shared
        self.weatherProvider = weatherProvider ?? WeatherKitLiveUVWeatherProvider()
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

        return makeForecast(
            generatedAt: referenceDate,
            sourceLabel: "Estimated locally",
            hours: hours
        )
    }

    private func dayHours(for date: Date, calendar: Calendar) -> [Date] {
        let dayStart = calendar.startOfDay(for: date)
        return (6...18).compactMap { hour in
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)
        }
    }

    private func liveForecast(
        referenceDate: Date,
        calendar: Calendar
    ) async -> SunclubUVForecast? {
        do {
            let location = try await locationService.currentLocation()
            let hours = try await weatherProvider.hourlyUVForecast(
                for: location,
                referenceDate: referenceDate,
                calendar: calendar
            )
            guard !hours.isEmpty else {
                return nil
            }

            return makeForecast(
                generatedAt: referenceDate,
                sourceLabel: "Live WeatherKit UV",
                hours: hours
            )
        } catch {
            return nil
        }
    }

    private func makeForecast(
        generatedAt: Date,
        sourceLabel: String,
        hours: [SunclubUVHourForecast]
    ) -> SunclubUVForecast {
        let peakHour = hours.max(by: { $0.index < $1.index })
        return SunclubUVForecast(
            generatedAt: generatedAt,
            sourceLabel: sourceLabel,
            hours: hours,
            peakHour: peakHour,
            recommendation: recommendation(for: peakHour?.level ?? .unknown)
        )
    }

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
