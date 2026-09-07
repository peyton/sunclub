import Foundation
import SwiftData
import XCTest
import UIKit
@testable import Sunclub

@MainActor
final class StartupTests: XCTestCase {
    func testReadableStoreStartsEvenWhileDeviceIsLocked() throws {
        let startup = SunclubStartup(
            isProtectedDataAvailable: { false },
            load: { try SunclubModelContainerFactory.makeInMemoryContainer() }
        )
        startup.retry()
        XCTAssertNotNil(startup.value)
        XCTAssertFalse(startup.isWaitingForProtectedData)
    }

    func testInaccessibleStoreRecoversWhenProtectedDataBecomesAvailableAndLoadsOnlyOnce() throws {
        var isAvailable = false
        var attempts = 0
        let startup = SunclubStartup(
            isProtectedDataAvailable: { isAvailable },
            load: {
                attempts += 1
                guard isAvailable else { throw CocoaError(.fileReadNoPermission) }
                return try SunclubModelContainerFactory.makeInMemoryContainer()
            }
        )

        startup.retry()
        XCTAssertNil(startup.value)
        XCTAssertTrue(startup.isWaitingForProtectedData)
        XCTAssertEqual(attempts, 1)

        isAvailable = true
        startup.retry()
        let container = try XCTUnwrap(startup.value)
        XCTAssertFalse(startup.isWaitingForProtectedData)
        startup.retry()
        XCTAssertTrue(startup.value === container)
        XCTAssertEqual(attempts, 2)
    }

    func testUnlockNotificationRecoversWithoutForegroundScene() async throws {
        let center = NotificationCenter()
        let loaded = expectation(description: "Opened after protected data became available")
        var isAvailable = false
        let startup = SunclubStartup(
            isProtectedDataAvailable: { isAvailable },
            load: {
                guard isAvailable else { throw CocoaError(.fileReadNoPermission) }
                let container = try SunclubModelContainerFactory.makeInMemoryContainer()
                loaded.fulfill()
                return container
            }
        )
        startup.observeProtectedDataAvailability(notificationCenter: center)
        startup.retry()
        XCTAssertNil(startup.value)

        isAvailable = true
        center.post(name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertNotNil(startup.value)
        XCTAssertFalse(startup.isWaitingForProtectedData)
    }

    func testAutomaticRetriesRecoverWithoutUserAction() async throws {
        var attempts = 0
        var delays: [Duration] = []
        let startup = SunclubStartup(
            isProtectedDataAvailable: { true },
            load: {
                attempts += 1
                if attempts < 4 { throw CocoaError(.fileReadNoPermission) }
                return try SunclubModelContainerFactory.makeInMemoryContainer()
            }
        )
        await startup.retryUntilReady { delay in delays.append(delay) }
        XCTAssertNotNil(startup.value)
        XCTAssertEqual(delays, [.seconds(1), .seconds(2), .seconds(4)])
        XCTAssertEqual(attempts, 4)
    }

    func testCancelledAutomaticRetryDoesNotOpenAnotherStore() async {
        var attempts = 0
        let startup = SunclubStartup<ModelContainer>(
            isProtectedDataAvailable: { true },
            load: {
                attempts += 1
                throw CocoaError(.fileReadNoPermission)
            }
        )
        await startup.retryUntilReady { _ in throw CancellationError() }
        XCTAssertNil(startup.value)
        XCTAssertEqual(attempts, 1)
    }

    func testFailedOpenKeepsExistingStoreAndRetryRecoversHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        let seededDates = try LegacyStoreFixture.seedCommit22ffStore(at: url)
        let originalData = try Data(contentsOf: url)
        var shouldFail = true
        let startup = SunclubStartup(
            isProtectedDataAvailable: { true },
            load: {
                if shouldFail {
                    throw CocoaError(.fileReadNoPermission)
                }
                return try SunclubModelContainerFactory.makeDiskBackedContainer(url: url)
            }
        )

        startup.retry()
        XCTAssertNil(startup.value)
        XCTAssertNotNil(startup.failureDescription)
        XCTAssertEqual(try Data(contentsOf: url), originalData)
        startup.retry()
        XCTAssertNil(startup.value)
        XCTAssertEqual(try Data(contentsOf: url), originalData)

        shouldFail = false
        startup.retry()
        let context = ModelContext(try XCTUnwrap(startup.value))
        XCTAssertNil(startup.failureDescription)
        let records = try context.fetch(FetchDescriptor<DailyRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(records.first?.verifiedAt, seededDates.verifiedAt)
        XCTAssertTrue(try XCTUnwrap(context.fetch(FetchDescriptor<Settings>()).first).hasCompletedOnboarding)
    }
}
