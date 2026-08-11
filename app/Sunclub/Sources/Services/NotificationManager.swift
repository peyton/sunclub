import BackgroundTasks
import Foundation
import OSLog
import SwiftData
import UserNotifications

private enum NotificationConstants {
    static let backgroundTaskID = "com.peyton.sunclub.weekly-report"
    static let dailyManualCategoryID = "SUNSCREEN_DAILY_MANUAL"
    static let reapplyCategoryID = "SUNSCREEN_REAPPLY"
    static let accountabilityCategoryID = "SUNSCREEN_ACCOUNTABILITY"
    static let actionManualID = "LOG_TODAY_ACTION"
    static let actionReappliedID = "LOG_REAPPLY_ACTION"
    static let actionSnoozeReapplyID = "SNOOZE_REAPPLY_ACTION"
    static let routeKey = "targetRoute"
    static let manualRoute = "manual"
    static let weeklyRoute = "weekly"
    static let reapplyRoute = "reapply"
    static let accountabilityRoute = "accountability"
    static let dailyPrefix = "sunscreen.daily."
    static let weeklyFallbackPrefix = "sunscreen.weekly.fallback."
    static let weeklyPrimaryPrefix = "sunscreen.weekly.primary."
    static let reapplyPrefix = "sunscreen.reapply."
    static let streakRiskPrefix = "sunscreen.streak-risk."
    static let leaveHomePrefix = "sunscreen.leave-home."
    static let uvBriefingPrefix = "sunscreen.uv-briefing."
    static let extremeUVPrefix = "sunscreen.uv-extreme."
    static let accountabilityPokePrefix = "sunscreen.accountability-poke."
    static let testPrefix = "sunscreen.test."
    static let ownedPrefix = "sunscreen."
}

@MainActor
protocol UserNotificationCenterClient: AnyObject {
    func configure(
        categories: Set<UNNotificationCategory>,
        delegate: any UNUserNotificationCenterDelegate
    )
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationState() async -> NotificationAuthorizationState
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemUserNotificationCenterClient: UserNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func configure(
        categories: Set<UNNotificationCategory>,
        delegate: any UNUserNotificationCenterDelegate
    ) {
        center.setNotificationCategories(categories)
        center.delegate = delegate
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
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

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

struct NotificationPlannedRequest {
    let category: NotificationRequestCategory
    let request: UNNotificationRequest
}

private struct NotificationSchedulingAttempt {
    var scheduledCounts: [NotificationRequestCategory: Int]
    var failures: [NotificationSchedulingFailure]
}

enum NotificationRequestBudget {
    static func select(
        from plannedRequests: [NotificationPlannedRequest],
        preservedImmediateCount: Int
    ) -> (selected: [NotificationPlannedRequest], dropped: [NotificationPlannedRequest]) {
        let capacity = max(
            0,
            min(
                NotificationSchedulingPolicy.maximumPlannedPendingRequests,
                NotificationSchedulingPolicy.maximumOwnedPendingRequests - preservedImmediateCount
            )
        )
        let selected = Array(plannedRequests.prefix(capacity))
        return (selected, Array(plannedRequests.dropFirst(selected.count)))
    }
}

@MainActor
protocol NotificationScheduling: AnyObject {
    func requestAuthorizationIfNeeded() async -> Bool
    @discardableResult
    func scheduleReminders(using state: AppState) async -> NotificationSchedulingReport
    @discardableResult
    func refreshStreakRiskReminder(using state: AppState) async -> NotificationOperationResult
    @discardableResult
    func scheduleReapplyReminder(plan: ReapplyReminderPlan, route: AppRoute) async -> NotificationOperationResult
    @discardableResult
    func scheduleLeaveHomeReminder(level: UVLevel, route: AppRoute) async -> NotificationOperationResult
    @discardableResult
    func scheduleAccountabilityPokeNotification(
        friendName: String,
        message: String,
        route: AppRoute
    ) async -> NotificationOperationResult
    func cancelDailyReminder(for day: Date, using state: AppState) async
    func cancelReapplyReminders() async
    func notificationHealthSnapshot(using state: AppState) async -> NotificationHealthSnapshot
}

@MainActor
final class NotificationManager: NSObject, NotificationScheduling, @MainActor UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private static let logger = Logger(subsystem: "com.peyton.sunclub", category: "Notifications")

    private let center: any UserNotificationCenterClient
    private let calendar: Calendar
    private let uvBriefingService = SunclubUVBriefingService()
    private let now: () -> Date

    private let isTesting = RuntimeEnvironment.isRunningTests
    private var modelContainer: ModelContainer?

    private var routeHandler: (AppRoute) -> Void = { route in
        SunclubWidgetSnapshotStore().setPendingRoute(route)
    }
    private var configured = false
    private var backgroundTaskRegistered = false
    private(set) var lastSchedulingReport: NotificationSchedulingReport?

    override convenience init() {
        self.init(center: SystemUserNotificationCenterClient())
    }

    init(
        center: any UserNotificationCenterClient,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.calendar = calendar
        self.now = now
        super.init()
    }

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
            let actionReapplied = UNNotificationAction(
                identifier: NotificationConstants.actionReappliedID,
                title: "Reapplied now",
                options: []
            )
            let actionSnoozeReapply = UNNotificationAction(
                identifier: NotificationConstants.actionSnoozeReapplyID,
                title: "Snooze 30 min",
                options: []
            )
            let reapplyCategory = UNNotificationCategory(
                identifier: NotificationConstants.reapplyCategoryID,
                actions: [actionReapplied, actionSnoozeReapply],
                intentIdentifiers: []
            )
            let accountabilityCategory = UNNotificationCategory(
                identifier: NotificationConstants.accountabilityCategoryID,
                actions: [],
                intentIdentifiers: []
            )

            center.configure(
                categories: [dailyManualCategory, reapplyCategory, accountabilityCategory],
                delegate: self
            )
        }

