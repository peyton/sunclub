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

struct NotificationHealthStatusPresentation: Equatable {
    let title: String
    let detail: String
    let symbolName: String
    let needsAttention: Bool
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
        case .authorized:
            if snapshot.pendingDailyReminderCount == 0 || snapshot.lastScheduledAt == nil {
                return NotificationHealthPresentation(
                    state: .stale,
                    title: "Reminders need attention",
                    detail: "Sunclub couldn't find an active daily reminder on this phone. Rebuild reminders to fix it.",
                    actionTitle: "Refresh Reminders"
                )
            }
            return nil
        case .provisional, .ephemeral:
            if snapshot.pendingDailyReminderCount == 0 || snapshot.lastScheduledAt == nil {
                return NotificationHealthPresentation(
                    state: .stale,
                    title: "Quiet reminders need attention",
                    detail: "Sunclub can deliver quiet reminders, but it couldn't find an active daily reminder on this phone.",
                    actionTitle: "Refresh Reminders"
                )
            }
            return nil
        case .notDetermined, .unknown:
            return nil
        }
    }

    static func statusPresentation(
        from snapshot: NotificationHealthSnapshot,
        onboardingComplete: Bool
    ) -> NotificationHealthStatusPresentation? {
        guard onboardingComplete else {
            return nil
        }

        if let presentation = presentation(from: snapshot, onboardingComplete: onboardingComplete) {
            return NotificationHealthStatusPresentation(
                title: presentation.title,
                detail: presentation.detail,
                symbolName: presentation.state == .denied ? "bell.slash.fill" : "bell.badge.fill",
                needsAttention: true
            )
        }

        switch snapshot.authorizationState {
        case .authorized:
            return NotificationHealthStatusPresentation(
                title: "Notifications are ready",
                detail: "Sunclub has an active daily reminder scheduled on this phone.",
                symbolName: "bell.fill",
                needsAttention: false
            )
        case .provisional, .ephemeral:
            return NotificationHealthStatusPresentation(
                title: "Quiet reminders are ready",
                detail: "Sunclub can deliver quiet daily reminders on this phone.",
                symbolName: "bell.fill",
                needsAttention: false
            )
        case .notDetermined:
            return NotificationHealthStatusPresentation(
                title: "Notification permission not asked",
                detail: "You can still log manually. Sunclub will ask before scheduling reminders.",
                symbolName: "bell",
                needsAttention: false
            )
        case .unknown:
            return NotificationHealthStatusPresentation(
                title: "Notification status unknown",
                detail: "Sunclub will refresh this status when reminders are checked.",
                symbolName: "bell",
                needsAttention: false
            )
        case .denied:
            return nil
        }
    }
}
