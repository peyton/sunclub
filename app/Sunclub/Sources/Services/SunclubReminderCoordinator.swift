import Foundation
import Observation

/// The scheduler's inputs and its two existing persistence hooks, independent of navigation and logging.
@MainActor
protocol SunclubReminderState: AnyObject {
    var settings: Settings { get }
    var growthSettings: SunclubGrowthSettings { get }
    var recordedDays: [Date] { get }
    var uvReading: UVReading? { get }
    var pendingDepartureReminder: DepartureCheckInSnapshot? { get }
    func nextDailyPhrases(count: Int) -> [String]
    func record(for day: Date) -> DailyRecord?
    func save()
    func recordDepartureCheckIn(at date: Date) throws -> UUID?
}

extension SunclubReminderState {
    var pendingDepartureReminder: DepartureCheckInSnapshot? { nil }
    func recordDepartureCheckIn(at date: Date) throws -> UUID? { nil }
}

@MainActor
@Observable
final class SunclubReminderCoordinator {
    private let notifications: NotificationScheduling
    private let homeMonitor: HomeExitReminderMonitoring
    private var healthOverride: NotificationHealthSnapshot?
    private var authorizationOverride: LeaveHomeAuthorizationState?
    private(set) var health: NotificationHealthSnapshot = .unknown
    private(set) var homeAuthorization: LeaveHomeAuthorizationState = .notDetermined

    init(notifications: NotificationScheduling, homeMonitor: HomeExitReminderMonitoring) {
        self.notifications = notifications
        self.homeMonitor = homeMonitor
    }

    func schedule(using input: any SunclubReminderState, after refresh: Task<Void, Never>? = nil) async {
        await notifications.scheduleReminders(using: input)
        if let refresh {
            await refresh.value
            await notifications.scheduleReminders(using: input)
        }
        await refreshHealth(using: input)
    }

    func refreshStreakRisk(using input: any SunclubReminderState) async {
        await notifications.refreshStreakRiskReminder(using: input)
    }

    func refreshHealth(using input: any SunclubReminderState) async {
        if let healthOverride {
            health = healthOverride
            return
        }
        var snapshot = await notifications.notificationHealthSnapshot(using: input)
        if snapshot.authorizationState.allowsDelivery,
           snapshot.lastScheduledAt == nil || !snapshot.hasRequiredScheduledRequests {
            await notifications.scheduleReminders(using: input)
            snapshot = await notifications.notificationHealthSnapshot(using: input)
        }
        guard healthOverride == nil else { return }
        health = snapshot
    }

    func refreshHomeAuthorization(using input: any SunclubReminderState, allowPermissionPrompt: Bool) async {
        if let authorizationOverride {
            homeAuthorization = authorizationOverride
            return
        }
        let state = await homeMonitor.refreshMonitoring(using: input, allowPermissionPrompt: allowPermissionPrompt)
        guard authorizationOverride == nil else { return }
        homeAuthorization = state
    }

    func authorizeAndSchedule(using input: any SunclubReminderState, scheduleWhenDenied: Bool) async {
        let granted = await notifications.requestAuthorizationIfNeeded()
        if granted || scheduleWhenDenied { await schedule(using: input) }
        health = await notifications.notificationHealthSnapshot(using: input)
    }

    func updateHomeAuthorization(_ state: LeaveHomeAuthorizationState) {
        homeAuthorization = state
    }

    func overrideHealth(_ snapshot: NotificationHealthSnapshot?) {
        healthOverride = snapshot
        health = snapshot ?? .unknown
    }

    func overrideHomeAuthorization(_ state: LeaveHomeAuthorizationState?) {
        authorizationOverride = state
        homeAuthorization = state ?? .notDetermined
    }
}
