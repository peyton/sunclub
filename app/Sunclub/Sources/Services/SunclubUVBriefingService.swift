import Foundation

@MainActor
final class SunclubUVBriefingService {
    private let cache: SunclubUVForecastCache

    init(
        locationService: SharedLocationManaging? = nil,
        weatherProvider: (any LiveUVWeatherProviding)? = nil,
        cache: SunclubUVForecastCache? = nil
    ) {
        _ = locationService
        _ = weatherProvider
        self.cache = cache ?? SunclubUVForecastCache()
    }

    func forecast(
        prefersLiveData: Bool,
        liveBundle: SunclubUVForecastBundle? = nil,
        allowPermissionPrompt: Bool = false,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) async -> SunclubUVForecast {
        _ = allowPermissionPrompt

        _ = prefersLiveData
        if let liveBundle,
           liveBundle.isFresh(now: referenceDate, ttl: UVIndexService.verifiedDataMaxAge),
           let forecast = liveForecast(from: liveBundle, referenceDate: referenceDate, calendar: calendar) {
            return forecast
        }

        return .unavailable(generatedAt: referenceDate)
    }

    func notificationForecast(
        referenceDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SunclubUVForecast {
        guard let bundle = cache.lastBundle(),
              bundle.isFresh(now: now, ttl: UVIndexService.verifiedDataMaxAge),
              let forecast = liveForecast(from: bundle, referenceDate: referenceDate, calendar: calendar) else {
            return .unavailable(generatedAt: referenceDate)
        }
        return forecast
    }

    private func liveForecast(
        from bundle: SunclubUVForecastBundle,
        referenceDate: Date,
        calendar: Calendar
    ) -> SunclubUVForecast? {
        let todayHours = bundle.hourly.filter {
            calendar.isDate($0.date, inSameDayAs: referenceDate)
        }
        guard !todayHours.isEmpty else {
            return nil
        }

        let peak = todayHours.max(by: { $0.index < $1.index })
        return SunclubUVForecast(
            generatedAt: bundle.generatedAt,
            sourceLabel: UVReadingSource.weatherKit.forecastLabel,
            hours: todayHours,
            peakHour: peak,
            recommendation: recommendation(for: peak?.level ?? .unknown)
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
            return "Use Sunclub's daily check-in to keep a clear log."
        }
    }
}
