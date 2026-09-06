import Foundation
import UserNotifications
import XCTest
@testable import Sunclub

@MainActor
final class DepartureReminderBridgeTests: XCTestCase {
    private let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
    private let id = UUID()

    func testUnrelatedSnapshotRefreshDuringAddKeepsSnoozedReminder() async throws {
        let deadline = now.addingTimeInterval(900)
        let harness = Harness(snapshot: snapshot(deadline: deadline))
        harness.onAdd = { [self] _, _ in
            await Task.yield()
            harness.snapshot = snapshot(deadline: deadline, uvIndex: 8)
        }
        await harness.run(now: now)
        XCTAssertEqual(harness.addCount, 1)
        XCTAssertEqual(harness.requests.count, 1)
        XCTAssertEqual(try triggerDate(harness), deadline)
        XCTAssertTrue(harness.removedIDs.isEmpty)
    }

    func testNewerSnoozeDuringAddReconcilesLatestDeadlineWithoutDeletingIt() async throws {
        let latest = now.addingTimeInterval(1800)
        let harness = Harness(snapshot: snapshot(deadline: now.addingTimeInterval(900)))
        harness.onAdd = { [self] _, attempt in
            guard attempt == 1 else { return }
            await Task.yield()
            harness.snapshot = snapshot(deadline: latest)
            // Another process publishes the newer snooze before this older add completes.
            let newer = SunclubDepartureReminderBridge.request(id: id, fireDate: latest, now: now)
            harness.requests[newer.identifier] = newer
        }
        await harness.run(now: now)
        XCTAssertEqual(harness.addCount, 2)
        XCTAssertEqual(try triggerDate(harness), latest)
        XCTAssertTrue(harness.removedIDs.isEmpty)
    }

    func testDismissalDuringAddRemovesStaleReminder() async {
        let harness = Harness(snapshot: snapshot(deadline: now.addingTimeInterval(900)))
        harness.onAdd = { _, _ in
            await Task.yield()
            harness.snapshot = .empty
        }
        await harness.run(now: now)
        XCTAssertEqual(harness.addCount, 1)
        XCTAssertTrue(harness.requests.isEmpty)
    }

    func testApplicationDuringAddRemovesStaleReminder() async {
        let deadline = now.addingTimeInterval(900)
        let harness = Harness(snapshot: snapshot(deadline: deadline))
        harness.onAdd = { [self] _, _ in
            await Task.yield()
            harness.snapshot = snapshot(deadline: deadline, logged: true)
        }
        await harness.run(now: now)
        XCTAssertTrue(harness.requests.isEmpty)
    }

    func testFailedReplacementPreservesExistingReminder() async throws {
        let original = now.addingTimeInterval(900)
        let harness = Harness(snapshot: snapshot(deadline: now.addingTimeInterval(1800)))
        let existing = SunclubDepartureReminderBridge.request(id: id, fireDate: original, now: now)
        harness.requests[existing.identifier] = existing
        harness.onAdd = { _, _ in throw NSError(domain: "NotificationFailure", code: 1) }
        await harness.run(now: now)
        XCTAssertEqual(try triggerDate(harness), original)
        XCTAssertTrue(harness.removedIDs.isEmpty)
    }

    func testMatchingSnoozeDoesNotAddAgainAndMissingInitialDeliveryDoesNotReplay() async {
        let deadline = now.addingTimeInterval(900)
        let harness = Harness(snapshot: snapshot(deadline: deadline))
        let existing = SunclubDepartureReminderBridge.request(id: id, fireDate: deadline, now: now)
        harness.requests[existing.identifier] = existing
        await harness.run(now: now)
        XCTAssertEqual(harness.addCount, 0)
        harness.requests.removeAll()
        harness.snapshot = snapshot(deadline: nil)
        await harness.run(now: now)
        XCTAssertEqual(harness.addCount, 0)
        XCTAssertTrue(harness.requests.isEmpty)
    }

    func testNextDaySnoozeClearsExistingAlert() async {
        let harness = Harness(snapshot: snapshot(deadline: now.addingTimeInterval(86400)))
        let existing = SunclubDepartureReminderBridge.request(id: id, fireDate: now.addingTimeInterval(900), now: now)
        harness.requests[existing.identifier] = existing
        await harness.run(now: now)
        XCTAssertTrue(harness.requests.isEmpty)
        XCTAssertEqual(harness.addCount, 0)
    }

    private func snapshot(deadline: Date?, uvIndex: Int? = nil, logged: Bool = false) -> SunclubWidgetSnapshot {
        SunclubWidgetSnapshot(
            isOnboardingComplete: true, lastLoggedDay: logged ? now : nil,
            lastVerifiedAt: logged ? now : nil, lastReappliedAt: nil,
            recordedDays: logged ? [Calendar.current.startOfDay(for: now)] : [],
            currentStreak: 0, longestStreak: 0, weeklyAppliedCount: 0,
            monthlyAppliedCount: 0, monthlyDayCount: 30, mostUsedSPF: nil,
            currentUVIndex: uvIndex, peakUVIndex: nil, peakUVHour: nil,
            reapplyReminderEnabled: false, reapplyIntervalMinutes: 120,
            pendingDepartureCheckInID: id, pendingDepartureDate: now,
            pendingDepartureSnoozedUntil: deadline
        )
    }

    private func triggerDate(_ harness: Harness) throws -> Date {
        let request = try XCTUnwrap(harness.requests.values.first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        return try XCTUnwrap(Calendar.current.date(from: trigger.dateComponents))
    }

    @MainActor
    private final class Harness {
        var snapshot: SunclubWidgetSnapshot
        var requests: [String: UNNotificationRequest] = [:]
        var removedIDs: [String] = []
        var addCount = 0
        var onAdd: (@MainActor (UNNotificationRequest, Int) async throws -> Void)?

        init(snapshot: SunclubWidgetSnapshot) { self.snapshot = snapshot }

        func run(now: Date) async {
            defer { onAdd = nil }
            await SunclubDepartureReminderBridge.reconcile(
                now: now,
                loadSnapshot: { self.snapshot },
                pendingRequests: { Array(self.requests.values) },
                addRequest: { request in
                    self.addCount += 1
                    try await self.onAdd?(request, self.addCount)
                    self.requests[request.identifier] = request
                },
                removeRequests: { ids in
                    self.removedIDs.append(contentsOf: ids)
                    for id in ids { self.requests.removeValue(forKey: id) }
                }
            )
        }
    }
}
