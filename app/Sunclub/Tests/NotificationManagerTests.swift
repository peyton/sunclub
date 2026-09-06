import SwiftData
import UserNotifications
import XCTest
@testable import Sunclub

@MainActor
private final class TestUserNotificationCenterClient: UserNotificationCenterClient {
    enum TestError: LocalizedError {
        case rejected(String)

        var errorDescription: String? {
            switch self {
            case let .rejected(identifier):
                return "Rejected \(identifier)"
            }
        }
    }

    private(set) var authorizationRequests = 0
    var authorization: NotificationAuthorizationState = .authorized
    var pendingRequests: [UNNotificationRequest] = []
    var rejectedIdentifierPrefixes: [String] = []
    private(set) var maximumPendingCount = 0
    private(set) var addedIdentifiers: [String] = []
    var transientFailures = 0
    var yieldsDuringAdd = false
    private var activeAdds = 0
    private(set) var maximumConcurrentAdds = 0
    private(set) var configuredCategories: Set<UNNotificationCategory> = []

    func configure(
        categories: Set<UNNotificationCategory>,
        delegate: any UNUserNotificationCenterDelegate
    ) {
        configuredCategories = categories
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequests += 1
        return authorization.allowsDelivery
    }

    func authorizationState() async -> NotificationAuthorizationState {
        authorization
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func add(_ request: UNNotificationRequest) async throws {
        activeAdds += 1
        maximumConcurrentAdds = max(maximumConcurrentAdds, activeAdds)
        defer { activeAdds -= 1 }
        if yieldsDuringAdd { await Task.yield() }
        addedIdentifiers.append(request.identifier)
        if transientFailures > 0 {
            transientFailures -= 1
            throw TestError.rejected(request.identifier)
        }
        if rejectedIdentifierPrefixes.contains(where: request.identifier.hasPrefix) {
            throw TestError.rejected(request.identifier)
        }
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
        maximumPendingCount = max(maximumPendingCount, pendingRequests.count)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        let identifierSet = Set(identifiers)
        pendingRequests.removeAll { identifierSet.contains($0.identifier) }
    }
}

@MainActor
private final class DepartureReminderTestState: SunclubReminderState {
    let underlying: AppState
    var pendingDepartureReminder: DepartureCheckInSnapshot?
    var settings: Settings { underlying.settings }
    var growthSettings: SunclubGrowthSettings { underlying.growthSettings }
    var recordedDays: [Date] { underlying.recordedDays }
    var uvReading: UVReading? { underlying.uvReading }

