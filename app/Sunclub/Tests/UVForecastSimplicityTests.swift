import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class UVForecastSimplicityTests: SunclubTestCase {
    // Catches reusing AppState's launch-day selection after the local clock crosses midnight.
    func testForecastDayFollowsMidnightWithoutChangingLegacyDaySelection() throws {
        let calendar = Calendar.current
        let initialDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 4)))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 5)))
        var now = try XCTUnwrap(calendar.date(bySettingHour: 23, minute: 59, second: 0, of: initialDay))
        let suite = "UVForecastSimplicityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let state = try makeAppState(
            notificationManager: MockNotificationManager(),
            homeExitReminderMonitor: MockHomeExitReminderMonitor(),
            cloudSyncCoordinator: ProbeCloudSyncCoordinator(),
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: defaults),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true, isPreviewing: false, hasAppGroupContainer: false
            ),
            clock: { now }
        )
        XCTAssertEqual(UVForecastDetailView.referenceDay(in: state), initialDay)
        XCTAssertEqual(state.selectedDay, initialDay)

        now = now.addingTimeInterval(2 * 60)

        XCTAssertEqual(
            UVForecastDetailView.referenceDay(in: state), nextDay,
            "Forecast must advance with the actual local day without relying on a navigation selection."
        )
        XCTAssertEqual(state.selectedDay, initialDay, "Reading today's forecast must not mutate another date selection.")
    }
}
