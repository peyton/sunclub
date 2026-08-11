import CloudKit
import Foundation
import SwiftData

private struct CloudSyncRecordFailure: Codable, Equatable, Sendable {
    let recordName: String
    let message: String
}

@MainActor
enum CloudSyncStartResult: Equatable {
    case restoredRemoteHistory
    case noRemoteHistory
    case skippedDisabled
    case failed(String)
}

@MainActor
protocol CloudSyncControlling: AnyObject {
    func start() async -> CloudSyncStartResult
    func setEnabled(_ enabled: Bool) async throws
    func queueBatchIfNeeded(_ batchID: UUID) async
    func syncNow() async
    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult
}

@MainActor
final class NoopCloudSyncCoordinator: CloudSyncControlling {
    private let historyService: SunclubHistoryService

    init(historyService: SunclubHistoryService) {
        self.historyService = historyService
    }

    func start() async -> CloudSyncStartResult {
        guard let preference = try? historyService.syncPreference() else {
            return .failed("Sunclub couldn't load iCloud sync settings.")
        }
        preference.status = preference.isICloudSyncEnabled ? .idle : .paused
        try? historyService.fetchContext().save()
        guard preference.isICloudSyncEnabled else {
            return .skippedDisabled
        }
        return (try? historyService.isEffectivelyEmptyForInitialICloudRestore()) == true
            ? .noRemoteHistory
            : .restoredRemoteHistory
    }

    func setEnabled(_ enabled: Bool) async throws {
        let preference = try historyService.syncPreference()
        preference.isICloudSyncEnabled = enabled
        preference.status = enabled ? .idle : .paused
        preference.lastSyncErrorDescription = nil
        try historyService.fetchContext().save()
    }

    func queueBatchIfNeeded(_ batchID: UUID) async {
        guard let preference = try? historyService.syncPreference(),
              preference.isICloudSyncEnabled else {
            return
        }

        guard let batch = try? historyService.fetchBatchForSync(id: batchID),
              batch.isLocalOnly == false,
              (try? historyService.cloudPublishableBatches().contains(where: { $0.id == batchID })) == true else {
            return
        }

        try? historyService.markBatchPublished(batchID: batchID)
        if let importSessionID = batch.importSessionID {
            try? historyService.markImportSessionPublishedIfNeeded(importSessionID)
        }
    }

    func syncNow() async {
        guard let preference = try? historyService.syncPreference(),
              preference.isICloudSyncEnabled else {
            return
        }
        preference.status = .idle
        preference.lastSyncAt = Date()
        preference.lastSyncErrorDescription = nil
        try? historyService.fetchContext().save()
    }

    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult {
        let result = try historyService.publishImportedChanges(for: sessionID)
        let session = try historyService.importSession(id: sessionID)
        for batchID in session?.importedBatchIDs ?? [] {
            try historyService.markBatchPublished(batchID: batchID)
        }
        try historyService.markImportSessionPublishedIfNeeded(sessionID)
        return result
    }
}

@MainActor
protocol CloudSyncEngineDriving: AnyObject {
    func addPendingDatabaseChanges(_ changes: [CKSyncEngine.PendingDatabaseChange])
    func addPendingRecordZoneChanges(_ changes: [CKSyncEngine.PendingRecordZoneChange])
    func sendAllChanges() async throws
    func fetchAllChanges() async throws
    func cancelOperations() async
}

@MainActor
final class LiveCloudSyncEngineDriver: CloudSyncEngineDriving {
    private let engine: CKSyncEngine

    init(engine: CKSyncEngine) {
        self.engine = engine
    }

    func addPendingDatabaseChanges(_ changes: [CKSyncEngine.PendingDatabaseChange]) {
        engine.state.add(pendingDatabaseChanges: changes)
    }

    func addPendingRecordZoneChanges(_ changes: [CKSyncEngine.PendingRecordZoneChange]) {
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    func sendAllChanges() async throws {
        try await engine.sendChanges(.init(scope: .all))
    }

    func fetchAllChanges() async throws {
        try await engine.fetchChanges(.init(scope: .all))
    }

    func cancelOperations() async {
        await engine.cancelOperations()
    }
}

@MainActor
final class CloudSyncCoordinator: NSObject, CloudSyncControlling, CKSyncEngineDelegate, @unchecked Sendable {
    private let historyService: SunclubHistoryService
    private let containerIdentifier: String
    private let cloudKitEntitlementProvider: SunclubCloudKitEntitlementProviding
    private let zoneID = CKRecordZone.ID(zoneName: "sunclub-history", ownerName: CKCurrentUserDefaultName)

