import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class RecoverySimplicityTests: XCTestCase {
    private let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))

    // Break caught: undo commits an inverse and marks the original undone even when persistence rejects it.
    func testFailedUndoPreservesRecordAndOriginalBatch() throws {
        let fixture = try makeFixture()
        let batch = try insertRecord(in: fixture.history, notes: "Keep me")
        let beforeIDs = try batchIDs(in: fixture.history)
        fixture.gate.rejectsChanges = true

        XCTAssertThrowsError(try fixture.history.undo(batchID: batch.id))

        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "Keep me")
        XCTAssertNil(try fixture.history.fetchBatchForSync(id: batch.id)?.undoneByBatchID)
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: redo bypasses the same durable-write failure boundary as undo.
    func testFailedRedoLeavesDeletionAndUndoHistoryIntact() throws {
        let fixture = try makeFixture()
        let batch = try insertRecord(in: fixture.history, notes: "Original")
        let undo = try fixture.history.undo(batchID: batch.id)
        let beforeIDs = try batchIDs(in: fixture.history)
        fixture.gate.rejectsChanges = true

        XCTAssertThrowsError(try fixture.history.redo(batchID: batch.id))

        XCTAssertNil(try fixture.history.record(for: day))
        XCTAssertNil(try fixture.history.fetchBatchForSync(id: undo.id)?.undoneByBatchID)
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: failed restore replaces the current projection or leaves a partial revision.
    func testFailedImportRestorePreservesCurrentProjection() throws {
        let fixture = try makeFixture()
        _ = try insertRecord(in: fixture.history, notes: "Before import")
        let session = try makeImportSession(in: fixture.history)
        _ = try insertRecord(in: fixture.history, notes: "Current edit")
        let beforeIDs = try batchIDs(in: fixture.history)
        fixture.gate.rejectsChanges = true

        XCTAssertThrowsError(try fixture.history.restoreImportSession(session.id))

        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "Current edit")
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: restoring a snapshot erases days created after that snapshot.
    func testImportRestorePreservesDaysAddedAfterRestorePoint() throws {
        let fixture = try makeFixture()
        let session = try makeImportSession(in: fixture.history)
        _ = try insertRecord(in: fixture.history, notes: "Logged after backup")

        _ = try fixture.history.restoreImportSession(session.id)

        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "Logged after backup")
        XCTAssertEqual(try fixture.history.records().count, 1)
    }

    // Break caught: an empty restore point resets completed onboarding and meaningful settings.
    func testEmptyRestorePointCannotReplaceCompletedSettingsWithDefaults() throws {
        let fixture = try makeFixture()
        let session = try makeImportSession(in: fixture.history)
        try fixture.history.applySettingsChange(
            kind: .onboarding, summary: "Completed setup", changedFields: [.hasCompletedOnboarding, .reminderHour]
        ) { snapshot in
            snapshot.hasCompletedOnboarding = true
            snapshot.reminderHour = 7
        }

        _ = try fixture.history.restoreImportSession(session.id)

        XCTAssertTrue(try fixture.history.settings().hasCompletedOnboarding)
        XCTAssertEqual(try fixture.history.settings().reminderHour, 7)
    }

    // Break caught: publishing marks batches eligible and the session pending after a rejected local save.
    func testFailedPublishPreparationKeepsImportLocalAndRetryable() throws {
        let fixture = try makeFixture()
        let session = try makeImportSession(in: fixture.history)
        let imported = try insertRecord(in: fixture.history, notes: "Local backup")
        imported.importSessionID = session.id
        imported.isLocalOnly = true
        session.setImportedBatchIDs([imported.id])
        try fixture.history.fetchContext().save()
        fixture.gate.rejectsChanges = true

        XCTAssertThrowsError(try fixture.history.publishImportedChanges(for: session.id))

        XCTAssertTrue(try XCTUnwrap(fixture.history.fetchBatchForSync(id: imported.id)).isLocalOnly)
        XCTAssertNil(try fixture.history.importSession(id: session.id)?.publishRequestedAt)
        XCTAssertNil(try fixture.history.importSession(id: session.id)?.publishedAt)
    }

    // Break caught: the AppState facade swallows errors, leaving the recovery screen unable to explain failure.
    func testMissingUndoExposesFailureWithoutChangingHistory() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        let beforeIDs = try batchIDs(in: fixture.history)

        state.undoChange(UUID())

        XCTAssertNotNil(state.logActionErrorMessage)
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    func testMissingRedoExposesFailureWithoutChangingHistory() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        let beforeIDs = try batchIDs(in: fixture.history)

        state.redoChange(UUID())

        XCTAssertNotNil(state.logActionErrorMessage)
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    func testMissingImportRestoreExposesFailureWithoutChangingHistory() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        let beforeIDs = try batchIDs(in: fixture.history)

        state.restoreImportedChanges(for: UUID())

        XCTAssertNotNil(state.logActionErrorMessage)
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: a late authorization completion overrides a newer explicit disable.
    func testDisablingHealthWhileAuthorizationIsPendingStaysDisabled() async throws {
        let fixture = try makeFixture()
        let health = RecoveryHealthService()
        let started = expectation(description: "Authorization requested")
        health.authorizationStarted = { started.fulfill() }
        let store = RecoveryGrowthStore()
        let state = makeState(history: fixture.history, health: health, growth: store)

        state.updateHealthKitEnabled(true)
        await fulfillment(of: [started], timeout: 2)
        state.updateHealthKitEnabled(false)
        health.completeAuthorization(true)
        await drainTasks()

        XCTAssertFalse(state.growthSettings.healthKit.isEnabled)
        XCTAssertFalse(store.load().healthKit.isEnabled)
    }

    func testDisablingHealthWhileSampleQueryIsPendingStaysDisabled() async throws {
        let fixture = try makeFixture()
        let health = RecoveryHealthService()
        let authorizationStarted = expectation(description: "Authorization requested")
        let queryStarted = expectation(description: "Sample query started")
        health.authorizationStarted = { authorizationStarted.fulfill() }
        health.sampleQueryStarted = { queryStarted.fulfill() }
        let store = RecoveryGrowthStore()
        let state = makeState(history: fixture.history, health: health, growth: store)

        state.updateHealthKitEnabled(true)
        await fulfillment(of: [authorizationStarted], timeout: 2)
        health.completeAuthorization(true)
        await fulfillment(of: [queryStarted], timeout: 2)
        state.updateHealthKitEnabled(false)
        health.completeSampleQuery(12)
        await drainTasks()

        XCTAssertFalse(state.growthSettings.healthKit.isEnabled)
        XCTAssertFalse(store.load().healthKit.isEnabled)
        XCTAssertEqual(state.growthSettings.healthKit.importedSampleCount, 0)
    }

    // Break caught: an unchanged manual save emits another cloud/reminder/live-activity/Health effect.
    func testUnchangedManualSaveDoesNotEmitFollowUpEffects() async throws {
        let fixture = try makeFixture()
        let cloud = ProbeCloudSyncCoordinator()
        let notifications = MockNotificationManager()
        let health = RecoveryHealthService()
        let live = RecoveryLiveActivityCoordinator()
        let state = makeState(history: fixture.history, cloud: cloud, notifications: notifications, health: health, live: live)
        let timestamp = day.addingTimeInterval(9 * 3_600)
        state.saveManualRecord(for: day, verifiedAt: timestamp, spfLevel: 30, notes: "Morning")
        await drainTasks()
        let beforeIDs = try batchIDs(in: fixture.history)
        let queuedIDs = cloud.queuedBatchIDs
        let reminderCount = notifications.refreshStreakRiskReminderCount
        let liveCount = live.syncCount
        let healthCount = health.exportCount

        let result = state.saveManualRecord(for: day, verifiedAt: timestamp, spfLevel: 30, notes: "Morning")
        await drainTasks()

        guard case let .success(receipt) = result else { return XCTFail("Unchanged save must succeed") }
        XCTAssertFalse(receipt.didChange)
        XCTAssertNil(receipt.batchID)
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
        XCTAssertEqual(cloud.queuedBatchIDs, queuedIDs)
        XCTAssertEqual(notifications.refreshStreakRiskReminderCount, reminderCount)
        XCTAssertEqual(live.syncCount, liveCount)
        XCTAssertEqual(health.exportCount, healthCount)
    }

    // Break caught: migration/projection seeding loses a non-empty shipped store or makes it unpublishable.
    func testPriorShippedStoreKeepsPublishableHistoryThroughRecoveryProjection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Sunclub.store")
        let dates = try LegacyStoreFixture.seedCurrentV3Store(at: url)
        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: url)
        let history = SunclubHistoryService(context: ModelContext(container), calendar: .migrationTestCalendar)
        try history.bootstrapIfNeeded()
        let session = try makeImportSession(in: history)

        _ = try history.restoreImportSession(session.id)
        try history.refreshProjectedState()

        let record = try XCTUnwrap(history.record(for: dates.startOfDay))
        XCTAssertEqual(record.notes, "Morning beach walk")
        XCTAssertEqual(record.spfLevel, 50)
        XCTAssertEqual(record.reapplyCount, 1)
        XCTAssertTrue(try history.settings().hasCompletedOnboarding)
        XCTAssertFalse(try history.cloudPublishableBatches().isEmpty)
    }

    // Break caught: synthetic empty bootstrap becomes a cloud-publishable replacement for remote history.
    func testEmptyProjectionRemainsLocalOnly() throws {
        let fixture = try makeFixture()
        try fixture.history.refreshProjectedState()
        XCTAssertTrue(try fixture.history.records().isEmpty)
        XCTAssertTrue(try fixture.history.cloudPublishableBatches().isEmpty)
    }

    // Break caught: a stale log receipt resurrects/rewrites a day deleted after the receipt was shown.
    func testReceiptUndoAfterDeletionFailsWithoutAddingHistory() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        let original = try insertRecord(in: fixture.history, notes: "Original")
        state.refresh()
        state.deleteRecord(for: day)
        let beforeIDs = try batchIDs(in: fixture.history)

        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: original.id))
        assertStale(state.undoChangeIfCurrent(batchID: original.id))

        XCTAssertNil(try fixture.history.record(for: day))
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: Undo Delete replaces a newer log with the deleted snapshot.
    func testDeleteReceiptUndoAfterReplacementPreservesNewLog() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        _ = try insertRecord(in: fixture.history, notes: "Deleted log")
        state.refresh()
        guard case let .success(receipt) = state.deleteRecord(for: day) else { return XCTFail("Delete failed") }
        let deletionID = try XCTUnwrap(receipt.batchID)
        _ = try insertRecord(in: fixture.history, notes: "Replacement")
        state.refresh()
        let beforeIDs = try batchIDs(in: fixture.history)

        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: deletionID))
        assertStale(state.undoChangeIfCurrent(batchID: deletionID))

        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "Replacement")
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: comparing values alone lets an old receipt undo a newer revision with identical values.
    func testReceiptUndoRejectsNewerRevisionEvenWhenValuesMatchAgain() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        let first = try insertRecord(in: fixture.history, notes: "Same visible values")
        _ = try insertRecord(in: fixture.history, notes: "Intermediate edit")
        _ = try insertRecord(in: fixture.history, notes: "Same visible values")
        state.refresh()
        let beforeIDs = try batchIDs(in: fixture.history)

        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: first.id))
        assertStale(state.undoChangeIfCurrent(batchID: first.id))

        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "Same visible values")
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: trusting the screen's cached batches misses a newer revision awaiting projection refresh.
    func testReceiptUndoChecksStoredRevisionsBeforeRefresh() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        let original = try insertRecord(in: fixture.history, notes: "Visible log")
        state.refresh()
        let nextOrder = try XCTUnwrap(original.logicalOrder) + 1
        let newer = SunclubChangeBatch(
            logicalOrder: nextOrder, kind: .historyEdit, scope: .day,
            scopeIdentifier: original.scopeIdentifier, authorDeviceID: original.authorDeviceID, summary: "Received edit"
        )
        let context = fixture.history.fetchContext()
        context.insert(newer)
        var snapshot = try XCTUnwrap(fixture.history.record(for: day)).projectionSnapshot
        snapshot.notes = "Newer stored log"
        context.insert(DailyRecordRevision(batch: newer, snapshot: snapshot, changedFields: [.notes]))
        try context.save()
        let beforeIDs = try batchIDs(in: fixture.history)

        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: original.id))
        assertStale(state.undoChangeIfCurrent(batchID: original.id))

        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
        try fixture.history.refreshProjectedState()
        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "Newer stored log")
    }

    // Break caught: checking revision identity alone overwrites a projection changed outside the history facade.
    func testReceiptUndoRejectsProjectionThatNoLongerMatchesRevision() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        let original = try insertRecord(in: fixture.history, notes: "Revision snapshot")
        state.refresh()
        let projected = try XCTUnwrap(fixture.history.record(for: day))
        projected.notes = "New projected edit"
        try fixture.history.fetchContext().save()
        let beforeIDs = try batchIDs(in: fixture.history)

        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: original.id))
        assertStale(state.undoChangeIfCurrent(batchID: original.id))

        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "New projected edit")
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: guarding against the globally latest batch unnecessarily disables Undo for an unrelated day.
    func testCurrentReceiptUndoAllowsUnrelatedDayChanges() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        _ = try insertRecord(in: fixture.history, notes: "Before edit")
        let edit = try insertRecord(in: fixture.history, notes: "After edit")
        let otherDay = day.addingTimeInterval(-86_400)
        state.saveManualRecord(for: otherDay, spfLevel: 50, notes: "Other day")

        XCTAssertTrue(state.canUndoChangeIfCurrent(batchID: edit.id))
        let inverse = try state.undoChangeIfCurrent(batchID: edit.id).get()

        XCTAssertEqual(inverse.inverseOfBatchID, edit.id)
        XCTAssertEqual(inverse.kind, .undo)
        XCTAssertEqual(state.record(for: day)?.notes, "Before edit")
        XCTAssertEqual(state.record(for: otherDay)?.notes, "Other day")
        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: edit.id))
    }

    // Break caught: treating all deleted days as stale prevents the current deletion receipt from restoring a log.
    func testCurrentDeletionReceiptRestoresDeletedLog() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        _ = try insertRecord(in: fixture.history, notes: "Restore this log")
        state.refresh()
        guard case let .success(receipt) = state.deleteRecord(for: day) else { return XCTFail("Delete failed") }
        let deletionID = try XCTUnwrap(receipt.batchID)

        XCTAssertTrue(state.canUndoChangeIfCurrent(batchID: deletionID))
        _ = try state.undoChangeIfCurrent(batchID: deletionID).get()

        XCTAssertEqual(state.record(for: day)?.notes, "Restore this log")
        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: deletionID))
    }

    // Break caught: applying ephemeral receipt constraints to explicit historical recovery removes that recovery route.
    func testExplicitHistoricalUndoRemainsAvailableAfterNewerEdits() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        _ = try insertRecord(in: fixture.history, notes: "Historical value")
        let edit = try insertRecord(in: fixture.history, notes: "First edit")
        _ = try insertRecord(in: fixture.history, notes: "Latest edit")
        state.refresh()

        _ = try state.undoChange(edit.id).get()

        XCTAssertEqual(state.record(for: day)?.notes, "Historical value")
    }

    // Break caught: the conflict disappears even though its merge could not be undone.
    func testFailedConflictUndoRemainsUnresolvedForRetry() throws {
        let fixture = try makeFixture()
        let conflict = SunclubConflictItem(
            scope: .day, scopeIdentifier: "missing-merge", summary: "Review merge",
            mergedBatchID: UUID(), competingBatchIDs: []
        )
        fixture.history.fetchContext().insert(conflict)
        try fixture.history.fetchContext().save()
        let state = makeState(history: fixture.history)

        if case .success = state.undoConflict(conflict.id) { XCTFail("Missing merge cannot be undone") }

        XCTAssertNil(conflict.resolvedAt)
        XCTAssertEqual(state.conflicts.map(\.id), [conflict.id])
    }

    func testConflictUndoCommitFailureRollsBackInverseAndResolutionBeforeRetry() throws {
        let fixture = try makeFixture()
        _ = try insertRecord(in: fixture.history, notes: "Before merge")
        let merged = try insertRecord(in: fixture.history, notes: "Merged value")
        let conflict = SunclubConflictItem(
            scope: .day, scopeIdentifier: "merged-day", summary: "Review merge",
            mergedBatchID: merged.id, competingBatchIDs: []
        )
        fixture.history.fetchContext().insert(conflict)
        try fixture.history.fetchContext().save()
        let state = makeState(history: fixture.history)
        let beforeIDs = try batchIDs(in: fixture.history)
        fixture.gate.rejectsChanges = true

        if case .success = state.undoConflict(conflict.id) { XCTFail("Commit should fail") }

        XCTAssertEqual(state.conflicts.map(\.id), [conflict.id])
        XCTAssertEqual(state.record(for: day)?.notes, "Merged value")
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
        XCTAssertNil(try fixture.history.fetchBatchForSync(id: merged.id)?.undoneByBatchID)

        fixture.gate.rejectsChanges = false
        _ = try state.undoConflict(conflict.id).get()

        XCTAssertTrue(state.conflicts.isEmpty)
        XCTAssertEqual(state.record(for: day)?.notes, "Before merge")
        XCTAssertEqual(try batchIDs(in: fixture.history).count, beforeIDs.count + 1)
        XCTAssertNotNil(try fixture.history.fetchBatchForSync(id: merged.id)?.undoneByBatchID)
    }

    // Break caught: resolving a conflict persists despite a failed durable write.
    func testFailedMarkReviewedKeepsConflictUnresolved() throws {
        let fixture = try makeFixture()
        let conflict = SunclubConflictItem(
            scope: .day, scopeIdentifier: "review", summary: "Review merge", mergedBatchID: UUID(), competingBatchIDs: []
        )
        fixture.history.fetchContext().insert(conflict)
        try fixture.history.fetchContext().save()
        fixture.gate.rejectsChanges = true

        XCTAssertThrowsError(try fixture.history.resolveConflict(conflict.id))

        XCTAssertEqual(try fixture.history.unresolvedConflicts().map(\.id), [conflict.id])
    }

    // Break caught: an async publication failure disappears at the AppState boundary.
    func testMissingPublishExposesFailureWithoutClaimingPublication() async throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history, cloud: NoopCloudSyncCoordinator(historyService: fixture.history))
        let beforeIDs = try batchIDs(in: fixture.history)

        state.publishImportedChanges(for: UUID())
        await drainTasks()

        XCTAssertNotNil(state.logActionErrorMessage)
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    // Break caught: the sync layer reports an error in persisted status but the recovery facade treats the request as success.
    func testPublishSendFailureRemainsPendingAndExposesRetryableError() async throws {
        let fixture = try makeFixture()
        let session = try makeImportSession(in: fixture.history)
        let imported = try insertRecord(in: fixture.history, notes: "Imported log")
        imported.importSessionID = session.id
        imported.isLocalOnly = true
        session.setImportedBatchIDs([imported.id])
        try fixture.history.fetchContext().save()
        let state = makeState(history: fixture.history, cloud: RecoveryFailedSendCloud(history: fixture.history))

        state.publishImportedChanges(for: session.id)
        await drainTasks()

        XCTAssertNotNil(state.logActionErrorMessage)
        XCTAssertNotNil(try fixture.history.importSession(id: session.id)?.publishRequestedAt)
        XCTAssertNil(try fixture.history.importSession(id: session.id)?.publishedAt)
        XCTAssertEqual(state.pendingImportedBatchCount, 1)
        XCTAssertEqual(state.record(for: day)?.notes, "Imported log")
    }

    // Break caught: a failed import discards existing history instead of reporting its error.
    func testUnreadableBackupImportThrowsAndKeepsCurrentHistory() throws {
        let fixture = try makeFixture()
        let state = makeState(history: fixture.history)
        _ = try insertRecord(in: fixture.history, notes: "Keep current data")
        let beforeIDs = try batchIDs(in: fixture.history)
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sunclub")

        XCTAssertThrowsError(try state.importBackup(from: missing))

        XCTAssertEqual(try fixture.history.record(for: day)?.notes, "Keep current data")
        XCTAssertEqual(try batchIDs(in: fixture.history), beforeIDs)
    }

    private func assertStale(
        _ result: Result<SunclubChangeBatch, SunclubHistoryMutationError>,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard case let .failure(error) = result else { return XCTFail("Stale Undo must fail", file: file, line: line) }
        XCTAssertEqual(error, .staleChange, file: file, line: line)
    }

    private func makeFixture() throws -> (history: SunclubHistoryService, gate: RecoveryMutationGate) {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let gate = RecoveryMutationGate()
        let history = SunclubHistoryService(context: ModelContext(container), mutationGuard: { try gate.check() })
        try history.bootstrapIfNeeded()
        return (history, gate)
    }

    private func insertRecord(in history: SunclubHistoryService, notes: String) throws -> SunclubChangeBatch {
        try XCTUnwrap(history.applyDayChange(
            for: day, kind: .historyEdit, summary: "Edit day", changedFields: [.notes, .verifiedAt, .spfLevel]
        ) { _ in
            DailyRecordProjectionSnapshot(
                startOfDay: self.day, verifiedAt: self.day.addingTimeInterval(9 * 3_600),
                methodRawValue: VerificationMethod.manual.rawValue, verificationDuration: nil,
                spfLevel: 30, notes: notes, reapplyCount: 0, lastReappliedAt: nil
            )
        })
    }

    private func makeImportSession(in history: SunclubHistoryService) throws -> SunclubImportSession {
        let restore = try history.createRestorePoint(summary: "Before import")
        let session = SunclubImportSession(sourceDescription: "Test backup", restorePointBatchID: restore.id)
        history.fetchContext().insert(session)
        try history.fetchContext().save()
        return session
    }

    private func batchIDs(in history: SunclubHistoryService) throws -> Set<UUID> {
        Set(try history.changeBatches().map(\.id))
    }

    private func makeState(
        history: SunclubHistoryService,
        cloud: CloudSyncControlling? = nil,
        notifications: MockNotificationManager? = nil,
        health: RecoveryHealthService? = nil,
        live: RecoveryLiveActivityCoordinator? = nil,
        growth: RecoveryGrowthStore? = nil
    ) -> AppState {
        AppState(
            context: history.fetchContext(), notificationManager: notifications ?? MockNotificationManager(),
            uvIndexService: UVIndexService(), healthKitService: health ?? RecoveryHealthService(),
            liveActivityCoordinator: live ?? RecoveryLiveActivityCoordinator(), historyService: history,
            cloudSyncCoordinator: cloud ?? ProbeCloudSyncCoordinator(),
            growthFeatureStore: growth ?? RecoveryGrowthStore(),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true, isPreviewing: false, hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            ),
            homeExitReminderMonitor: MockHomeExitReminderMonitor(),
            clock: { self.day.addingTimeInterval(18 * 3_600) }
        )
    }

    private func drainTasks() async {
        for _ in 0..<20 { await Task.yield() }
    }
}

