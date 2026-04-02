import BackgroundTasks
import Foundation
import SwiftData
import UserNotifications

private enum NotificationConstants {
    static let backgroundTaskID = "com.peyton.sunclub.weekly-report"
    static let dailyManualCategoryID = "SUNSCREEN_DAILY_MANUAL"
    static let reapplyCategoryID = "SUNSCREEN_REAPPLY"
    static let actionManualID = "LOG_TODAY_ACTION"
    static let routeKey = "targetRoute"
    static let manualRoute = "manual"
    static let weeklyRoute = "weekly"
    static let reapplyRoute = "reapply"
    static let dailyPrefix = "sunscreen.daily."
    static let weeklyFallbackPrefix = "sunscreen.weekly.fallback."
    static let weeklyPrimaryPrefix = "sunscreen.weekly.primary."
    static let reapplyPrefix = "sunscreen.reapply."
    static let streakRiskPrefix = "sunscreen.streak-risk."
}

@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleReminders(using state: AppState) async
    func refreshStreakRiskReminder(using state: AppState) async
    func scheduleReapplyReminder(plan: ReapplyReminderPlan, route: AppRoute) async
    func cancelReapplyReminders() async
    func notificationHealthSnapshot(using state: AppState) async -> NotificationHealthSnapshot
}

