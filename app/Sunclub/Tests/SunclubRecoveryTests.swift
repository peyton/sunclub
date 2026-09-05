import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubRecoveryTests: SunclubTestCase {
    @MainActor
    func testCloudKitAvailabilityAcceptsValidContainerIdentifier() throws {
        XCTAssertNoThrow(
            try SunclubCloudKitAvailability.validate(
                containerIdentifier: "iCloud.app.peyton.sunclub"
            )
        )
    }

    @MainActor
    func testCloudKitAvailabilityAcceptsSignedRuntimeEntitlements() throws {
        let containerIdentifier = "iCloud.app.peyton.sunclub"
        let entitlementProvider = StaticCloudKitEntitlementProvider(
            entitlements: Self.cloudKitEntitlements(containerIdentifier: containerIdentifier)
        )

        XCTAssertNoThrow(
            try SunclubCloudKitAvailability.validateRuntime(
                containerIdentifier: containerIdentifier,
                entitlementProvider: entitlementProvider
            )
        )
    }

    @MainActor
    func testCloudKitAvailabilityAcceptsWildcardCloudKitServiceEntitlement() throws {
        let containerIdentifier = "iCloud.app.peyton.sunclub"
        var entitlements = Self.cloudKitEntitlements(containerIdentifier: containerIdentifier)
        entitlements["com.apple.developer.icloud-services"] = "*"
        let entitlementProvider = StaticCloudKitEntitlementProvider(entitlements: entitlements)

        XCTAssertNoThrow(
            try SunclubCloudKitAvailability.validateRuntime(
                containerIdentifier: containerIdentifier,
                entitlementProvider: entitlementProvider
            )
        )
    }

    @MainActor
    func testCloudKitAvailabilityRejectsMissingRuntimeContainerEntitlement() {
        let containerIdentifier = "iCloud.app.peyton.sunclub"
        let entitlementProvider = StaticCloudKitEntitlementProvider(
            entitlements: ["com.apple.developer.icloud-services": ["CloudKit"]]
        )

        XCTAssertThrowsError(
            try SunclubCloudKitAvailability.validateRuntime(
                containerIdentifier: containerIdentifier,
                entitlementProvider: entitlementProvider
            )
        ) { error in
            XCTAssertEqual(
                error as? SunclubCloudKitConfigurationError,
                .missingContainerEntitlement(containerIdentifier)
            )
        }
    }

    @MainActor
    func testCloudKitAvailabilityRejectsMissingRuntimeCloudKitServiceEntitlement() {
        let containerIdentifier = "iCloud.app.peyton.sunclub"
        let entitlementProvider = StaticCloudKitEntitlementProvider(
            entitlements: [
                "com.apple.developer.icloud-container-identifiers": [containerIdentifier]
            ]
        )

        XCTAssertThrowsError(
            try SunclubCloudKitAvailability.validateRuntime(
                containerIdentifier: containerIdentifier,
                entitlementProvider: entitlementProvider
            )
        ) { error in
            XCTAssertEqual(
                error as? SunclubCloudKitConfigurationError,
                .missingCloudKitServiceEntitlement
            )
        }
    }

    @MainActor
    func testCloudKitAvailabilityRejectsUnsafeLaunchConfiguration() {
        XCTAssertThrowsError(
            try SunclubCloudKitAvailability.validate(
                containerIdentifier: "$(SUNCLUB_ICLOUD_CONTAINER)"
            )
        ) { error in
            XCTAssertEqual(error as? SunclubCloudKitConfigurationError, .invalidContainerIdentifier)
        }
    }

    @MainActor
    func testCloudSyncCoordinatorRecordsConfigurationErrorForInvalidContainerIdentifier() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()
        let coordinator = CloudSyncCoordinator(
            historyService: historyService,
            containerIdentifier: "$(SUNCLUB_ICLOUD_CONTAINER)"
        )

        _ = await coordinator.start()

        let preference = try historyService.syncPreference()
        XCTAssertEqual(preference.status, .error)
        XCTAssertEqual(
            preference.lastSyncErrorDescription,
            SunclubCloudKitConfigurationError.invalidContainerIdentifier.errorDescription
        )
    }

    @MainActor
    func testCloudSyncCoordinatorRecordsMissingCloudKitEntitlementBeforeContainerAccess() async throws {
        let containerIdentifier = "iCloud.app.peyton.sunclub"
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()
        let coordinator = CloudSyncCoordinator(
            historyService: historyService,
            containerIdentifier: containerIdentifier,
            cloudKitEntitlementProvider: StaticCloudKitEntitlementProvider(entitlements: [:])
        )

        _ = await coordinator.start()

        let preference = try historyService.syncPreference()
        XCTAssertEqual(preference.status, .error)
        XCTAssertEqual(
            preference.lastSyncErrorDescription,
            SunclubCloudKitConfigurationError
                .missingContainerEntitlement(containerIdentifier)
                .errorDescription
        )
    }

    @MainActor
    func testSettingsDefaultValues() {
        let settings = Settings()
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 8)
        XCTAssertEqual(settings.reminderMinute, 0)
        XCTAssertEqual(settings.weeklyHour, 18)
        XCTAssertEqual(settings.weeklyWeekday, 1)
        XCTAssertNil(settings.dailyPhraseState)
        XCTAssertNil(settings.weeklyPhraseState)
        XCTAssertNil(settings.smartReminderSettingsData)
        XCTAssertEqual(settings.longestStreak, 0)
        XCTAssertFalse(settings.reapplyReminderEnabled)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 120)
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)
        XCTAssertEqual(settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 8, minute: 0))
        XCTAssertEqual(settings.smartReminderSettings.weekendTime, ReminderTime(hour: 8, minute: 0))
        XCTAssertTrue(settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertTrue(settings.smartReminderSettings.streakRiskEnabled)
    }

    @MainActor
    func testCloudSyncDefaultsToEnabled() throws {
        let state = try makeAppState()

        XCTAssertTrue(state.syncPreference?.isICloudSyncEnabled ?? false)
        XCTAssertEqual(state.cloudSyncStatusPresentation.title, "iCloud sync is on")
    }

    @MainActor
    func testCloudSyncToggleUpdatesPresentation() async throws {
        let state = try makeAppState()

        state.updateCloudSyncEnabled(false)
        await Task.yield()

        XCTAssertFalse(state.syncPreference?.isICloudSyncEnabled ?? true)
        XCTAssertEqual(state.cloudSyncStatusPresentation.title, "Saved only on this phone")

        state.updateCloudSyncEnabled(true)
        await Task.yield()

        XCTAssertTrue(state.syncPreference?.isICloudSyncEnabled ?? false)
        XCTAssertEqual(state.cloudSyncStatusPresentation.title, "iCloud sync is on")
    }

    @MainActor
    func testDefaultCloudSyncCoordinatorUsesLiveSyncWhenAppGroupContainerIsUnavailableInProductionRuntime() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        let runtimeEnvironment = RuntimeEnvironmentSnapshot(
            isRunningTests: false,
            isPreviewing: false,
            hasAppGroupContainer: false,
            isPublicAccountabilityTransportEnabled: false
        )

        let coordinator = AppState.defaultCloudSyncCoordinator(
            historyService: historyService,
            runtimeEnvironment: runtimeEnvironment
        )

        XCTAssertTrue(coordinator is CloudSyncCoordinator)
    }

    @MainActor
    func testDefaultCloudSyncCoordinatorUsesNoopSyncForTestsAndPreviews() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))

        let testCoordinator = AppState.defaultCloudSyncCoordinator(
            historyService: historyService,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )
        let previewCoordinator = AppState.defaultCloudSyncCoordinator(
            historyService: historyService,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: true,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )

        XCTAssertTrue(testCoordinator is NoopCloudSyncCoordinator)
        XCTAssertTrue(previewCoordinator is NoopCloudSyncCoordinator)
    }

    @MainActor
    func testAppStateStartsInjectedCloudSyncCoordinatorWhenProductionRuntimeLacksAppGroupContainer() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let coordinator = ProbeCloudSyncCoordinator()

        let state = AppState(
            context: ModelContext(container),
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            cloudSyncCoordinator: coordinator,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            ),
            homeExitReminderMonitor: nil
        )

        await Task.yield()
        await Task.yield()

        XCTAssertEqual(coordinator.startCallCount, 1)
        XCTAssertTrue(state.syncPreference?.isICloudSyncEnabled ?? false)
    }

    @MainActor
    func testFreshInstallFetchesICloudBeforeSendingEmptyBootstrap() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()
        let driver = FakeCloudSyncEngineDriver()
        let coordinator = CloudSyncCoordinator(
            historyService: historyService,
            syncEngineDriver: driver
        )

        let result = await coordinator.start()

        XCTAssertEqual(result, .noRemoteHistory)
        XCTAssertEqual(Array(driver.operations.prefix(1)), [.fetch])
        XCTAssertTrue(driver.operations.contains(.saveZone))
        XCTAssertTrue(driver.operations.contains(.send))
    }

    @MainActor
    func testSyntheticEmptyBootstrapIsNotPublishedToCloud() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()

        XCTAssertTrue(try historyService.isEffectivelyEmptyForInitialICloudRestore())
        XCTAssertTrue(try historyService.cloudPublishableBatches().isEmpty)
    }

    @MainActor
    func testInitialICloudRestoreNoRemoteHistoryFallsThroughToOnboarding() async throws {
        let coordinator = ProbeCloudSyncCoordinator()
        coordinator.startResults = [.noRemoteHistory]

        let state = try makeAppState(
            cloudSyncCoordinator: coordinator,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )
        XCTAssertEqual(state.initialICloudRestoreState, .checking)

        await waitForMainActorTasks()

        XCTAssertEqual(coordinator.startCallCount, 1)
        XCTAssertEqual(state.initialICloudRestoreState, .noRemoteHistory)
        XCTAssertFalse(state.settings.hasCompletedOnboarding)
        XCTAssertFalse(state.shouldShowInitialICloudRestoreGate)
    }

    @MainActor
    func testInitialICloudRestoreFailureCanRetryOrContinueLocally() async throws {
        let coordinator = ProbeCloudSyncCoordinator()
        coordinator.startResults = [.failed("iCloud is offline."), .noRemoteHistory]

        let state = try makeAppState(
            cloudSyncCoordinator: coordinator,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )
        await waitForMainActorTasks()

        XCTAssertEqual(state.initialICloudRestoreState, .failed("iCloud is offline."))
        XCTAssertTrue(state.shouldShowInitialICloudRestoreGate)

        state.continueWithoutInitialICloudRestore()
        XCTAssertEqual(state.initialICloudRestoreState, .continuedLocally)
        XCTAssertFalse(state.shouldShowInitialICloudRestoreGate)

        state.retryInitialICloudRestore()
        await waitForMainActorTasks()
        XCTAssertEqual(state.initialICloudRestoreState, .noRemoteHistory)
        XCTAssertEqual(coordinator.startCallCount, 2)
    }

    func testCloudSyncSendFailureRecoveryActions() {
        XCTAssertEqual(
            CloudSyncCoordinator.sendFailureRecoveryAction(for: CKError(.zoneNotFound)),
            .requeueZoneAndFetch
        )
        XCTAssertEqual(
            CloudSyncCoordinator.sendFailureRecoveryAction(for: CKError(.unknownItem)),
            .requeueZoneAndFetch
        )
        XCTAssertEqual(
            CloudSyncCoordinator.sendFailureRecoveryAction(for: CKError(.serverRecordChanged)),
            .fetchRemote
        )
    }

    @MainActor
    func testZoneMissingSendFailureRequeuesZoneAndRecordBeforeFetch() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()
        let driver = FakeCloudSyncEngineDriver()
        let coordinator = CloudSyncCoordinator(
            historyService: historyService,
            syncEngineDriver: driver
        )
        let recordID = CKRecord.ID(
            recordName: "DailyRecordRevision:failed-record",
            zoneID: CKRecordZone.ID(zoneName: "sunclub-history", ownerName: CKCurrentUserDefaultName)
        )

        try await coordinator.recoverFailedRecordSave(recordID: recordID, error: CKError(.zoneNotFound))

        XCTAssertEqual(
            driver.operations,
            [.saveZone, .saveRecord("DailyRecordRevision:failed-record"), .fetch]
        )
    }

    @MainActor
    func testUnknownItemSendFailureRequeuesZoneAndRecordBeforeFetch() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()
        let driver = FakeCloudSyncEngineDriver()
        let coordinator = CloudSyncCoordinator(
            historyService: historyService,
            syncEngineDriver: driver
        )
        let recordID = CKRecord.ID(
            recordName: "SettingsRevision:failed-settings",
            zoneID: CKRecordZone.ID(zoneName: "sunclub-history", ownerName: CKCurrentUserDefaultName)
        )

        try await coordinator.recoverFailedRecordSave(recordID: recordID, error: CKError(.unknownItem))

        XCTAssertEqual(
            driver.operations,
            [.saveZone, .saveRecord("SettingsRevision:failed-settings"), .fetch]
        )
    }

    @MainActor
    func testUndoingDeleteRestoresProjectedRecord() throws {
        let state = try makeAppState()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let verifiedAt = try XCTUnwrap(Calendar.current.date(bySettingHour: 8, minute: 15, second: 0, of: yesterday))
        let reappliedAt = try XCTUnwrap(Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: yesterday))

        state.saveManualRecord(for: yesterday, verifiedAt: verifiedAt, spfLevel: 50, notes: "Beach day")
        state.recordReapplication(for: yesterday, performedAt: reappliedAt)
        state.deleteRecord(for: yesterday)

        let deletedBatch = try XCTUnwrap(state.changeBatches.first(where: { $0.kind == .deleteRecord }))
        XCTAssertNil(state.record(for: yesterday))

        state.undoChange(deletedBatch.id)

        let restored = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertEqual(restored.spfLevel, 50)
        XCTAssertEqual(restored.notes, "Beach day")
        XCTAssertEqual(restored.verifiedAt, verifiedAt)
        XCTAssertEqual(restored.reapplyCount, 1)
        XCTAssertEqual(restored.lastReappliedAt, reappliedAt)
    }

    @MainActor
    func testRemoteDayConflictAutoMergesAndCreatesReviewItem() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let referenceDate = calendar.date(byAdding: .hour, value: 12, to: today) ?? Date()
        let state = try makeAppState(clock: { referenceDate })
        let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: today) ?? today

        state.saveManualRecord(for: today, verifiedAt: verifiedAt, spfLevel: 30, notes: "Local entry")

        let remoteCreatedAt = Date().addingTimeInterval(60)
        let remoteBatch = SunclubChangeBatch(
            createdAt: remoteCreatedAt,
            kind: .historyEdit,
            scope: .day,
            scopeIdentifier: today.formatted(.iso8601.year().month().day()),
            authorDeviceID: "remote-device",
            summary: "Remote history edit",
            isLocalOnly: false,
            isPublishedToCloud: true,
            cloudPublishedAt: remoteCreatedAt
        )
        state.modelContext.insert(remoteBatch)
        state.modelContext.insert(
            DailyRecordRevision(
                batch: remoteBatch,
                snapshot: DailyRecordProjectionSnapshot(
                    startOfDay: today,
                    verifiedAt: verifiedAt,
                    methodRawValue: VerificationMethod.manual.rawValue,
                    verificationDuration: nil,
                    spfLevel: 50,
                    notes: "Remote entry",
                    reapplyCount: 1,
                    lastReappliedAt: remoteCreatedAt
                ),
                changedFields: [.spfLevel, .notes, .reapplyCount, .lastReappliedAt]
            )
        )
        state.save()

        state.refresh()

        let mergedRecord = try XCTUnwrap(state.record(for: today))
        XCTAssertEqual(mergedRecord.spfLevel, 50)
        XCTAssertEqual(mergedRecord.notes, "Remote entry")
        XCTAssertEqual(mergedRecord.reapplyCount, 1)
        XCTAssertEqual(state.conflicts.count, 1)
        XCTAssertEqual(state.conflicts.first?.scope, .day)
        XCTAssertEqual(state.homeDailyPlanPresentation.action, .reviewRecovery)
        let conflict = try XCTUnwrap(state.conflicts.first)
        let changedFields = state.conflictChangedFieldNames(for: conflict)
        XCTAssertTrue(changedFields.contains("SPF"))
        XCTAssertTrue(changedFields.contains("Notes"))
        XCTAssertTrue(changedFields.contains("Reapply count"))
    }
}
