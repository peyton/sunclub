import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class BackupTests: XCTestCase {
    func testBackupExportAndImportRoundTripsSettingsAndRecords() async throws {
        let sourceNotificationManager = MockNotificationManager()
        let source = try makeAppState(notificationManager: sourceNotificationManager)
        source.completeOnboarding()
        source.updateReminderTime(for: .weekday, hour: 7, minute: 30)
        source.updateReminderTime(for: .weekend, hour: 9, minute: 15)
        source.updateTravelTimeZoneHandling(followsTravelTimeZone: false)
        source.updateStreakRiskReminder(enabled: false)
        source.updateReapplySettings(enabled: true, intervalMinutes: 90)

        let calendar = Calendar.current
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: Date()))
        source.saveManualRecord(for: yesterday, spfLevel: 50, notes: "  Beach day  ")
        source.recordVerificationSuccess(
            method: .manual,
            verificationDuration: 0.8,
            spfLevel: 30,
            notes: "Morning run"
        )
        await Task.yield()

        let document = try source.exportBackupDocument()

        let targetNotificationManager = MockNotificationManager()
        let target = try makeAppState(notificationManager: targetNotificationManager)
        let summary = try target.importBackupDocument(document)
        await Task.yield()

        XCTAssertEqual(summary.restoredRecordCount, 2)
        XCTAssertGreaterThan(target.pendingImportedBatchCount, 0)
        XCTAssertNil(target.recentImportSession?.publishedAt)
        XCTAssertTrue(target.settings.hasCompletedOnboarding)
        XCTAssertEqual(target.settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 30))
        XCTAssertEqual(target.settings.smartReminderSettings.weekendTime, ReminderTime(hour: 9, minute: 15))
        XCTAssertFalse(target.settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertFalse(target.settings.smartReminderSettings.streakRiskEnabled)
        XCTAssertTrue(target.settings.reapplyReminderEnabled)
        XCTAssertEqual(target.settings.reapplyIntervalMinutes, 90)
        XCTAssertEqual(target.longestStreak, 2)

        let importedRecords = target.records.sorted { $0.startOfDay < $1.startOfDay }
        XCTAssertEqual(importedRecords.count, 2)
        XCTAssertEqual(importedRecords[0].spfLevel, 50)
        XCTAssertEqual(importedRecords[0].notes, "Beach day")
        XCTAssertEqual(importedRecords[1].verificationDuration, 0.8)
        XCTAssertEqual(importedRecords[1].spfLevel, 30)
        XCTAssertEqual(importedRecords[1].notes, "Morning run")
        XCTAssertNil(target.verificationSuccessPresentation)
        XCTAssertEqual(targetNotificationManager.cancelReapplyRemindersCount, 1)
        XCTAssertEqual(targetNotificationManager.scheduleRemindersCount, 1)
        XCTAssertEqual(targetNotificationManager.refreshStreakRiskReminderCount, 1)
    }

    func testImportingLegacyBackupMigratesSchemaBeforeRestoring() async throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent(SunclubBackupService.storeFilename)
        let seededDates = try LegacyStoreFixture.seedCommit22ffStore(at: storeURL)
        let document = SunclubBackupDocument(
            payload: SunclubBackupPayload(
                createdAt: Date(timeIntervalSince1970: 0),
                schemaVersion: "1.0.0",
                storeFiles: try SunclubBackupService.storeFiles(at: storeURL)
            )
        )

        let target = try makeAppState(notificationManager: MockNotificationManager())
        let summary = try target.importBackupDocument(document)
        await Task.yield()

        XCTAssertEqual(summary.restoredRecordCount, 1)
        XCTAssertTrue(target.settings.hasCompletedOnboarding)
        XCTAssertEqual(target.settings.reminderHour, 7)
        XCTAssertEqual(target.settings.reminderMinute, 45)
        XCTAssertEqual(target.settings.weeklyHour, 20)
        XCTAssertEqual(target.settings.weeklyWeekday, 6)
        XCTAssertEqual(target.settings.dailyPhraseState, Data("daily".utf8))
        XCTAssertEqual(target.settings.weeklyPhraseState, Data("weekly".utf8))
        XCTAssertEqual(target.settings.longestStreak, 1)
        XCTAssertTrue(target.settings.reapplyReminderEnabled)
        XCTAssertEqual(target.settings.reapplyIntervalMinutes, 90)
        XCTAssertNotNil(target.settings.smartReminderSettingsData)
        XCTAssertEqual(target.settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertEqual(target.settings.smartReminderSettings.weekendTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertTrue(target.settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertTrue(target.settings.smartReminderSettings.streakRiskEnabled)
        XCTAssertFalse(target.settings.smartReminderSettings.anchoredTimeZoneIdentifier.isEmpty)

        let record = try XCTUnwrap(target.records.first)
        XCTAssertEqual(target.records.count, 1)
        XCTAssertEqual(record.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(record.verifiedAt, seededDates.verifiedAt)
        XCTAssertEqual(record.methodRawValue, VerificationMethod.manual.rawValue)
        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.verificationDuration, 1.5)
        XCTAssertEqual(record.spfLevel, 50)
        XCTAssertEqual(record.notes, "Beach day")
    }

    func testImportedBackupRequiresExplicitPublishBeforeMarkingImportSynced() async throws {
        let source = try makeAppState(notificationManager: MockNotificationManager())
        source.completeOnboarding()
        source.saveManualRecord(for: Date(), spfLevel: 50, notes: "Today")
        let document = try source.exportBackupDocument()

        let target = try makeAppState(notificationManager: MockNotificationManager())
        let summary = try target.importBackupDocument(document)
        await Task.yield()

        XCTAssertGreaterThan(target.pendingImportedBatchCount, 0)
        XCTAssertNil(target.recentImportSession?.publishedAt)

        target.publishImportedChanges(for: summary.importSessionID)
        await Task.yield()

        XCTAssertEqual(target.pendingImportedBatchCount, 0)
        XCTAssertEqual(target.recentImportSession?.id, summary.importSessionID)
        XCTAssertNotNil(target.recentImportSession?.publishedAt)
    }

    private func makeAppState(notificationManager: NotificationScheduling) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager,
            uvIndexService: UVIndexService()
        )
    }
}