    private var syncEngine: CKSyncEngine?
    private var syncEngineDriver: CloudSyncEngineDriving?
    private var hasQueuedZoneSave = false

    init(
        historyService: SunclubHistoryService,
        containerIdentifier: String = SunclubRuntimeConfiguration.cloudKitContainerIdentifier,
        cloudKitEntitlementProvider: SunclubCloudKitEntitlementProviding = CodeSignatureCloudKitEntitlementProvider(),
        syncEngineDriver: CloudSyncEngineDriving? = nil
    ) {
        self.historyService = historyService
        self.containerIdentifier = containerIdentifier
        self.cloudKitEntitlementProvider = cloudKitEntitlementProvider
        self.syncEngineDriver = syncEngineDriver
        super.init()
    }

    func start() async -> CloudSyncStartResult {
        do {
            let preference = try historyService.syncPreference()
            guard preference.isICloudSyncEnabled else {
                preference.status = .paused
                try historyService.fetchContext().save()
                return .skippedDisabled
            }

            let shouldRestoreFirst = try historyService.isEffectivelyEmptyForInitialICloudRestore()
            try configureEngineIfNeeded()
            preference.status = .syncing
            try historyService.fetchContext().save()

            if shouldRestoreFirst {
                try await fetchCloudChanges()
                try historyService.refreshProjectedState()

                if try !historyService.isEffectivelyEmptyForInitialICloudRestore() {
                    let queuedLocalChanges = try await queueAllUnpublishedBatches()
                    if queuedLocalChanges {
                        try await sendPendingChangesIfNeeded()
                    }
                    await finishSync()
                    return .restoredRemoteHistory
                }

                try ensureZoneSaveQueuedIfNeeded()
                try await queueAllUnpublishedBatches()
                try await sendPendingChangesIfNeeded()
                try await fetchCloudChanges()
                await finishSync()
                return .noRemoteHistory
            }

            try ensureZoneSaveQueuedIfNeeded()
            try await queueAllUnpublishedBatches()
            try await sendPendingChangesIfNeeded()
            try await fetchCloudChanges()
            await finishSync()
            return .noRemoteHistory
        } catch {
            await record(error: error, level: .warning)
            return .failed(Self.errorMessage(for: error))
        }
    }

    func setEnabled(_ enabled: Bool) async throws {
        let preference = try historyService.syncPreference()
        preference.isICloudSyncEnabled = enabled
        preference.status = enabled ? .idle : .paused
        preference.lastSyncErrorDescription = nil
        try historyService.fetchContext().save()

        if enabled {
            try configureEngineIfNeeded()
            try ensureZoneSaveQueuedIfNeeded()
            try await queueAllUnpublishedBatches()
            await syncNow()
        } else {
            await syncEngineDriver?.cancelOperations()
        }
    }

    func queueBatchIfNeeded(_ batchID: UUID) async {
        do {
            let preference = try historyService.syncPreference()
            guard preference.isICloudSyncEnabled else {
                return
            }
            guard try historyService.cloudPublishableBatches().contains(where: { $0.id == batchID }) else {
                return
            }

            try configureEngineIfNeeded()
            try enqueueBatch(batchID)
        } catch {
            await record(error: error, level: .warning)
        }
    }