    init(underlying: AppState, departure: DepartureCheckInSnapshot) {
        self.underlying = underlying
        pendingDepartureReminder = departure
    }
    func record(for day: Date) -> DailyRecord? { underlying.record(for: day) }
    func nextDailyPhrases(count: Int) -> [String] { underlying.nextDailyPhrases(count: count) }
    func save() { underlying.save() }
}

@MainActor
final class NotificationManagerTests: XCTestCase {
    func testDailyReminderPlannerUsesFutureDatedRequests() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 10,
            hour: 10
        )))
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center, calendar: calendar, now: { now })
        let state = try makeAppState(notificationManager: manager, clock: { now })

        let requests = manager.makeDailyReminderRequests(using: state)

        XCTAssertGreaterThanOrEqual(requests.count, 27)
        XCTAssertEqual(Set(requests.map(\.identifier)).count, requests.count)
        for request in requests {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertFalse(trigger.repeats)
            XCTAssertNotNil(trigger.dateComponents.day)
            XCTAssertNotNil(trigger.dateComponents.hour)
            XCTAssertNotNil(trigger.dateComponents.minute)
        }
    }

    func testScheduleReportCountsFailuresAndOnlyRecordsSuccessfulRebuilds() async throws {
        let center = TestUserNotificationCenterClient()
        center.rejectedIdentifierPrefixes = ["sunscreen.daily."]
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let report = await manager.scheduleReminders(using: state)

        XCTAssertFalse(report.isSuccessful)
        XCTAssertGreaterThanOrEqual(report.result(for: .daily).requested, 27)
        XCTAssertEqual(report.result(for: .daily).scheduled, 0)
        XCTAssertEqual(report.result(for: .daily).failed, report.result(for: .daily).requested)
        // Every request gets its first attempt before the queue pays retry backoff.
        XCTAssertEqual(Set(center.addedIdentifiers.prefix(report.requestedCount)).count, report.requestedCount)
        let failedID = try XCTUnwrap(center.addedIdentifiers.first { $0.hasPrefix("sunscreen.daily.") })
        XCTAssertEqual(center.addedIdentifiers.filter { $0 == failedID }.count, 3)
        XCTAssertNil(state.settings.lastReminderScheduleAt)
        XCTAssertLessThanOrEqual(
            report.finalSunclubOwnedPendingCount,
            NotificationSchedulingPolicy.maximumOwnedPendingRequests
        )
    }

    func testScheduleReportRecordsTimestampAfterEveryRequiredRequestSucceeds() async throws {
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let report = await manager.scheduleReminders(using: state)

        XCTAssertTrue(report.isSuccessful)
        XCTAssertGreaterThanOrEqual(report.result(for: .daily).scheduled, 27)
        XCTAssertEqual(report.result(for: .weekly).scheduled, 1)
        XCTAssertNotNil(state.settings.lastReminderScheduleAt)
        XCTAssertLessThanOrEqual(
            report.finalSunclubOwnedPendingCount,
            NotificationSchedulingPolicy.maximumPlannedPendingRequests
        )
    }

    func testBudgetAlwaysReservesTwoImmediateRequestSlots() {
        let requests = (0..<70).map { index in
            NotificationPlannedRequest(
                category: .daily,
                request: UNNotificationRequest(
                    identifier: "sunscreen.daily.test.\(index)",
                    content: UNMutableNotificationContent(),
                    trigger: nil
                )
            )
        }

        let selection = NotificationRequestBudget.select(
            from: requests,
            preservedImmediateCount: 0
        )

        XCTAssertEqual(
            selection.selected.count,
            NotificationSchedulingPolicy.maximumPlannedPendingRequests
        )
        XCTAssertEqual(selection.dropped.count, 12)
    }

    func testHealthSnapshotRequiresEveryExpectedCategoryAndCountsAllPendingTypes() {
        let snapshot = NotificationHealthSnapshot(
            authorizationState: .authorized,
            pendingCategoryCounts: [
                .daily: 7,
                .weekly: 1,
                .reapply: 1,
                .test: 1
            ],
            expectedCategoryCounts: [
                .daily: 7,
                .weekly: 1,
                .uvBriefing: 7
            ],
            lastScheduledAt: Date()
        )

        XCTAssertEqual(snapshot.pendingSunclubOwnedCount, 10)
        XCTAssertEqual(snapshot.missingExpectedCategories, [.uvBriefing])
        let presentation = NotificationHealthEvaluator.presentation(
            from: snapshot,
            onboardingComplete: true
        )
        XCTAssertEqual(presentation?.state, .stale)
        XCTAssertTrue(presentation?.detail.contains("UV briefing") == true)
    }

    func testHealthSnapshotAccountsForEveryOwnedRequestCategory() async throws {
        let center = TestUserNotificationCenterClient()
        let expectedIdentifiers: [(String, NotificationRequestCategory)] = [
            ("sunscreen.daily.repeating.1", .daily),
            ("sunscreen.uv-briefing.1", .uvBriefing),
            ("sunscreen.uv-extreme.1", .extremeUV),
            ("sunscreen.weekly.fallback.repeating", .weekly),
            ("sunscreen.streak-risk.1", .streakRisk),
            ("sunscreen.reapply.1", .reapply),
            ("sunscreen.leave-home.1", .leaveHome),
            ("sunscreen.test.current", .test)
        ]
        center.pendingRequests = expectedIdentifiers.map { pair in
            UNNotificationRequest(
                identifier: pair.0,
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        }
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let snapshot = await manager.notificationHealthSnapshot(using: state)

        XCTAssertEqual(snapshot.pendingSunclubOwnedCount, expectedIdentifiers.count)
        for (_, category) in expectedIdentifiers {
            XCTAssertEqual(snapshot.pendingCount(for: category), 1)
        }
    }

    func testReconciliationKeepsTestRequestAndRemovesOrphanedReminders() async throws {
        let center = TestUserNotificationCenterClient()
        center.pendingRequests = [
            UNNotificationRequest(
                identifier: "sunscreen.reapply.current",
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "sunscreen.test.current",
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "sunscreen.leave-home.stale",
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        ]
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let report = await manager.scheduleReminders(using: state)

        XCTAssertFalse(center.pendingRequests.contains { $0.identifier == "sunscreen.reapply.current" })
        XCTAssertTrue(center.pendingRequests.contains { $0.identifier == "sunscreen.test.current" })
        XCTAssertFalse(center.pendingRequests.contains { $0.identifier == "sunscreen.leave-home.stale" })
        XCTAssertEqual(report.result(for: .reapply).pending, 0)
        XCTAssertEqual(report.result(for: .test).pending, 1)
        XCTAssertLessThanOrEqual(
            report.finalSunclubOwnedPendingCount,
            NotificationSchedulingPolicy.maximumOwnedPendingRequests
        )
    }

    func testConfigureRegistersBackgroundReapplyAndSnoozeActions() async {
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center)

        _ = await manager.configure()

        let titles = center.configuredCategories.flatMap { category in
            category.actions.map(\.title)
        }
        XCTAssertTrue(titles.contains("Log reapplication"))
        XCTAssertTrue(titles.contains("Snooze 30 min"))
    }

    func testTestReminderUsesReservedSlotAndReturnsSchedulingFailure() async {
        let center = TestUserNotificationCenterClient()
        center.pendingRequests = (0..<NotificationSchedulingPolicy.maximumOwnedPendingRequests).map { index in
            UNNotificationRequest(
                identifier: "sunscreen.leave-home.\(index)",
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        }
        let manager = NotificationManager(center: center)

        let result = await manager.sendTestNotification()

        XCTAssertFalse(result.isSuccessful)
        XCTAssertTrue(result.message.contains("queue is full"))
        XCTAssertEqual(center.pendingRequests.count, NotificationSchedulingPolicy.maximumOwnedPendingRequests)
    }

    func testTestReminderCanUseFinalReservedSlot() async {
        let center = TestUserNotificationCenterClient()
        center.pendingRequests = (0..<(NotificationSchedulingPolicy.maximumOwnedPendingRequests - 1)).map { index in
            UNNotificationRequest(
                identifier: "sunscreen.leave-home.\(index)",
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        }
        let manager = NotificationManager(center: center)

        let result = await manager.sendTestNotification()

        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(center.pendingRequests.count, NotificationSchedulingPolicy.maximumOwnedPendingRequests)
        XCTAssertTrue(center.pendingRequests.contains { $0.identifier == "sunscreen.test.current" })
    }

    func testReconciliationDoesNotRewriteUnchangedRequests() async throws {
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)
        _ = await manager.scheduleReminders(using: state)
        let count = center.addedIdentifiers.count

        _ = await manager.scheduleReminders(using: state)

        XCTAssertEqual(center.addedIdentifiers.count, count)
    }

    func testFailedReplacementPreservesPreviouslyScheduledReminder() async throws {
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)
        _ = await manager.scheduleReminders(using: state)
        let previous = try XCTUnwrap(center.pendingRequests.first { $0.identifier.hasPrefix("sunscreen.daily.") })
        state.settings.smartReminderSettings.weekdayTime = ReminderTime(hour: 11, minute: 0)
        state.settings.smartReminderSettings.weekendTime = ReminderTime(hour: 11, minute: 0)
        center.rejectedIdentifierPrefixes = ["sunscreen.daily."]

        let report = await manager.scheduleReminders(using: state)

        XCTAssertFalse(report.isSuccessful)
        let preserved = try XCTUnwrap(center.pendingRequests.first { $0.identifier == previous.identifier })
        XCTAssertTrue(preserved.trigger!.isEqual(previous.trigger))
    }

    func testTransientSchedulingFailureIsRetriedAutomatically() async throws {
        let center = TestUserNotificationCenterClient()
        center.transientFailures = 1
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let report = await manager.scheduleReminders(using: state)

        XCTAssertTrue(report.isSuccessful)
        XCTAssertNotNil(state.settings.lastReminderScheduleAt)
    }

    func testLoggingSuppressesOnlyThatDayAcrossReconciliation() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 14)))
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center, calendar: calendar, now: { now })
        let state = try makeAppState(notificationManager: manager, clock: { now })
        state.settings.smartReminderSettings.weekdayTime = ReminderTime(hour: 23, minute: 0)
        state.settings.smartReminderSettings.weekendTime = ReminderTime(hour: 23, minute: 0)
        _ = await manager.scheduleReminders(using: state)
        _ = state.markAppliedToday(method: .manual)

        await manager.cancelDailyReminder(for: now, using: state)
        _ = await manager.scheduleReminders(using: state)

        let daily = center.pendingRequests.filter { $0.identifier.hasPrefix("sunscreen.daily.") }
        XCTAssertGreaterThanOrEqual(daily.count, 27)
        for request in daily {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertFalse(trigger.repeats)
            let date = try XCTUnwrap(calendar.date(from: trigger.dateComponents))
            XCTAssertFalse(calendar.isDate(date, inSameDayAs: now))
        }
    }

    func testFailedReapplyReplacementPreservesExistingDeadline() async throws {
        let center = TestUserNotificationCenterClient()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 9)))
        let manager = NotificationManager(center: center, calendar: calendar, now: { now })
        let firstPlan = ReapplyReminderPlan(snoozeMinutes: 30, now: now, calendar: calendar)
        _ = await manager.scheduleReapplyReminder(plan: firstPlan, route: .reapplyCheckIn)
        let first = try XCTUnwrap(center.pendingRequests.first)
        center.rejectedIdentifierPrefixes = ["sunscreen.reapply."]

        let result = await manager.scheduleReapplyReminder(
            plan: ReapplyReminderPlan(snoozeMinutes: 15, now: now, calendar: calendar),
            route: .reapplyCheckIn
        )

        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(center.pendingRequests.count, 1)
        XCTAssertTrue(center.pendingRequests.first?.trigger?.isEqual(first.trigger) == true)
    }

    func testOverlappingReconciliationsSerializeNotificationWrites() async throws {
        let center = TestUserNotificationCenterClient()
        center.yieldsDuringAdd = true
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)
        let first = Task { await manager.scheduleReminders(using: state) }
        let second = Task { await manager.scheduleReminders(using: state) }

        _ = await first.value
        _ = await second.value

        XCTAssertEqual(center.maximumConcurrentAdds, 1)
        XCTAssertEqual(center.pendingRequests.count, Set(center.addedIdentifiers).count)
    }

    func testDeniedAuthorizationDoesNotClaimSuccessfulScheduling() async throws {
        let center = TestUserNotificationCenterClient()
        center.authorization = .denied
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let report = await manager.scheduleReminders(using: state)

        XCTAssertFalse(report.isSuccessful)
        XCTAssertNil(state.settings.lastReminderScheduleAt)
        XCTAssertTrue(center.pendingRequests.isEmpty)
    }

    func testBackgroundLoggingPreservesReminderWhenReplacementFails() async throws {
        let now = try XCTUnwrap(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()))
        let snapshot = SunclubWidgetSnapshot(
            isOnboardingComplete: true,
            lastLoggedDay: Calendar.current.startOfDay(for: now),
            lastVerifiedAt: now, lastReappliedAt: nil,
            recordedDays: [Calendar.current.startOfDay(for: now)],
            currentStreak: 1, longestStreak: 1, weeklyAppliedCount: 1,
            monthlyAppliedCount: 1, monthlyDayCount: 1,
            mostUsedSPF: nil, currentUVIndex: nil, peakUVIndex: nil, peakUVHour: nil,
            reapplyReminderEnabled: true, reapplyIntervalMinutes: 120
        )
        let center = TestUserNotificationCenterClient()
        let previous = UNNotificationRequest(
            identifier: "sunscreen.reapply.previous", content: UNMutableNotificationContent(),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 100, repeats: false)
        )
        center.pendingRequests = [previous]
        center.rejectedIdentifierPrefixes = ["sunscreen.reapply."]

        await SunclubLoggingReminderBridge.sync(
            snapshot: snapshot, now: now, loadSnapshot: { snapshot },
            pendingRequests: { center.pendingRequests },
            removeRequests: { center.removePendingNotificationRequests(withIdentifiers: $0) },
            addRequest: { try await center.add($0) }
        )

        XCTAssertEqual(center.pendingRequests.map(\.identifier), [previous.identifier])
    }

    func testReconciliationRepairsMissingReapplyFromCommittedApplicationTime() async throws {
        let now = try XCTUnwrap(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()))
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center, now: { now })
        let state = try makeAppState(notificationManager: manager, clock: { now })
        _ = state.markAppliedToday(method: .manual)
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        XCTAssertTrue(state.settings.reapplyReminderEnabled)
        XCTAssertNotNil(state.record(for: now))

        _ = await manager.scheduleReminders(using: state)

        let reapply = try XCTUnwrap(center.pendingRequests.first { $0.identifier.hasPrefix("sunscreen.reapply.") })
        let trigger = try XCTUnwrap(reapply.trigger as? UNCalendarNotificationTrigger)
        let deadline = try XCTUnwrap(Calendar.current.date(from: trigger.dateComponents))
        XCTAssertEqual(deadline.timeIntervalSince(now), 120 * 60, accuracy: 1)
    }

    func testReconciliationReclaimsObsoleteCapacityBeforeAddingRequests() async throws {
        let center = TestUserNotificationCenterClient()
        center.pendingRequests = (0..<60).map {
            UNNotificationRequest(identifier: "sunscreen.obsolete.\($0)", content: UNMutableNotificationContent(), trigger: nil)
        }
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let report = await manager.scheduleReminders(using: state)

        XCTAssertTrue(report.isSuccessful)
        XCTAssertLessThanOrEqual(center.maximumPendingCount, NotificationSchedulingPolicy.maximumOwnedPendingRequests)
    }

    func testDailyRequestUsesValidLocalTimeDuringSpringForward() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12)))
        let manager = NotificationManager(center: TestUserNotificationCenterClient(), calendar: calendar, now: { now })
        let state = try makeAppState(notificationManager: manager, clock: { now })
        state.settings.smartReminderSettings = SmartReminderSettings(
            weekdayTime: ReminderTime(hour: 2, minute: 30), weekendTime: ReminderTime(hour: 2, minute: 30),
            followsTravelTimeZone: false, anchoredTimeZoneIdentifier: calendar.timeZone.identifier
        )

        let request = try XCTUnwrap(manager.makeDailyReminderRequests(using: state).first {
            ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.day == 8
        })
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 3)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
    }

    func testContainerConfigurationRegistersBackgroundActionsWithoutPermissionPrompt() throws {
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center)
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()

        manager.configure(modelContainer: container)

        XCTAssertTrue(center.configuredCategories.contains { $0.identifier == "SUNSCREEN_DEPARTURE_CHECK_IN" })
        XCTAssertEqual(center.authorizationRequests, 0)
    }

    func testPendingInitialDepartureSurvivesReconciliationUntilResolved() async throws {
        let now = Date()
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center, now: { now })
        let departure = DepartureCheckInSnapshot(id: UUID(), day: Calendar.current.startOfDay(for: now), departedAt: now)
        let state = DepartureReminderTestState(
            underlying: try makeAppState(notificationManager: manager, clock: { now }), departure: departure
        )
        let result = await manager.scheduleDepartureCheckIn(id: departure.id, at: now)
        XCTAssertTrue(result.isSuccessful)

        _ = await manager.scheduleReminders(using: state)
        XCTAssertTrue(center.pendingRequests.contains { $0.identifier == "sunscreen.leave-home.\(departure.id.uuidString)" })

        state.pendingDepartureReminder?.resolution = .dismissed
        _ = await manager.scheduleReminders(using: state)
        XCTAssertFalse(center.pendingRequests.contains { $0.identifier.hasPrefix("sunscreen.leave-home.") })
    }

    func testPartialLegacyMigrationKeepsRepeatingFallbackWithoutDuplicateDatedRequests() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10, hour: 10)))
        let center = TestUserNotificationCenterClient()
        center.pendingRequests = (1...7).map { (weekday: Int) in
            UNNotificationRequest(
                identifier: "sunscreen.daily.repeating.\(weekday)", content: UNMutableNotificationContent(),
                trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 8, weekday: weekday), repeats: true)
            )
        }
        let legacyIDs = Set(center.pendingRequests.map(\.identifier))
        center.rejectedIdentifierPrefixes = ["sunscreen.daily.2026-8-11"]
        let manager = NotificationManager(center: center, calendar: calendar, now: { now })
        let state = try makeAppState(notificationManager: manager, clock: { now })

        let report = await manager.scheduleReminders(using: state)

        XCTAssertFalse(report.isSuccessful)
        XCTAssertEqual(Set(center.pendingRequests.filter { $0.identifier.hasPrefix("sunscreen.daily.") }.map(\.identifier)), legacyIDs)
    }

    func testSnoozeRejectsNotificationFromPreviousApplication() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let content = UNMutableNotificationContent()
        content.userInfo = ["applicationDate": now.addingTimeInterval(-3600).timeIntervalSince1970]
        let stale = UNNotificationRequest(identifier: "sunscreen.reapply.previous", content: content, trigger: nil)
        XCTAssertFalse(NotificationManager.shouldHandleSnooze(request: stale, currentApplication: now))
        XCTAssertTrue(NotificationManager.shouldHandleSnooze(request: stale, currentApplication: now.addingTimeInterval(-3600)))
        XCTAssertFalse(NotificationManager.shouldHandleSnooze(request: stale, currentApplication: nil))
        let unknown = UNNotificationRequest(identifier: "sunscreen.reapply.current", content: UNMutableNotificationContent(), trigger: nil)
        XCTAssertFalse(NotificationManager.shouldHandleSnooze(request: unknown, currentApplication: now))
    }

    func testDepartureConfirmationEarlierTimeSurvivesAppStateReapplyScheduling() async throws {
        let now = try XCTUnwrap(Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()))
        let appliedAt = now.addingTimeInterval(-30 * 60)
        let center = TestUserNotificationCenterClient()
        let manager = NotificationManager(center: center, now: { now })
        let state = try makeAppState(notificationManager: manager, clock: { now })
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        let id = try XCTUnwrap(state.recordDepartureCheckIn(at: now))
        XCTAssertTrue(state.resolveDepartureCheckIn(id: id, action: .confirm(appliedAt: appliedAt, spfLevel: nil, notes: nil)).succeeded)

        await state.scheduleReapplyReminder().value

        let reapply = try XCTUnwrap(center.pendingRequests.first { $0.identifier.hasPrefix("sunscreen.reapply.") })
        let trigger = try XCTUnwrap(reapply.trigger as? UNCalendarNotificationTrigger)
        let deadline = try XCTUnwrap(Calendar.current.date(from: trigger.dateComponents))
        XCTAssertEqual(deadline.timeIntervalSince(appliedAt), 120 * 60, accuracy: 1)
    }

    func testSnoozeRequiresAnApplicationAndReconcilesWhenDayChangesDuringScheduling() async throws {
        let now = try XCTUnwrap(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()))
        var clock = now
        let manager = MockNotificationManager()
        let state = try makeAppState(notificationManager: manager, clock: { clock })
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        let withoutApplication = await state.snoozeReapplyReminder(minutes: 15)
        XCTAssertFalse(withoutApplication.isSuccessful)
        _ = state.markAppliedToday(method: .manual)
        await Task.yield()
        var reconciliationCountAtDayChange = 0
        manager.reapplySchedulingHook = {
            clock = now.addingTimeInterval(24 * 60 * 60)
            reconciliationCountAtDayChange = manager.scheduleRemindersCount
        }

        _ = await state.snoozeReapplyReminder(minutes: 15)

        XCTAssertGreaterThan(manager.scheduleRemindersCount, reconciliationCountAtDayChange)
    }

    func testBackgroundEffectDiscardsOldDeadlineWhenSnoozeChangesWithoutSnapshotChange() async throws {
        let now = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2027, month: 6, day: 1, hour: 9)))
        let snapshot = SunclubWidgetSnapshot(
            isOnboardingComplete: true,
            lastLoggedDay: Calendar.current.startOfDay(for: now), lastVerifiedAt: now, lastReappliedAt: nil,
            recordedDays: [Calendar.current.startOfDay(for: now)],
            currentStreak: 1, longestStreak: 1, weeklyAppliedCount: 1,
            monthlyAppliedCount: 1, monthlyDayCount: 1,
            mostUsedSPF: nil, currentUVIndex: nil, peakUVIndex: nil, peakUVHour: nil,
            reapplyReminderEnabled: true, reapplyIntervalMinutes: 120
        )
        let baseline = now.addingTimeInterval(120 * 60)
        SunclubReapplySnoozeStore.save(applicationDate: now, deadline: baseline)
        defer { SunclubReapplySnoozeStore.save(applicationDate: now, deadline: baseline) }
        var pending: [String: UNNotificationRequest] = [:]
        var currentRequestID: String?

        await SunclubLoggingReminderBridge.sync(
            snapshot: snapshot, now: now, loadSnapshot: { snapshot }, pendingRequests: { [] },
            removeRequests: { ids in ids.forEach { pending.removeValue(forKey: $0) } },
            addRequest: { request in
                pending[request.identifier] = request
                SunclubReapplySnoozeStore.save(applicationDate: now, deadline: now.addingTimeInterval(30 * 60))
                let current = try XCTUnwrap(SunclubLoggingReminderBridge.request(snapshot: snapshot, now: now))
                XCTAssertNotEqual(current.identifier, request.identifier, "The snooze must change the deadline without changing the snapshot.")
                currentRequestID = current.identifier
                pending[current.identifier] = current
            }
        )

        XCTAssertEqual(Set(pending.keys), [try XCTUnwrap(currentRequestID)])
    }

    private func makeAppState(
        notificationManager: NotificationScheduling,
        clock: @escaping () -> Date = Date.init
    ) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(),
            runtimeEnvironment: .current,
            clock: clock
        )
    }
}
