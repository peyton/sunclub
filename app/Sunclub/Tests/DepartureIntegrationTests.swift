import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class DepartureIntegrationTests: XCTestCase {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12))!

    private func fixture() throws -> (AppState, SunclubGrowthFeatureStore, SunclubWidgetSnapshotStore) {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let growth = SunclubGrowthFeatureStore(userDefaults: defaults)
        let widgets = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let state = AppState(context: ModelContext(container), notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(), widgetSnapshotStore: widgets, growthFeatureStore: growth,
            homeExitReminderMonitor: NoopHomeExitReminderMonitor(), clock: { self.now })
        XCTAssertTrue(state.completeOnboarding().succeeded)
        return (state, growth, widgets)
    }

    func testAppConfirmationUsesChosenTimeAndUndoRestoresPending() throws {
        let (state, _, _) = try fixture()
        let id = try XCTUnwrap(state.recordDepartureCheckIn(at: now))
        XCTAssertNil(state.record(for: now))
        XCTAssertEqual(state.pendingDepartureCheckInID, id)
        let applied = now.addingTimeInterval(-1800)
        let result = state.resolveDepartureCheckIn(id: id, action: .confirm(appliedAt: applied, spfLevel: 30, notes: nil))
        guard case let .success(receipt) = result else { return XCTFail("Expected confirmed application") }
        XCTAssertEqual(state.record(for: now)?.verifiedAt, applied)
        XCTAssertNil(state.pendingDepartureCheckIn)
        _ = state.undoChangeIfCurrent(batchID: try XCTUnwrap(receipt.batchID))
        XCTAssertEqual(state.pendingDepartureCheckInID, id)
        XCTAssertNil(state.record(for: now))
    }

    func testSnoozedCheckInRemainsInSharedSnapshotWithoutActivePrompt() throws {
        let (state, _, widgets) = try fixture()
        let id = try XCTUnwrap(state.recordDepartureCheckIn(at: now))
        let deadline = now.addingTimeInterval(900)
        XCTAssertTrue(state.resolveDepartureCheckIn(id: id, action: .snooze(until: deadline)).succeeded)
        XCTAssertNil(state.pendingDepartureCheckIn)
        XCTAssertEqual(widgets.load().pendingDepartureCheckInID, id)
        XCTAssertEqual(widgets.load().pendingDepartureSnoozedUntil, deadline)
        XCTAssertNil(state.record(for: now))
    }

    func testCheckInAutomationRespectsURLWritePermission() throws {
        let (state, growth, widgets) = try fixture()
        let id = try XCTUnwrap(state.recordDepartureCheckIn(at: now))
        var preferences = growth.load()
        preferences.automation.urlWriteActionsEnabled = false
        growth.save(preferences)
        XCTAssertThrowsError(try SunclubAutomationRuntime.perform(.dismissDepartureCheckIn(id: id), invocation: .url,
            context: state.modelContext, growthStore: growth, widgetStore: widgets, now: now)) {
            XCTAssertEqual($0 as? SunclubAutomationError, .urlWriteActionsDisabled)
        }
        state.refresh()
        XCTAssertEqual(state.pendingDepartureCheckInID, id)
    }

    func testCheckInAutomationRoutesRoundTripAndRejectInvalidIdentity() {
        for action in [SunclubAutomationAction.confirmDepartureCheckIn(id: UUID(), appliedAt: now),
                       .snoozeDepartureCheckIn(id: UUID()), .dismissDepartureCheckIn(id: UUID()),
                       .open(.departureCheckIn)] {
            let request = SunclubAutomationRequest(action: action, callback: nil)
            XCTAssertEqual(SunclubDeepLink(url: request.url), .automation(request))
        }
        XCTAssertNil(SunclubDeepLink(url: URL(string: "sunclub://automation/dismiss-check-in?id=bad")!))
    }
}
