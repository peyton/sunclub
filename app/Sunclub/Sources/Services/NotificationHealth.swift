import Foundation

enum NotificationRequestCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case daily
    case uvBriefing
    case extremeUV
    case weekly
    case streakRisk
    case reapply
    case leaveHome

    case test

    var diagnosticLabel: String {
        switch self {
        case .daily:
            return "Daily"
        case .uvBriefing:
            return "UV briefing"
        case .extremeUV:
            return "Extreme UV"
        case .weekly:
            return "Weekly"
        case .streakRisk:
            return "Evening log"
        case .reapply:
            return "Reapply"
        case .leaveHome:
            return "Leave home"
        case .test:
            return "Test"
        }
    }
}

struct NotificationCategorySchedulingResult: Equatable, Sendable {
    let requested: Int
    let scheduled: Int
    let failed: Int
    let pending: Int

    static let empty = NotificationCategorySchedulingResult(
        requested: 0,
        scheduled: 0,
        failed: 0,
        pending: 0
    )
}

struct NotificationSchedulingFailure: Equatable, Sendable {
    let category: NotificationRequestCategory
    let identifier: String
    let message: String
}

struct NotificationSchedulingReport: Equatable, Sendable {
    let categories: [NotificationRequestCategory: NotificationCategorySchedulingResult]
    let failures: [NotificationSchedulingFailure]
    let finalSunclubOwnedPendingCount: Int

    static let empty = NotificationSchedulingReport(
        categories: [:],
        failures: [],
        finalSunclubOwnedPendingCount: 0
    )

    var requestedCount: Int {
        categories.values.reduce(0) { $0 + $1.requested }
    }

    var scheduledCount: Int {
        categories.values.reduce(0) { $0 + $1.scheduled }
    }

    var failedCount: Int {
        categories.values.reduce(0) { $0 + $1.failed }
    }

    var isSuccessful: Bool {
        failures.isEmpty
            && failedCount == 0
            && finalSunclubOwnedPendingCount <= NotificationSchedulingPolicy.maximumOwnedPendingRequests
    }

    func result(for category: NotificationRequestCategory) -> NotificationCategorySchedulingResult {
        categories[category] ?? .empty
    }
}

enum NotificationSchedulingPolicy {
    static let maximumOwnedPendingRequests = 60
    static let immediateRequestReserve = 2
    static let maximumPlannedPendingRequests = maximumOwnedPendingRequests - immediateRequestReserve
    static let uvRollingDayCount = 7
}

struct NotificationOperationResult: Equatable, Sendable {
    let isSuccessful: Bool
    let message: String

    static func success(_ message: String) -> NotificationOperationResult {
        NotificationOperationResult(isSuccessful: true, message: message)
    }

    static func failure(_ message: String) -> NotificationOperationResult {
        NotificationOperationResult(isSuccessful: false, message: message)
    }
}

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
    let pendingCategoryCounts: [NotificationRequestCategory: Int]
    let expectedCategoryCounts: [NotificationRequestCategory: Int]
    let lastScheduledAt: Date?

    var pendingDailyReminderCount: Int {
        pendingCount(for: .daily)
    }

    var pendingStreakRiskReminderCount: Int {
        pendingCount(for: .streakRisk)
    }

    var pendingReapplyReminderCount: Int {
        pendingCount(for: .reapply)
    }

    var pendingSunclubOwnedCount: Int {
        pendingCategoryCounts.values.reduce(0, +)
    }

    var missingExpectedCategories: [NotificationRequestCategory] {
        expectedCategoryCounts.compactMap { category, expectedCount in
            guard expectedCount > 0, pendingCount(for: category) < expectedCount else {
                return nil
            }
            return category
        }
        .sorted { $0.rawValue < $1.rawValue }
    }

    var hasRequiredScheduledRequests: Bool {
        if expectedCategoryCounts.isEmpty {
            return pendingDailyReminderCount > 0
        }
        return missingExpectedCategories.isEmpty
    }

    init(
        authorizationState: NotificationAuthorizationState,
        pendingCategoryCounts: [NotificationRequestCategory: Int],
        expectedCategoryCounts: [NotificationRequestCategory: Int],
        lastScheduledAt: Date?
    ) {
        self.authorizationState = authorizationState
        self.pendingCategoryCounts = pendingCategoryCounts.filter { $0.value > 0 }
        self.expectedCategoryCounts = expectedCategoryCounts.filter { $0.value > 0 }
        self.lastScheduledAt = lastScheduledAt
    }

    init(
        authorizationState: NotificationAuthorizationState,
        pendingDailyReminderCount: Int,
        pendingStreakRiskReminderCount: Int,
        pendingReapplyReminderCount: Int,
        lastScheduledAt: Date?
    ) {
        self.init(
            authorizationState: authorizationState,
            pendingCategoryCounts: [
                .daily: pendingDailyReminderCount,
                .streakRisk: pendingStreakRiskReminderCount,
                .reapply: pendingReapplyReminderCount
            ],
            expectedCategoryCounts: [:],
            lastScheduledAt: lastScheduledAt
        )
    }

    func pendingCount(for category: NotificationRequestCategory) -> Int {
        pendingCategoryCounts[category] ?? 0
    }

    static let unknown = NotificationHealthSnapshot(
        authorizationState: .unknown,
        pendingCategoryCounts: [:],
        expectedCategoryCounts: [:],
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
    let actionTitle: String?
    let actionKind: NotificationHealthStatusAction?
}

