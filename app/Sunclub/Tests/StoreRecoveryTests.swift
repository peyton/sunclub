import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class StoreRecoveryTests: XCTestCase {
    func testLegacyApplicationSupportStoreRecoveryRestoresSettingsAndRecordsThenPublishes() async throws {
        let fixture = try makeRecoveryFixture()
        defer { fixture.cleanup() }
        let seededDates = try LegacyStoreFixture.seedCommit22ffStore(at: fixture.location.legacyApplicationSupportStoreURL)
        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: fixture.location.currentStoreURL)
        let historyService = SunclubHistoryService(context: ModelContext(container))
        let recoveryService = SunclubStoreRecoveryService(storeLocation: fixture.location)

        let result = try XCTUnwrap(
            try recoveryService.recoverLegacyApplicationSupportStoreIfNeeded(
                into: historyService.fetchContext(),
                historyService: historyService
            )
        )

        XCTAssertTrue(result.sourceDescription.hasPrefix(SunclubStoreRecoveryService.sourceDescriptionPrefix))
        XCTAssertEqual(result.recoveredRecordCount, 1)
        let settings = try historyService.settings()
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 7)
        XCTAssertEqual(settings.reminderMinute, 45)
        XCTAssertEqual(settings.weeklyHour, 20)
        XCTAssertEqual(settings.weeklyWeekday, 6)
        XCTAssertEqual(settings.dailyPhraseState, Data("daily".utf8))
        XCTAssertEqual(settings.weeklyPhraseState, Data("weekly".utf8))
        XCTAssertEqual(settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertTrue(settings.reapplyReminderEnabled)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 90)

        let records = try historyService.records()
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(record.verifiedAt, seededDates.verifiedAt)
        XCTAssertEqual(record.spfLevel, 50)
        XCTAssertEqual(record.notes, "Beach day")

        let recoveryBatch = try XCTUnwrap(
            try historyService.changeBatches().first { $0.kind == .legacyStoreRecovery }
        )
        XCTAssertTrue(recoveryBatch.isLocalOnly)
        XCTAssertFalse(recoveryBatch.isPublishedToCloud)

        let publishResult = try await NoopCloudSyncCoordinator(historyService: historyService)
            .publishImportedSession(result.importSessionID)
        XCTAssertEqual(publishResult.publishedBatchCount, 1)

        let publishedBatch = try XCTUnwrap(
            try historyService.changeBatches().first { $0.id == recoveryBatch.id }
        )
        XCTAssertFalse(publishedBatch.isLocalOnly)
        XCTAssertTrue(publishedBatch.isPublishedToCloud)
        XCTAssertNotNil(try historyService.importSession(id: result.importSessionID)?.publishedAt)
    }

    func testLegacyApplicationSupportStoreRecoveryIsIdempotent() throws {
        let fixture = try makeRecoveryFixture()
        defer { fixture.cleanup() }
        try LegacyStoreFixture.seedCommit22ffStore(at: fixture.location.legacyApplicationSupportStoreURL)
        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: fixture.location.currentStoreURL)
        let historyService = SunclubHistoryService(context: ModelContext(container))
        let recoveryService = SunclubStoreRecoveryService(storeLocation: fixture.location)

        XCTAssertNotNil(
            try recoveryService.recoverLegacyApplicationSupportStoreIfNeeded(
                into: historyService.fetchContext(),
                historyService: historyService
            )
        )
        let batchCount = try historyService.changeBatches(limit: 100).count

        XCTAssertNil(
            try recoveryService.recoverLegacyApplicationSupportStoreIfNeeded(
                into: historyService.fetchContext(),
                historyService: historyService
            )
        )
        XCTAssertEqual(try historyService.changeBatches(limit: 100).count, batchCount)
    }

    func testLegacyApplicationSupportStoreRecoveryDoesNotOverwriteCurrentRecordsOrSettings() throws {
        let fixture = try makeRecoveryFixture()
        defer { fixture.cleanup() }
        let seededDates = try LegacyStoreFixture.seedCommit22ffStore(at: fixture.location.legacyApplicationSupportStoreURL)
        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: fixture.location.currentStoreURL)
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()

        try historyService.applySettingsChange(
            kind: .reminderSettings,
            summary: "Current settings",
            changedFields: [.hasCompletedOnboarding, .reminderHour, .reminderMinute]
        ) { snapshot in
            snapshot.hasCompletedOnboarding = true
            snapshot.reminderHour = 6
            snapshot.reminderMinute = 10
        }
        try historyService.applyDayChange(
            for: seededDates.startOfDay,
            kind: .manualLog,
            summary: "Current day",
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        ) { _ in
            DailyRecordProjectionSnapshot(
                startOfDay: seededDates.startOfDay,
                verifiedAt: seededDates.verifiedAt.addingTimeInterval(600),
                methodRawValue: VerificationMethod.manual.rawValue,
                verificationDuration: nil,
                spfLevel: 15,
                notes: "Current app-group entry",
                reapplyCount: 0,
                lastReappliedAt: nil
            )
        }

        let recoveryService = SunclubStoreRecoveryService(storeLocation: fixture.location)
        _ = try recoveryService.recoverLegacyApplicationSupportStoreIfNeeded(
            into: historyService.fetchContext(),
            historyService: historyService
        )

        let settings = try historyService.settings()
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 6)
        XCTAssertEqual(settings.reminderMinute, 10)

        let records = try historyService.records()
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.spfLevel, 15)
        XCTAssertEqual(record.notes, "Current app-group entry")
    }

    func testAppStatePublishesRecoveredLegacyStoreOnLaunchWhenICloudSyncIsEnabled() async throws {
        let fixture = try makeRecoveryFixture()
        defer { fixture.cleanup() }
        try LegacyStoreFixture.seedCommit22ffStore(at: fixture.location.legacyApplicationSupportStoreURL)
        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: fixture.location.currentStoreURL)
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        let cloudSyncCoordinator = NoopCloudSyncCoordinator(historyService: historyService)
        let state = AppState(
            context: context,
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            storeRecoveryService: SunclubStoreRecoveryService(storeLocation: fixture.location),
            historyService: historyService,
            cloudSyncCoordinator: cloudSyncCoordinator,
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: false,
                hasAppGroupContainer: true
            )
        )

        await waitForMainActorTasks()

        XCTAssertTrue(state.settings.hasCompletedOnboarding)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.pendingImportedBatchCount, 0)
        XCTAssertNotNil(state.recentImportSession?.publishedAt)
    }

    func testEmptyBootstrapCreatesLocalOnlyMigrationSeed() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))

        try historyService.bootstrapIfNeeded()

        let batch = try XCTUnwrap(try historyService.changeBatches().first)
        XCTAssertEqual(batch.kind, .migrationSeed)
        XCTAssertTrue(batch.isLocalOnly)
        XCTAssertFalse(batch.isPublishedToCloud)
    }

    func testNonEmptyBootstrapCreatesPublishableMigrationSeed() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let settings = Settings()
        settings.hasCompletedOnboarding = true
        settings.reminderHour = 7
        context.insert(settings)
        try context.save()
        let historyService = SunclubHistoryService(context: context)

        try historyService.bootstrapIfNeeded()

        let batch = try XCTUnwrap(try historyService.changeBatches().first)
        XCTAssertEqual(batch.kind, .migrationSeed)
        XCTAssertFalse(batch.isLocalOnly)
    }

    func testNewerDefaultMigrationSeedDoesNotOverrideMeaningfulRemoteSettings() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()
        let defaultBatch = try XCTUnwrap(try historyService.changeBatches().first)

        let remoteBatch = SunclubChangeBatch(
            createdAt: defaultBatch.createdAt.addingTimeInterval(-60),
            kind: .reminderSettings,
            scope: .settings,
            scopeIdentifier: "settings",
            authorDeviceID: "remote-device",
            summary: "Remote settings",
            isLocalOnly: false,
            isPublishedToCloud: true
        )
        context.insert(remoteBatch)
        context.insert(
            SettingsRevision(
                batch: remoteBatch,
                snapshot: meaningfulSettingsSnapshot,
                changedFields: Self.settingsFields
            )
        )
        try context.save()

        try historyService.refreshProjectedState()

        let settings = try historyService.settings()
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 7)
        XCTAssertEqual(settings.reminderMinute, 45)
    }

    func testPollutedDefaultConflictMergeDoesNotOverrideMeaningfulRemoteSettings() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()
        let defaultBatch = try XCTUnwrap(try historyService.changeBatches().first)

        let remoteBatch = SunclubChangeBatch(
            createdAt: defaultBatch.createdAt.addingTimeInterval(-60),
            kind: .reminderSettings,
            scope: .settings,
            scopeIdentifier: "settings",
            authorDeviceID: "remote-device",
            summary: "Remote settings",
            isLocalOnly: false,
            isPublishedToCloud: true
        )
        context.insert(remoteBatch)
        context.insert(
            SettingsRevision(
                batch: remoteBatch,
                snapshot: meaningfulSettingsSnapshot,
                changedFields: Self.settingsFields
            )
        )

        let pollutedBatch = SunclubChangeBatch(
            createdAt: defaultBatch.createdAt.addingTimeInterval(60),
            kind: .conflictAutoMerge,
            scope: .settings,
            scopeIdentifier: "settings",
            authorDeviceID: "local-device",
            summary: "Polluted default merge"
        )
        context.insert(pollutedBatch)
        context.insert(
            SettingsRevision(
                batch: pollutedBatch,
                snapshot: defaultSettingsSnapshot,
                changedFields: Self.settingsFields
            )
        )
        try context.save()

        try historyService.refreshProjectedState()

        let settings = try historyService.settings()
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 7)
        XCTAssertEqual(settings.reminderMinute, 45)
    }

    func testNormalUserChangeToDefaultSettingsStillProjects() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()
        let defaultBatch = try XCTUnwrap(try historyService.changeBatches().first)

        let remoteBatch = SunclubChangeBatch(
            createdAt: defaultBatch.createdAt.addingTimeInterval(-60),
            kind: .reminderSettings,
            scope: .settings,
            scopeIdentifier: "settings",
            authorDeviceID: "remote-device",
            summary: "Remote settings",
            isLocalOnly: false,
            isPublishedToCloud: true
        )
        context.insert(remoteBatch)
        context.insert(
            SettingsRevision(
                batch: remoteBatch,
                snapshot: meaningfulSettingsSnapshot,
                changedFields: Self.settingsFields
            )
        )

        let userBatch = SunclubChangeBatch(
            createdAt: defaultBatch.createdAt.addingTimeInterval(60),
            kind: .reminderSettings,
            scope: .settings,
            scopeIdentifier: "settings",
            authorDeviceID: "local-device",
            summary: "User returned settings to defaults"
        )
        context.insert(userBatch)
        context.insert(
            SettingsRevision(
                batch: userBatch,
                snapshot: defaultSettingsSnapshot,
                changedFields: Self.settingsFields
            )
        )
        try context.save()

        try historyService.refreshProjectedState()

        let settings = try historyService.settings()
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 8)
        XCTAssertEqual(settings.reminderMinute, 0)
    }

    private var meaningfulSettingsSnapshot: SettingsProjectionSnapshot {
        SettingsProjectionSnapshot(
            hasCompletedOnboarding: true,
            reminderHour: 7,
            reminderMinute: 45,
            weeklyHour: 20,
            weeklyWeekday: 6,
            dailyPhraseState: Data("daily".utf8),
            weeklyPhraseState: Data("weekly".utf8),
            smartReminderSettingsData: nil,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90,
            usesLiveUV: true
        )
    }

    private var defaultSettingsSnapshot: SettingsProjectionSnapshot {
        SettingsProjectionSnapshot(
            hasCompletedOnboarding: false,
            reminderHour: 8,
            reminderMinute: 0,
            weeklyHour: 18,
            weeklyWeekday: 1,
            dailyPhraseState: nil,
            weeklyPhraseState: nil,
            smartReminderSettingsData: nil,
            reapplyReminderEnabled: false,
            reapplyIntervalMinutes: 120,
            usesLiveUV: false
        )
    }

    private static let settingsFields: Set<SunclubTrackedField> = [
        .hasCompletedOnboarding,
        .reminderHour,
        .reminderMinute,
        .weeklyHour,
        .weeklyWeekday,
        .dailyPhraseState,
        .weeklyPhraseState,
        .smartReminderSettingsData,
        .reapplyReminderEnabled,
        .reapplyIntervalMinutes,
        .usesLiveUV
    ]

    private func makeRecoveryFixture() throws -> RecoveryFixture {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appGroupDirectory = rootDirectory.appendingPathComponent("app-group", isDirectory: true)
        let applicationSupportDirectory = rootDirectory
            .appendingPathComponent("Application Support", isDirectory: true)
        try FileManager.default.createDirectory(at: appGroupDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)

        return RecoveryFixture(
            rootDirectory: rootDirectory,
            location: SunclubStoreLocation(
                currentStoreURL: appGroupDirectory.appendingPathComponent(
                    SunclubModelContainerFactory.sharedStoreFilename
                ),
                legacyApplicationSupportStoreURL: applicationSupportDirectory.appendingPathComponent(
                    SunclubModelContainerFactory.sharedStoreFilename
                ),
                isUsingAppGroupContainer: true
            )
        )
    }

    private func waitForMainActorTasks() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }

    private struct RecoveryFixture {
        let rootDirectory: URL
        let location: SunclubStoreLocation

        func cleanup() {
            try? FileManager.default.removeItem(at: rootDirectory)
        }
    }
}