        registerBackgroundTaskIfNeeded()

        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Self.logger.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        await configure()
    }

    func setRouteHandler(_ handler: @escaping (AppRoute) -> Void) {
        routeHandler = handler
    }

    @discardableResult
    func scheduleReminders(using state: AppState) async -> NotificationSchedulingReport {
        registerBackgroundTaskIfNeeded()
        let preservedImmediateRequests = await replaceOwnedRequestsPreservingImmediate()
        let plannedRequests = makePlannedRequests(using: state)
        let budgetedRequests = NotificationRequestBudget.select(
            from: plannedRequests,
            preservedImmediateCount: preservedImmediateRequests.count
        )
        let attempt = await addBudgetedRequests(
            budgetedRequests.selected,
            droppedRequests: budgetedRequests.dropped
        )
        let report = await makeSchedulingReport(
            requested: plannedRequests,
            attempt: attempt
        )
        lastSchedulingReport = report
        if report.isSuccessful {
            state.settings.lastReminderScheduleAt = now()
            state.save()
        }

        submitWeeklyBackgroundTask(
            weekday: state.settings.weeklyWeekday,
            hour: state.settings.weeklyHour,
            minute: 0
        )
        return report
    }

    private func replaceOwnedRequestsPreservingImmediate() async -> [UNNotificationRequest] {
        let pendingRequests = await center.pendingNotificationRequests()
        let preservedRequests = preservedImmediateRequests(from: pendingRequests)
        let preservedIdentifiers = Set(preservedRequests.map(\.identifier))
        let replacedIdentifiers: [String] = pendingRequests.compactMap { request -> String? in
            guard isSunclubOwned(request), !preservedIdentifiers.contains(request.identifier) else {
                return nil
            }
            return request.identifier
        }

        if !replacedIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: replacedIdentifiers)
        }
        return preservedRequests
    }

    private func makePlannedRequests(using state: AppState) -> [NotificationPlannedRequest] {
        var requests = makeDailyReminderRequests(using: state).map {
            NotificationPlannedRequest(category: .daily, request: $0)
        }
        if let weeklyFallback = makeWeeklyFallbackRequest(using: state) {
            requests.append(NotificationPlannedRequest(category: .weekly, request: weeklyFallback))
        }
        if let streakRisk = makeStreakRiskRequest(using: state) {
            requests.append(NotificationPlannedRequest(category: .streakRisk, request: streakRisk))
        }
        requests += makeUVBriefingRequests(using: state).map {
            NotificationPlannedRequest(category: .uvBriefing, request: $0)
        }
        requests += makeExtremeUVRequests(using: state).map {
            NotificationPlannedRequest(category: .extremeUV, request: $0)
        }
        return requests
    }

    private func addBudgetedRequests(
        _ requests: [NotificationPlannedRequest],
        droppedRequests: [NotificationPlannedRequest]
    ) async -> NotificationSchedulingAttempt {
        var attempt = NotificationSchedulingAttempt(
            scheduledCounts: [:],
            failures: droppedRequests.map {
                NotificationSchedulingFailure(
                    category: $0.category,
                    identifier: $0.request.identifier,
                    message: "Skipped to keep capacity for immediate reminders."
                )
            }
        )

        for plannedRequest in requests {
            do {
                try await center.add(plannedRequest.request)
                attempt.scheduledCounts[plannedRequest.category, default: 0] += 1
            } catch {
                Self.logger.error(
                    "Failed to add \(plannedRequest.category.rawValue, privacy: .public) notification: \(error.localizedDescription, privacy: .public)"
                )
                attempt.failures.append(NotificationSchedulingFailure(
                    category: plannedRequest.category,
                    identifier: plannedRequest.request.identifier,
                    message: error.localizedDescription
                ))
            }
        }
        return attempt
    }

    private func makeSchedulingReport(
        requested: [NotificationPlannedRequest],
        attempt: NotificationSchedulingAttempt
    ) async -> NotificationSchedulingReport {
        let pendingRequests = await center.pendingNotificationRequests()
        let ownedPendingRequests = pendingRequests.filter(isSunclubOwned)
        let pendingCounts = categoryCounts(for: ownedPendingRequests)
        let requestedCounts: [NotificationRequestCategory: Int] = requested.reduce(into: [:]) { counts, plannedRequest in
            counts[plannedRequest.category, default: 0] += 1
        }
        let failedCounts: [NotificationRequestCategory: Int] = attempt.failures.reduce(into: [:]) { counts, failure in
            counts[failure.category, default: 0] += 1
        }
        let categories: [NotificationRequestCategory: NotificationCategorySchedulingResult] = Dictionary(
            uniqueKeysWithValues: NotificationRequestCategory.allCases.map { category in
                (
                    category,
                    NotificationCategorySchedulingResult(
                        requested: requestedCounts[category] ?? 0,
                        scheduled: attempt.scheduledCounts[category] ?? 0,
                        failed: failedCounts[category] ?? 0,
                        pending: pendingCounts[category] ?? 0
                    )
                )
            }
        )
        return NotificationSchedulingReport(
            categories: categories,
            failures: attempt.failures,
            finalSunclubOwnedPendingCount: ownedPendingRequests.count
        )
    }

    func makeDailyReminderRequests(using state: AppState) -> [UNNotificationRequest] {
        let reminderSettings = state.settings.smartReminderSettings
        let timeZone = reminderSettings.notificationTimeZone()
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone

        // One repeating request per weekday supports distinct weekday/weekend times
        // without consuming a dated request for every future day.
        let phrases = state.nextDailyPhrases(count: 7)
        return zip(1...7, phrases).map { weekday, phrase in
            let reminderTime = (weekday == 1 || weekday == 7)
                ? reminderSettings.weekendTime
                : reminderSettings.weekdayTime
            var components = DateComponents()
            components.calendar = scheduleCalendar
            components.timeZone = timeZone
            components.weekday = weekday
            components.hour = reminderTime.hour
            components.minute = reminderTime.minute

            return UNNotificationRequest(
                identifier: dailyReminderIdentifier(forWeekday: weekday),
                content: makeContent(
                    title: "Sunclub check-in",
                    body: phrase,
                    categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                    route: NotificationConstants.manualRoute,
                    type: "daily",
                    includeDefaultSound: true
                ),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
        }
    }

    private func makeUVBriefingRequests(using state: AppState) -> [UNNotificationRequest] {
        guard state.growthSettings.uvBriefing.dailyBriefingEnabled,
              state.settings.usesLiveUV || state.settings.selectedUVPlace != nil else {
            return []
        }

        let reminderSettings = state.settings.smartReminderSettings
        let timeZone = reminderSettings.notificationTimeZone()
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone
        let referenceNow = now()
        let dayStart = scheduleCalendar.startOfDay(for: referenceNow)

        return (0..<NotificationSchedulingPolicy.uvRollingDayCount).compactMap { offset in
            guard let day = scheduleCalendar.date(byAdding: .day, value: offset, to: dayStart) else {
                return nil
            }

            let forecast = uvBriefingService.notificationForecast(
                referenceDate: day,
                now: referenceNow,
                calendar: scheduleCalendar
            )
            guard forecast.isAvailable else {
                return nil
            }
            var components = scheduleCalendar.dateComponents([.year, .month, .day], from: day)
            components.hour = state.growthSettings.uvBriefing.morningHour
            components.minute = state.growthSettings.uvBriefing.morningMinute
            components.timeZone = timeZone

            return UNNotificationRequest(
                identifier: "\(NotificationConstants.uvBriefingPrefix)\(Int(day.timeIntervalSince1970))",
                content: makeContent(
                    title: "Sunclub UV briefing",
                    body: "\(forecast.headline). \(forecast.recommendation)",
                    categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                    route: NotificationConstants.manualRoute,
                    type: "uv_briefing"
                ),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    private func makeExtremeUVRequests(using state: AppState) -> [UNNotificationRequest] {
        guard state.growthSettings.uvBriefing.extremeAlertEnabled,
              state.settings.usesLiveUV || state.settings.selectedUVPlace != nil else {
            return []
        }

        let reminderSettings = state.settings.smartReminderSettings
        let timeZone = reminderSettings.notificationTimeZone()
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone
        let referenceNow = now()
        let dayStart = scheduleCalendar.startOfDay(for: referenceNow)

        return (0..<NotificationSchedulingPolicy.uvRollingDayCount).compactMap { offset in
            guard let day = scheduleCalendar.date(byAdding: .day, value: offset, to: dayStart) else {
                return nil
            }

            let forecast = uvBriefingService.notificationForecast(
                referenceDate: day,
                now: referenceNow,
                calendar: scheduleCalendar
            )
            guard forecast.isAvailable else {
                return nil
            }
            guard let peakHour = forecast.peakHour, peakHour.level == .extreme else {
                return nil
            }

            var components = scheduleCalendar.dateComponents([.year, .month, .day], from: peakHour.date)
            components.hour = scheduleCalendar.component(.hour, from: peakHour.date)
            components.minute = 0
            components.timeZone = timeZone

            return UNNotificationRequest(
                identifier: "\(NotificationConstants.extremeUVPrefix)\(Int(day.timeIntervalSince1970))",
                content: makeContent(
                    title: "Extreme UV today",
                    body: "UV peaks around \(peakHour.date.formatted(date: .omitted, time: .shortened)). Apply early and plan to reapply sooner.",
                    categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                    route: NotificationConstants.manualRoute,
                    type: "uv_extreme",
                    includeDefaultSound: true
                ),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    @discardableResult
    func scheduleLeaveHomeReminder(
        level: UVLevel,
        route: AppRoute
    ) async -> NotificationOperationResult {
        await clearPendingRequests(prefix: NotificationConstants.leaveHomePrefix)

        let content = makeContent(
            title: level.shouldShowBanner ? "Heading out? UV is up." : "Heading out?",
            body: leaveHomeReminderBody(for: level),
            categoryIdentifier: NotificationConstants.dailyManualCategoryID,
            route: notificationRoute(for: route),
            type: "leave_home",
            includeDefaultSound: true
        )

        let request = UNNotificationRequest(
            identifier: "\(NotificationConstants.leaveHomePrefix)\(Int(now().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        return await addImmediateRequest(request, category: .leaveHome)
    }

    @discardableResult
    func scheduleAccountabilityPokeNotification(
        friendName: String,
        message: String,
        route: AppRoute
    ) async -> NotificationOperationResult {
        let content = makeContent(
            title: "\(friendName) sent a reminder",
            body: message.isEmpty ? "Sunscreen reminder." : message,
            categoryIdentifier: NotificationConstants.accountabilityCategoryID,
            route: notificationRoute(for: route),
            type: "accountability_poke",
            includeDefaultSound: true
        )
        let request = UNNotificationRequest(
            identifier: "\(NotificationConstants.accountabilityPokePrefix)\(Int(now().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        return await addImmediateRequest(request, category: .accountabilityPoke)
    }

    func cancelDailyReminder(for day: Date, using state: AppState) async {
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = state.settings.smartReminderSettings.notificationTimeZone()
        center.removePendingNotificationRequests(withIdentifiers: [
            dailyReminderIdentifier(forWeekday: scheduleCalendar.component(.weekday, from: day))
        ])
    }

    @discardableResult
    func refreshStreakRiskReminder(using state: AppState) async -> NotificationOperationResult {
        await clearPendingRequests(prefix: NotificationConstants.streakRiskPrefix)

        guard let streakRiskRequest = makeStreakRiskRequest(using: state) else {
            return .success("No evening reminder is needed right now.")
        }

        return await addImmediateRequest(streakRiskRequest, category: .streakRisk)
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

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Self.logger.error("Failed to submit weekly background task: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func nextDate(weekday: Int, hour: Int, minute: Int) -> Date {
        let referenceNow = now()
        let currentWeekday = calendar.component(.weekday, from: referenceNow)
        let delta = (weekday - currentWeekday + 7) % 7

        let base = calendar.date(byAdding: .day, value: delta, to: calendar.startOfDay(for: referenceNow)) ?? referenceNow
        let sameWeekTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base

        if sameWeekTime <= referenceNow {
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
            let report = CalendarAnalytics.weeklyReport(records: records, now: now(), calendar: calendar)

            let phrase = PhraseRotation.nextPhrase(from: settings.weeklyPhraseState, catalog: PhraseBank.weeklyPhrases)
            settings.weeklyPhraseState = phrase.1
            try context.save()

            let request = UNNotificationRequest(
                identifier: "\(NotificationConstants.weeklyPrimaryPrefix)\(Int(now().timeIntervalSince1970))",
                content: makeContent(
                    title: "Sunclub weekly report",
                    body: "You logged sunscreen \(report.appliedCount)/\(report.totalDays) days. "
                        + (report.missedDays.isEmpty ? "All 7 days are logged. " : "Not logged: \(report.missedDays.joined(separator: ", ")). ")
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
            Self.logger.error("Weekly report task failed: \(error.localizedDescription, privacy: .public)")
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

    @discardableResult
    func scheduleReapplyReminder(
        plan: ReapplyReminderPlan,
        route: AppRoute
    ) async -> NotificationOperationResult {
        await clearPendingRequests(prefix: NotificationConstants.reapplyPrefix)
        guard plan.shouldScheduleNotification else {
            return .success("No reapply reminder is needed right now.")
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(plan.intervalMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(NotificationConstants.reapplyPrefix)\(Int(now().timeIntervalSince1970))",
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

        return await addImmediateRequest(request, category: .reapply)
    }

    func cancelReapplyReminders() async {
        await clearPendingRequests(prefix: NotificationConstants.reapplyPrefix)
    }

    func notificationHealthSnapshot(using state: AppState) async -> NotificationHealthSnapshot {
        let pendingRequests = await center.pendingNotificationRequests()

        return NotificationHealthSnapshot(
            authorizationState: await center.authorizationState(),
            pendingCategoryCounts: categoryCounts(for: pendingRequests),
            expectedCategoryCounts: expectedCategoryCounts(using: state),
            lastScheduledAt: state.settings.lastReminderScheduleAt
        )
    }

    func sendTestNotification() async -> NotificationOperationResult {
        _ = await configure()
        let authorizationState = await center.authorizationState()
        guard authorizationState.allowsDelivery else {
            return .failure("Notifications are off. Turn them on in Settings, then try again.")
        }

        await clearPendingRequests(prefix: NotificationConstants.testPrefix)
        let content = makeContent(
            title: "Sunclub test reminder",
            body: "If you can see this, reminders are working on this phone.",
            categoryIdentifier: NotificationConstants.dailyManualCategoryID,
            route: NotificationConstants.manualRoute,
            type: "test",
            includeDefaultSound: true
        )
        let request = UNNotificationRequest(
            identifier: "\(NotificationConstants.testPrefix)current",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        let result = await addImmediateRequest(request, category: .test)
        if result.isSuccessful {
            return .success("Test reminder scheduled for about five seconds from now.")
        }
        return result
    }

    func diagnostics(using state: AppState) async -> String {
        let snapshot = await notificationHealthSnapshot(using: state)
        var lines = [
            "Sunclub notification diagnostics",
            "Authorization: \(snapshot.authorizationState.rawValue)",
            "Pending Sunclub requests: \(snapshot.pendingSunclubOwnedCount)/\(NotificationSchedulingPolicy.maximumOwnedPendingRequests)"
        ]
        for category in NotificationRequestCategory.allCases {
            let pending = snapshot.pendingCount(for: category)
            let expected = snapshot.expectedCategoryCounts[category] ?? 0
            guard pending > 0 || expected > 0 else {
                continue
            }
            lines.append("\(category.diagnosticLabel): \(pending) pending, \(expected) expected")
        }
        if let lastScheduledAt = snapshot.lastScheduledAt {
            lines.append("Last successful rebuild: \(lastScheduledAt.ISO8601Format())")
        } else {
            lines.append("Last successful rebuild: never")
        }
        if let lastSchedulingReport {
            lines.append("Last rebuild result: \(lastSchedulingReport.isSuccessful ? "success" : "failed")")
            lines.append("Last rebuild failures: \(lastSchedulingReport.failedCount)")
            for failure in lastSchedulingReport.failures.prefix(5) {
                lines.append("- \(failure.category.diagnosticLabel): \(failure.message)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func makeStreakRiskRequest(using state: AppState) -> UNNotificationRequest? {
        guard let plan = ReminderPlanner.streakRiskPlan(
            records: state.recordedDays,
            now: now(),
            settings: state.settings.smartReminderSettings,
            calendar: calendar
        ) else {
            return nil
        }

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
                title: "Today is still open",
                body: "Log sunscreen before the day ends if you wore it today.",
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

    @discardableResult
    private func addImmediateRequest(
        _ request: UNNotificationRequest,
        category: NotificationRequestCategory
    ) async -> NotificationOperationResult {
        let pendingRequests = await center.pendingNotificationRequests()
        let replacesExistingRequest = pendingRequests.contains { $0.identifier == request.identifier }
        let ownedPendingCount = pendingRequests.filter(isSunclubOwned).count
        guard replacesExistingRequest || ownedPendingCount < NotificationSchedulingPolicy.maximumOwnedPendingRequests else {
            let message = "Sunclub's reminder queue is full. Refresh Reminders in Settings, then try again."
            Self.logger.error("Skipped \(category.rawValue, privacy: .public) notification because the owned queue is full.")
            return .failure(message)
        }

        do {
            try await center.add(request)
            return .success("Reminder scheduled.")
        } catch {
            Self.logger.error(
                "Failed to add \(category.rawValue, privacy: .public) notification: \(error.localizedDescription, privacy: .public)"
            )
            return .failure("Sunclub couldn't schedule that reminder. Refresh Reminders and try again.")
        }
    }

    private func preservedImmediateRequests(
        from pendingRequests: [UNNotificationRequest]
    ) -> [UNNotificationRequest] {
        [.reapply, .test].compactMap { category in
            pendingRequests
                .filter { notificationCategory(for: $0) == category }
                .max { $0.identifier < $1.identifier }
        }
    }

    private func expectedCategoryCounts(using state: AppState) -> [NotificationRequestCategory: Int] {
        var counts: [NotificationRequestCategory: Int] = [
            .daily: 7,
            .weekly: 1
        ]

        let uvBriefingCount = makeUVBriefingRequests(using: state).count
        if uvBriefingCount > 0 {
            counts[.uvBriefing] = uvBriefingCount
        }

        let extremeUVCount = makeExtremeUVRequests(using: state).count
        if extremeUVCount > 0 {
            counts[.extremeUV] = extremeUVCount
        }

        if makeStreakRiskRequest(using: state) != nil {
            counts[.streakRisk] = 1
        }

        return counts
    }

    private func categoryCounts(
        for requests: [UNNotificationRequest]
    ) -> [NotificationRequestCategory: Int] {
        requests.reduce(into: [:]) { counts, request in
            guard let category = notificationCategory(for: request) else {
                return
            }
            counts[category, default: 0] += 1
        }
    }

    private func isSunclubOwned(_ request: UNNotificationRequest) -> Bool {
        request.identifier.hasPrefix(NotificationConstants.ownedPrefix)
    }

    private func notificationCategory(
        for request: UNNotificationRequest
    ) -> NotificationRequestCategory? {
        let identifier = request.identifier
        if identifier.hasPrefix(NotificationConstants.dailyPrefix) {
            return .daily
        }
        if identifier.hasPrefix(NotificationConstants.uvBriefingPrefix) {
            return .uvBriefing
        }
        if identifier.hasPrefix(NotificationConstants.extremeUVPrefix) {
            return .extremeUV
        }
        if identifier.hasPrefix(NotificationConstants.weeklyFallbackPrefix)
            || identifier.hasPrefix(NotificationConstants.weeklyPrimaryPrefix) {
            return .weekly
        }
        if identifier.hasPrefix(NotificationConstants.streakRiskPrefix) {
            return .streakRisk
        }
        if identifier.hasPrefix(NotificationConstants.reapplyPrefix) {
            return .reapply
        }
        if identifier.hasPrefix(NotificationConstants.leaveHomePrefix) {
            return .leaveHome
        }
        if identifier.hasPrefix(NotificationConstants.accountabilityPokePrefix) {
            return .accountabilityPoke
        }
        if identifier.hasPrefix(NotificationConstants.testPrefix) {
            return .test
        }
        return nil
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

    private func dailyReminderIdentifier(forWeekday weekday: Int) -> String {
        "\(NotificationConstants.dailyPrefix)repeating.\(weekday)"
    }

    private func leaveHomeReminderBody(for level: UVLevel) -> String {
        switch level {
        case .high:
            return "UV is high today. Log sunscreen before you leave home."
        case .veryHigh:
            return "UV is very high today. Log sunscreen before you head out and stay covered."
        case .extreme:
            return "UV is extreme today. Log sunscreen before you leave and plan to reapply early."
        default:
            return "Log sunscreen before you head out so today stays covered."
        }
    }

    private func notificationRoute(for route: AppRoute) -> String {
        switch route {
        case .manualLog:
            return NotificationConstants.manualRoute
        case .reapplyCheckIn:
            return NotificationConstants.reapplyRoute
        case .weeklySummary:
            return NotificationConstants.weeklyRoute
        case .friends, .accountabilityOnboarding:
            return NotificationConstants.accountabilityRoute
        default:
            return NotificationConstants.manualRoute
        }
    }

    private func handleReappliedNotificationAction() async {
        do {
            _ = try SunclubAutomationRuntime.performStandalone(.logReapply, invocation: .widget, now: now())
            await cancelReapplyReminders()
            await SunclubLiveActivityCoordinator.shared.endAll()
            await scheduleNextReapplyReminderFromStoredSettings()
        } catch {
            Self.logger.error(
                "Failed to log reapplication from notification action: \(error.localizedDescription, privacy: .public)"
            )
            routeHandler(.reapplyCheckIn)
        }
    }

    private func scheduleNextReapplyReminderFromStoredSettings() async {
        guard let context = makeBackgroundContext() else {
            return
        }

        do {
            let settings = try fetchSettings(context: context)
            guard settings.reapplyReminderEnabled else {
                return
            }
            let plan = ReapplyReminderPlan(
                baseIntervalMinutes: settings.reapplyIntervalMinutes,
                uvReading: nil,
                now: now(),
                calendar: calendar
            )
            await scheduleReapplyReminder(plan: plan, route: .reapplyCheckIn)
        } catch {
            Self.logger.error(
                "Failed to read reapply settings after notification action: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func handleSnoozeNotificationAction() async {
        let referenceDate = now()
        let plan = ReapplyReminderPlan(snoozeMinutes: 30, now: referenceDate, calendar: calendar)
        await clearPendingRequests(prefix: NotificationConstants.reapplyPrefix)
        guard plan.shouldScheduleNotification else {
            routeHandler(.reapplyCheckIn)
            return
        }

        let request = UNNotificationRequest(
            identifier: "\(NotificationConstants.reapplyPrefix)snooze",
            content: makeContent(
                title: plan.notificationTitle,
                body: plan.notificationBody,
                categoryIdentifier: NotificationConstants.reapplyCategoryID,
                route: NotificationConstants.reapplyRoute,
                type: "reapply_snooze",
                includeDefaultSound: true
            ),
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(plan.intervalMinutes * 60),
                repeats: false
            )
        )
        let result = await addImmediateRequest(request, category: .reapply)
        if result.isSuccessful, let deadline = plan.fireDate {
            await SunclubLiveActivityCoordinator.shared.snoozeAll(until: deadline, now: referenceDate)
        } else {
            routeHandler(.reapplyCheckIn)
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
            guard let self else {
                completionHandler()
                return
            }

            switch actionIdentifier {
            case NotificationConstants.actionManualID:
                routeHandler(.manualLog)
            case NotificationConstants.actionReappliedID:
                await handleReappliedNotificationAction()
            case NotificationConstants.actionSnoozeReapplyID:
                await handleSnoozeNotificationAction()
            default:
                if targetRoute == NotificationConstants.weeklyRoute {
                    routeHandler(.weeklySummary)
                } else if targetRoute == NotificationConstants.reapplyRoute {
                    routeHandler(.reapplyCheckIn)
                } else if targetRoute == NotificationConstants.accountabilityRoute {
                    routeHandler(.friends)
                } else if targetRoute == NotificationConstants.manualRoute {
                    routeHandler(.manualLog)
                } else {
                    routeHandler(.home)
                }
            }
            completionHandler()
        }
    }
}
