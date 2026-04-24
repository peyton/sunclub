import ActivityKit
import Foundation

@MainActor
protocol SunclubLiveActivityCoordinating: AnyObject {
    func sync(using state: AppState) async
    func endAll() async
}

@MainActor
final class SunclubLiveActivityCoordinator: SunclubLiveActivityCoordinating {
    static let shared = SunclubLiveActivityCoordinator()

    func sync(using state: AppState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        guard let record = state.record(for: state.currentDateValue),
              let uvPayload = Self.compactSurfaceUVPayload(
                reading: state.uvReading,
                forecast: state.uvForecast,
                now: state.currentDateValue
              ) else {
            await endAll()
            return
        }

        guard uvPayload.level == .high || uvPayload.level == .veryHigh || uvPayload.level == .extreme else {
            await endAll()
            return
        }

        let countdownLabel: String
        if let deadline = state.reapplyReminderPlan.fireDate ?? state.uvForecast?.peakHour?.date {
            countdownLabel = deadline.formatted(date: .omitted, time: .shortened)
        } else {
            countdownLabel = "Later today"
        }

        let lastAppliedLabel = record.verifiedAt.formatted(date: .omitted, time: .shortened)
        let contentState = SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: uvPayload.currentUVIndex,
            peakUVIndex: uvPayload.peakUVIndex,
            countdownLabel: countdownLabel,
            lastAppliedLabel: lastAppliedLabel,
            streakLabel: "\(state.currentStreak)d streak"
        )

        let attributes = SunclubLiveActivityAttributes(headline: "Sunclub UV Guard")
        let content = ActivityContent(state: contentState, staleDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date()))

        if let existing = Activity<SunclubLiveActivityAttributes>.activities.first {
            await existing.update(content)
        } else {
            do {
                _ = try Activity<SunclubLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                return
            }
        }
    }

    func endAll() async {
        for activity in Activity<SunclubLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .default)
        }
    }

    static func compactSurfaceUVPayload(
        reading: UVReading?,
        forecast: SunclubUVForecast?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SunclubLiveActivityUVPayload? {
        guard let reading,
              let forecast,
              let peakHour = compactSurfacePeakHour(from: forecast, now: now, calendar: calendar) else {
            return nil
        }
        let currentReading = compactSurfaceReading(from: reading, now: now, calendar: calendar)

        return SunclubLiveActivityUVPayload(
            currentUVIndex: currentReading.index,
            peakUVIndex: peakHour.index,
            level: currentReading.level
        )
    }

    private static func compactSurfaceReading(
        from reading: UVReading,
        now: Date,
        calendar: Calendar
    ) -> UVReading {
        guard reading.source == .weatherKit else {
            return reading
        }

        return UVReading(
            index: SunclubUVEstimator.estimatedIndex(at: now, calendar: calendar),
            timestamp: now,
            source: .heuristic
        )
    }

    private static func compactSurfacePeakHour(
        from forecast: SunclubUVForecast,
        now: Date,
        calendar: Calendar
    ) -> SunclubUVHourForecast? {
        guard forecast.sourceLabel == UVReadingSource.weatherKit.forecastLabel else {
            return forecast.peakHour
        }

        let dayStart = calendar.startOfDay(for: now)
        return (6...18)
            .compactMap { hour in
                calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)
            }
            .map { hourDate in
                SunclubUVHourForecast(
                    date: hourDate,
                    index: SunclubUVEstimator.estimatedIndex(at: hourDate, calendar: calendar),
                    sourceLabel: UVReadingSource.heuristic.hourlySourceLabel
                )
            }
            .max(by: { $0.index < $1.index })
    }
}

struct SunclubLiveActivityUVPayload: Equatable {
    let currentUVIndex: Int
    let peakUVIndex: Int
    let level: UVLevel
}

private extension AppState {
    var currentDateValue: Date {
        Date()
    }
}
