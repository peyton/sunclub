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

    var authorization: NotificationAuthorizationState = .authorized
    var pendingRequests: [UNNotificationRequest] = []
    var rejectedIdentifierPrefixes: [String] = []
    private(set) var configuredCategories: Set<UNNotificationCategory> = []

    func configure(
        categories: Set<UNNotificationCategory>,
        delegate: any UNUserNotificationCenterDelegate
    ) {
        configuredCategories = categories
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorization.allowsDelivery
    }

    func authorizationState() async -> NotificationAuthorizationState {
        authorization
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func add(_ request: UNNotificationRequest) async throws {
        if rejectedIdentifierPrefixes.contains(where: request.identifier.hasPrefix) {
            throw TestError.rejected(request.identifier)
        }
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        let identifierSet = Set(identifiers)
        pendingRequests.removeAll { identifierSet.contains($0.identifier) }
    }
}

@MainActor
final class NotificationManagerTests: XCTestCase {
    func testDailyReminderPlannerUsesSevenRepeatingWeekdayRequests() throws {
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

        XCTAssertEqual(requests.count, 7)
        XCTAssertEqual(Set(requests.map(\.identifier)).count, 7)
        for request in requests {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertTrue(trigger.repeats)
            XCTAssertNotNil(trigger.dateComponents.weekday)
            XCTAssertNotNil(trigger.dateComponents.hour)
            XCTAssertNotNil(trigger.dateComponents.minute)
        }
    }

    func testScheduleReportCountsFailuresAndOnlyRecordsSuccessfulRebuilds() async throws {
        let center = TestUserNotificationCenterClient()
        center.rejectedIdentifierPrefixes = ["sunscreen.daily.repeating.3"]
        let manager = NotificationManager(center: center)
        let state = try makeAppState(notificationManager: manager)

        let report = await manager.scheduleReminders(using: state)

        XCTAssertFalse(report.isSuccessful)
        XCTAssertEqual(report.result(for: .daily).requested, 7)
        XCTAssertEqual(report.result(for: .daily).scheduled, 6)
        XCTAssertEqual(report.result(for: .daily).failed, 1)
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
        XCTAssertEqual(report.result(for: .daily).scheduled, 7)
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

    func testScheduleRebuildPreservesImmediateSlotsAndReplacesOtherOwnedRequests() async throws {
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

        XCTAssertTrue(center.pendingRequests.contains { $0.identifier == "sunscreen.reapply.current" })
        XCTAssertTrue(center.pendingRequests.contains { $0.identifier == "sunscreen.test.current" })
        XCTAssertFalse(center.pendingRequests.contains { $0.identifier == "sunscreen.leave-home.stale" })
        XCTAssertEqual(report.result(for: .reapply).pending, 1)
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
