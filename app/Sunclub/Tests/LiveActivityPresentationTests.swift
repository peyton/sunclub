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

    func testDisabledRemindersDoNotPublishActivityFromSnapshot() {
        let now = Date()
        XCTAssertNil(SunclubLiveActivitySnapshotBridge.contentState(
            snapshot: makeSnapshot(now: now, remindersEnabled: false), now: now
        ))
        XCTAssertNil(SunclubLiveActivitySnapshotBridge.contentState(snapshot: .empty, now: now))
    }

    func testSnapshotDoesNotExtendActivityPastReminderSunsetCutoff() {
        let now = ReminderPlanner.estimatedSunset(for: Date()).addingTimeInterval(-60)
        let snapshot = makeSnapshot(now: now, remindersEnabled: true)
        XCTAssertNil(SunclubLiveActivitySnapshotBridge.contentState(snapshot: snapshot, now: now))
    }

    private func makeSnapshot(now: Date, remindersEnabled: Bool) -> SunclubWidgetSnapshot {
        SunclubWidgetSnapshot(
            isOnboardingComplete: true,
            lastLoggedDay: Calendar.current.startOfDay(for: now),
            lastVerifiedAt: now.addingTimeInterval(-60),
            lastReappliedAt: now,
            recordedDays: [Calendar.current.startOfDay(for: now)],
            currentStreak: 1, longestStreak: 1, weeklyAppliedCount: 1,
            monthlyAppliedCount: 1, monthlyDayCount: 1,
            mostUsedSPF: nil, currentUVIndex: nil, peakUVIndex: nil, peakUVHour: nil,
            reapplyReminderEnabled: remindersEnabled, reapplyIntervalMinutes: 120
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
