import ActivityKit
import Foundation

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
    }

    var headline: String
}

extension SunclubLiveActivityAttributes.ContentState {
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
        guard let reapplyStartDate else { return true }
        return reapplyStartDate <= now && calendar.isDate(reapplyStartDate, inSameDayAs: now)
    }

    func isReapplyDue(now: Date = Date()) -> Bool {
        guard hasCurrentApplication(now: now) else { return false }
        if countdownLabel == "due" {
            return true
        }

        guard let reapplyDeadline else {
            return false
        }

        return reapplyDeadline <= now
    }

    func statusTitle(now: Date = Date()) -> String {
        guard hasCurrentApplication(now: now) else { return "Not logged today" }
        return isReapplyDue(now: now) ? "Reapply due" : "Reapply in"
    }

    func fallbackTimerText(now: Date = Date()) -> String {
        if isReapplyDue(now: now) {
            return "Due"
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
    static func updateExisting(snapshot: SunclubWidgetSnapshot, now: Date) async {
        let state = contentState(snapshot: snapshot, now: now)
        for activity in Activity<SunclubLiveActivityAttributes>.activities {
            guard let state, let deadline = state.reapplyDeadline else {
                await activity.end(nil, dismissalPolicy: .default)
                continue
            }
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? deadline
            await activity.update(ActivityContent(state: state, staleDate: min(deadline, nextDay)))
        }
    }

    static func contentState(
        snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar = .current
    ) -> SunclubLiveActivityAttributes.ContentState? {
        let status = snapshot.applicationStatus(now: now, calendar: calendar)
        guard status.isSetupComplete,
              let start = status.lastAppliedAt,
              status.reapplyDeadline != nil,
              let deadline = ReminderPlanner.reapplyFireDate(
                from: start, intervalMinutes: snapshot.reapplyIntervalMinutes, calendar: calendar
              ) else { return nil }
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
