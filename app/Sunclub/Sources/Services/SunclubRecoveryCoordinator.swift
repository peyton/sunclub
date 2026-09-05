import Foundation
import Observation
import SwiftData

enum InitialICloudRestoreState: Equatable {
    case notNeeded
    case checking
    case restored
    case noRemoteHistory
    case failed(String)
    case continuedLocally
}

@MainActor
@Observable
final class SunclubRecoveryCoordinator {
    private let history: SunclubHistoryService
    private let cloud: CloudSyncControlling
    private let backups: SunclubBackupService
    private let context: ModelContext
    var initialRestoreState: InitialICloudRestoreState = .notNeeded

    init(history: SunclubHistoryService, cloud: CloudSyncControlling, backups: SunclubBackupService) {
        self.history = history
        self.cloud = cloud
        self.backups = backups
        context = history.fetchContext()
    }

    func start(launchRecovery: SunclubStoreRecoveryResult? = nil, syncEnabled: Bool = true) async {
        if let launchRecovery, syncEnabled {
            _ = try? await cloud.publishImportedSession(launchRecovery.importSessionID)
        }
        applyStartResult(await cloud.start())
    }

    func retry() async {
        initialRestoreState = .checking
        await start()
    }

    func publishImport(_ id: UUID) async throws -> CloudPublishResult {
        let result = try await cloud.publishImportedSession(id)
        let preference = try history.syncPreference()
        if try history.importSession(id: id)?.publishedAt == nil, preference.status == .error {
            throw SunclubHistoryMutationError.recoveryFailure(
                preference.lastSyncErrorDescription ?? "iCloud couldn't finish sending these changes. Please try again."
            )
        }
        return result
    }
    func restoreImport(_ id: UUID, currentPreferences: SunclubRestorablePreferences) throws -> SunclubChangeBatch {
        try history.restoreImportSession(id, currentPreferences: currentPreferences)
    }
    func undo(_ id: UUID) throws -> SunclubChangeBatch { try history.undo(batchID: id) }
    func redo(_ id: UUID) throws -> SunclubChangeBatch { try history.redo(batchID: id) }
    func undoIfCurrent(_ id: UUID) throws -> SunclubChangeBatch { try history.undoChangeIfCurrent(batchID: id) }
    func canUndoIfCurrent(_ id: UUID) throws -> Bool { try history.canUndoChangeIfCurrent(batchID: id) }
    func undoConflict(_ id: UUID) throws -> SunclubChangeBatch { try history.undoConflict(id) }
    func resolveConflict(_ id: UUID) throws { try history.resolveConflict(id) }

    func exportDocument(preferences: SunclubRestorablePreferences) throws -> SunclubBackupDocument {
        try backups.exportDocument(from: context, restorablePreferences: preferences)
    }

    func export(to url: URL, preferences: SunclubRestorablePreferences) throws -> SunclubBackupDocument {
        try backups.exportBackup(from: context, to: url, restorablePreferences: preferences)
    }

    func importDocument(
        _ document: SunclubBackupDocument, currentPreferences: SunclubRestorablePreferences
    ) throws -> SunclubBackupImportSummary {
        try backups.importBackupDocument(document, into: context, currentPreferences: currentPreferences)
    }

    func importDocument(from url: URL, currentPreferences: SunclubRestorablePreferences) throws -> SunclubBackupImportSummary {
        try backups.importBackup(from: url, into: context, currentPreferences: currentPreferences)
    }

    @MainActor
    static func recoverLegacyStoreIfNeeded(
        storeRecoveryService: SunclubStoreRecoveryService,
        context: ModelContext,
        historyService: SunclubHistoryService,
        runtimeEnvironment: RuntimeEnvironmentSnapshot
    ) -> SunclubStoreRecoveryResult? {
        guard runtimeEnvironment.shouldRunLaunchStoreRecovery else {
            return nil
        }

        return try? storeRecoveryService.recoverLegacyApplicationSupportStoreIfNeeded(
            into: context,
            historyService: historyService
        )
    }

    static func initialICloudRestoreState(
        historyService: SunclubHistoryService,
        runtimeEnvironment: RuntimeEnvironmentSnapshot
    ) -> InitialICloudRestoreState {
        guard runtimeEnvironment.shouldStartCloudSyncOnLaunch else {
            return .notNeeded
        }

        guard (try? historyService.syncPreference().isICloudSyncEnabled) == true else {
            return .notNeeded
        }

        guard (try? historyService.isEffectivelyEmptyForInitialICloudRestore()) == true else {
            return .notNeeded
        }

        return .checking
    }

    func applyStartResult(_ result: CloudSyncStartResult) {
        switch result {
        case .restoredRemoteHistory:
            initialRestoreState = .restored
        case .noRemoteHistory:
            if initialRestoreState == .checking {
                initialRestoreState = .noRemoteHistory
            }
        case .skippedDisabled:
            if initialRestoreState == .checking {
                initialRestoreState = .notNeeded
            }
        case let .failed(message):
            if initialRestoreState == .checking {
                initialRestoreState = .failed(message)
            }
        }
    }

}
