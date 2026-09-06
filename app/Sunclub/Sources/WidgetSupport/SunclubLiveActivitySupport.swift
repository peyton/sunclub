import ActivityKit
import Foundation
import OSLog
import WidgetKit

struct SunclubLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var currentUVIndex: Int
        var peakUVIndex: Int
        var countdownLabel: String
        var lastAppliedLabel: String
        var lastLogDetail: String
        var reapplyStartDate: Date?
        var reapplyDeadline: Date?
        var uvValidUntil: Date?
        var pendingDepartureCheckInID: UUID?
        var pendingDepartureDate: Date?
    }

    var headline: String
}

extension SunclubLiveActivityAttributes.ContentState {
    func hasPendingCheckIn(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard pendingDepartureCheckInID != nil, let pendingDepartureDate else { return false }
        return pendingDepartureDate <= now && calendar.isDate(pendingDepartureDate, inSameDayAs: now)
    }

    var sessionID: String? {
        if let pendingDepartureCheckInID { return "departure-\(pendingDepartureCheckInID.uuidString)" }
        return reapplyStartDate.map { "application-\($0.timeIntervalSince1970)" }
    }

    var reapplyInterval: ClosedRange<Date>? {
        guard let reapplyStartDate,
              let reapplyDeadline,
              reapplyStartDate < reapplyDeadline else {
            return nil
        }

        return reapplyStartDate...reapplyDeadline
    }

    var uvPillLabel: String {
        uvPillLabel(now: Date())
    }

    func hasFreshUV(now: Date = Date()) -> Bool {
        guard let uvValidUntil else {
            return false
        }
        return now <= uvValidUntil
    }

    func uvPillLabel(now: Date = Date()) -> String {
        guard hasFreshUV(now: now) else {
            return "UV unavailable"
        }
        return "UV \(currentUVIndex) \(UVLevel.from(index: currentUVIndex).displayName)"
    }

    var appliedLabel: String {
        "Applied \(lastAppliedLabel)"
    }

    func hasCurrentApplication(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard pendingDepartureCheckInID == nil else { return false }
        guard let reapplyStartDate else { return true }
        return reapplyStartDate <= now && calendar.isDate(reapplyStartDate, inSameDayAs: now)
    }

    func isReapplyDue(now: Date = Date()) -> Bool {
        guard hasCurrentApplication(now: now) else { return false }
        guard let reapplyDeadline else {
            return countdownLabel == "due"
        }

        return reapplyDeadline <= now
    }

    func statusTitle(now: Date = Date()) -> String {
        if hasPendingCheckIn(now: now) { return "Did you apply sunscreen?" }
        guard hasCurrentApplication(now: now) else { return "Not logged today" }
        return isReapplyDue(now: now) ? "Reapply due" : "Reapply in"
    }

    func fallbackTimerText(now: Date = Date()) -> String {
        if isReapplyDue(now: now) {
            return "Due"
        }

        if let deadline = reapplyDeadline {
            let totalMinutes = max(1, Int(ceil(deadline.timeIntervalSince(now) / 60)))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours == 0 { return "\(minutes)m" }
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        return countdownLabel.replacingOccurrences(of: "in ", with: "")
    }

    func nextReapplyLabel(now: Date = Date()) -> String? {
        guard hasCurrentApplication(now: now),
              let reapplyDeadline,
              reapplyDeadline > now else {
            return nil
        }

        return "Next \(reapplyDeadline.formatted(date: .omitted, time: .shortened))"
    }

    func accessibilitySummary(now: Date = Date()) -> String {
        if hasPendingCheckIn(now: now) { return "Did you apply sunscreen? Unconfirmed. Open Sunclub to confirm when you applied." }
        guard hasCurrentApplication(now: now) else { return "Not logged today. Open Sunclub to log today." }
        let nextText = nextReapplyLabel(now: now).map { ". \($0)" } ?? ""

        if isReapplyDue(now: now) {
            return "\(statusTitle(now: now)). \(uvPillLabel(now: now)). \(appliedLabel)."
        }

        return "\(statusTitle(now: now)) \(fallbackTimerText(now: now)). \(uvPillLabel(now: now)). \(appliedLabel)\(nextText)."
    }
}

/// Keeps an existing timer current after a committed widget or Live Activity action.
@MainActor
enum SunclubLiveActivitySnapshotBridge {
    static func updateExisting(snapshot: SunclubWidgetSnapshot, now: Date, mayStart: Bool = false) async {
        let state = contentState(snapshot: snapshot, now: now)
        await SunclubLiveActivitySessionStore.publish(state, now: now, mayStart: mayStart)
    }

