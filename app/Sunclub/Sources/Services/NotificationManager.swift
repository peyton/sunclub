import BackgroundTasks
import Foundation
import OSLog
import SwiftData
import UserNotifications

private enum NotificationConstants {
    static let backgroundTaskID = "com.peyton.sunclub.weekly-report"
    static let dailyManualCategoryID = "SUNSCREEN_DAILY_MANUAL"
    static let departureCategoryID = "SUNSCREEN_DEPARTURE_CHECK_IN"
    static let departureRoute = "departure-check-in"
    static let actionDepartureAppliedID = "SUNSCREEN_DEPARTURE_ALREADY_APPLIED"
    static let actionDepartureSnoozeID = "SUNSCREEN_DEPARTURE_SNOOZE"
    static let actionDepartureDismissID = "SUNSCREEN_DEPARTURE_DISMISS"
    static let reapplyCategoryID = "SUNSCREEN_REAPPLY"
    static let actionManualID = "LOG_TODAY_ACTION"
    static let actionReappliedID = "LOG_REAPPLY_ACTION"
    static let actionSnoozeReapplyID = "SNOOZE_REAPPLY_ACTION"
    static let routeKey = "targetRoute"
    static let manualRoute = "manual"
    static let weeklyRoute = "weekly"
    static let reapplyRoute = "reapply"
    static let dailyPrefix = "sunscreen.daily."
    static let weeklyFallbackPrefix = "sunscreen.weekly.fallback."
    static let weeklyPrimaryPrefix = "sunscreen.weekly.primary."
    static let reapplyPrefix = "sunscreen.reapply."
    static let streakRiskPrefix = "sunscreen.streak-risk."
    static let leaveHomePrefix = "sunscreen.leave-home."
    static let uvBriefingPrefix = "sunscreen.uv-briefing."
    static let extremeUVPrefix = "sunscreen.uv-extreme."
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
    func scheduleReminders(using state: any SunclubReminderState) async -> NotificationSchedulingReport
    @discardableResult
    func refreshStreakRiskReminder(using state: any SunclubReminderState) async -> NotificationOperationResult
    @discardableResult
    func scheduleReapplyReminder(plan: ReapplyReminderPlan, route: AppRoute) async -> NotificationOperationResult
    @discardableResult
    func scheduleLeaveHomeReminder(level: UVLevel, route: AppRoute) async -> NotificationOperationResult
    @discardableResult
    func scheduleDepartureCheckIn(id: UUID, at date: Date) async -> NotificationOperationResult
    func cancelDailyReminder(for day: Date, using state: any SunclubReminderState) async
    func cancelReapplyReminders() async
    func notificationHealthSnapshot(using state: any SunclubReminderState) async -> NotificationHealthSnapshot
}

extension NotificationScheduling {
    func scheduleDepartureCheckIn(id: UUID, at date: Date) async -> NotificationOperationResult {
        await scheduleLeaveHomeReminder(level: .unknown, route: .departureCheckIn)
    }
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
    private var isReconciling = false
    private var reconciliationWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var lastSchedulingReport: NotificationSchedulingReport?

    override convenience init() {
        self.init(center: SystemUserNotificationCenterClient())
    }

