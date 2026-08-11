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
        let migrationBatch = try XCTUnwrap(try context.fetch(FetchDescriptor<SunclubChangeBatch>()).first)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SunclubChangeBatch>()).count, 1)
        XCTAssertFalse(migrationBatch.isLocalOnly)
        XCTAssertEqual(migrationBatch.logicalOrder, 1)
        XCTAssertNil(migrationBatch.serverReceivedAt)
        let settingsRevision = try XCTUnwrap(try context.fetch(FetchDescriptor<SettingsRevision>()).first)
        let recordRevision = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyRecordRevision>()).first)
        XCTAssertEqual(settingsRevision.logicalOrder, 1)
        XCTAssertEqual(recordRevision.logicalOrder, 1)
        XCTAssertNil(settingsRevision.serverReceivedAt)
        XCTAssertNil(recordRevision.serverReceivedAt)
    }

    func testMigrationFromEmptyV3StoreCreatesLocalOnlyDefaultSeed() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        try LegacyStoreFixture.seedEmptyCurrentV3Store(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyRecord>()).isEmpty)

        let migrationBatch = try XCTUnwrap(try context.fetch(FetchDescriptor<SunclubChangeBatch>()).first)
        XCTAssertEqual(migrationBatch.kind, .migrationSeed)
        XCTAssertTrue(migrationBatch.isLocalOnly)
        XCTAssertFalse(migrationBatch.isPublishedToCloud)
        XCTAssertEqual(migrationBatch.logicalOrder, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SettingsRevision>()).count, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyRecordRevision>()).isEmpty)
    }

    func testMigrationFromV4PreservesSettingsAndSeedsNewOptionalValues() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        let fixture = try LegacyStoreFixture.seedCurrentV4Store(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.usesLiveUV)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 90)
        XCTAssertNil(settings.selectedUVPlace)
        XCTAssertNil(settings.sunscreenProfile)
        XCTAssertNil(settings.restorablePreferences)

        let revisionID = fixture.settingsRevisionID
        let revisionPredicate = #Predicate<SettingsRevision> { $0.id == revisionID }
        let revision = try XCTUnwrap(
            try context.fetch(FetchDescriptor(predicate: revisionPredicate)).first
        )
        XCTAssertTrue(revision.snapshot.usesLiveUV)
        XCTAssertNil(revision.snapshot.selectedUVPlace)
        XCTAssertNil(revision.snapshot.sunscreenProfile)
        XCTAssertNil(revision.snapshot.restorablePreferences)
        XCTAssertEqual(revision.logicalOrder, 2)
        XCTAssertNil(revision.serverReceivedAt)

        let batches = try context.fetch(FetchDescriptor<SunclubChangeBatch>())
            .sorted { ($0.logicalOrder ?? 0) < ($1.logicalOrder ?? 0) }
        XCTAssertEqual(batches.map(\.id), fixture.orderedBatchIDs)
        XCTAssertEqual(batches.map(\.logicalOrder), [1, 2])
        XCTAssertTrue(batches.allSatisfy { $0.createdAt == Date(timeIntervalSince1970: 1_800_000_000) })
        XCTAssertTrue(batches.allSatisfy { $0.serverReceivedAt == nil })

        let recordRevisionID = fixture.recordRevisionID
        let recordRevision = try XCTUnwrap(
            try context.fetch(
                FetchDescriptor<DailyRecordRevision>(predicate: #Predicate { $0.id == recordRevisionID })
            ).first
        )
        XCTAssertEqual(recordRevision.logicalOrder, 1)
        XCTAssertNil(recordRevision.serverReceivedAt)
        XCTAssertEqual(recordRevision.snapshot?.startOfDay, fixture.day)
        XCTAssertEqual(recordRevision.snapshot?.spfLevel, 50)
        XCTAssertEqual(recordRevision.snapshot?.notes, "V4 history")
        let fixtureDay = fixture.day
        let projectedRecord = try XCTUnwrap(
            try context.fetch(
                FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.startOfDay == fixtureDay })
            ).first
        )
        XCTAssertEqual(projectedRecord.spfLevel, 50)
        XCTAssertEqual(projectedRecord.notes, "V4 history")

        let cloudState = try XCTUnwrap(try context.fetch(FetchDescriptor<CloudSyncState>()).first)
        XCTAssertEqual(cloudState.stateSerializationData, Data("state".utf8))
        XCTAssertNil(cloudState.unresolvedCloudRecordFailuresData)
    }

    func testDiskBackedContainerCreatesMissingParentDirectory() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let storeURL = rootDirectory
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("Sunclub.store")

        _ = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.deletingLastPathComponent().path))
    }
}