    static func contentState(
        snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar = .current
    ) -> SunclubLiveActivityAttributes.ContentState? {
        guard snapshot.isOnboardingComplete, snapshot.liveActivitiesEnabled else { return nil }
        if let id = snapshot.pendingDepartureCheckInID, let date = snapshot.pendingDepartureDate,
           date <= now, calendar.isDate(date, inSameDayAs: now),
           (snapshot.pendingDepartureSnoozedUntil ?? .distantPast) <= now,
           !snapshot.hasLoggedToday(now: now, calendar: calendar) {
            return pendingContentState(id: id, departureDate: date)
        }
        let status = snapshot.applicationStatus(now: now, calendar: calendar)
        guard status.isSetupComplete,
              let start = status.lastAppliedAt,
              let baselineDeadline = ReminderPlanner.reapplyFireDate(
                from: start, intervalMinutes: snapshot.reapplyIntervalMinutes, calendar: calendar
              ) else { return nil }
        let deadline = SunclubLiveActivitySessionStore.deadline(applicationDate: start, baseline: baselineDeadline, now: now)
        return SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: snapshot.currentUVIndex(at: now) ?? 0,
            peakUVIndex: snapshot.peakUVIndex(at: now) ?? 0,
            countdownLabel: deadline <= now ? "due" : "in \(max(1, Int(ceil(deadline.timeIntervalSince(now) / 60))))m",
            lastAppliedLabel: start.formatted(date: .omitted, time: .shortened),
            lastLogDetail: snapshot.todaySPFLevel.map { "SPF \($0)" } ?? "Logged",
            reapplyStartDate: start,
            reapplyDeadline: deadline,
            uvValidUntil: snapshot.uvValidUntil ?? .distantPast
        )
    }
}


extension SunclubLiveActivitySnapshotBridge {
    static func pendingContentState(id: UUID, departureDate: Date) -> SunclubLiveActivityAttributes.ContentState {
        SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: 0, peakUVIndex: 0, countdownLabel: "Unconfirmed",
            lastAppliedLabel: "", lastLogDetail: "Unconfirmed",
            pendingDepartureCheckInID: id, pendingDepartureDate: departureDate
        )
    }
}

/// Operational state shared with notification and widget actions, never application history.
@MainActor
enum SunclubLiveActivitySessionStore {
    private static let defaults = RuntimeEnvironment.isRunningTests ? nil : UserDefaults(suiteName: SunclubWidgetDefaults.appGroupID)
    private static let logger = Logger(subsystem: "Sunclub", category: "LiveActivities")
    private static var operation: Task<Void, Never>?
    private static let sessionKey = "liveActivity.publishedSession"

    static func shouldStart(sessionID: String, previousSessionID: String?, mayStart: Bool) -> Bool {
        mayStart && previousSessionID != sessionID
    }

    static var lastRequestError: String? { defaults?.string(forKey: "liveActivity.lastRequestError") }

    static func deadline(applicationDate: Date, baseline: Date, now: Date, defaults: UserDefaults? = nil) -> Date {
        SunclubReapplySnoozeStore.deadline(applicationDate: applicationDate, baseline: baseline, now: now, defaults: defaults)
    }

    static func saveSnooze(applicationDate: Date, deadline: Date, defaults: UserDefaults? = nil) {
        SunclubReapplySnoozeStore.save(applicationDate: applicationDate, deadline: deadline, defaults: defaults)
        if !RuntimeEnvironment.isRunningTests { WidgetCenter.shared.reloadAllTimelines() }
    }

    static func publish(_ state: SunclubLiveActivityAttributes.ContentState?, now: Date, mayStart: Bool) async {
        // Unit tests exercise pure session/presentation rules without contacting ActivityKit's daemon.
        guard !RuntimeEnvironment.isRunningTests else { return }
        let previous = operation
        let task = Task { @MainActor in
            await previous?.value
            await performPublish(state, now: now, mayStart: mayStart)
        }
        operation = task
        await task.value
    }

    private static func performPublish(_ state: SunclubLiveActivityAttributes.ContentState?, now: Date, mayStart: Bool) async {
        let activities = Activity<SunclubLiveActivityAttributes>.activities
        guard let state, let sessionID = state.sessionID, ActivityAuthorizationInfo().areActivitiesEnabled else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            defaults?.removeObject(forKey: sessionKey)
            return
        }
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
        let content = ActivityContent(state: state, staleDate: min(state.reapplyDeadline ?? nextDay, nextDay))
        let existing = activities.first { $0.activityState == .active || $0.activityState == .stale }
        for duplicate in activities where duplicate.id != existing?.id {
            await duplicate.end(nil, dismissalPolicy: .immediate)
        }
        if let existing {
            await existing.update(content)
            defaults?.set(sessionID, forKey: sessionKey)
        } else if shouldStart(sessionID: sessionID, previousSessionID: defaults?.string(forKey: sessionKey), mayStart: mayStart) {
            do {
                _ = try Activity.request(
                    attributes: SunclubLiveActivityAttributes(headline: state.hasPendingCheckIn(now: now) ? "Sunscreen check-in" : "Reapply timer"),
                    content: content, pushType: nil
                )
                defaults?.set(sessionID, forKey: sessionKey)
                defaults?.removeObject(forKey: "liveActivity.lastRequestError")
            } catch {
                let message = String(describing: error)
                defaults?.set(message, forKey: "liveActivity.lastRequestError")
                logger.error("Live Activity request failed: \(message, privacy: .public)")
            }
        }
    }
}