    func syncNow() async {
        do {
            let preference = try historyService.syncPreference()
            guard preference.isICloudSyncEnabled else {
                return
            }

            preference.status = .syncing
            try ensureZoneSaveQueuedIfNeeded()
            try await queueAllUnpublishedBatches()
            try await sendPendingChangesIfNeeded()
            try await fetchCloudChanges()
            await finishSync()
        } catch {
            await record(error: error, level: .error)
        }
    }

    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult {
        let result = try historyService.publishImportedChanges(for: sessionID)
        let session = try historyService.importSession(id: sessionID)
        for sessionBatchID in session?.importedBatchIDs ?? [] {
            try enqueueBatch(sessionBatchID)
        }
        await syncNow()
        try historyService.markImportSessionPublishedIfNeeded(sessionID)
        return result
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case let .stateUpdate(update):
            await persist(stateSerialization: update.stateSerialization)
        case let .sentRecordZoneChanges(changes):
            await handleSentRecordZoneChanges(changes)
        case let .fetchedRecordZoneChanges(changes):
            await handleFetchedRecordZoneChanges(changes.modifications)
        case let .accountChange(change):
            await handleAccountChange(change)
        case let .didFetchChanges(changes):
            await finishSync()
            await record(
                message: "Fetched CloudKit changes (\(changes.context.reason)).",
                level: .info
            )
        case let .didSendChanges(changes):
            await record(
                message: "Sent CloudKit changes (\(changes.context.reason)).",
                level: .info
            )
        case let .sentDatabaseChanges(changes):
            await handleSentDatabaseChanges(changes)
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges.filter {
            context.options.scope.contains($0)
        }
        guard !pendingChanges.isEmpty else {
            return nil
        }

        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: pendingChanges,
            recordProvider: { [weak self] recordID in
                await self?.recordForCloudKit(recordID)
            }
        )
    }

    func nextFetchChangesOptions(
        _ context: CKSyncEngine.FetchChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.FetchChangesOptions {
        .init(scope: .all)
    }

    private func configureEngineIfNeeded() throws {
        guard syncEngineDriver == nil else {
            return
        }

        try SunclubCloudKitAvailability.validateRuntime(
            containerIdentifier: containerIdentifier,
            entitlementProvider: cloudKitEntitlementProvider
        )
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: try currentStateSerialization(),
            delegate: self
        )
        let engine = CKSyncEngine(configuration)
        syncEngine = engine
        syncEngineDriver = LiveCloudSyncEngineDriver(engine: engine)
    }

    private func configuredEngineDriver() throws -> CloudSyncEngineDriving {
        try configureEngineIfNeeded()
        guard let syncEngineDriver else {
            throw CloudSyncError.engineUnavailable
        }
        return syncEngineDriver
    }

