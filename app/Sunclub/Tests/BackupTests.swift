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

    func testBackupRoundTripPreservesHistoryOrderingMetadata() throws {
        let backupService = SunclubBackupService()
        let sourceContainer = try SunclubModelContainerFactory.makeInMemoryContainer()
        let sourceContext = ModelContext(sourceContainer)
        let sourceHistory = SunclubHistoryService(context: sourceContext)
        try sourceHistory.bootstrapIfNeeded()

        let sourceDate = Date(timeIntervalSince1970: 1_900_000_000)
        let serverDate = Date(timeIntervalSince1970: 2_000_000_000)
        let day = Calendar.current.startOfDay(for: sourceDate)
        let authorDeviceID = try sourceHistory.syncPreference().deviceID
        let batch = SunclubChangeBatch(
            createdAt: sourceDate,
            logicalOrder: 42,
            serverReceivedAt: serverDate,
            kind: .historyEdit,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: authorDeviceID,
            summary: "Metadata round trip"
        )
        let recordRevision = DailyRecordRevision(
            batch: batch,
            snapshot: DailyRecordProjectionSnapshot(
                startOfDay: day,
                verifiedAt: day.addingTimeInterval(9 * 60 * 60),
                methodRawValue: VerificationMethod.manual.rawValue,
                verificationDuration: nil,
                spfLevel: 50,
                notes: "Metadata round trip",
                reapplyCount: 0,
                lastReappliedAt: nil
            ),
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        )
        let settingsRevision = SettingsRevision(
            batch: batch,
            snapshot: SettingsProjectionSnapshot(
                hasCompletedOnboarding: true,
                reminderHour: 9,
                reminderMinute: 0,
                weeklyHour: 18,
                weeklyWeekday: 1,
                dailyPhraseState: nil,
                weeklyPhraseState: nil,
                smartReminderSettingsData: nil,
                reapplyReminderEnabled: false,
                reapplyIntervalMinutes: 120,
                usesLiveUV: false
            ),
            changedFields: [.hasCompletedOnboarding, .reminderHour]
        )
        sourceContext.insert(batch)
        sourceContext.insert(recordRevision)
        sourceContext.insert(settingsRevision)
        try sourceContext.save()
        try sourceHistory.refreshProjectedState()

        let document = try backupService.exportDocument(from: sourceContext)
        let targetContainer = try SunclubModelContainerFactory.makeInMemoryContainer()
        let targetContext = ModelContext(targetContainer)
        _ = try backupService.importBackupDocument(document, into: targetContext)

        let batchID = batch.id
        let recordRevisionID = recordRevision.id
        let settingsRevisionID = settingsRevision.id
        let restoredBatch = try XCTUnwrap(
            try targetContext.fetch(
                FetchDescriptor<SunclubChangeBatch>(predicate: #Predicate { $0.id == batchID })
            ).first
        )
        let restoredRecordRevision = try XCTUnwrap(
            try targetContext.fetch(
                FetchDescriptor<DailyRecordRevision>(predicate: #Predicate { $0.id == recordRevisionID })
            ).first
        )
        let restoredSettingsRevision = try XCTUnwrap(
            try targetContext.fetch(
                FetchDescriptor<SettingsRevision>(predicate: #Predicate { $0.id == settingsRevisionID })
            ).first
        )
        XCTAssertEqual(restoredBatch.createdAt, sourceDate)
        XCTAssertEqual(restoredBatch.logicalOrder, 42)
        XCTAssertEqual(restoredBatch.serverReceivedAt, serverDate)
        XCTAssertEqual(restoredRecordRevision.logicalOrder, 42)
        XCTAssertEqual(restoredRecordRevision.serverReceivedAt, serverDate)
        XCTAssertEqual(restoredSettingsRevision.logicalOrder, 42)
        XCTAssertEqual(restoredSettingsRevision.serverReceivedAt, serverDate)
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

    func testOlderBackupIgnoresRetiredFieldsAndRestoresPreferencesAndHistory() async throws {
        let sourceGrowthSettings = SunclubGrowthSettings(
            preferredName: "Peyton",
            uvBriefing: SunclubUVBriefingPreferences(
                dailyBriefingEnabled: false,
                extremeAlertEnabled: true,
                morningHour: 9,
                morningMinute: 15
            ),
            automation: SunclubAutomationPreferences(
                shortcutWritesEnabled: false,
                urlOpenActionsEnabled: true,
                urlWriteActionsEnabled: false,
                callbackResultDetailsEnabled: false
            )
        )
        let sourceStore = BackupMemoryGrowthFeatureStore(settings: sourceGrowthSettings)
        let source = try makeAppState(
            notificationManager: MockNotificationManager(),
            growthFeatureStore: sourceStore
        )
        let expectedPreferences = SunclubRestorablePreferences(growthSettings: sourceGrowthSettings)
        XCTAssertEqual(source.settings.restorablePreferences, expectedPreferences)
        XCTAssertTrue(
            source.changeBatches.contains { $0.kind == .preferenceSettings }
        )

        source.completeOnboarding()
        source.saveManualRecord(for: Date(), spfLevel: 50, notes: "Preserved history")
        let exported = try source.exportBackupDocument()
        var legacyPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: exported.serializedData()) as? [String: Any])
        var legacyPreferences = try XCTUnwrap(legacyPayload["restorablePreferences"] as? [String: Any])
        // Populated retired keys from older backups must be ignored without dropping retained fields.
        legacyPreferences["friends"] = [["name": "Maya", "currentStreak": 4, "hasLoggedToday": true]]
        legacyPreferences["accountability"] = [
            "displayName": "Peyton",
            "inviteTokens": [["token": "old-token", "createdAt": "2026-09-01T12:00:00Z"]],
            "connections": [["relationshipToken": "old-connection"]]
        ]
        legacyPayload["restorablePreferences"] = legacyPreferences
        let document = try SunclubBackupDocument(data: JSONSerialization.data(withJSONObject: legacyPayload))
        XCTAssertEqual(document.payload.restorablePreferences?.automation, sourceGrowthSettings.automation)

        let targetStore = BackupMemoryGrowthFeatureStore(settings: SunclubGrowthSettings())
        let target = try makeAppState(
            notificationManager: MockNotificationManager(),
            growthFeatureStore: targetStore
        )
        try target.importBackupDocument(document)
        await Task.yield()

        XCTAssertEqual(target.growthSettings.preferredName, "Peyton")
        XCTAssertEqual(target.growthSettings.uvBriefing, sourceGrowthSettings.uvBriefing)
        XCTAssertEqual(target.growthSettings.automation, sourceGrowthSettings.automation)
        XCTAssertEqual(targetStore.load(), target.growthSettings)
        XCTAssertEqual(target.settings.restorablePreferences, expectedPreferences)
        XCTAssertTrue(target.settings.hasCompletedOnboarding)
        XCTAssertEqual(target.records.count, 1)
        XCTAssertEqual(target.records.first?.spfLevel, 50)
        XCTAssertEqual(target.records.first?.notes, "Preserved history")
        XCTAssertGreaterThan(target.pendingImportedBatchCount, 0)
        let reencoded = try XCTUnwrap(JSONSerialization.jsonObject(with: document.serializedData()) as? [String: Any])
        let retainedPreferences = try XCTUnwrap(reencoded["restorablePreferences"] as? [String: Any])
        XCTAssertNil(retainedPreferences["friends"])
        XCTAssertNil(retainedPreferences["accountability"])
    }

    func testLegacyBackupWithoutPreferenceEnvelopePreservesCurrentPreferences() async throws {
        let source = try makeAppState(notificationManager: MockNotificationManager())
        let exported = try source.exportBackupDocument()
        let legacyDocument = SunclubBackupDocument(
            payload: SunclubBackupPayload(
                createdAt: exported.payload.createdAt,
                schemaVersion: exported.payload.schemaVersion,
                storeFiles: exported.payload.storeFiles
            )
        )
        let current = SunclubGrowthSettings(
            automation: SunclubAutomationPreferences(
                shortcutWritesEnabled: false,
                urlOpenActionsEnabled: false,
                urlWriteActionsEnabled: false,
                callbackResultDetailsEnabled: false
            )
        )
        let targetStore = BackupMemoryGrowthFeatureStore(settings: current)
        let target = try makeAppState(
            notificationManager: MockNotificationManager(),
            growthFeatureStore: targetStore
        )

        try target.importBackupDocument(legacyDocument)
        await Task.yield()

        XCTAssertEqual(target.growthSettings.automation, current.automation)
        XCTAssertEqual(targetStore.load().automation, current.automation)
        XCTAssertEqual(target.settings.restorablePreferences?.automation, current.automation)
    }

    func testDefaultImportedPreferencesDoNotReplaceRicherCurrentChoices() {
        let current = SunclubGrowthSettings(
            uvBriefing: SunclubUVBriefingPreferences(
                dailyBriefingEnabled: false,
                extremeAlertEnabled: true,
                morningHour: 10,
                morningMinute: 30
            ),
            automation: SunclubAutomationPreferences(
                shortcutWritesEnabled: false,
                urlOpenActionsEnabled: false,
                urlWriteActionsEnabled: false,
                callbackResultDetailsEnabled: false
            )
        )
        let importedDefaults = SunclubRestorablePreferences(
            growthSettings: SunclubGrowthSettings()
        )

        let merged = importedDefaults.merging(into: current)

        XCTAssertEqual(merged.uvBriefing, current.uvBriefing)
        XCTAssertEqual(merged.automation, current.automation)
    }

    private func makeAppState(
        notificationManager: NotificationScheduling,
        growthFeatureStore: SunclubGrowthFeatureStoring = BackupMemoryGrowthFeatureStore(
            settings: SunclubGrowthSettings()
        )
    ) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(),
            growthFeatureStore: growthFeatureStore,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: true,
                hasAppGroupContainer: false
            )
        )
    }
}

private final class BackupMemoryGrowthFeatureStore: SunclubGrowthFeatureStoring {
    private var settings: SunclubGrowthSettings

    init(settings: SunclubGrowthSettings) {
        self.settings = settings
    }

    func load() -> SunclubGrowthSettings {
        settings
    }

    func save(_ settings: SunclubGrowthSettings) {
        self.settings = settings
    }
}
