import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class MigrationTests: XCTestCase {
    func testMigrationFromCommit22ffSchemaBackfillsSmartReminderSettingsAndNormalizesLegacyMethods() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        let seededDates = try LegacyStoreFixture.seedCommit22ffStore(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 7)
        XCTAssertEqual(settings.reminderMinute, 45)
        XCTAssertEqual(settings.weeklyHour, 20)
        XCTAssertEqual(settings.weeklyWeekday, 6)
        XCTAssertEqual(settings.dailyPhraseState, Data("daily".utf8))
        XCTAssertEqual(settings.weeklyPhraseState, Data("weekly".utf8))
        XCTAssertEqual(settings.longestStreak, 4)
        XCTAssertTrue(settings.reapplyReminderEnabled)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 90)
        XCTAssertNotNil(settings.smartReminderSettingsData)
        XCTAssertEqual(settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertEqual(settings.smartReminderSettings.weekendTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertTrue(settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertTrue(settings.smartReminderSettings.streakRiskEnabled)
        XCTAssertFalse(settings.smartReminderSettings.anchoredTimeZoneIdentifier.isEmpty)
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)

        let records = try context.fetch(
            FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .forward)])
        )
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(record.verifiedAt, seededDates.verifiedAt)
        XCTAssertEqual(record.methodRawValue, VerificationMethod.manual.rawValue)
        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.verificationDuration, 1.5)
        XCTAssertEqual(record.spfLevel, 50)
        XCTAssertEqual(record.notes, "Beach day")
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
    }

    func testMigrationFromCurrentV2SchemaSeedsNewDefaults() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        let seededDates = try LegacyStoreFixture.seedCurrentV2Store(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertEqual(settings.smartReminderSettings.weekendTime, ReminderTime(hour: 8, minute: 30))
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)

        let record = try XCTUnwrap(
            try context.fetch(FetchDescriptor<DailyRecord>()).first
        )
        XCTAssertEqual(record.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(record.verifiedAt, seededDates.verifiedAt)
        XCTAssertEqual(record.spfLevel, 50)
        XCTAssertEqual(record.notes, "Morning beach walk")
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
    }

    func testMigrationFromV3SeedsRevisionHistoryAndDefaultSyncPreference() throws {
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
        XCTAssertEqual(settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertEqual(settings.smartReminderSettings.weekendTime, ReminderTime(hour: 8, minute: 30))
        XCTAssertTrue(settings.reapplyReminderEnabled)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 90)

        let records = try context.fetch(
            FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .forward)])
        )
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(records.first?.verifiedAt, seededDates.verifiedAt)

        let syncPreference = try XCTUnwrap(try context.fetch(FetchDescriptor<CloudSyncPreference>()).first)
        XCTAssertTrue(syncPreference.isICloudSyncEnabled)
        XCTAssertEqual(syncPreference.status, .idle)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CloudSyncState>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SunclubChangeBatch>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SettingsRevision>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyRecordRevision>()).count, 1)
    }
}