    private func currentStateSerialization() throws -> CKSyncEngine.State.Serialization? {
        guard let data = try historyService.cloudSyncState().stateSerializationData else {
            return nil
        }
        return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func enqueueBatch(_ batchID: UUID) throws {
        let driver = try configuredEngineDriver()
        try ensureZoneSaveQueuedIfNeeded()

        let batchRecordID = Self.recordID(for: .batch(batchID), zoneID: zoneID)
        driver.addPendingRecordZoneChanges([.saveRecord(batchRecordID)])

        guard try historyService.fetchBatchForSync(id: batchID) != nil else {
            return
        }

        let recordRevisionPredicate = #Predicate<DailyRecordRevision> { $0.batchID == batchID }
        let recordDescriptors = try historyService.fetchContext().fetch(FetchDescriptor(predicate: recordRevisionPredicate))
        for revision in recordDescriptors {
            driver.addPendingRecordZoneChanges([
                .saveRecord(Self.recordID(for: .recordRevision(revision.id), zoneID: zoneID))
            ])
        }

        let settingsRevisionPredicate = #Predicate<SettingsRevision> { $0.batchID == batchID }
        let settingsDescriptors = try historyService.fetchContext().fetch(FetchDescriptor(predicate: settingsRevisionPredicate))
        for revision in settingsDescriptors {
            driver.addPendingRecordZoneChanges([
                .saveRecord(Self.recordID(for: .settingsRevision(revision.id), zoneID: zoneID))
            ])
        }
    }

    @discardableResult
    private func queueAllUnpublishedBatches() async throws -> Bool {
        let batches = try historyService.cloudPublishableBatches()
        for batch in batches {
            try enqueueBatch(batch.id)
        }
        return !batches.isEmpty
    }

    private func ensureZoneSaveQueuedIfNeeded() throws {
        guard !hasQueuedZoneSave else {
            return
        }
        let driver = try configuredEngineDriver()
        driver.addPendingDatabaseChanges([.saveZone(CKRecordZone(zoneID: zoneID))])
        hasQueuedZoneSave = true
    }

    private func sendPendingChangesIfNeeded() async throws {
        try await configuredEngineDriver().sendAllChanges()
    }

    private func fetchCloudChanges() async throws {
        try await configuredEngineDriver().fetchAllChanges()
    }

    private func recordForCloudKit(_ recordID: CKRecord.ID) async -> CKRecord? {
        do {
            let target = try Self.recordTarget(for: recordID.recordName)
            switch target {
            case let .batch(batchID):
                guard let batch = try historyService.fetchBatchForSync(id: batchID) else {
                    return nil
                }
                let record = CKRecord(recordType: "ChangeBatch", recordID: recordID)
                record["payload"] = try JSONEncoder().encode(BatchWire(batch: batch)) as NSData
                return record
            case let .recordRevision(revisionID):
                guard let revision = try historyService.fetchRecordRevisionForSync(id: revisionID) else {
                    return nil
                }
                let record = CKRecord(recordType: "DailyRecordRevision", recordID: recordID)
                record["payload"] = try JSONEncoder().encode(RecordRevisionWire(revision: revision)) as NSData
                return record
            case let .settingsRevision(revisionID):
                guard let revision = try historyService.fetchSettingsRevisionForSync(id: revisionID) else {
                    return nil
                }
                let record = CKRecord(recordType: "SettingsRevision", recordID: recordID)
                record["payload"] = try JSONEncoder().encode(SettingsRevisionWire(revision: revision)) as NSData
                return record
            }
        } catch {
            await record(error: error, level: .warning)
            return nil
        }
    }

    private func handleSentRecordZoneChanges(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) async {
        do {
            try await handleFailedRecordSaves(changes.failedRecordSaves)
            var touchedImportSessionIDs = Set<UUID>()
            for record in changes.savedRecords {
                switch try Self.recordTarget(for: record.recordID.recordName) {
                case let .batch(batchID):
                    let batch = try historyService.fetchBatchForSync(id: batchID)
                    if let importSessionID = batch?.importSessionID {
                        touchedImportSessionIDs.insert(importSessionID)
                    }
                    try historyService.markBatchPublished(batchID: batchID)
                case .recordRevision, .settingsRevision:
                    break
                }
            }
            for sessionID in touchedImportSessionIDs {
                try historyService.markImportSessionPublishedIfNeeded(sessionID)
            }
            await finishSync()
        } catch {
            await record(error: error, level: .warning)
        }
    }

    private func handleSentDatabaseChanges(_ changes: CKSyncEngine.Event.SentDatabaseChanges) async {
        if changes.failedZoneSaves.isEmpty {
            hasQueuedZoneSave = false
            return
        }

        hasQueuedZoneSave = false
        for failure in changes.failedZoneSaves {
            await record(message: Self.errorMessage(for: failure.error), level: .warning)
        }
    }

    private func handleFailedRecordSaves(
        _ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave]
    ) async throws {
        for failure in failures {
            try await recoverFailedRecordSave(recordID: failure.record.recordID, error: failure.error)
        }
    }

    func recoverFailedRecordSave(recordID: CKRecord.ID, error: Error) async throws {
        switch Self.sendFailureRecoveryAction(for: error) {
        case .requeueZoneAndFetch:
            hasQueuedZoneSave = false
            try ensureZoneSaveQueuedIfNeeded()
            try configuredEngineDriver().addPendingRecordZoneChanges([.saveRecord(recordID)])
            try await fetchCloudChanges()
        case .fetchRemote:
            try await fetchCloudChanges()
        case .recordOnly:
            await record(message: Self.errorMessage(for: error), level: .warning)
        }
    }

