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

        let now = state.currentDateValue
        let reapplyPlan = state.reapplyReminderPlan
        let reapplyStartDate = record.lastReappliedAt ?? record.verifiedAt
        guard state.settings.reapplyReminderEnabled,
              let reapplyDeadline = ReminderPlanner.reapplyFireDate(
                from: reapplyStartDate,
                intervalMinutes: reapplyPlan.intervalMinutes
              ) else {
            await endAll()
            return
        }

        let contentState = Self.contentState(
            record: record,
            uvPayload: uvPayload,
            reapplyStartDate: reapplyStartDate,
            reapplyDeadline: reapplyDeadline,
            now: now
        )

        let attributes = SunclubLiveActivityAttributes(headline: "Reapply timer")
        let content = ActivityContent(state: contentState, staleDate: uvPayload.validUntil)

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

    func snoozeAll(until deadline: Date, now: Date = Date()) async {
        for activity in Activity<SunclubLiveActivityAttributes>.activities {
            let state = Self.snoozedContentState(activity.content.state, until: deadline, now: now)
            let timerStaleDate = Calendar.current.date(byAdding: .hour, value: 1, to: deadline)
            let staleDate = [state.uvValidUntil, timerStaleDate].compactMap { $0 }.min()
            let content = ActivityContent(
                state: state,
                staleDate: staleDate
            )
            await activity.update(content)
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
              let currentReading = compactSurfaceReading(from: reading, now: now, calendar: calendar),
              let peakHour = compactSurfacePeakHour(from: forecast, now: now, calendar: calendar) else {
            return nil
        }

        return SunclubLiveActivityUVPayload(
            currentUVIndex: currentReading.index,
            peakUVIndex: peakHour.index,
            level: currentReading.level,
            validUntil: min(
                currentReading.timestamp.addingTimeInterval(UVIndexService.verifiedDataMaxAge),
                forecast.generatedAt.addingTimeInterval(UVIndexService.verifiedDataMaxAge)
            )
        )
    }

    static func reapplyCountdownLabel(deadline: Date, now: Date) -> String {
        if deadline <= now {
            return "due"
        }

        let minutesUntilDeadline = max(1, Int(ceil(deadline.timeIntervalSince(now) / 60)))
        let hours = minutesUntilDeadline / 60
        let minutes = minutesUntilDeadline % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "in \(minutes)m"
        case (let hours, 0):
            return "in \(hours)h"
        default:
            return "in \(hours)h \(minutes)m"
        }
    }

    static func lastLogDetail(for record: DailyRecord) -> String {
        record.spfLevel.map { "SPF \($0)" } ?? "Logged"
    }

    static func contentState(
        record: DailyRecord,
        uvPayload: SunclubLiveActivityUVPayload,
        reapplyStartDate: Date,
        reapplyDeadline: Date,
        now: Date
    ) -> SunclubLiveActivityAttributes.ContentState {
        SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: uvPayload.currentUVIndex,
            peakUVIndex: uvPayload.peakUVIndex,
            countdownLabel: Self.reapplyCountdownLabel(deadline: reapplyDeadline, now: now),
            lastAppliedLabel: record.verifiedAt.formatted(date: .omitted, time: .shortened),
            lastLogDetail: Self.lastLogDetail(for: record),
            reapplyStartDate: reapplyStartDate,
            reapplyDeadline: reapplyDeadline,
            uvValidUntil: uvPayload.validUntil
        )
    }

    static func snoozedContentState(
        _ state: SunclubLiveActivityAttributes.ContentState,
        until deadline: Date,
        now: Date
    ) -> SunclubLiveActivityAttributes.ContentState {
        var updated = state
        updated.countdownLabel = reapplyCountdownLabel(deadline: deadline, now: now)
        updated.reapplyStartDate = now
        updated.reapplyDeadline = deadline
        return updated
    }

    private static func compactSurfaceReading(
        from reading: UVReading,
        now: Date,
        calendar: Calendar
    ) -> UVReading? {
        _ = calendar
        guard reading.source == .weatherKit,
              reading.isFresh(at: now, maxAge: UVIndexService.verifiedDataMaxAge) else {
            return nil
        }
        return reading
    }

    private static func compactSurfacePeakHour(
        from forecast: SunclubUVForecast,
        now: Date,
        calendar: Calendar
    ) -> SunclubUVHourForecast? {
        _ = calendar
        let age = now.timeIntervalSince(forecast.generatedAt)
        guard forecast.sourceLabel == UVReadingSource.weatherKit.forecastLabel,
              age >= 0,
              age <= UVIndexService.verifiedDataMaxAge else {
            return nil
        }
        return forecast.peakHour
    }
}

struct SunclubLiveActivityUVPayload: Equatable {
    let currentUVIndex: Int
    let peakUVIndex: Int
    let level: UVLevel
    let validUntil: Date

    init(
        currentUVIndex: Int,
        peakUVIndex: Int,
        level: UVLevel,
        validUntil: Date = .distantFuture
    ) {
        self.currentUVIndex = currentUVIndex
        self.peakUVIndex = peakUVIndex
        self.level = level
        self.validUntil = validUntil
    }
}

private extension AppState {
    var currentDateValue: Date {
        Date()
    }
}