    init(
        center: any UserNotificationCenterClient,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.calendar = calendar
        self.now = now
        super.init()
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        configureCategoriesIfNeeded()
        registerBackgroundTaskIfNeeded()
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

    private func configureCategoriesIfNeeded() {
        if !configured {
            configured = true

            let actionManual = UNNotificationAction(identifier: NotificationConstants.actionManualID, title: "Log sunscreen", options: [.foreground])
            let dailyManualCategory = UNNotificationCategory(
                identifier: NotificationConstants.dailyManualCategoryID,
                actions: [actionManual],
                intentIdentifiers: []
            )
            let actionReapplied = UNNotificationAction(
                identifier: NotificationConstants.actionReappliedID,
                title: "Log reapplication",
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

            let departureCategory = UNNotificationCategory(
                identifier: NotificationConstants.departureCategoryID,
                actions: [
                    UNNotificationAction(identifier: NotificationConstants.actionDepartureAppliedID, title: "Already applied", options: [.foreground]),
                    UNNotificationAction(identifier: NotificationConstants.actionDepartureSnoozeID, title: "Remind me in 15 minutes", options: []),
                    UNNotificationAction(identifier: NotificationConstants.actionDepartureDismissID, title: "Dismiss", options: [])
                ],
                intentIdentifiers: []
            )
            center.configure(
                categories: [dailyManualCategory, reapplyCategory, departureCategory],
                delegate: self
            )
        }

    }

    func configure() async -> Bool {
        configureCategoriesIfNeeded()
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
    func scheduleReminders(using state: any SunclubReminderState) async -> NotificationSchedulingReport {
        await acquireReconciliation()
        defer { releaseReconciliation() }
        configureCategoriesIfNeeded()
        registerBackgroundTaskIfNeeded()
        let pendingRequests = await center.pendingNotificationRequests()
        let preservedImmediateRequests = preservedImmediateRequests(from: pendingRequests, using: state)
        let plannedRequests = makePlannedRequests(using: state)
        let budgetedRequests = NotificationRequestBudget.select(
            from: plannedRequests,
            preservedImmediateCount: preservedImmediateRequests.count
        )
        let selectedIDs = Set(budgetedRequests.selected.map { $0.request.identifier })
        let selectedCategories = Set(budgetedRequests.selected.map(\.category))
        let preservedIDs = Set(preservedImmediateRequests.map(\.identifier))
        // Reclaim disabled, expired and unknown requests before consuming more OS slots.
        // A valid request in a category being changed survives until replacement succeeds.
        let retiredIDs = pendingRequests.filter { request in
            guard isSunclubOwned(request), !selectedIDs.contains(request.identifier),
                  !preservedIDs.contains(request.identifier) else { return false }
            guard let category = notificationCategory(for: request), selectedCategories.contains(category) else { return true }
            if category == .reapply, let record = state.record(for: now()),
               !Self.shouldHandleSnooze(request: request, currentApplication: record.lastReappliedAt ?? record.verifiedAt) {
                return true
            }
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger, !trigger.repeats,
                  let date = calendar.date(from: trigger.dateComponents) else { return false }
            return date <= now()
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: retiredIDs)
        var attempt = await addBudgetedRequests(
            budgetedRequests.selected,
            droppedRequests: budgetedRequests.dropped,
            authorization: await center.authorizationState()
        )
        let desiredIDs = Set(budgetedRequests.selected.map { $0.request.identifier })
            .union(preservedImmediateRequests.map(\.identifier))
        let failedCategories = Set(attempt.failures.map(\.category))
        if failedCategories.contains(.daily), pendingRequests.contains(where: {
            notificationCategory(for: $0) == .daily && ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == true
        }) {
            // Calendar recurrence cannot skip individual dates. If its migration only
            // partly succeeds, keep the old recurrence and roll back dated additions
            // so the same application reminder never fires from both schedules.
            let datedIDs = (pendingRequests + budgetedRequests.selected.map(\.request)).filter {
                notificationCategory(for: $0) == .daily && ($0.trigger as? UNCalendarNotificationTrigger)?.repeats == false
            }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: datedIDs)
            attempt.scheduledCounts[.daily] = 0
        }
        // Only retire superseded requests after their category's replacements succeeded.
        // Requests for a disabled category are deliberately obsolete.
        let obsolete = pendingRequests.filter { request in
            guard isSunclubOwned(request), !desiredIDs.contains(request.identifier) else { return false }
            return notificationCategory(for: request).map { !failedCategories.contains($0) } ?? true
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: obsolete)
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

    private func acquireReconciliation() async {
        if !isReconciling {
            isReconciling = true
            return
        }
        await withCheckedContinuation { reconciliationWaiters.append($0) }
    }

    private func releaseReconciliation() {
        if reconciliationWaiters.isEmpty {
            isReconciling = false
        } else {
            reconciliationWaiters.removeFirst().resume()
        }
    }

    private func makePlannedRequests(using state: any SunclubReminderState) -> [NotificationPlannedRequest] {
        var requests = makeDailyReminderRequests(using: state).map {
            NotificationPlannedRequest(category: .daily, request: $0)
        }
        if let reapply = makeReapplyRequest(using: state) {
            requests.append(NotificationPlannedRequest(category: .reapply, request: reapply))
        }
        if let departure = state.pendingDepartureReminder,
           departure.resolution == .unconfirmed,
           departure.isOnDay(now(), calendar: calendar),
           let deadline = departure.snoozedUntil, deadline > now(),
           calendar.isDate(deadline, inSameDayAs: now()) {
            requests.append(NotificationPlannedRequest(
                category: .leaveHome, request: makeDepartureCheckInRequest(id: departure.id, at: deadline)
            ))
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
        droppedRequests: [NotificationPlannedRequest],
        authorization: NotificationAuthorizationState
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
        var remaining = requests
        var remainingFailures: [NotificationSchedulingFailure] = []

        // Back off once per round, not per request: a daemon failure must not
        // turn a month's reminder queue into a long, blocking onboarding wait.
        for round in 0..<3 {
            guard !remaining.isEmpty else { break }
            if round > 0 {
                guard authorization.allowsDelivery, !Task.isCancelled else { break }
                do {
                    try await Task.sleep(for: .milliseconds(100 * round))
                } catch { break }
            }
            let currentPending = await center.pendingNotificationRequests()
            var ownedIDs = Set(currentPending.filter(isSunclubOwned).map(\.identifier))
            var retryRequests: [NotificationPlannedRequest] = []
            var roundFailures: [NotificationSchedulingFailure] = []
            for planned in remaining {
                do {
                    guard authorization.allowsDelivery else {
                        throw NotificationReconciliationError.notificationsUnavailable
                    }
                    let existing = currentPending.first { $0.identifier == planned.request.identifier }
                    if existing.map({ requestsMatch($0, planned.request) }) != true {
                        guard ownedIDs.contains(planned.request.identifier)
                            || ownedIDs.count < NotificationSchedulingPolicy.maximumOwnedPendingRequests else {
                            throw NotificationReconciliationError.queueFull
                        }
                        try await center.add(planned.request)
                        ownedIDs.insert(planned.request.identifier)
                    }
                    attempt.scheduledCounts[planned.category, default: 0] += 1
                } catch {
                    retryRequests.append(planned)
                    roundFailures.append(NotificationSchedulingFailure(
                        category: planned.category,
                        identifier: planned.request.identifier,
                        message: error.localizedDescription
                    ))
                }
            }
            remaining = retryRequests
            remainingFailures = roundFailures
        }
        for failure in remainingFailures {
            Self.logger.error("Failed to add \(failure.category.rawValue, privacy: .public) notification: \(failure.message, privacy: .public)")
        }
        attempt.failures += remainingFailures
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

    func makeDailyReminderRequests(using state: any SunclubReminderState) -> [UNNotificationRequest] {
        let reminderSettings = state.settings.smartReminderSettings
        let timeZone = reminderSettings.notificationTimeZone()
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone
        let referenceNow = now()
        let today = scheduleCalendar.startOfDay(for: referenceNow)
        let loggedDays = Set(state.recordedDays.map { scheduleCalendar.startOfDay(for: $0) })

        // Dated requests can skip a logged day without deleting future weekday reminders.
        // Every foreground/background reconciliation replenishes this rolling horizon.
        return (0..<NotificationSchedulingPolicy.dailyRollingDayCount).compactMap { offset in
            guard let day = scheduleCalendar.date(byAdding: .day, value: offset, to: today),
                  !loggedDays.contains(day) else { return nil }
            let weekday = scheduleCalendar.component(.weekday, from: day)
            let time = (weekday == 1 || weekday == 7) ? reminderSettings.weekendTime : reminderSettings.weekdayTime
            guard let fireDate = ReminderPlanner.scheduledDate(
                for: day, time: time, timeZone: timeZone, calendar: scheduleCalendar
            ), fireDate > referenceNow else { return nil }
            let components = scheduleCalendar.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: fireDate
            )
            let phrases = PhraseBank.dailyPhrases
            let ordinal = scheduleCalendar.ordinality(of: .day, in: .era, for: day) ?? offset
            let phrase = phrases.isEmpty ? "Did you apply sunscreen today?" : phrases[abs(ordinal) % phrases.count]
            return UNNotificationRequest(
                identifier: "\(NotificationConstants.dailyPrefix)\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)",
                content: makeContent(
                    title: "Sunclub check-in", body: phrase,
                    categoryIdentifier: NotificationConstants.dailyManualCategoryID,
                    route: NotificationConstants.manualRoute, type: "daily", includeDefaultSound: true
                ),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    private func makeUVBriefingRequests(using state: any SunclubReminderState) -> [UNNotificationRequest] {
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
                readingSource: state.uvReading?.source,
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
            guard let fireDate = scheduleCalendar.date(from: components), fireDate > referenceNow else { return nil }

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

    private func makeExtremeUVRequests(using state: any SunclubReminderState) -> [UNNotificationRequest] {
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
                readingSource: state.uvReading?.source,
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
            guard let fireDate = scheduleCalendar.date(from: components), fireDate > referenceNow else { return nil }

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
    func scheduleDepartureCheckIn(id: UUID, at date: Date) async -> NotificationOperationResult {
        await addImmediateRequest(makeDepartureCheckInRequest(id: id, at: date), category: .leaveHome)
    }

    private func makeDepartureCheckInRequest(id: UUID, at date: Date) -> UNNotificationRequest {
        SunclubDepartureReminderBridge.request(id: id, fireDate: date, now: now())
    }

    func cancelDailyReminder(for day: Date, using state: any SunclubReminderState) async {
        // The committed history is the suppression source, including after restart or undo.
        _ = await scheduleReminders(using: state)
    }

    @discardableResult
    func refreshStreakRiskReminder(using state: any SunclubReminderState) async -> NotificationOperationResult {
        let report = await scheduleReminders(using: state)
        return report.result(for: .streakRisk).failed == 0
            ? .success("Evening reminder checked.")
            : .failure("Sunclub couldn't update the evening reminder. It will retry automatically.")
    }

    private func makeWeeklyFallbackRequest(using state: any SunclubReminderState) -> UNNotificationRequest? {
        var components = DateComponents()
        components.weekday = state.settings.weeklyWeekday
        components.hour = state.settings.weeklyHour
        components.minute = 0
        components.timeZone = state.settings.smartReminderSettings.notificationTimeZone()

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
            let succeeded = await reconcileStoredReminders()
            submitWeeklyBackgroundTask(
                weekday: settings.weeklyWeekday,
                hour: settings.weeklyHour,
                minute: 0
            )
            task.setTaskCompleted(success: succeeded)
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
        throw NotificationReconciliationError.missingSettings
    }

    @discardableResult
    func scheduleReapplyReminder(
        plan: ReapplyReminderPlan,
        route: AppRoute
    ) async -> NotificationOperationResult {
        guard let fireDate = plan.fireDate, fireDate > now() else {
            await cancelReapplyReminders()
            return .success("No reapply reminder is needed right now.")
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: fireDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(NotificationConstants.reapplyPrefix)current",
            content: makeContent(
                title: plan.notificationTitle,
                body: plan.notificationBody,
                categoryIdentifier: NotificationConstants.reapplyCategoryID,
                route: notificationRoute(for: route),
                type: "reapply",
                includeDefaultSound: true,
                applicationDate: SunclubWidgetSnapshotStore().load().lastApplicationDate(now: now())
                    ?? fireDate.addingTimeInterval(-TimeInterval(plan.intervalMinutes * 60))
            ),
            trigger: trigger
        )

        return await addImmediateRequest(request, category: .reapply)
    }

    func cancelReapplyReminders() async {
        await acquireReconciliation()
        defer { releaseReconciliation() }
        await clearPendingRequests(prefix: NotificationConstants.reapplyPrefix)
    }

    func notificationHealthSnapshot(using state: any SunclubReminderState) async -> NotificationHealthSnapshot {
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

    func diagnostics(using state: any SunclubReminderState) async -> String {
        let snapshot = await notificationHealthSnapshot(using: state)
        var lines = [
            "Sunclub notification diagnostics",
            "Authorization: \(snapshot.authorizationState.rawValue)",
            "Pending Sunclub requests: \(snapshot.pendingSunclubOwnedCount)/\(NotificationSchedulingPolicy.maximumOwnedPendingRequests)"
        ]
        lines.append("Live Activities preference: \(state.settings.smartReminderSettings.liveActivitiesEnabled ? "on" : "off")")
        if let error = SunclubLiveActivitySessionStore.lastRequestError {
            lines.append("Last Live Activity request failure: \(error)")
        }
        lines.append("Daily horizon: up to \(NotificationSchedulingPolicy.dailyRollingDayCount) days; refreshed when Sunclub runs.")
        lines.append("Pending requests are accepted by iOS; delivery may be quiet or delayed by system settings.")
        for category in NotificationRequestCategory.allCases {
            let pending = snapshot.pendingCount(for: category)
            let expected = snapshot.expectedCategoryCounts[category] ?? 0
            guard pending > 0 || expected > 0 else {
                continue
            }
            lines.append("\(category.diagnosticLabel): \(pending) pending, \(expected) expected")
        }
        if let lastScheduledAt = snapshot.lastScheduledAt {
            lines.append("Last successful reconciliation: \(lastScheduledAt.ISO8601Format())")
        } else {
            lines.append("Last successful reconciliation: never")
        }
        if let lastSchedulingReport {
            lines.append("Last reconciliation result: \(lastSchedulingReport.isSuccessful ? "success" : "failed")")
            lines.append("Last reconciliation failures: \(lastSchedulingReport.failedCount)")
            for failure in lastSchedulingReport.failures.prefix(5) {
                lines.append("- \(failure.category.diagnosticLabel): \(failure.message)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func makeStreakRiskRequest(using state: any SunclubReminderState) -> UNNotificationRequest? {
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
        await acquireReconciliation()
        defer { releaseReconciliation() }
        guard await center.authorizationState().allowsDelivery else {
            return .failure("Notifications are off. Turn them on in Settings.")
        }
        let pendingRequests = await center.pendingNotificationRequests()
        let replacesExistingRequest = pendingRequests.contains { $0.identifier == request.identifier }
        let ownedPendingCount = pendingRequests.filter(isSunclubOwned).count
        guard replacesExistingRequest || ownedPendingCount < NotificationSchedulingPolicy.maximumOwnedPendingRequests else {
            let message = "Sunclub's reminder queue is full. It will be checked automatically when Sunclub runs."
            Self.logger.error("Skipped \(category.rawValue, privacy: .public) notification because the owned queue is full.")
            return .failure(message)
        }

        do {
            if pendingRequests.first(where: { $0.identifier == request.identifier }).map({ requestsMatch($0, request) }) != true {
                try await addWithRetry(request)
            }
            let superseded = pendingRequests.filter {
                notificationCategory(for: $0) == category && $0.identifier != request.identifier
            }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: superseded)
            return .success("Reminder accepted by iOS.")
        } catch {
            Self.logger.error(
                "Failed to add \(category.rawValue, privacy: .public) notification: \(error.localizedDescription, privacy: .public)"
            )
            return .failure("Sunclub couldn't schedule that reminder. It will retry when Sunclub next checks reminders.")
        }
    }

    private func preservedImmediateRequests(
        from pendingRequests: [UNNotificationRequest], using state: any SunclubReminderState
    ) -> [UNNotificationRequest] {
        var preserved = pendingRequests.filter { notificationCategory(for: $0) == .test }
            .max { $0.identifier < $1.identifier }.map { [$0] } ?? []
        if let departure = state.pendingDepartureReminder,
           departure.resolution == .unconfirmed,
           departure.isOnDay(now(), calendar: calendar), state.record(for: now()) == nil,
           departure.snoozedUntil.map({ calendar.isDate($0, inSameDayAs: now()) }) ?? true,
           let request = pendingRequests.first(where: {
               $0.identifier == "\(NotificationConstants.leaveHomePrefix)\(departure.id.uuidString)"
           }) {
            // Initial delivery may still be pending during another foreground refresh.
            // Preserve that request, but never recreate it once iOS has delivered it.
            preserved.append(request)
        }
        return preserved
    }

    private func expectedCategoryCounts(using state: any SunclubReminderState) -> [NotificationRequestCategory: Int] {
        makePlannedRequests(using: state).reduce(into: [:]) { counts, planned in
            counts[planned.category, default: 0] += 1
        }
    }

    private func makeReapplyRequest(using state: any SunclubReminderState) -> UNNotificationRequest? {
        let referenceNow = now()
        guard state.settings.reapplyReminderEnabled, let record = state.record(for: referenceNow) else { return nil }
        let applicationDate = record.lastReappliedAt ?? record.verifiedAt
        guard applicationDate <= referenceNow, calendar.isDate(applicationDate, inSameDayAs: referenceNow) else { return nil }
        let plan = ReapplyReminderPlan(
            baseIntervalMinutes: state.settings.reapplyIntervalMinutes,
            uvReading: state.uvReading, now: applicationDate, calendar: calendar
        )
        guard let baseline = plan.fireDate else { return nil }
        let deadline = SunclubLiveActivitySessionStore.deadline(
            applicationDate: applicationDate, baseline: baseline, now: referenceNow
        )
        guard deadline > referenceNow, calendar.isDate(deadline, inSameDayAs: referenceNow) else { return nil }
        return UNNotificationRequest(
            identifier: "\(NotificationConstants.reapplyPrefix)\(applicationDate.timeIntervalSince1970).\(deadline.timeIntervalSince1970)",
            content: makeContent(
                title: plan.notificationTitle, body: plan.notificationBody,
                categoryIdentifier: NotificationConstants.reapplyCategoryID,
                route: NotificationConstants.reapplyRoute, type: "reapply", includeDefaultSound: true,
                applicationDate: applicationDate
            ),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: deadline),
                repeats: false
            )
        )
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
        includeDefaultSound: Bool = false,
        applicationDate: Date? = nil
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [NotificationConstants.routeKey: route, "type": type]
        if let applicationDate { content.userInfo["applicationDate"] = applicationDate.timeIntervalSince1970 }
        if includeDefaultSound {
            content.sound = .default
        }
        return content
    }

    fileprivate enum NotificationReconciliationError: LocalizedError {
        case notificationsUnavailable
        case queueFull
        case missingSettings
        var errorDescription: String? {
            switch self {
            case .notificationsUnavailable: "Notification permission is not enabled."
            case .queueFull: "The reminder queue is full; existing reminders were retained."
            case .missingSettings: "Reminder settings have not finished restoring."
            }
        }
    }

    private func requestsMatch(_ lhs: UNNotificationRequest, _ rhs: UNNotificationRequest) -> Bool {
        lhs.content.isEqual(rhs.content) && (
            (lhs.trigger == nil && rhs.trigger == nil) || lhs.trigger?.isEqual(rhs.trigger) == true
        )
    }

    private func addWithRetry(_ request: UNNotificationRequest) async throws {
        let pending = await center.pendingNotificationRequests()
        guard pending.contains(where: { $0.identifier == request.identifier })
            || pending.filter(isSunclubOwned).count < NotificationSchedulingPolicy.maximumOwnedPendingRequests else {
            throw NotificationReconciliationError.queueFull
        }
        for attempt in 0..<3 {
            do {
                try await center.add(request)
                return
            } catch {
                if attempt == 2 || Task.isCancelled { throw error }
                try await Task.sleep(for: .milliseconds(100 * (attempt + 1)))
            }
        }
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
        case .departureCheckIn:
            return NotificationConstants.departureRoute
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

    private func handleReappliedNotificationAction() async {
        do {
            _ = try SunclubAutomationRuntime.performStandalone(.logReapply, invocation: .widget, now: now())
            let snapshot = SunclubWidgetSnapshotStore().load()
            await SunclubLoggingReminderBridge.sync(snapshot: snapshot, now: now())
            await SunclubLiveActivitySnapshotBridge.updateExisting(snapshot: snapshot, now: now())
            await reconcileStoredReminders()
        } catch {
            Self.logger.error(
                "Failed to log reapplication from notification action: \(error.localizedDescription, privacy: .public)"
            )
            routeHandler(.reapplyCheckIn)
        }
    }

    @discardableResult
    private func reconcileStoredReminders() async -> Bool {
        guard let context = makeBackgroundContext() else { return false }
        do {
            let input = try BackgroundReminderState(context: context)
            return await scheduleReminders(using: input).isSuccessful
        } catch {
            Self.logger.error("Couldn't refresh stored reminders: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func shouldHandleSnooze(request: UNNotificationRequest, currentApplication: Date?) -> Bool {
        guard let currentApplication else { return false }
        let timestamp: TimeInterval?
        if let recorded = request.content.userInfo["applicationDate"] as? TimeInterval {
            timestamp = recorded
        } else if request.identifier.hasPrefix(NotificationConstants.reapplyPrefix) {
            // Shipped numeric identifiers used the original schedule timestamp.
            // Legacy "current" and "snooze" identifiers have no trustworthy identity.
            let suffix = String(request.identifier.dropFirst(NotificationConstants.reapplyPrefix.count))
            let components = suffix.split(separator: ".")
            timestamp = Double(suffix) ?? (components.count >= 3
                ? Double("\(components[0]).\(components[1])") : nil)
        } else {
            timestamp = nil
        }
        guard let timestamp, timestamp.isFinite else { return false }
        return abs(timestamp - currentApplication.timeIntervalSince1970) < 0.001
    }

    private func handleSnoozeNotificationAction(_ request: UNNotificationRequest) async {
        let referenceDate = now()
        let applicationDate = SunclubWidgetSnapshotStore().load().lastApplicationDate(now: referenceDate)
        guard Self.shouldHandleSnooze(request: request, currentApplication: applicationDate) else { return }
        let plan = ReapplyReminderPlan(snoozeMinutes: 30, now: referenceDate, calendar: calendar)
        guard let deadline = plan.fireDate, calendar.isDate(deadline, inSameDayAs: referenceDate) else { return }
        let result = await scheduleReapplyReminder(plan: plan, route: .reapplyCheckIn)
        let latest = now()
        let snapshot = SunclubWidgetSnapshotStore().load()
        guard snapshot.reapplyReminderEnabled, calendar.isDate(referenceDate, inSameDayAs: latest),
              snapshot.lastApplicationDate(now: latest) == applicationDate else {
            await reconcileStoredReminders()
            return
        }
        if result.isSuccessful {
            await SunclubLiveActivityCoordinator.shared.snoozeAll(
                until: deadline, now: referenceDate, applicationDate: applicationDate
            )
            await reconcileStoredReminders()
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
        let checkInID = (response.notification.request.content.userInfo["checkInID"] as? String).flatMap(UUID.init(uuidString:))

        Task { @MainActor [weak self] in
            guard let self else {
                completionHandler()
                return
            }

            switch actionIdentifier {
            case NotificationConstants.actionDepartureAppliedID:
                routeHandler(.departureCheckIn)
            case NotificationConstants.actionDepartureSnoozeID, NotificationConstants.actionDepartureDismissID:
                do {
                    let action: SunclubAutomationAction = actionIdentifier == NotificationConstants.actionDepartureSnoozeID
                        ? .snoozeDepartureCheckIn(id: checkInID) : .dismissDepartureCheckIn(id: checkInID)
                    let result = try SunclubAutomationRuntime.performStandalone(action, invocation: .widget, now: now())
                    await DepartureCheckInIntentEffects.sync(didChange: result.didChange == true)
                    await reconcileStoredReminders()
                } catch {
                    routeHandler(.departureCheckIn)
                }
            case NotificationConstants.actionManualID:
                routeHandler(.manualLog)
            case NotificationConstants.actionReappliedID:
                await handleReappliedNotificationAction()
            case NotificationConstants.actionSnoozeReapplyID:
                await handleSnoozeNotificationAction(response.notification.request)
            default:
                if targetRoute == NotificationConstants.departureRoute {
                    routeHandler(.departureCheckIn)
                } else if targetRoute == NotificationConstants.weeklyRoute {
                    routeHandler(.weeklySummary)
                } else if targetRoute == NotificationConstants.reapplyRoute {
                    routeHandler(.reapplyCheckIn)
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

@MainActor
private final class BackgroundReminderState: SunclubReminderState {
    let settings: Settings
    let growthSettings: SunclubGrowthSettings
    let recordedDays: [Date]
    let uvReading: UVReading? = nil
    let pendingDepartureReminder: DepartureCheckInSnapshot?
    private let context: ModelContext
    private let records: [DailyRecord]

    init(context: ModelContext) throws {
        self.context = context
        let history = SunclubHistoryService(context: context)
        guard let savedSettings = try context.fetch(FetchDescriptor<Settings>()).first else {
            throw NotificationManager.NotificationReconciliationError.missingSettings
        }
        settings = savedSettings
        records = try context.fetch(FetchDescriptor<DailyRecord>())
        recordedDays = records.map(\.startOfDay)
        growthSettings = SunclubGrowthFeatureStore().load()
        pendingDepartureReminder = try history.departureCheckIns().first {
            $0.resolution == .unconfirmed && $0.isOnDay(Date())
        }
    }

    func nextDailyPhrases(count: Int) -> [String] { Array(PhraseBank.dailyPhrases.prefix(count)) }
    func record(for day: Date) -> DailyRecord? { records.first { Calendar.current.isDate($0.startOfDay, inSameDayAs: day) } }
    func save() { try? context.save() }
}