    private func handleFetchedRecordZoneChanges(
        _ modifications: [CKDatabase.RecordZoneChange.Modification]
    ) async {
        var unresolvedFailures = loadUnresolvedRecordFailures()

        for modification in modifications {
            let cloudRecord = modification.record
            guard cloudRecord.recordID.zoneID == zoneID else {
                continue
            }

            guard let payload = cloudRecord["payload"] as? Data else {
                guard Self.isHistoryRecordType(cloudRecord.recordType) else {
                    continue
                }
                let message = "Missing history payload."
                unresolvedFailures[cloudRecord.recordID.recordName] = CloudSyncRecordFailure(
                    recordName: cloudRecord.recordID.recordName,
                    message: message
                )
                await record(
                    message: "Skipped invalid CloudKit record \(cloudRecord.recordID.recordName): \(message)",
                    level: .warning
                )
                continue
            }

            do {
                try applyFetchedRecord(cloudRecord, payload: payload)
                unresolvedFailures.removeValue(forKey: cloudRecord.recordID.recordName)
            } catch {
                let message = Self.errorMessage(for: error)
                unresolvedFailures[cloudRecord.recordID.recordName] = CloudSyncRecordFailure(
                    recordName: cloudRecord.recordID.recordName,
                    message: message
                )
                await record(
                    message: "Skipped invalid CloudKit record \(cloudRecord.recordID.recordName): \(message)",
                    level: .warning
                )
            }
        }

        do {
            try persistUnresolvedRecordFailures(unresolvedFailures)
            try historyService.refreshProjectedState()
            await finishSync()
        } catch {
            await record(error: error, level: .warning)
        }
    }

    private func applyFetchedRecord(_ record: CKRecord, payload: Data) throws {
        switch record.recordType {
        case "ChangeBatch":
            var wire = try JSONDecoder().decode(BatchWire.self, from: payload)
            wire.serverReceivedAt = record.modificationDate
            try historyService.upsertRemoteBatch(wire)
        case "DailyRecordRevision":
            var wire = try JSONDecoder().decode(RecordRevisionWire.self, from: payload)
            wire.serverReceivedAt = record.modificationDate
            try historyService.upsertRemoteRecordRevision(wire)
        case "SettingsRevision":
            var wire = try JSONDecoder().decode(SettingsRevisionWire.self, from: payload)
            wire.serverReceivedAt = record.modificationDate
            try historyService.upsertRemoteSettingsRevision(wire)
        default:
            break
        }
    }

    func applyFetchedRecordsForTesting(_ records: [CKRecord]) async {
        var unresolvedFailures = loadUnresolvedRecordFailures()

        for record in records where record.recordID.zoneID == zoneID {
            guard let payload = record["payload"] as? Data else {
                guard Self.isHistoryRecordType(record.recordType) else {
                    continue
                }
                unresolvedFailures[record.recordID.recordName] = CloudSyncRecordFailure(
                    recordName: record.recordID.recordName,
                    message: "Missing history payload."
                )
                continue
            }
            do {
                try applyFetchedRecord(record, payload: payload)
                unresolvedFailures.removeValue(forKey: record.recordID.recordName)
            } catch {
                let message = Self.errorMessage(for: error)
                unresolvedFailures[record.recordID.recordName] = CloudSyncRecordFailure(
                    recordName: record.recordID.recordName,
                    message: message
                )
            }
        }

        do {
            try persistUnresolvedRecordFailures(unresolvedFailures)
            try historyService.refreshProjectedState()
            await finishSync()
        } catch {
            await record(error: error, level: .warning)
        }
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) async {
        do {
            let preference = try historyService.syncPreference()
            switch change.changeType {
            case .signIn, .switchAccounts:
                preference.status = .idle
                preference.lastSyncErrorDescription = nil
            case .signOut:
                preference.status = .paused
                preference.lastSyncErrorDescription = "Sign in to iCloud again to resume sync."
            @unknown default:
                preference.status = .error
                preference.lastSyncErrorDescription = "Sunclub detected an unknown iCloud account change."
            }
            try historyService.fetchContext().save()
        } catch {
            await record(error: error, level: .warning)
        }
    }

    private func persist(stateSerialization: CKSyncEngine.State.Serialization) async {
        do {
            let state = try historyService.cloudSyncState()
            state.stateSerializationData = try JSONEncoder().encode(stateSerialization)
            try historyService.fetchContext().save()
        } catch {
            await record(error: error, level: .warning)
        }
    }

    private func finishSync() async {
        do {
            let preference = try historyService.syncPreference()
            let unresolvedFailures = loadUnresolvedRecordFailures()
            preference.status = unresolvedFailures.isEmpty
                ? (preference.isICloudSyncEnabled ? .idle : .paused)
                : .error
            preference.lastSyncAt = Date()
            if unresolvedFailures.isEmpty {
                preference.lastSyncErrorDescription = nil
            } else {
                let count = unresolvedFailures.count
                let noun = count == 1 ? "record" : "records"
                preference.lastSyncErrorDescription = "iCloud sync skipped \(count) invalid \(noun). Sunclub kept the rest of your history and will retry corrected records."
            }
            try historyService.fetchContext().save()
        } catch {
            await record(error: error, level: .warning)
        }
    }

