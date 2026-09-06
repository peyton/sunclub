import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class LiveActivityPresentationTests: XCTestCase {
    func testPreviousDayApplicationDoesNotShowReapplyDueOrNextTimer() throws {
        let now = Date()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let state = makeState(start: yesterday, deadline: now.addingTimeInterval(600))

        XCTAssertFalse(state.hasCurrentApplication(now: now))
        XCTAssertFalse(state.isReapplyDue(now: now))
        XCTAssertEqual(state.statusTitle(now: now), "Not logged today")
        XCTAssertNil(state.nextReapplyLabel(now: now))
    }

    func testFutureApplicationIsNotShownAsCurrent() {
        let now = Date()
        let state = makeState(start: now.addingTimeInterval(60), deadline: now.addingTimeInterval(600))
        XCTAssertFalse(state.hasCurrentApplication(now: now))
    }

    func testCurrentApplicationBecomesDueAtDeadline() {
        let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 60 * 60)
        let deadline = now.addingTimeInterval(600)
        let state = makeState(start: now, deadline: deadline)

        XCTAssertTrue(state.hasCurrentApplication(now: now))
        XCTAssertFalse(state.isReapplyDue(now: deadline.addingTimeInterval(-1)))
        XCTAssertTrue(state.isReapplyDue(now: deadline))
        XCTAssertEqual(state.statusTitle(now: deadline), "Reapply due")
    }

    func testCommittedSnapshotRestartsTimerWithoutUV() throws {
        let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 60 * 60)
        let snapshot = makeSnapshot(now: now, remindersEnabled: true)
        let state = try XCTUnwrap(SunclubLiveActivitySnapshotBridge.contentState(snapshot: snapshot, now: now))
        XCTAssertEqual(state.reapplyStartDate, now)
        XCTAssertEqual(state.reapplyDeadline, now.addingTimeInterval(120 * 60))
        XCTAssertEqual(state.lastAppliedLabel, now.formatted(date: .omitted, time: .shortened))
        XCTAssertFalse(state.hasFreshUV(now: now))
    }

    func testDisabledNotificationsStillAllowLiveActivityFromSnapshot() {
        let now = Date()
        let noon = Calendar.current.startOfDay(for: now).addingTimeInterval(12 * 3600)
        XCTAssertNotNil(SunclubLiveActivitySnapshotBridge.contentState(
            snapshot: makeSnapshot(now: noon, remindersEnabled: false), now: noon
        ))
        XCTAssertNil(SunclubLiveActivitySnapshotBridge.contentState(snapshot: .empty, now: now))
    }

    func testSnapshotDoesNotExtendActivityPastReminderSunsetCutoff() {
        let now = ReminderPlanner.estimatedSunset(for: Date()).addingTimeInterval(-60)
        let snapshot = makeSnapshot(now: now, remindersEnabled: true)
        XCTAssertNil(SunclubLiveActivitySnapshotBridge.contentState(snapshot: snapshot, now: now))
    }

    func testSnoozePreservesActualApplicationTime() {
        let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let original = makeState(start: now.addingTimeInterval(-3600), deadline: now)
        let updated = SunclubLiveActivityCoordinator.snoozedContentState(
            original, until: now.addingTimeInterval(900), now: now
        )
        XCTAssertEqual(updated.reapplyStartDate, original.reapplyStartDate)
        XCTAssertEqual(updated.lastAppliedLabel, original.lastAppliedLabel)
        XCTAssertFalse(updated.isReapplyDue(now: now))
    }

    func testDeadlineOverridesStaleDueLabel() {
        let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        var state = makeState(start: now, deadline: now.addingTimeInterval(900))
        state.countdownLabel = "due"
        XCTAssertFalse(state.isReapplyDue(now: now))
    }

    func testPendingCheckInNeverReportsAnApplicationAndExpiresAtMidnight() throws {
        let noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let state = SunclubLiveActivitySnapshotBridge.pendingContentState(id: UUID(), departureDate: noon)
        XCTAssertTrue(state.hasPendingCheckIn(now: noon))
        XCTAssertFalse(state.hasCurrentApplication(now: noon))
        XCTAssertEqual(state.statusTitle(now: noon), "Did you apply sunscreen?")
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: noon))
        XCTAssertFalse(state.hasPendingCheckIn(now: tomorrow))
        XCTAssertFalse(state.isReapplyDue(now: tomorrow))
        XCTAssertEqual(state.statusTitle(now: tomorrow), "Not logged today")
    }

    func testSnoozeSurvivesRefreshAndDoesNotApplyToNextApplication() throws {
        let suite = "LiveActivityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let start = noon.addingTimeInterval(-7200)
        let snoozed = noon.addingTimeInterval(900)
        SunclubLiveActivitySessionStore.saveSnooze(applicationDate: start, deadline: snoozed, defaults: defaults)
        XCTAssertEqual(SunclubLiveActivitySessionStore.deadline(applicationDate: start, baseline: noon, now: noon, defaults: defaults), snoozed)
        // An expired snooze stays due; refresh must not reset the timer.
        XCTAssertEqual(SunclubLiveActivitySessionStore.deadline(applicationDate: start, baseline: noon, now: snoozed.addingTimeInterval(60), defaults: defaults), snoozed)
        XCTAssertEqual(SunclubLiveActivitySessionStore.deadline(applicationDate: noon, baseline: noon.addingTimeInterval(7200), now: noon, defaults: defaults), noon.addingTimeInterval(7200))
    }

    func testDismissedSessionDoesNotRestartButNextApplicationCanStart() {
        XCTAssertFalse(SunclubLiveActivitySessionStore.shouldStart(sessionID: "application-1", previousSessionID: "application-1", mayStart: true))
        XCTAssertTrue(SunclubLiveActivitySessionStore.shouldStart(sessionID: "application-2", previousSessionID: "application-1", mayStart: true))
        XCTAssertFalse(SunclubLiveActivitySessionStore.shouldStart(sessionID: "application-2", previousSessionID: nil, mayStart: false))
    }

    func testLegacySettingsAndSnapshotDefaultLiveActivitiesOn() throws {
        let settings = try JSONDecoder().decode(SmartReminderSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(settings.liveActivitiesEnabled)
        let snapshot = try JSONDecoder().decode(SunclubWidgetSnapshot.self, from: Data("{}".utf8))
        XCTAssertTrue(snapshot.liveActivitiesEnabled)
        XCTAssertNil(snapshot.pendingDepartureCheckInID)
        var updated = settings
        updated.liveActivitiesEnabled = false
        XCTAssertFalse(try JSONDecoder().decode(SmartReminderSettings.self, from: JSONEncoder().encode(updated)).liveActivitiesEnabled)
        XCTAssertFalse(updated.normalized(fallbackHour: 8, fallbackMinute: 0).liveActivitiesEnabled)
    }

    func testLiveActivityPreferenceDisablesSnapshotTimerEvenWithRemindersOn() {
        let noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        XCTAssertNil(SunclubLiveActivitySnapshotBridge.contentState(
            snapshot: makeSnapshot(now: noon, remindersEnabled: true, liveActivitiesEnabled: false), now: noon
        ))
    }

    func testFallbackCountdownUsesCurrentDateInsteadOfCachedLabel() {
        let noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let state = makeState(start: noon, deadline: noon.addingTimeInterval(600))
        XCTAssertEqual(state.fallbackTimerText(now: noon.addingTimeInterval(300)), "5m")
    }

    func testWidgetStatusUsesDurableSnoozeWithoutChangingApplication() throws {
        let suite = "WidgetSnoozeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let noon = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let snapshot = makeSnapshot(now: noon, remindersEnabled: true)
        let due = noon.addingTimeInterval(7200)
        let snoozed = due.addingTimeInterval(900)
        SunclubReapplySnoozeStore.save(applicationDate: noon, deadline: snoozed, defaults: defaults)
        let status = snapshot.applicationStatus(now: due, snoozeDefaults: defaults)
        XCTAssertEqual(status.lastAppliedAt, noon)
        XCTAssertEqual(status.reapplyDeadline, snoozed)
        XCTAssertFalse(status.isReapplyDue)
        XCTAssertTrue(snapshot.applicationStatus(now: snoozed, snoozeDefaults: defaults).isReapplyDue)
        let reapplied = makeSnapshot(now: due, remindersEnabled: true)
        XCTAssertEqual(reapplied.reapplyDeadline(now: due, snoozeDefaults: defaults), due.addingTimeInterval(7200))
    }

    private func makeSnapshot(now: Date, remindersEnabled: Bool, liveActivitiesEnabled: Bool = true) -> SunclubWidgetSnapshot {
        SunclubWidgetSnapshot(
            isOnboardingComplete: true,
            lastLoggedDay: Calendar.current.startOfDay(for: now),
            lastVerifiedAt: now.addingTimeInterval(-60),
            lastReappliedAt: now,
            recordedDays: [Calendar.current.startOfDay(for: now)],
            currentStreak: 1, longestStreak: 1, weeklyAppliedCount: 1,
            monthlyAppliedCount: 1, monthlyDayCount: 1,
            mostUsedSPF: nil, currentUVIndex: nil, peakUVIndex: nil, peakUVHour: nil,
            reapplyReminderEnabled: remindersEnabled, reapplyIntervalMinutes: 120,
            liveActivitiesEnabled: liveActivitiesEnabled
        )
    }

    private func makeState(start: Date, deadline: Date) -> SunclubLiveActivityAttributes.ContentState {
        SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: 0,
            peakUVIndex: 0,
            countdownLabel: "in 10m",
            lastAppliedLabel: "12:00 PM",
            lastLogDetail: "SPF 50",
            reapplyStartDate: start,
            reapplyDeadline: deadline,
            uvValidUntil: .distantPast
        )
    }
}