enum NotificationHealthStatusAction: Equatable {
    case requestPermission
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
            if needsScheduleRepair(snapshot) {
                return NotificationHealthPresentation(
                    state: .stale,
                    title: "Reminders need attention",
                    detail: scheduleRepairDetail(snapshot),
                    actionTitle: "Refresh Reminders"
                )
            }
            return nil
        case .provisional, .ephemeral:
            if needsScheduleRepair(snapshot) {
                return NotificationHealthPresentation(
                    state: .stale,
                    title: "Quiet reminders need attention",
                    detail: "Sunclub can deliver quiet reminders, but \(scheduleRepairDetail(snapshot).lowercased())",
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
            return attentionStatusPresentation(from: presentation)
        }

        switch snapshot.authorizationState {
        case .authorized:
            return NotificationHealthStatusPresentation(
                title: "Notifications are ready",
                detail: readyDetail(snapshot),
                symbolName: "bell.fill",
                needsAttention: false,
                actionTitle: nil,
                actionKind: nil
            )
        case .provisional, .ephemeral:
            return NotificationHealthStatusPresentation(
                title: "Quiet reminders are ready",
                detail: "Sunclub can deliver \(snapshot.pendingSunclubOwnedCount) quiet reminder request\(snapshot.pendingSunclubOwnedCount == 1 ? "" : "s") on this phone.",
                symbolName: "bell.fill",
                needsAttention: false,
                actionTitle: nil,
                actionKind: nil
            )
        case .notDetermined:
            return NotificationHealthStatusPresentation(
                title: "Allow notifications?",
                detail: "Sunclub can send sunscreen reminders and reports. You can keep logging manually either way.",
                symbolName: "bell.badge.fill",
                needsAttention: false,
                actionTitle: "Allow Notifications",
                actionKind: .requestPermission
            )
        case .unknown:
            return NotificationHealthStatusPresentation(
                title: "Notification status unknown",
                detail: "Sunclub will refresh this status when reminders are checked.",
                symbolName: "bell",
                needsAttention: false,
                actionTitle: nil,
                actionKind: nil
            )
        case .denied:
            return nil
        }
    }

    private static func attentionStatusPresentation(
        from presentation: NotificationHealthPresentation
    ) -> NotificationHealthStatusPresentation {
        NotificationHealthStatusPresentation(
            title: presentation.title,
            detail: presentation.detail,
            symbolName: presentation.state == .denied ? "bell.slash.fill" : "bell.badge.fill",
            needsAttention: true,
            actionTitle: nil,
            actionKind: nil
        )
    }

    private static func needsScheduleRepair(_ snapshot: NotificationHealthSnapshot) -> Bool {
        snapshot.lastScheduledAt == nil
            || !snapshot.hasRequiredScheduledRequests
            || snapshot.pendingSunclubOwnedCount > NotificationSchedulingPolicy.maximumOwnedPendingRequests
    }

    private static func scheduleRepairDetail(_ snapshot: NotificationHealthSnapshot) -> String {
        if snapshot.pendingSunclubOwnedCount > NotificationSchedulingPolicy.maximumOwnedPendingRequests {
            return "Sunclub found too many pending reminders on this phone. Rebuild reminders to fix the queue."
        }

        let missingLabels = snapshot.missingExpectedCategories.map(\.diagnosticLabel)
        if !missingLabels.isEmpty {
            return "Sunclub couldn't find an active \(formattedList(missingLabels)) reminder on this phone. Rebuild reminders to fix it."
        }

        return "Sunclub couldn't confirm when reminders were last rebuilt. Refresh reminders to fix it."
    }

    private static func readyDetail(_ snapshot: NotificationHealthSnapshot) -> String {
        "Sunclub has \(snapshot.pendingSunclubOwnedCount) active reminder request\(snapshot.pendingSunclubOwnedCount == 1 ? "" : "s") on this phone."
    }

    private static func formattedList(_ labels: [String]) -> String {
        switch labels.count {
        case 0:
            return "required"
        case 1:
            return labels[0]
        case 2:
            return labels.joined(separator: " and ")
        default:
            return labels.dropLast().joined(separator: ", ") + ", and " + (labels.last ?? "required")
        }
    }
}
