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
        readingSource: UVReadingSource? = nil,
        fallbackLatitude: Double? = nil,
        allowPermissionPrompt: Bool = false,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) async -> SunclubUVForecast {
        _ = allowPermissionPrompt

        _ = prefersLiveData
        if readingSource?.isAppleWeather == true,
           let liveBundle,
           liveBundle.isFresh(now: referenceDate, ttl: UVIndexService.lastKnownDataMaxAge),
           let forecast = weatherForecast(
               from: liveBundle,
               source: weatherSource(
                   for: liveBundle,
                   readingSource: readingSource,
                   referenceDate: referenceDate
               ),
               referenceDate: referenceDate,
               calendar: calendar
           ) {
            return forecast
        }

        return localForecast(
            referenceDate: referenceDate,
            calendar: calendar,
            latitude: fallbackLatitude ?? liveBundle?.latitude
        )
    }

    func notificationForecast(
        referenceDate: Date,
        readingSource: UVReadingSource?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SunclubUVForecast {
        guard readingSource?.isAppleWeather == true,
              let bundle = cache.lastBundle(),
              bundle.isFresh(now: now, ttl: UVIndexService.verifiedDataMaxAge),
              let forecast = weatherForecast(
                  from: bundle,
                  source: .cachedWeatherKit,
                  referenceDate: referenceDate,
                  calendar: calendar
              ) else {
            return .unavailable(generatedAt: referenceDate)
        }
        return forecast
    }

    private func weatherSource(
        for bundle: SunclubUVForecastBundle,
        readingSource: UVReadingSource?,
        referenceDate: Date
    ) -> UVReadingSource {
        guard bundle.isFresh(now: referenceDate, ttl: UVIndexService.verifiedDataMaxAge) else {
            return .cachedWeatherKit
        }
        return readingSource == .cachedWeatherKit ? .cachedWeatherKit : .weatherKit
    }

    private func weatherForecast(
        from bundle: SunclubUVForecastBundle,
        source: UVReadingSource,
        referenceDate: Date,
        calendar: Calendar
    ) -> SunclubUVForecast? {
        let todayHours = bundle.hourly.filter {
            calendar.isDate($0.date, inSameDayAs: referenceDate)
        }.map {
            SunclubUVHourForecast(
                date: $0.date,
                index: $0.index,
                sourceLabel: source.hourlySourceLabel
            )
        }
        guard !todayHours.isEmpty else {
            return nil
        }

        let peak = todayHours.max(by: { $0.index < $1.index })
        return SunclubUVForecast(
            generatedAt: bundle.generatedAt,
            sourceLabel: source.forecastLabel,
            hours: todayHours,
            peakHour: peak,
            recommendation: recommendation(for: peak?.level ?? .unknown)
        )
    }

    private func localForecast(
        referenceDate: Date,
        calendar: Calendar,
        latitude: Double?
    ) -> SunclubUVForecast {
        let hours = SunclubUVEstimator.hourlyForecast(
            for: referenceDate,
            calendar: calendar,
            latitude: latitude
        )
        let peak = hours.max(by: { $0.index < $1.index })
        return SunclubUVForecast(
            generatedAt: referenceDate,
            sourceLabel: UVReadingSource.localEstimate.forecastLabel,
            hours: hours,
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
