import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SettingsRecoverySimplicityTests: XCTestCase {
    private let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))

    // Catches Settings dropping a rejected local publish preparation instead of offering its retry.
    func testPublishSaveFailureKeepsImportPendingAndExposesItsRetry() async throws {
        let fixture = try makeFixture()
        let actions = SettingsImportActionState()
        fixture.gate.rejectsChanges = true

        await actions.perform(.publish(fixture.sessionID), in: fixture.state)?.value

        XCTAssertEqual(actions.failure?.action, .publish(fixture.sessionID))
        XCTAssertEqual(actions.failure?.error, .persistenceFailure)
        XCTAssertNil(actions.activeAction)
        let session = try XCTUnwrap(fixture.history.importSession(id: fixture.sessionID))
        XCTAssertNil(session.publishRequestedAt)
        XCTAssertNil(session.publishedAt)
        XCTAssertEqual(fixture.state.pendingImportedBatchCount, 1)
        XCTAssertEqual(fixture.state.record(for: day)?.notes, "Imported value")
    }

    // Catches Settings silently ignoring a rejected Undo Import and losing the original retry target.
    func testRestoreSaveFailureKeepsCurrentDataAndExposesItsRetry() throws {
        let fixture = try makeFixture()
        let actions = SettingsImportActionState()
        fixture.gate.rejectsChanges = true

        actions.perform(.restore(fixture.sessionID), in: fixture.state)

        XCTAssertEqual(actions.failure?.action, .restore(fixture.sessionID))
        XCTAssertEqual(actions.failure?.error, .persistenceFailure)
        XCTAssertNil(actions.activeAction)
        XCTAssertEqual(fixture.state.record(for: day)?.notes, "Imported value")
        XCTAssertEqual(fixture.state.pendingImportedBatchCount, 1)
        XCTAssertNil(try fixture.history.importSession(id: fixture.sessionID)?.publishedAt)
    }

    // Catches retrying the most recent import rather than the import whose publish failed.
    func testPublishRetryRetainsOriginalSessionAndClearsFailureOnSuccess() async throws {
        let fixture = try makeFixture()
        let actions = SettingsImportActionState()
        fixture.gate.rejectsChanges = true
        await actions.perform(.publish(fixture.sessionID), in: fixture.state)?.value
        let retry = try XCTUnwrap(actions.failure).action
        fixture.gate.rejectsChanges = false
        let newer = try makeSession(in: fixture.history, createdAt: day.addingTimeInterval(1))
        fixture.state.refresh()
        XCTAssertEqual(fixture.state.recentImportSession?.id, newer.id)

        await actions.perform(retry, in: fixture.state)?.value

        XCTAssertNil(actions.failure)
        XCTAssertNil(actions.activeAction)
        XCTAssertNotNil(try fixture.history.importSession(id: fixture.sessionID)?.publishRequestedAt)
        XCTAssertNil(newer.publishRequestedAt)
        // Preparing a send is not confirmation that iCloud received it.
        XCTAssertNil(try fixture.history.importSession(id: fixture.sessionID)?.publishedAt)
        XCTAssertEqual(fixture.state.pendingImportedBatchCount, 1)
    }

    // Catches Retry Undo switching to a newer restore point or leaving a stale failure after success.
    func testRestoreRetryUsesOriginalRestorePointAndClearsFailure() throws {
        let fixture = try makeFixture()
        let actions = SettingsImportActionState()
        fixture.gate.rejectsChanges = true
        actions.perform(.restore(fixture.sessionID), in: fixture.state)
        let retry = try XCTUnwrap(actions.failure).action
        fixture.gate.rejectsChanges = false
        let newer = try makeSession(in: fixture.history, createdAt: day.addingTimeInterval(1))
        fixture.state.refresh()
        XCTAssertEqual(fixture.state.recentImportSession?.id, newer.id)

        actions.perform(retry, in: fixture.state)

        XCTAssertNil(actions.failure)
        XCTAssertNil(actions.activeAction)
        XCTAssertEqual(fixture.state.record(for: day)?.notes, "Before import")
        XCTAssertNil(try fixture.history.importSession(id: fixture.sessionID)?.publishedAt)
    }

    // Catches ending progress before the awaited send or allowing Undo Import during that send.
    func testPublishStaysBusyAndBlocksUndoUntilTheSendReturns() async throws {
        let fixture = try makeFixture()
        let actions = SettingsImportActionState()
        let started = expectation(description: "Publication reached the transport boundary")
        fixture.cloud.holdsSend = true
        fixture.cloud.sendStarted = { started.fulfill() }
        let task = actions.perform(.publish(fixture.sessionID), in: fixture.state)
        await fulfillment(of: [started], timeout: 2)

        XCTAssertEqual(actions.activeAction, .publish(fixture.sessionID))
        actions.perform(.restore(fixture.sessionID), in: fixture.state)
        XCTAssertEqual(fixture.state.record(for: day)?.notes, "Imported value")
        XCTAssertEqual(actions.activeAction, .publish(fixture.sessionID))
        XCTAssertNil(actions.failure)

        fixture.cloud.releaseSend()
        await task?.value

        XCTAssertNil(actions.activeAction)
        XCTAssertNil(actions.failure)
        XCTAssertNil(try fixture.history.importSession(id: fixture.sessionID)?.publishedAt)
        XCTAssertEqual(fixture.state.pendingImportedBatchCount, 1)
    }

    // Catches consuming only local preparation and dropping an asynchronous transport failure.
    func testSendFailureAfterPreparationRemainsPendingWithPublishRetry() async throws {
        let fixture = try makeFixture()
        let actions = SettingsImportActionState()
        fixture.cloud.sendFailure = .recoveryFailure("Connection interrupted")

        await actions.perform(.publish(fixture.sessionID), in: fixture.state)?.value

        XCTAssertEqual(actions.failure?.action, .publish(fixture.sessionID))
        XCTAssertEqual(actions.failure?.error, .recoveryFailure("Connection interrupted"))
        XCTAssertNil(actions.activeAction)
        let session = try XCTUnwrap(fixture.history.importSession(id: fixture.sessionID))
        XCTAssertNotNil(session.publishRequestedAt)
        XCTAssertNil(session.publishedAt)
        XCTAssertEqual(fixture.state.pendingImportedBatchCount, 1)
        XCTAssertEqual(fixture.state.record(for: day)?.notes, "Imported value")
    }

    private struct Fixture {
        let history: SunclubHistoryService
        let gate: SettingsRecoveryMutationGate
        let cloud: SettingsRecoveryCloud
        let state: AppState
        let sessionID: UUID
    }

    private func makeFixture() throws -> Fixture {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let gate = SettingsRecoveryMutationGate()
        let history = SunclubHistoryService(context: ModelContext(container), mutationGuard: { try gate.check() })
        try history.bootstrapIfNeeded()
        _ = try writeRecord(in: history, notes: "Before import")
        let session = try makeSession(in: history, createdAt: day)
        let imported = try writeRecord(in: history, notes: "Imported value")
        imported.importSessionID = session.id
        imported.isLocalOnly = true
        session.setImportedBatchIDs([imported.id])
        try history.fetchContext().save()
        let cloud = SettingsRecoveryCloud(history: history)
        let suite = "SettingsRecoverySimplicityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(
            context: history.fetchContext(), notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            historyService: history, cloudSyncCoordinator: cloud,
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: defaults),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true, isPreviewing: false, hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            ),
            homeExitReminderMonitor: MockHomeExitReminderMonitor(),
            clock: { self.day.addingTimeInterval(18 * 3_600) }
        )
        return Fixture(history: history, gate: gate, cloud: cloud, state: state, sessionID: session.id)
    }

    private func makeSession(in history: SunclubHistoryService, createdAt: Date) throws -> SunclubImportSession {
        let restore = try history.createRestorePoint(summary: "Before import")
        let session = SunclubImportSession(
            createdAt: createdAt, sourceDescription: "Test backup", restorePointBatchID: restore.id
        )
        history.fetchContext().insert(session)
        try history.fetchContext().save()
        return session
    }

    private func writeRecord(in history: SunclubHistoryService, notes: String) throws -> SunclubChangeBatch {
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
}

@MainActor
private final class SettingsRecoveryMutationGate {
    var rejectsChanges = false
    func check() throws {
        if rejectsChanges { throw SunclubHistoryMutationError.persistenceFailure }
    }
}

@MainActor
private final class SettingsRecoveryCloud: CloudSyncControlling {
    let history: SunclubHistoryService
    var holdsSend = false
    var sendFailure: SunclubHistoryMutationError?
    var sendStarted: (() -> Void)?
    private var sendContinuation: CheckedContinuation<Void, Never>?

    init(history: SunclubHistoryService) { self.history = history }
    func start() async -> CloudSyncStartResult { .noRemoteHistory }
    func setEnabled(_ enabled: Bool) async throws {}
    func queueBatchIfNeeded(_ batchID: UUID) async {}
    func syncNow() async {}

    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult {
        let result = try history.publishImportedChanges(for: sessionID)
        if holdsSend {
            await withCheckedContinuation { continuation in
                sendContinuation = continuation
                sendStarted?()
            }
        }
        if let sendFailure { throw sendFailure }
        return result
    }

    func releaseSend() {
        holdsSend = false
        sendContinuation?.resume()
        sendContinuation = nil
    }
}