@MainActor
final class NotificationManager: NSObject, NotificationScheduling, @MainActor UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    private let isTesting = RuntimeEnvironment.isRunningTests
    private var modelContainer: ModelContainer?

    private var routeHandler: (AppRoute) -> Void = { _ in }
    private var configured = false
    private var backgroundTaskRegistered = false

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func registerBackgroundTaskIfNeeded() {
        guard !backgroundTaskRegistered, !isTesting else { return }
        backgroundTaskRegistered = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: NotificationConstants.backgroundTaskID, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task {
                await self.handleWeeklyReportTask(refresh)
            }
        }
    }

    func configure() async -> Bool {
        if !configured {
            configured = true

            let actionManual = UNNotificationAction(identifier: NotificationConstants.actionManualID, title: "Log Today", options: [.foreground])
            let dailyManualCategory = UNNotificationCategory(
                identifier: NotificationConstants.dailyManualCategoryID,
                actions: [actionManual],
                intentIdentifiers: []
            )
            let reapplyCategory = UNNotificationCategory(
                identifier: NotificationConstants.reapplyCategoryID,
                actions: [],
                intentIdentifiers: []
            )

            center.setNotificationCategories([dailyManualCategory, reapplyCategory])
            center.delegate = self
        }

        registerBackgroundTaskIfNeeded()

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        await configure()
    }

    func setRouteHandler(_ handler: @escaping (AppRoute) -> Void) {
        routeHandler = handler
    }

    func scheduleReminders(using state: AppState) async {
        registerBackgroundTaskIfNeeded()

        await clearPendingRequests(prefix: NotificationConstants.dailyPrefix)
        await clearPendingRequests(prefix: NotificationConstants.weeklyFallbackPrefix)
        await clearPendingRequests(prefix: NotificationConstants.weeklyPrimaryPrefix)
        await clearPendingRequests(prefix: NotificationConstants.streakRiskPrefix)

        await addRequests(makeDailyReminderRequests(using: state))
        if let weeklyFallback = makeWeeklyFallbackRequest(using: state) {
            try? await center.add(weeklyFallback)
        }
        state.settings.lastReminderScheduleAt = Date()
        state.save()
        await refreshStreakRiskReminder(using: state)
        submitWeeklyBackgroundTask(
            weekday: state.settings.weeklyWeekday,
            hour: state.settings.weeklyHour,
            minute: 0
        )
    }

    private func makeDailyReminderRequests(using state: AppState) -> [UNNotificationRequest] {
        let reminderSettings = state.settings.smartReminderSettings
        let timeZone = reminderSettings.notificationTimeZone()
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone

        let dayStart = scheduleCalendar.startOfDay(for: Date())
        var requests: [UNNotificationRequest] = []

        for offset in 0..<60 {
            guard let day = scheduleCalendar.date(byAdding: .day, value: offset, to: dayStart) else { continue }
            let phrase = state.nextDailyPhrase()
            let reminderTime = reminderSettings.time(for: day, calendar: scheduleCalendar)
            let components = ReminderPlanner.notificationComponents(
                for: day,
                time: reminderTime,
                timeZone: timeZone,
                calendar: scheduleCalendar
            )

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            requests.append(
                UNNotificationRequest(
                    identifier: "\(NotificationConstants.dailyPrefix)\(Int(day.timeIntervalSince1970))",
                    content: makeContent(
                        title: "Sunclub check-in",
                        body: phrase,
                        categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                        route: NotificationConstants.manualRoute,
                        type: "daily",
                        includeDefaultSound: true
                    ),
                    trigger: trigger
                )
            )
        }

        return requests
    }

    func refreshStreakRiskReminder(using state: AppState) async {
        await clearPendingRequests(prefix: NotificationConstants.streakRiskPrefix)

        guard let streakRiskRequest = makeStreakRiskRequest(using: state) else {
            return
        }

        try? await center.add(streakRiskRequest)
    }

    private func makeWeeklyFallbackRequest(using state: AppState) -> UNNotificationRequest? {
        var components = DateComponents()
        components.weekday = state.settings.weeklyWeekday
        components.hour = state.settings.weeklyHour
        components.minute = 0

        return UNNotificationRequest(
            identifier: "\(NotificationConstants.weeklyFallbackPrefix)repeating",
            content: makeContent(
                title: "Sunclub weekly report",
                body: "Open Sunclub to view your latest 7-day report.",
                categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                route: NotificationConstants.weeklyRoute,
                type: "weekly_fallback"
            ),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }

    private func submitWeeklyBackgroundTask(weekday: Int, hour: Int, minute: Int) {
        guard backgroundTaskRegistered else { return }

        let request = BGAppRefreshTaskRequest(identifier: NotificationConstants.backgroundTaskID)
        request.earliestBeginDate = nextDate(weekday: weekday, hour: hour, minute: minute)

        try? BGTaskScheduler.shared.submit(request)
    }

    private func nextDate(weekday: Int, hour: Int, minute: Int) -> Date {
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now)
        let delta = (weekday - currentWeekday + 7) % 7

        let base = calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: now)) ?? now
        let sameWeekTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base

        if sameWeekTime <= now {
            return calendar.date(byAdding: .day, value: 7, to: sameWeekTime) ?? sameWeekTime
        }

        return sameWeekTime
    }

    private func handleWeeklyReportTask(_ task: BGAppRefreshTask) async {
        guard let context = makeBackgroundContext() else {
            task.setTaskCompleted(success: false)
            return
        }

        do {
            let settings = try fetchSettings(context: context)
            let records = try fetchRecords(context: context)
            let report = CalendarAnalytics.weeklyReport(records: records, now: Date(), calendar: calendar)

            let phrase = PhraseRotation.nextPhrase(from: settings.weeklyPhraseState, catalog: PhraseBank.weeklyPhrases)
            settings.weeklyPhraseState = phrase.1
            try context.save()

            let request = UNNotificationRequest(
                identifier: "\(NotificationConstants.weeklyPrimaryPrefix)\(Int(Date().timeIntervalSince1970))",
                content: makeContent(
                    title: "Sunclub weekly report",
                    body: "You applied sunscreen \(report.appliedCount)/\(report.totalDays) days. Current streak: \(report.streak). "
                        + (report.missedDays.isEmpty ? "No misses this week. " : "Missed: \(report.missedDays.joined(separator: ", ")). ")
                        + phrase.0,
                    categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                    route: NotificationConstants.weeklyRoute,
                    type: "weekly_primary"
                ),
                trigger: nil
            )

            try await center.add(request)
            submitWeeklyBackgroundTask(
                weekday: settings.weeklyWeekday,
                hour: settings.weeklyHour,
                minute: 0
            )
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    private func makeBackgroundContext() -> ModelContext? {
        guard let container = modelContainer else { return nil }
        return ModelContext(container)
    }

    private func fetchSettings(context: ModelContext) throws -> Settings {
        let descriptor = FetchDescriptor<Settings>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let created = Settings()
        context.insert(created)
        try context.save()
        return created
    }

    private func fetchRecords(context: ModelContext) throws -> [Date] {
        let descriptor = FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .reverse)])
        return try context.fetch(descriptor).map { $0.startOfDay }
    }

    func scheduleReapplyReminder(plan: ReapplyReminderPlan, route: AppRoute) async {
        await clearPendingRequests(prefix: NotificationConstants.reapplyPrefix)

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(plan.intervalMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(NotificationConstants.reapplyPrefix)\(Int(Date().timeIntervalSince1970))",
            content: makeContent(
                title: plan.notificationTitle,
                body: plan.notificationBody,
                categoryIdentifier: NotificationConstants.reapplyCategoryID,
                route: notificationRoute(for: route),
                type: "reapply",
                includeDefaultSound: true
            ),
            trigger: trigger
        )

        try? await center.add(request)
    }

    func cancelReapplyReminders() async {
        await clearPendingRequests(prefix: NotificationConstants.reapplyPrefix)
    }

    func notificationHealthSnapshot(using state: AppState) async -> NotificationHealthSnapshot {
        let settings = await center.notificationSettings()
        let pendingRequests = await center.pendingNotificationRequests()

        return NotificationHealthSnapshot(
            authorizationState: authorizationState(from: settings.authorizationStatus),
            pendingDailyReminderCount: pendingRequests.filter {
                $0.identifier.hasPrefix(NotificationConstants.dailyPrefix)
            }.count,
            pendingStreakRiskReminderCount: pendingRequests.filter {
                $0.identifier.hasPrefix(NotificationConstants.streakRiskPrefix)
            }.count,
            pendingReapplyReminderCount: pendingRequests.filter {
                $0.identifier.hasPrefix(NotificationConstants.reapplyPrefix)
            }.count,
            lastScheduledAt: state.settings.lastReminderScheduleAt
        )
    }

    private func makeStreakRiskRequest(using state: AppState) -> UNNotificationRequest? {
        guard let plan = ReminderPlanner.streakRiskPlan(
            records: state.recordedDays,
            now: Date(),
            settings: state.settings.smartReminderSettings,
            calendar: calendar
        ) else {
            return nil
        }

        let streakLabel = plan.streakCount == 1 ? "1-day streak" : "\(plan.streakCount)-day streak"
        let timeZone = state.settings.smartReminderSettings.notificationTimeZone()
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone
        var triggerComponents = scheduleCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: plan.fireDate)
        triggerComponents.timeZone = timeZone
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents,
            repeats: false
        )

        return UNNotificationRequest(
            identifier: "\(NotificationConstants.streakRiskPrefix)\(Int(plan.fireDate.timeIntervalSince1970))",
            content: makeContent(
                title: "Keep your streak alive",
                body: "Today is still open. Log sunscreen before the day ends to protect your \(streakLabel).",
                categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                route: NotificationConstants.manualRoute,
                type: "streak_risk",
                includeDefaultSound: true
            ),
            trigger: trigger
        )
    }

    private func clearPendingRequests(prefix: String) async {
        let requests = await center.pendingNotificationRequests()

        let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func addRequests(_ requests: [UNNotificationRequest]) async {
        for request in requests {
            try? await center.add(request)
        }
    }

    private func makeContent(
        title: String,
        body: String,
        categoryIdentifier: String,
        route: String,
        type: String,
        includeDefaultSound: Bool = false
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [NotificationConstants.routeKey: route, "type": type]
        if includeDefaultSound {
            content.sound = .default
        }
        return content
    }

    private func notificationRoute(for route: AppRoute) -> String {
        switch route {
        case .manualLog:
            return NotificationConstants.manualRoute
        case .reapplyCheckIn:
            return NotificationConstants.reapplyRoute
        case .weeklySummary:
            return NotificationConstants.weeklyRoute
        default:
            return NotificationConstants.manualRoute
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let targetRoute = response.notification.request.content.userInfo[NotificationConstants.routeKey] as? String
        let actionIdentifier = response.actionIdentifier

        Task { @MainActor [weak self] in
            guard let self else { return }

            switch actionIdentifier {
            case NotificationConstants.actionManualID:
                routeHandler(.manualLog)
            default:
                if targetRoute == NotificationConstants.weeklyRoute {
                    routeHandler(.weeklySummary)
                } else if targetRoute == NotificationConstants.reapplyRoute {
                    routeHandler(.reapplyCheckIn)
                } else if targetRoute == NotificationConstants.manualRoute {
                    routeHandler(.manualLog)
                } else {
                    routeHandler(.home)
                }
            }
        }

        completionHandler()
    }

    private func authorizationState(from status: UNAuthorizationStatus) -> NotificationAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }
}
