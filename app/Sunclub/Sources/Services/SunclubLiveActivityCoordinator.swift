import ActivityKit
import Foundation
import UIKit

@MainActor
protocol SunclubLiveActivityCoordinating: AnyObject {
    func sync(using state: AppState) async
    func endAll() async
}

@MainActor
final class SunclubLiveActivityCoordinator: SunclubLiveActivityCoordinating {
    static let shared = SunclubLiveActivityCoordinator()

    func sync(using state: AppState) async {
        guard !RuntimeEnvironment.isRunningTests else { return }
        let now = state.referenceDate
        guard state.settings.smartReminderSettings.liveActivitiesEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return
        }
        if let id = state.pendingDepartureCheckInID, let date = state.pendingDepartureDate,
           date <= now, Calendar.current.isDate(date, inSameDayAs: now), state.record(for: now) == nil {
            await SunclubLiveActivitySessionStore.publish(
                SunclubLiveActivitySnapshotBridge.pendingContentState(id: id, departureDate: date),
                now: now, mayStart: UIApplication.shared.applicationState == .active
            )
            return
        }
        guard let record = state.record(for: now) else {
            await endAll()
            return
        }
        let uvPayload = Self.compactSurfaceUVPayload(
            reading: state.uvReading,
            forecast: state.uvForecast,
            now: now
        ) ?? SunclubLiveActivityUVPayload(
            currentUVIndex: 0,
            peakUVIndex: 0,
            level: .unknown,
            validUntil: .distantPast
        )

        let reapplyPlan = state.reapplyReminderPlan
        let reapplyStartDate = record.lastReappliedAt ?? record.verifiedAt
        guard reapplyStartDate <= now,
              Calendar.current.isDate(reapplyStartDate, inSameDayAs: now),
              let baselineDeadline = ReminderPlanner.reapplyFireDate(
                from: reapplyStartDate,
                intervalMinutes: reapplyPlan.intervalMinutes
              ) else {
            await endAll()
            return
        }

        let reapplyDeadline = SunclubLiveActivitySessionStore.deadline(
            applicationDate: reapplyStartDate, baseline: baselineDeadline, now: now
        )
        let contentState = Self.contentState(
            record: record,
            uvPayload: uvPayload,
            reapplyStartDate: reapplyStartDate,
            reapplyDeadline: reapplyDeadline,
            now: now
        )

        await publish(contentState, now: now)
    }

    private func publish(_ contentState: SunclubLiveActivityAttributes.ContentState, now: Date) async {
        await SunclubLiveActivitySessionStore.publish(contentState, now: now, mayStart: UIApplication.shared.applicationState == .active)
    }

    func endAll() async {
        await SunclubLiveActivitySessionStore.publish(nil, now: Date(), mayStart: false)
    }

    func snoozeAll(until deadline: Date, now: Date = Date(), applicationDate: Date? = nil) async {
        if let applicationDate {
            SunclubLiveActivitySessionStore.saveSnooze(applicationDate: applicationDate, deadline: deadline)
        }
        guard !RuntimeEnvironment.isRunningTests else { return }
        guard let activity = Activity<SunclubLiveActivityAttributes>.activities.first(where: {
            $0.activityState == .active || $0.activityState == .stale
        }), let start = activity.content.state.reapplyStartDate,
            applicationDate == nil || applicationDate == start,
            Calendar.current.isDate(start, inSameDayAs: now) else { return }
        SunclubLiveActivitySessionStore.saveSnooze(applicationDate: start, deadline: deadline)
        let state = Self.snoozedContentState(activity.content.state, until: deadline, now: now)
        await SunclubLiveActivitySessionStore.publish(state, now: now, mayStart: false)
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
            lastAppliedLabel: (record.lastReappliedAt ?? record.verifiedAt).formatted(date: .omitted, time: .shortened),
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
        updated.reapplyDeadline = deadline
        return updated
    }

    private static func compactSurfaceReading(
        from reading: UVReading,
        now: Date,
        calendar: Calendar
    ) -> UVReading? {
        _ = calendar
        guard reading.source.shouldDisplayAttribution,
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
        guard UVReadingSource.shouldDisplayAttribution(for: forecast.sourceLabel),
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
