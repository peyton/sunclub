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

    func publishImport(_ id: UUID) async throws { _ = try await cloud.publishImportedSession(id) }
    func restoreImport(_ id: UUID) throws -> SunclubChangeBatch? { try history.restoreImportSession(id) }
    func undo(_ id: UUID) throws -> SunclubChangeBatch? { try history.undo(batchID: id) }
    func redo(_ id: UUID) throws -> SunclubChangeBatch? { try history.redo(batchID: id) }
    func resolveConflict(_ id: UUID) throws { try history.resolveConflict(id) }

    func exportDocument(preferences: SunclubRestorablePreferences) throws -> SunclubBackupDocument {
        try backups.exportDocument(from: context, restorablePreferences: preferences)
    }

    func export(to url: URL, preferences: SunclubRestorablePreferences) throws -> SunclubBackupDocument {
        try backups.exportBackup(from: context, to: url, restorablePreferences: preferences)
    }

    func importDocument(_ document: SunclubBackupDocument) throws -> SunclubBackupImportSummary {
        try backups.importBackupDocument(document, into: context)
    }

    func importDocument(from url: URL) throws -> SunclubBackupImportSummary {
        try backups.importBackup(from: url, into: context)
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