    private func loadUnresolvedRecordFailures() -> [String: CloudSyncRecordFailure] {
        guard let data = try? historyService.cloudSyncState().unresolvedCloudRecordFailuresData,
              let failures = try? JSONDecoder().decode([CloudSyncRecordFailure].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: failures.map { ($0.recordName, $0) })
    }

    private func persistUnresolvedRecordFailures(
        _ failures: [String: CloudSyncRecordFailure]
    ) throws {
        let state = try historyService.cloudSyncState()
        state.unresolvedCloudRecordFailuresData = failures.isEmpty
            ? nil
            : try JSONEncoder().encode(failures.values.sorted { $0.recordName < $1.recordName })
        try historyService.fetchContext().save()
    }

    private static func isHistoryRecordType(_ recordType: String) -> Bool {
        recordType == "ChangeBatch"
            || recordType == "DailyRecordRevision"
            || recordType == "SettingsRevision"
    }

    private func record(error: Error, level: CloudSyncDiagnosticLevel) async {
        let message = Self.errorMessage(for: error)
        await record(message: message, level: level)
        do {
            let preference = try historyService.syncPreference()
            preference.status = .error
            preference.lastSyncErrorDescription = message
            try historyService.fetchContext().save()
        } catch {
            // Ignore nested persistence failures.
        }
    }

    private func record(message: String, level: CloudSyncDiagnosticLevel) async {
        do {
            let diagnostic = CloudSyncDiagnostic(level: level, message: message)
            historyService.fetchContext().insert(diagnostic)
            try historyService.fetchContext().save()
        } catch {
            // Ignore diagnostics failures.
        }
    }

    enum SendFailureRecoveryAction: Equatable {
        case requeueZoneAndFetch
        case fetchRemote
        case recordOnly
    }

    nonisolated static func sendFailureRecoveryAction(for error: Error) -> SendFailureRecoveryAction {
        guard let cloudError = error as? CKError else {
            return .recordOnly
        }

        switch cloudError.code {
        case .zoneNotFound, .unknownItem:
            return .requeueZoneAndFetch
        case .serverRecordChanged:
            return .fetchRemote
        default:
            return .recordOnly
        }
    }

    private static func errorMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private enum RecordTarget {
        case batch(UUID)
        case recordRevision(UUID)
        case settingsRevision(UUID)
    }

    private static func recordID(for target: RecordTarget, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        switch target {
        case let .batch(id):
            return CKRecord.ID(recordName: "batch.\(id.uuidString)", zoneID: zoneID)
        case let .recordRevision(id):
            return CKRecord.ID(recordName: "record-revision.\(id.uuidString)", zoneID: zoneID)
        case let .settingsRevision(id):
            return CKRecord.ID(recordName: "settings-revision.\(id.uuidString)", zoneID: zoneID)
        }
    }

    private static func recordTarget(for recordName: String) throws -> RecordTarget {
        if let id = UUID(uuidString: recordName.replacingOccurrences(of: "batch.", with: "")),
           recordName.hasPrefix("batch.") {
            return .batch(id)
        }

        if let id = UUID(uuidString: recordName.replacingOccurrences(of: "record-revision.", with: "")),
           recordName.hasPrefix("record-revision.") {
            return .recordRevision(id)
        }

        if let id = UUID(uuidString: recordName.replacingOccurrences(of: "settings-revision.", with: "")),
           recordName.hasPrefix("settings-revision.") {
            return .settingsRevision(id)
        }

        throw CloudSyncError.invalidRecordName
    }
}

enum CloudSyncError: LocalizedError {
    case engineUnavailable
    case invalidRecordName

    var errorDescription: String? {
        switch self {
        case .engineUnavailable:
            return "Sunclub couldn't start iCloud sync."
        case .invalidRecordName:
            return "Sunclub received an invalid CloudKit record."
        }
    }
}