@MainActor
private final class RecoveryMutationGate {
    var rejectsChanges = false
    func check() throws {
        if rejectsChanges { throw SunclubHistoryMutationError.persistenceFailure }
    }
}

private final class RecoveryGrowthStore: SunclubGrowthFeatureStoring {
    private var settings = SunclubGrowthSettings()
    func load() -> SunclubGrowthSettings { settings }
    func save(_ settings: SunclubGrowthSettings) { self.settings = settings }
}

@MainActor
private final class RecoveryHealthService: SunclubHealthKitServing {
    var isAvailable: Bool { true }
    var authorizationStarted: (() -> Void)?
    var sampleQueryStarted: (() -> Void)?
    private var authorization: CheckedContinuation<Bool, Never>?
    private var sampleQuery: CheckedContinuation<Int, Never>?
    private(set) var exportCount = 0

    func requestAuthorizationIfNeeded() async -> Bool {
        await withCheckedContinuation { continuation in
            authorization = continuation
            authorizationStarted?()
        }
    }

    func completeAuthorization(_ granted: Bool) {
        authorization?.resume(returning: granted)
        authorization = nil
    }

    func exportLog(recordDate: Date, uvIndex: Int?, externalID: UUID?, spfLevel: Int?) async { exportCount += 1 }
    func recentUVSampleCount(since startDate: Date) async -> Int {
        guard let sampleQueryStarted else { return 12 }
        return await withCheckedContinuation { continuation in
            sampleQuery = continuation
            sampleQueryStarted()
        }
    }

    func completeSampleQuery(_ count: Int) {
        sampleQuery?.resume(returning: count)
        sampleQuery = nil
    }
}

@MainActor
private final class RecoveryLiveActivityCoordinator: SunclubLiveActivityCoordinating {
    private(set) var syncCount = 0
    func sync(using state: AppState) async { syncCount += 1 }
    func endAll() async {}
}

@MainActor
private final class RecoveryFailedSendCloud: CloudSyncControlling {
    let history: SunclubHistoryService
    init(history: SunclubHistoryService) { self.history = history }
    func start() async -> CloudSyncStartResult { .noRemoteHistory }
    func setEnabled(_ enabled: Bool) async throws {}
    func queueBatchIfNeeded(_ batchID: UUID) async {}
    func syncNow() async {}

    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult {
        let result = try history.publishImportedChanges(for: sessionID)
        let preference = try history.syncPreference()
        preference.status = .error
        preference.lastSyncErrorDescription = "The connection was interrupted."
        try history.fetchContext().save()
        return result
    }
}
