import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class ImprovementTests: XCTestCase {

    // MARK: - Fix 1: Duplicate widgetSnapshotStore parameter removed

    func testAppStateInitAcceptsSingleWidgetSnapshotStore() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService(),
            widgetSnapshotStore: SunclubWidgetSnapshotStore()
        )
        XCTAssertNotNil(state)
    }

    // MARK: - Fix 2: SunclubSchemaV3 frozen model definitions

    func testSchemaV3DefinesFrozenDailyRecord() {
        let models = SunclubSchemaV3.models
        XCTAssertTrue(models.contains(where: { $0 == SunclubSchemaV3.DailyRecord.self }))
    }

    func testSchemaV3DefinesFrozenSettings() {
        let models = SunclubSchemaV3.models
        XCTAssertTrue(models.contains(where: { $0 == SunclubSchemaV3.Settings.self }))
    }

    func testMigrationV2ToV3UsesFrozenTypes() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        _ = try LegacyStoreFixture.seedCurrentV2Store(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyRecord>()).first)
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
    }

    func testMigrationV3ToV4PreservesData() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        let seededDates = try LegacyStoreFixture.seedCurrentV3Store(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.reapplyReminderEnabled)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyRecord>()).first)
        XCTAssertEqual(record.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(record.reapplyCount, 1)
    }

    func testFullMigrationV1ThroughV4() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        _ = try LegacyStoreFixture.seedCommit22ffStore(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertNotNil(settings.smartReminderSettingsData)
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyRecord>()).first)
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
        XCTAssertEqual(record.method, .manual)

        XCTAssertFalse(try context.fetch(FetchDescriptor<SunclubChangeBatch>()).isEmpty)
        XCTAssertFalse(try context.fetch(FetchDescriptor<SettingsRevision>()).isEmpty)
    }

    // MARK: - Fix 6: UV heuristic hemisphere support

    func testEstimatedUVNorthernHemisphereSummerIsHigh() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // July noon, Northern Hemisphere
        let julyNoon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let uvNorth = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: 40.0)
        XCTAssertGreaterThanOrEqual(uvNorth, 6, "Northern Hemisphere summer noon should have high UV")
    }

    func testEstimatedUVSouthernHemisphereSummerIsHigh() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // January noon, Southern Hemisphere (their summer)
        let janNoon = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let uvSouth = UVIndexService.estimatedUVIndex(at: janNoon, calendar: calendar, latitude: -33.0)
        XCTAssertGreaterThanOrEqual(uvSouth, 6, "Southern Hemisphere January noon should have high UV")
    }

    func testEstimatedUVSouthernHemisphereWinterIsLow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // July noon, Southern Hemisphere (their winter)
        let julyNoon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let uvSouth = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: -33.0)
        XCTAssertLessThanOrEqual(uvSouth, 3, "Southern Hemisphere July noon should have low UV")
    }

    func testEstimatedUVNilLatitudeDefaultsToNorthernHemisphere() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let julyNoon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let uvDefault = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: nil)
        let uvNorth = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: 40.0)
        XCTAssertEqual(uvDefault, uvNorth, "nil latitude should behave like Northern Hemisphere")
    }

    func testEstimatedUVNighttimeIsZero() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let midnight = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 2))!
        XCTAssertEqual(UVIndexService.estimatedUVIndex(at: midnight, calendar: calendar, latitude: 40.0), 0)
        XCTAssertEqual(UVIndexService.estimatedUVIndex(at: midnight, calendar: calendar, latitude: -33.0), 0)
    }

    // MARK: - Fix 7 & 8: AppState error logging

    func testAppStateHasLastRefreshErrorProperty() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService()
        )
        XCTAssertNil(state.lastRefreshError, "lastRefreshError should be nil after successful init")
    }

    func testRefreshClearsLastRefreshErrorOnSuccess() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService()
        )
        state.refresh()
        XCTAssertNil(state.lastRefreshError)
    }
}
