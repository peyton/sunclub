import Foundation
import BackgroundTasks
import UserNotifications
import SwiftData

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let bgTaskID = "com.peyton.sun-day.weekly-report"
    private let dailyCategoryID = "SUNSCREEN_DAILY"
    private let actionScanID = "SCAN_BARCODE_ACTION"
    private let actionSelfieID = "TAKE_SELFIE_ACTION"
    private let routeKey = "targetRoute"
    private let homeRoute = "home"
    private let weeklyRoute = "weekly"
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UITEST_MODE")

    private var routeHandler: (AppRoute) -> Void = { _ in }
    private var configured = false
    private var backgroundTaskRegistered = false

    func registerBackgroundTaskIfNeeded() {
        guard !backgroundTaskRegistered, !isUITesting else { return }
        backgroundTaskRegistered = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskID, using: nil) { task in
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

            let actionScan = UNNotificationAction(identifier: actionScanID, title: "Scan Barcode", options: [.foreground])
            let actionSelfie = UNNotificationAction(identifier: actionSelfieID, title: "Take Selfie", options: [.foreground])
            let category = UNNotificationCategory(identifier: dailyCategoryID, actions: [actionScan, actionSelfie], intentIdentifiers: [])

            center.setNotificationCategories([category])
            center.delegate = self
        }

        registerBackgroundTaskIfNeeded()

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        return granted
    }

    func setRouteHandler(_ handler: @escaping (AppRoute) -> Void) {
        routeHandler = handler
    }

    func scheduleReminders(using state: AppState) async {
        registerBackgroundTaskIfNeeded()

        await clearPendingRequests(prefix: "sunscreen.daily.")
        await clearPendingRequests(prefix: "sunscreen.weekly.fallback.")
        await clearPendingRequests(prefix: "sunscreen.weekly.primary.")

        scheduleDailyReminders(using: state)
        scheduleWeeklyFallback(using: state)
        scheduleWeeklyBackgroundTask(using: state)
    }

    private func scheduleDailyReminders(using state: AppState) {
        let dayStart = calendar.startOfDay(for: Date())

        for offset in 0..<60 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: dayStart) else { continue }
            let phrase = state.nextDailyPhrase()

            let content = UNMutableNotificationContent()
            content.title = "Sun Club check-in"
            content.body = phrase
            content.sound = .default
            content.categoryIdentifier = dailyCategoryID
            content.userInfo = [routeKey: homeRoute, "type": "daily"]

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = state.settings.reminderHour
            components.minute = state.settings.reminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "sunscreen.daily.\(Int(day.timeIntervalSince1970))",
                content: content,
                trigger: trigger
            )

            Task {
                try? await center.add(request)
            }
        }
    }

    private func scheduleWeeklyFallback(using state: AppState) {
        let content = UNMutableNotificationContent()
        content.title = "Sun Club weekly report"
        content.body = "Open Sun Club to view your latest 7-day report."
        content.categoryIdentifier = dailyCategoryID
        content.userInfo = [routeKey: weeklyRoute, "type": "weekly_fallback"]

        var components = DateComponents()
        components.weekday = state.settings.weeklyWeekday
        components.hour = state.settings.weeklyHour
        components.minute = 0

        let request = UNNotificationRequest(
            identifier: "sunscreen.weekly.fallback.repeating",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        Task {
            try? await center.add(request)
        }
    }

    private func scheduleWeeklyBackgroundTask(using state: AppState) {
        guard backgroundTaskRegistered else { return }

        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = nextDate(weekday: state.settings.weeklyWeekday, hour: state.settings.weeklyHour, minute: 0)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule BG task: \(error)")
        }
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

            let content = UNMutableNotificationContent()
            content.title = "Sun Club weekly report"
            content.body = "You applied sunscreen \(report.appliedCount)/\(report.totalDays) days. Current streak: \(report.streak). "
                + (report.missedDays.isEmpty ? "No misses this week. " : "Missed: \(report.missedDays.joined(separator: ", ")). ")
                + phrase.0
            content.categoryIdentifier = dailyCategoryID
            content.userInfo = [routeKey: weeklyRoute, "type": "weekly_primary"]

            let request = UNNotificationRequest(
                identifier: "sunscreen.weekly.primary.\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )

            try await center.add(request)
            scheduleWeeklyBackgroundTask(using: AppState(context: context))
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    private func makeBackgroundContext() -> ModelContext? {
        guard let container = AppDataContainer.shared else { return nil }
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

    private func clearPendingRequests(prefix: String) async {
        let requests = await center.pendingNotificationRequests()

        let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let targetRoute = response.notification.request.content.userInfo[routeKey] as? String

        defer { completionHandler() }

        switch response.actionIdentifier {
        case actionScanID:
            routeHandler(.barcodeScan)
        case actionSelfieID:
            routeHandler(.selfie)
        default:
            if targetRoute == weeklyRoute {
                routeHandler(.weeklyReport)
            } else {
                routeHandler(.home)
            }
        }
    }
}
