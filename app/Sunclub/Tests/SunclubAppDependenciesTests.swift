import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubAppDependenciesTests: XCTestCase {
    func testTestFactoryInjectsClockAndDisablesExternalSync() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dependencies = SunclubAppDependencies.test(
            context: ModelContext(container), notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(), clock: { date }
        )
        XCTAssertTrue(dependencies.cloudSyncCoordinator is NoopCloudSyncCoordinator)
        XCTAssertTrue(dependencies.homeExitReminderMonitor is NoopHomeExitReminderMonitor)
        let state = AppState(dependencies: dependencies)
        XCTAssertEqual(state.referenceDate, date)
        XCTAssertEqual(state.selectedDay, Calendar.current.startOfDay(for: date))
    }
}
