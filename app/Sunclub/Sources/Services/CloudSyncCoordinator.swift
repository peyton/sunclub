import CloudKit
import Foundation
import SwiftData

@MainActor
protocol CloudSyncControlling: AnyObject {
    func start() async
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

    func start() async {
        guard let preference = try? historyService.syncPreference() else {
            return
        }
        preference.status = preference.isICloudSyncEnabled ? .idle : .paused
        try? historyService.fetchContext().save()
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
              batch.isLocalOnly == false else {
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
final class CloudSyncCoordinator: NSObject, CloudSyncControlling, CKSyncEngineDelegate, @unchecked Sendable {
    private let historyService: SunclubHistoryService
    private let containerIdentifier: String
    private let zoneID = CKRecordZone.ID(zoneName: "sunclub-history", ownerName: CKCurrentUserDefaultName)

    private var syncEngine: CKSyncEngine?
    private var hasQueuedZoneSave = false

    init(
        historyService: SunclubHistoryService,
        containerIdentifier: String = "iCloud.app.peyton.sunclub"
    ) {
        self.historyService = historyService
        self.containerIdentifier = containerIdentifier
        super.init()
    }

    func start() async {
        do {
            let preference = try historyService.syncPreference()
            guard preference.isICloudSyncEnabled else {
                preference.status = .paused
                try historyService.fetchContext().save()
                return
            }

            try configureEngineIfNeeded()
            try await queueAllUnpublishedBatches()
            await syncNow()
        } catch {
            await record(error: error, level: .warning)
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
            try await queueAllUnpublishedBatches()
            await syncNow()
        } else {
            await syncEngine?.cancelOperations()
        }
    }

    func queueBatchIfNeeded(_ batchID: UUID) async {
        do {
            let preference = try historyService.syncPreference()
            guard preference.isICloudSyncEnabled else {
                return
            }
            guard let batch = try historyService.fetchBatchForSync(id: batchID),
                  !batch.isLocalOnly else {
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
            let engine = try configuredEngine()
            try await engine.sendChanges(.init(scope: .all))
            try await engine.fetchChanges(.init(scope: .all))
            preference.status = .idle
            preference.lastSyncAt = Date()
            preference.lastSyncErrorDescription = nil
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
            await handleSentRecordZoneChanges(changes.savedRecords)
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
            hasQueuedZoneSave = changes.failedZoneSaves.isEmpty
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
        guard syncEngine == nil else {
            return
        }

        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: try currentStateSerialization(),
            delegate: self
        )
        let engine = CKSyncEngine(configuration)
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        hasQueuedZoneSave = true
        syncEngine = engine
    }

    private func configuredEngine() throws -> CKSyncEngine {
        try configureEngineIfNeeded()
        guard let syncEngine else {
            throw CloudSyncError.engineUnavailable
        }
        return syncEngine
    }

    private func currentStateSerialization() throws -> CKSyncEngine.State.Serialization? {
        guard let data = try historyService.cloudSyncState().stateSerializationData else {
            return nil
        }
        return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func enqueueBatch(_ batchID: UUID) throws {
        let engine = try configuredEngine()
        if !hasQueuedZoneSave {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            hasQueuedZoneSave = true
        }

        let batchRecordID = Self.recordID(for: .batch(batchID), zoneID: zoneID)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(batchRecordID)])

        guard try historyService.fetchBatchForSync(id: batchID) != nil else {
            return
        }

        let recordRevisionPredicate = #Predicate<DailyRecordRevision> { $0.batchID == batchID }
        let recordDescriptors = try historyService.fetchContext().fetch(FetchDescriptor(predicate: recordRevisionPredicate))
        for revision in recordDescriptors {
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID(for: .recordRevision(revision.id), zoneID: zoneID))])
        }

        let settingsRevisionPredicate = #Predicate<SettingsRevision> { $0.batchID == batchID }
        let settingsDescriptors = try historyService.fetchContext().fetch(FetchDescriptor(predicate: settingsRevisionPredicate))
        for revision in settingsDescriptors {
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.recordID(for: .settingsRevision(revision.id), zoneID: zoneID))])
        }
    }

    private func queueAllUnpublishedBatches() async throws {
        let predicate = #Predicate<SunclubChangeBatch> {
            !$0.isLocalOnly && !$0.isPublishedToCloud
        }
        let batches = try historyService.fetchContext().fetch(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        for batch in batches {
            try enqueueBatch(batch.id)
        }
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

    private func handleSentRecordZoneChanges(_ records: [CKRecord]) async {
        do {
            var touchedImportSessionIDs = Set<UUID>()
            for record in records {
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

    private func handleFetchedRecordZoneChanges(
        _ modifications: [CKDatabase.RecordZoneChange.Modification]
    ) async {
        do {
            for modification in modifications {
                guard modification.record.recordID.zoneID == zoneID,
                      let payload = modification.record["payload"] as? Data else {
                    continue
                }

                switch modification.record.recordType {
                case "ChangeBatch":
                    try historyService.upsertRemoteBatch(try JSONDecoder().decode(BatchWire.self, from: payload))
                case "DailyRecordRevision":
                    try historyService.upsertRemoteRecordRevision(try JSONDecoder().decode(RecordRevisionWire.self, from: payload))
                case "SettingsRevision":
                    try historyService.upsertRemoteSettingsRevision(try JSONDecoder().decode(SettingsRevisionWire.self, from: payload))
                default:
                    break
                }
            }
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
            preference.status = preference.isICloudSyncEnabled ? .idle : .paused
            preference.lastSyncAt = Date()
            preference.lastSyncErrorDescription = nil
            try historyService.fetchContext().save()
        } catch {
            await record(error: error, level: .warning)
        }
    }

    private func record(error: Error, level: CloudSyncDiagnosticLevel) async {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

struct BatchWire: Codable {
    let id: UUID
    let createdAt: Date
    let kindRawValue: String
    let scopeRawValue: String
    let scopeIdentifier: String
    let authorDeviceID: String
    let summary: String
    let inverseOfBatchID: UUID?
    let undoneByBatchID: UUID?

    init(batch: SunclubChangeBatch) {
        id = batch.id
        createdAt = batch.createdAt
        kindRawValue = batch.kindRawValue
        scopeRawValue = batch.scopeRawValue
        scopeIdentifier = batch.scopeIdentifier
        authorDeviceID = batch.authorDeviceID
        summary = batch.summary
        inverseOfBatchID = batch.inverseOfBatchID
        undoneByBatchID = batch.undoneByBatchID
    }
}

struct RecordRevisionWire: Codable {
    let id: UUID
    let batchID: UUID
    let createdAt: Date
    let authorDeviceID: String
    let startOfDay: Date
    let isDeleted: Bool
    let verifiedAt: Date?
    let methodRawValue: Int?
    let verificationDuration: Double?
    let spfLevel: Int?
    let notes: String?
    let reapplyCount: Int
    let lastReappliedAt: Date?
    let changedFields: [String]
    let batchKindRawValue: String

    init(revision: DailyRecordRevision) {
        id = revision.id
        batchID = revision.batchID
        createdAt = revision.createdAt
        authorDeviceID = revision.authorDeviceID
        startOfDay = revision.startOfDay
        isDeleted = revision.isDeleted
        verifiedAt = revision.verifiedAt
        methodRawValue = revision.methodRawValue
        verificationDuration = revision.verificationDuration
        spfLevel = revision.spfLevel
        notes = revision.notes
        reapplyCount = revision.reapplyCount
        lastReappliedAt = revision.lastReappliedAt
        changedFields = revision.changedFields.map(\.rawValue).sorted()
        batchKindRawValue = revision.batchKindRawValue
    }
}

struct SettingsRevisionWire: Codable {
    let id: UUID
    let batchID: UUID
    let createdAt: Date
    let authorDeviceID: String
    let snapshot: SettingsProjectionSnapshot
    let changedFields: [String]
    let batchKindRawValue: String

    init(revision: SettingsRevision) {
        id = revision.id
        batchID = revision.batchID
        createdAt = revision.createdAt
        authorDeviceID = revision.authorDeviceID
        snapshot = revision.snapshot
        changedFields = revision.changedFields.map(\.rawValue).sorted()
        batchKindRawValue = revision.batchKindRawValue
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
