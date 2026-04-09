import Foundation

enum NotificationAuthorizationState: String, Equatable {
    case notDetermined
    case authorized
    case denied
    case provisional
    case ephemeral
    case unknown

    var allowsDelivery: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}

struct NotificationHealthSnapshot: Equatable {
    let authorizationState: NotificationAuthorizationState
    let pendingDailyReminderCount: Int
    let pendingStreakRiskReminderCount: Int
    let pendingReapplyReminderCount: Int
    let lastScheduledAt: Date?

    static let unknown = NotificationHealthSnapshot(
        authorizationState: .unknown,
        pendingDailyReminderCount: 0,
        pendingStreakRiskReminderCount: 0,
        pendingReapplyReminderCount: 0,
        lastScheduledAt: nil
    )
}

enum NotificationHealthState: Equatable {
    case healthy
    case denied
    case stale
}

struct NotificationHealthPresentation: Equatable {
    let state: NotificationHealthState
    let title: String
    let detail: String
    let actionTitle: String

    var needsAttention: Bool {
        true
    }
}

enum NotificationHealthEvaluator {
    static func presentation(
        from snapshot: NotificationHealthSnapshot,
        onboardingComplete: Bool
    ) -> NotificationHealthPresentation? {
        guard onboardingComplete else {
            return nil
        }

        switch snapshot.authorizationState {
        case .denied:
            return NotificationHealthPresentation(
                state: .denied,
                title: "Notifications are off",
                detail: "Turn notifications back on in Settings to get daily reminders again.",
                actionTitle: "Open Settings"
            )
        case .authorized, .provisional, .ephemeral:
            if snapshot.pendingDailyReminderCount == 0 || snapshot.lastScheduledAt == nil {
                return NotificationHealthPresentation(
                    state: .stale,
                    title: "Reminders need attention",
                    detail: "Sunclub couldn't find an active daily reminder on this phone. Rebuild reminders to fix it.",
                    actionTitle: "Refresh Reminders"
                )
            }
            return nil
        case .notDetermined, .unknown:
            return nil
        }
    }
}
