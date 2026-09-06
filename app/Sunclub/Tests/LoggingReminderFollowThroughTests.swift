import Foundation
import SwiftData
import UserNotifications
import XCTest
@testable import Sunclub

@MainActor
final class LoggingReminderFollowThroughTests: XCTestCase {
    private let now = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)

    func testAdaptiveWidgetLogCancelsPreviouslySnoozedDeparture() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let history = SunclubHistoryService(context: context)
        try history.bootstrapIfNeeded()
        _ = try history.applySettingsChange(kind: .onboarding, summary: "Finish setup", changedFields: [.hasCompletedOnboarding]) {
            $0.hasCompletedOnboarding = true
        }
        _ = try history.recordDeparture(at: now)
        let checkIn = try XCTUnwrap(history.departureCheckIns().first)
        let deadline = now.addingTimeInterval(900)
        _ = try history.resolveDeparture(id: checkIn.id, action: .snooze(until: deadline), now: now)
        let departure = SunclubDepartureReminderBridge.request(id: checkIn.id, fireDate: deadline, now: now)
        var pending = [departure.identifier: departure]
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let widgets = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let result = try SunclubAutomationRuntime.performAdaptiveLog(
            context: context, growthStore: SunclubGrowthFeatureStore(userDefaults: defaults),
            widgetStore: widgets, now: now, historyService: history
        )
        XCTAssertEqual(result.didChange, true)
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .confirmed)
        await SunclubLoggingReminderBridge.sync(
            snapshot: widgets.load(), now: now, loadSnapshot: { widgets.load() },
            pendingRequests: { Array(pending.values) },
            removeRequests: { ids in ids.forEach { pending.removeValue(forKey: $0) } },
            addRequest: { pending[$0.identifier] = $0 }
        )
        XCTAssertFalse(pending.keys.contains { $0.hasPrefix(SunclubDepartureReminderBridge.prefix) })
    }

    func testUVRefreshDuringPendingFetchStillSchedulesCommittedApplicationReminder() async throws {
        let initial = snapshot(uv: nil)
        var current = initial
        var pending: [UNNotificationRequest] = []
        await SunclubLoggingReminderBridge.sync(
            snapshot: initial, now: now, loadSnapshot: { current },
            pendingRequests: {
                await Task.yield()
                current = self.snapshot(uv: 8)
                return []
            },
            removeRequests: { ids in pending.removeAll { ids.contains($0.identifier) } },
            addRequest: { pending.append($0) }
        )
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.identifier, SunclubLoggingReminderBridge.request(snapshot: current, now: now)?.identifier)
    }

    private func snapshot(uv: Int?) -> SunclubWidgetSnapshot {
        SunclubWidgetSnapshot(
            isOnboardingComplete: true, lastLoggedDay: Calendar.current.startOfDay(for: now),
            lastVerifiedAt: now, lastReappliedAt: nil, recordedDays: [Calendar.current.startOfDay(for: now)],
            currentStreak: 1, longestStreak: 1, weeklyAppliedCount: 1, monthlyAppliedCount: 1,
            monthlyDayCount: 30, mostUsedSPF: nil, currentUVIndex: uv, peakUVIndex: nil,
            peakUVHour: nil, reapplyReminderEnabled: true, reapplyIntervalMinutes: 120
        )
    }
}
