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

    func isReapplyDue(now: Date = Date()) -> Bool {
        if countdownLabel == "due" {
            return true
        }

        guard let reapplyDeadline else {
            return false
        }

        return reapplyDeadline <= now
    }

    func statusTitle(now: Date = Date()) -> String {
        isReapplyDue(now: now) ? "Reapply due" : "Reapply in"
    }

    func fallbackTimerText(now: Date = Date()) -> String {
        if isReapplyDue(now: now) {
            return "Due"
        }

        return countdownLabel.replacingOccurrences(of: "in ", with: "")
    }

    func nextReapplyLabel(now: Date = Date()) -> String? {
        guard let reapplyDeadline,
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
