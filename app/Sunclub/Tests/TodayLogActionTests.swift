import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class TodayLogActionTests: SunclubTestCase {
    func testFirstLogSchedulesExactlyOneEnabledReapplyReminder() async throws {
        var now = try timestamp(hour: 9)
        let notifications = MockNotificationManager()
        let state = try makeAppState(notificationManager: notifications, clock: { now })
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        await waitForMainActorTasks()

        XCTAssertTrue(SunTodayLogAction.perform(in: state).succeeded)
        XCTAssertTrue(state.reapplyReminderPlan.shouldScheduleNotification)
        await waitForMainActorTasks()
        XCTAssertEqual(notifications.scheduleReapplyReminderPlans.count, 1)

        now = now.addingTimeInterval(3600)
        XCTAssertTrue(SunTodayLogAction.perform(in: state).succeeded)
        await waitForMainActorTasks()
        XCTAssertEqual(notifications.scheduleReapplyReminderPlans.count, 2)
    }

    func testFailedFirstLogDoesNotScheduleReapplyReminder() async throws {
        let now = try timestamp(hour: 9)
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        var rejectsChanges = false
        let history = SunclubHistoryService(context: context) {
            if rejectsChanges { throw SunclubHistoryMutationError.persistenceFailure }
        }
        let notifications = MockNotificationManager()
        let state = AppState(
            context: context, notificationManager: notifications, uvIndexService: UVIndexService(),
            historyService: history, cloudSyncCoordinator: ProbeCloudSyncCoordinator(), clock: { now }
        )
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        await waitForMainActorTasks()
        rejectsChanges = true

        XCTAssertFalse(SunTodayLogAction.perform(in: state).succeeded)
        await waitForMainActorTasks()

        XCTAssertNil(state.record(for: now))
        XCTAssertTrue(notifications.scheduleReapplyReminderPlans.isEmpty)
    }

    func testTodayIgnoresHistorySelectionAndNeverCopiesFreeFormNotes() throws {
        let now = try timestamp(hour: 12)
        let state = try makeAppState(clock: { now })
        let yesterday = now.addingTimeInterval(-86400)
        XCTAssertTrue(state.saveManualRecord(
            for: yesterday, verifiedAt: yesterday, spfLevel: 50,
            notes: "Private beach note\nAreas: Ears, Body"
        ).succeeded)
        state.selectDay(yesterday)

        XCTAssertTrue(SunTodayLogAction.perform(in: state).succeeded)

        let today = try XCTUnwrap(state.record(for: now))
        XCTAssertEqual(today.verifiedAt, now)
        XCTAssertEqual(today.spfLevel, 50)
        XCTAssertEqual(SunManualLogInput.coveredAreas(in: today.notes), ["Ears", "Body"])
        XCTAssertEqual(SunManualLogInput.notesRemovingCoveredAreas(today.notes), "")
        XCTAssertEqual(state.record(for: yesterday)?.notes, "Private beach note\nAreas: Ears, Body")
    }

    func testReapplicationAndUndoWorkWhenRemindersAreDisabled() throws {
        var now = try timestamp(hour: 9)
        let state = try makeAppState(clock: { now })
        XCTAssertFalse(state.settings.reapplyReminderEnabled)
        XCTAssertTrue(SunTodayLogAction.perform(in: state).succeeded)
        let first = now
        now = now.addingTimeInterval(3600)

        guard case let .success(receipt) = SunTodayLogAction.perform(in: state) else {
            return XCTFail("Reapplication must be independent of reminders.")
        }
        XCTAssertEqual(state.record(for: now)?.verifiedAt, first)
        XCTAssertEqual(state.record(for: now)?.lastReappliedAt, now)
        XCTAssertEqual(state.record(for: now)?.reapplyCount, 1)
        let batchID = try XCTUnwrap(receipt.batchID)
        _ = try state.undoChangeIfCurrent(batchID: batchID).get()
        XCTAssertEqual(state.record(for: now)?.reapplyCount, 0)
        XCTAssertEqual(state.record(for: now)?.verifiedAt, first)
    }

    func testTapAfterMidnightCreatesNewDayWithoutChangingYesterday() throws {
        var now = try timestamp(hour: 23, minute: 59)
        let state = try makeAppState(clock: { now })
        XCTAssertTrue(SunTodayLogAction.perform(in: state).succeeded)
        let yesterday = now
        now = now.addingTimeInterval(120)

        XCTAssertTrue(SunTodayLogAction.perform(in: state).succeeded)

        XCTAssertEqual(state.records.count, 2)
        XCTAssertEqual(state.record(for: now)?.verifiedAt, now)
        XCTAssertEqual(state.record(for: now)?.reapplyCount, 0)
        XCTAssertEqual(state.record(for: yesterday)?.verifiedAt, yesterday)
        XCTAssertEqual(state.record(for: yesterday)?.reapplyCount, 0)
    }

    private func timestamp(hour: Int, minute: Int = 0) throws -> Date {
        try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: hour, minute: minute)))
    }
}
