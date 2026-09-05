import Foundation
import SwiftData

struct SunclubImportResult: Equatable {
    let importedBatchCount: Int
    let importSessionID: UUID
    let restorePointBatchID: UUID
}

struct CloudPublishResult: Equatable, Sendable {
    let importSessionID: UUID
    let publishedBatchCount: Int
}

@MainActor
final class SunclubHistoryService {
    private let context: ModelContext
    private let calendar: Calendar
    private let mutationGuard: () throws -> Void

    init(
        context: ModelContext,
        calendar: Calendar = .current,
        mutationGuard: @escaping () throws -> Void = {}
    ) {
        self.context = context
        self.calendar = calendar
        self.mutationGuard = mutationGuard
    }

    func fetchContext() -> ModelContext {
        context
    }

    func bootstrapIfNeeded() throws {
        let settings = try loadOrCreateSettings()
        let preference = try loadOrCreateSyncPreference()
        _ = try loadOrCreateCloudSyncState()
        let records = try context.fetch(FetchDescriptor<DailyRecord>())

        let existingBatchCount = try context.fetch(FetchDescriptor<SunclubChangeBatch>()).count
        if existingBatchCount == 0 {
            let isEmptyDefaultSeed = Self.isDefaultSettingsSnapshot(settings.projectionSnapshot) && records.isEmpty
            let batch = SunclubChangeBatch(
                logicalOrder: try nextLogicalOrder(),
                kind: .migrationSeed,
                scope: .timeline,
                scopeIdentifier: "timeline",
                authorDeviceID: preference.deviceID,
                summary: "Initialized Sunclub history.",
                isLocalOnly: isEmptyDefaultSeed
            )
            context.insert(batch)
            context.insert(
                SettingsRevision(
                    batch: batch,
                    snapshot: settings.projectionSnapshot,
                    changedFields: Self.allSettingsFields
                )
            )

            for record in records {
                context.insert(
                    DailyRecordRevision(
                        batch: batch,
                        snapshot: record.projectionSnapshot,
                        changedFields: Self.allRecordFields
                    )
                )
            }
            try context.save()
        }

        try rebuildProjections()
    }

    func refreshProjectedState() throws {
        try seedProjectedRowsIntoHistoryIfNeeded()
        try rebuildProjections()
    }

    func record(for day: Date) throws -> DailyRecord? {
        let targetDay = calendar.startOfDay(for: day)
        let predicate = #Predicate<DailyRecord> { $0.startOfDay == targetDay }
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startOfDay, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    func records() throws -> [DailyRecord] {
        try context.fetch(
            FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .reverse)])
        )
    }

    func settings() throws -> Settings {
        try loadOrCreateSettings()
    }

    func syncPreference() throws -> CloudSyncPreference {
        try loadOrCreateSyncPreference()
    }

    func cloudSyncState() throws -> CloudSyncState {
        try loadOrCreateCloudSyncState()
    }

    func isEffectivelyEmptyForInitialICloudRestore() throws -> Bool {
        if try !records().isEmpty {
            return false
        }

        if !Self.isDefaultSettingsSnapshot(try settings().projectionSnapshot) {
            return false
        }

        let batches = try context.fetch(FetchDescriptor<SunclubChangeBatch>())
        for batch in batches where try !isSyntheticEmptyDefaultBatch(batch) {
            return false
        }

        return true
    }

    func cloudPublishableBatches() throws -> [SunclubChangeBatch] {
        let predicate = #Predicate<SunclubChangeBatch> {
            !$0.isLocalOnly && !$0.isPublishedToCloud
        }
        let batches = try context.fetch(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        return try batches.filter { try !isSyntheticEmptyDefaultBatch($0) }
    }

    func changeBatches(limit: Int = 50) throws -> [SunclubChangeBatch] {
        var descriptor = FetchDescriptor<SunclubChangeBatch>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func importSessions(limit: Int = 10) throws -> [SunclubImportSession] {
        var descriptor = FetchDescriptor<SunclubImportSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func hasImportSession(sourceDescriptionPrefix: String) throws -> Bool {
        let sessions = try context.fetch(FetchDescriptor<SunclubImportSession>())
        return sessions.contains { $0.sourceDescription.hasPrefix(sourceDescriptionPrefix) }
    }

    func importSession(id: UUID) throws -> SunclubImportSession? {
        let predicate = #Predicate<SunclubImportSession> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    func unresolvedConflicts() throws -> [SunclubConflictItem] {
        let predicate = #Predicate<SunclubConflictItem> { $0.resolvedAt == nil }
        return try context.fetch(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
    }

    func conflict(for day: Date) throws -> SunclubConflictItem? {
        let scopeIdentifier = Self.scopeIdentifier(for: calendar.startOfDay(for: day))
        let predicate = #Predicate<SunclubConflictItem> {
            $0.scopeIdentifier == scopeIdentifier && $0.resolvedAt == nil
        }
        return try context.fetch(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).first
    }

    @discardableResult
    func applySettingsChange(
        kind: SunclubChangeKind,
        summary: String,
        changedFields: Set<SunclubTrackedField>,
        isLocalOnly: Bool = false,
        mutate: (inout SettingsProjectionSnapshot) -> Void
    ) throws -> SunclubChangeBatch? {
        var snapshot = try loadOrCreateSettings().projectionSnapshot
        let previous = snapshot
        mutate(&snapshot)
        guard snapshot != previous else {
            return nil
        }

        var createdBatch: SunclubChangeBatch?
        do {
            try context.transaction {
                let batch = try createBatch(
                    kind: kind,
                    scope: .settings,
                    scopeIdentifier: "settings",
                    summary: summary,
                    isLocalOnly: isLocalOnly
                )
                context.insert(SettingsRevision(batch: batch, snapshot: snapshot, changedFields: changedFields))
                try rebuildProjections(savingChanges: false)
                try mutationGuard()
                createdBatch = batch
            }
        } catch {
            rollbackAndRestoreProjections()
            throw error
        }
        return createdBatch
    }

    @discardableResult
    func applyDayChange(
        for day: Date,
        kind: SunclubChangeKind,
        summary: String,
        changedFields: Set<SunclubTrackedField>,
        isLocalOnly: Bool = false,
        mutate: (DailyRecordProjectionSnapshot?) -> DailyRecordProjectionSnapshot?
    ) throws -> SunclubChangeBatch? {
        let targetDay = calendar.startOfDay(for: day)
        let existingSnapshot = try record(for: targetDay)?.projectionSnapshot
        let nextSnapshot = mutate(existingSnapshot)

        if nextSnapshot == existingSnapshot {
            return nil
        }

        var createdBatch: SunclubChangeBatch?
        do {
            try context.transaction {
                let batch = try createBatch(
                    kind: kind,
                    scope: .day,
                    scopeIdentifier: Self.scopeIdentifier(for: targetDay),
                    summary: summary,
                    isLocalOnly: isLocalOnly
                )

                if let nextSnapshot {
                    context.insert(
                        DailyRecordRevision(
                            batch: batch,
                            snapshot: nextSnapshot,
                            changedFields: changedFields
                        )
                    )
                } else {
                    context.insert(
                        DailyRecordRevision(
                            deletedDay: targetDay,
                            batch: batch,
                            changedFields: changedFields.union([.isDeleted])
                        )
                    )
                }

                try rebuildProjections(savingChanges: false)
                try mutationGuard()
                createdBatch = batch
            }
        } catch {
            rollbackAndRestoreProjections()
            throw error
        }
        return createdBatch
    }

    @discardableResult
    func deleteAllRecords() throws -> SunclubChangeBatch? {
        let currentRecords = try records()
        guard !currentRecords.isEmpty else {
            return nil
        }

        var createdBatch: SunclubChangeBatch?
        do {
            try context.transaction {
                let batch = try createBatch(
                    kind: .deleteRecord,
                    scope: .timeline,
                    scopeIdentifier: "timeline",
                    summary: "Deleted all sunscreen history."
                )
                for record in currentRecords {
                    context.insert(
                        DailyRecordRevision(
                            deletedDay: calendar.startOfDay(for: record.startOfDay),
                            batch: batch,
                            changedFields: Self.allRecordFields.union([.isDeleted])
                        )
                    )
                }

                try rebuildProjections(savingChanges: false)
                try mutationGuard()
                createdBatch = batch
            }
        } catch {
            rollbackAndRestoreProjections()
            throw error
        }
        return createdBatch
    }

    @discardableResult
    func createRestorePoint(summary: String) throws -> SunclubChangeBatch {
        let batch = try createBatch(
            kind: .importRestorePoint,
            scope: .timeline,
            scopeIdentifier: "timeline",
            summary: summary,
            isLocalOnly: true
        )

        let settings = try loadOrCreateSettings()
        context.insert(
            SettingsRevision(
                batch: batch,
                snapshot: settings.projectionSnapshot,
                changedFields: Self.allSettingsFields
            )
        )

        for record in try records() {
            context.insert(
                DailyRecordRevision(
                    batch: batch,
                    snapshot: record.projectionSnapshot,
                    changedFields: Self.allRecordFields
                )
            )
        }

        try context.save()
        return batch
    }

    @discardableResult
    func importDomainData(
        from importedContext: ModelContext,
        sourceDescription: String
    ) throws -> SunclubImportResult {
        try bootstrapIfNeeded()

        let restorePoint = try createRestorePoint(summary: "Saved state before local backup import.")
        let session = SunclubImportSession(
            sourceDescription: sourceDescription,
            restorePointBatchID: restorePoint.id
        )
        context.insert(session)

        let importedDomain = try ImportedDomainSnapshot(context: importedContext)
        var importedBatchIDs = try cloneImportedBatches(importedDomain.batches, sessionID: session.id)
        try cloneImportedRecordRevisions(importedDomain.recordRevisions)
        try cloneImportedSettingsRevisions(importedDomain.settingsRevisions)

        let importBatch = try applyImportedProjectedState(
            projectedSettings: importedDomain.projectedSettings,
            projectedRecords: importedDomain.projectedRecords,
            sessionID: session.id
        )
        importedBatchIDs.append(importBatch.id)

        session.setImportedBatchIDs(importedBatchIDs)
        try context.save()
        try rebuildProjections()

        return SunclubImportResult(
            importedBatchCount: importedBatchIDs.count,
            importSessionID: session.id,
            restorePointBatchID: restorePoint.id
        )
    }

    @discardableResult
    func recoverLegacyDomainData(
        from importedContext: ModelContext,
        sourceDescription: String
    ) throws -> SunclubImportResult? {
        try bootstrapIfNeeded()

        guard try hasImportSession(sourceDescriptionPrefix: sourceDescription) == false else {
            return nil
        }

        let importedHistoryService = SunclubHistoryService(context: importedContext, calendar: calendar)
        try importedHistoryService.refreshProjectedState()
        let importedDomain = try ImportedDomainSnapshot(context: importedContext)
        guard Self.isMeaningfulRecovery(
            settings: importedDomain.projectedSettings?.projectionSnapshot,
            records: importedDomain.projectedRecords
        ) else {
            return nil
        }

        let recoveryPlan = try recoveredProjectedState(
            projectedSettings: importedDomain.projectedSettings,
            projectedRecords: importedDomain.projectedRecords
        )
        guard recoveryPlan.hasChanges else {
            return nil
        }

        let restorePoint = try createRestorePoint(summary: "Saved state before legacy store recovery.")
        let session = SunclubImportSession(
            sourceDescription: sourceDescription,
            restorePointBatchID: restorePoint.id
        )
        context.insert(session)

        let recoveryBatch = try createBatch(
            kind: .legacyStoreRecovery,
            scope: .timeline,
            scopeIdentifier: "timeline",
            summary: "Recovered data from the pre-entitlement local store.",
            isLocalOnly: true,
            importSessionID: session.id
        )

        if let recoveredSettings = recoveryPlan.settings {
            context.insert(
                SettingsRevision(
                    batch: recoveryBatch,
                    snapshot: recoveredSettings,
                    changedFields: Self.allSettingsFields
                )
            )
        }

        for record in recoveryPlan.records {
            context.insert(
                DailyRecordRevision(
                    batch: recoveryBatch,
                    snapshot: record.projectionSnapshot,
                    changedFields: Self.allRecordFields
                )
            )
        }

        session.setImportedBatchIDs([recoveryBatch.id])
        try context.save()
        try rebuildProjections()

        return SunclubImportResult(
            importedBatchCount: 1,
            importSessionID: session.id,
            restorePointBatchID: restorePoint.id
        )
    }

    private func cloneImportedBatches(
        _ importedBatches: [SunclubChangeBatch],
        sessionID: UUID
    ) throws -> [UUID] {
        let existingBatchIDs = Set(try context.fetch(FetchDescriptor<SunclubChangeBatch>()).map(\.id))
        var importedBatchIDs: [UUID] = []

        for batch in importedBatches where !existingBatchIDs.contains(batch.id) {
            let clone = SunclubChangeBatch(
                id: batch.id,
                createdAt: batch.createdAt,
                logicalOrder: batch.logicalOrder,
                serverReceivedAt: batch.serverReceivedAt,
                kind: batch.kind,
                scope: batch.scope,
                scopeIdentifier: batch.scopeIdentifier,
                authorDeviceID: batch.authorDeviceID,
                summary: batch.summary,
                isLocalOnly: true,
                isPublishedToCloud: false,
                cloudPublishedAt: nil,
                inverseOfBatchID: batch.inverseOfBatchID,
                undoneByBatchID: batch.undoneByBatchID,
                importSessionID: sessionID
            )
            context.insert(clone)
            importedBatchIDs.append(clone.id)
        }

        return importedBatchIDs
    }

    private func cloneImportedRecordRevisions(_ importedRevisions: [DailyRecordRevision]) throws {
        let existingRevisionIDs = Set(try context.fetch(FetchDescriptor<DailyRecordRevision>()).map(\.id))

        for revision in importedRevisions where !existingRevisionIDs.contains(revision.id) {
            context.insert(
                DailyRecordRevision(
                    id: revision.id,
                    batchID: revision.batchID,
                    createdAt: revision.createdAt,
                    logicalOrder: revision.logicalOrder,
                    serverReceivedAt: revision.serverReceivedAt,
                    authorDeviceID: revision.authorDeviceID,
                    startOfDay: revision.startOfDay,
                    isDeleted: revision.snapshot == nil,
                    verifiedAt: revision.verifiedAt,
                    methodRawValue: revision.methodRawValue,
                    verificationDuration: revision.verificationDuration,
                    spfLevel: revision.spfLevel,
                    notes: revision.notes,
                    reapplyCount: revision.reapplyCount,
                    lastReappliedAt: revision.lastReappliedAt,
                    changedFields: revision.changedFields,
                    batchKind: revision.batchKind
                )
            )
        }
    }

    private func cloneImportedSettingsRevisions(_ importedRevisions: [SettingsRevision]) throws {
        let existingRevisionIDs = Set(try context.fetch(FetchDescriptor<SettingsRevision>()).map(\.id))

        for revision in importedRevisions where !existingRevisionIDs.contains(revision.id) {
            context.insert(
                SettingsRevision(
                    id: revision.id,
                    batchID: revision.batchID,
                    createdAt: revision.createdAt,
                    logicalOrder: revision.logicalOrder,
                    serverReceivedAt: revision.serverReceivedAt,
                    authorDeviceID: revision.authorDeviceID,
                    snapshot: revision.snapshot,
                    changedFields: revision.changedFields,
                    batchKind: revision.batchKind
                )
            )
        }
    }

    private func applyImportedProjectedState(
        projectedSettings: Settings?,
        projectedRecords: [DailyRecord],
        sessionID: UUID
    ) throws -> SunclubChangeBatch {
        let importBatch = try createBatch(
            kind: .importLocal,
            scope: .timeline,
            scopeIdentifier: "timeline",
            summary: "Imported a local backup.",
            isLocalOnly: true,
            importSessionID: sessionID
        )

        if let projectedSettings {
            context.insert(
                SettingsRevision(
                    batch: importBatch,
                    snapshot: projectedSettings.projectionSnapshot,
                    changedFields: Self.allSettingsFields
                )
            )
        }

        try insertDeletedDaysMissingFromImport(into: importBatch, projectedRecords: projectedRecords)
        try insertImportedProjectedRecords(projectedRecords, batch: importBatch)
        return importBatch
    }

    private func recoveredProjectedState(
        projectedSettings: Settings?,
        projectedRecords: [DailyRecord]
    ) throws -> RecoveredProjectedState {
        let currentSettings = try loadOrCreateSettings().projectionSnapshot
        let recoveredSettings = projectedSettings
            .map(\.projectionSnapshot)
            .map { Self.mergeRecoveredSettings(current: currentSettings, imported: $0) }
        let settingsToRecover = recoveredSettings == currentSettings ? nil : recoveredSettings

        let currentDays = Set(try records().map { calendar.startOfDay(for: $0.startOfDay) })
        let recordsToRecover = projectedRecords.filter { record in
            !currentDays.contains(calendar.startOfDay(for: record.startOfDay))
        }

        return RecoveredProjectedState(settings: settingsToRecover, records: recordsToRecover)
    }

    private func insertDeletedDaysMissingFromImport(
        into batch: SunclubChangeBatch,
        projectedRecords: [DailyRecord]
    ) throws {
        let importedDays = Set(projectedRecords.map { calendar.startOfDay(for: $0.startOfDay) })

        for currentRecord in try records() {
            let currentDay = calendar.startOfDay(for: currentRecord.startOfDay)
            guard !importedDays.contains(currentDay) else {
                continue
            }

            context.insert(
                DailyRecordRevision(
                    deletedDay: currentDay,
                    batch: batch,
                    changedFields: Self.allRecordFields.union([.isDeleted])
                )
            )
        }
    }

    private func insertImportedProjectedRecords(
        _ projectedRecords: [DailyRecord],
        batch: SunclubChangeBatch
    ) throws {
        for record in projectedRecords {
            context.insert(
                DailyRecordRevision(
                    batch: batch,
                    snapshot: record.projectionSnapshot,
                    changedFields: Self.allRecordFields
                )
            )
        }
    }

    @discardableResult
    func restoreImportSession(_ sessionID: UUID) throws -> SunclubChangeBatch {
        guard let session = try importSession(id: sessionID) else {
            throw HistoryServiceError.importSessionNotFound
        }

        let restorePointRevisions = try revisions(forBatchID: session.restorePointBatchID)
        let restorePointSettings = try settingsRevision(forBatchID: session.restorePointBatchID)
        var removedDays = Set<Date>()

        return try commitRecoveryChange(validate: {
            for day in removedDays where try self.record(for: day) != nil {
                throw HistoryServiceError.importUndoIncomplete
            }
        }, {
            let batch = try createBatch(
                kind: .restore,
                scope: .timeline,
                scopeIdentifier: "timeline",
                summary: "Undid the import.",
                isLocalOnly: true
            )
            removedDays = try insertImportUndoDeletions(session, restorePointRevisions: restorePointRevisions, into: batch)
            if let restorePointSettings {
                let currentSettings = try settings().projectionSnapshot
                context.insert(
                    SettingsRevision(
                        batch: batch,
                        snapshot: Self.mergeRecoveredSettings(current: restorePointSettings.snapshot, imported: currentSettings),
                        changedFields: Self.allSettingsFields
                    )
                )
            }

            for snapshot in restorePointRevisions.compactMap(\.snapshot) {
                context.insert(
                    DailyRecordRevision(batch: batch, snapshot: snapshot, changedFields: Self.allRecordFields)
                )
            }
            return batch
        })
    }

    private func insertImportUndoDeletions(
        _ session: SunclubImportSession,
        restorePointRevisions: [DailyRecordRevision],
        into batch: SunclubChangeBatch
    ) throws -> Set<Date> {
        let originalDays = Set(restorePointRevisions.map { calendar.startOfDay(for: $0.startOfDay) })
        let importedBatchIDs = Set(session.importedBatchIDs)
        let batches = try context.fetch(FetchDescriptor<SunclubChangeBatch>())
        // Automatic legacy-store recovery must remain non-destructive.
        guard batches.contains(where: {
            $0.kind == .importLocal && $0.importSessionID == session.id && importedBatchIDs.contains($0.id)
        }) else { return [] }
        let revisionsByDay = Dictionary(grouping: Self.sortedRecordRevisions(
            try context.fetch(FetchDescriptor<DailyRecordRevision>())
        )) { calendar.startOfDay(for: $0.startOfDay) }
        var removedDays = Set<Date>()

        for record in try records() {
            let day = calendar.startOfDay(for: record.startOfDay)
            guard !originalDays.contains(day),
                  let latest = revisionsByDay[day]?.last,
                  importOwnsRevision(latest, session: session, batches: batches),
                  latest.snapshot?.makeModel().projectionSnapshot == record.projectionSnapshot else { continue }

            let deletion = DailyRecordRevision(
                deletedDay: day, batch: batch, changedFields: Self.allRecordFields.union([.isDeleted])
            )
            // This explicit removal must not auto-merge a foreign-author imported value back in.
            deletion.batchKindRawValue = SunclubChangeKind.deleteRecord.rawValue
            context.insert(deletion)
            removedDays.insert(day)
        }
        return removedDays
    }

    private func importOwnsRevision(
        _ revision: DailyRecordRevision,
        session: SunclubImportSession,
        batches: [SunclubChangeBatch]
    ) -> Bool {
        let importedIDs = Set(session.importedBatchIDs)
        var candidateID = revision.batchID
        var visited = Set<UUID>()
        while visited.insert(candidateID).inserted {
            let matches = batches.filter { $0.id == candidateID }
            guard matches.count == 1, let batch = matches.first else { return false }
            if importedIDs.contains(batch.id), batch.importSessionID == session.id { return true }
            guard batch.kind == .conflictAutoMerge, let originalID = batch.inverseOfBatchID else { return false }
            candidateID = originalID
        }
        return false
    }

    @discardableResult
    func publishImportedChanges(for sessionID: UUID) throws -> CloudPublishResult {
        guard let session = try importSession(id: sessionID) else {
            throw HistoryServiceError.importSessionNotFound
        }

        let predicate = #Predicate<SunclubChangeBatch> { batch in
            batch.importSessionID == sessionID
        }
        let batches = try context.fetch(FetchDescriptor(predicate: predicate))
        return try commitRecoveryChange(rebuildsProjections: false) {
            for batch in batches {
                batch.isLocalOnly = false
                batch.isPublishedToCloud = false
            }
            session.publishRequestedAt = Date()
            return CloudPublishResult(importSessionID: sessionID, publishedBatchCount: batches.count)
        }
    }

    @discardableResult
    func undo(batchID: UUID, kind: SunclubChangeKind = .undo) throws -> SunclubChangeBatch {
        try commitRecoveryChange { try createInverse(batchID: batchID, kind: kind) }
    }

    func canUndoChangeIfCurrent(batchID: UUID) throws -> Bool {
        guard let batch = try fetchBatchForSync(id: batchID),
              batch.scope == .day, batch.undoneByBatchID == nil,
              try settingsRevision(forBatchID: batchID) == nil else { return false }
        let targets = try revisions(forBatchID: batchID)
        guard !targets.isEmpty else { return false }
        let allRevisions = Self.sortedRecordRevisions(try context.fetch(FetchDescriptor<DailyRecordRevision>()))
        let projectedRecords = try records()
        for target in targets {
            let day = calendar.startOfDay(for: target.startOfDay)
            guard allRevisions.last(where: { calendar.startOfDay(for: $0.startOfDay) == day })?.id == target.id else {
                return false
            }
            let projected = projectedRecords.filter { calendar.startOfDay(for: $0.startOfDay) == day }
            if let snapshot = target.snapshot {
                guard projected.count == 1, projected.first?.projectionSnapshot == snapshot else { return false }
            } else if !projected.isEmpty {
                return false
            }
        }
        return true
    }

    @discardableResult
    func undoChangeIfCurrent(batchID: UUID) throws -> SunclubChangeBatch {
        // Check before entering the write/rollback path so a stale receipt cannot rebuild
        // a divergent projection. Check and write remain synchronous on the context's actor.
        guard try canUndoChangeIfCurrent(batchID: batchID) else { throw HistoryServiceError.staleChange }
        return try undo(batchID: batchID)
    }

    @discardableResult
    func undoConflict(_ conflictID: UUID) throws -> SunclubChangeBatch {
        let predicate = #Predicate<SunclubConflictItem> { $0.id == conflictID }
        guard let conflict = try context.fetch(FetchDescriptor(predicate: predicate)).first,
              conflict.resolvedAt == nil else { throw HistoryServiceError.staleChange }
        return try commitRecoveryChange {
            let inverse = try createInverse(batchID: conflict.mergedBatchID, kind: .undo)
            conflict.resolvedAt = Date()
            return inverse
        }
    }

    private func createInverse(batchID: UUID, kind: SunclubChangeKind) throws -> SunclubChangeBatch {
        let batch = try fetchBatch(id: batchID)
        guard batch.undoneByBatchID == nil else {
            throw HistoryServiceError.batchAlreadyUndone
        }

        let inverseBatch = try createBatch(
            kind: kind,
            scope: batch.scope,
            scopeIdentifier: batch.scopeIdentifier,
            summary: "\(kind.displayTitle): \(batch.summary)",
            isLocalOnly: batch.isLocalOnly,
            inverseOfBatchID: batch.id
        )

        if let settingsRevision = try settingsRevision(forBatchID: batch.id) {
            let previousSettings = try previousSettingsSnapshot(before: settingsRevision)
            context.insert(
                SettingsRevision(
                    batch: inverseBatch,
                    snapshot: previousSettings,
                    changedFields: Self.allSettingsFields
                )
            )
        }

        for revision in try revisions(forBatchID: batch.id) {
            if let previous = try previousRecordRevision(for: revision.startOfDay, before: revision)?.snapshot {
                context.insert(
                    DailyRecordRevision(
                        batch: inverseBatch,
                        snapshot: previous,
                        changedFields: Self.allRecordFields
                    )
                )
            } else {
                context.insert(DailyRecordRevision(deletedDay: revision.startOfDay, batch: inverseBatch))
            }
        }

        batch.undoneByBatchID = inverseBatch.id
        return inverseBatch
    }

    private func commitRecoveryChange<Value>(
        rebuildsProjections: Bool = true,
        validate: () throws -> Void = {},
        _ operation: () throws -> Value
    ) throws -> Value {
        var value: Value?
        do {
            try context.transaction {
                value = try operation()
                if rebuildsProjections {
                    try rebuildProjections(savingChanges: false)
                }
                try validate()
                try mutationGuard()
            }
        } catch {
            rollbackAndRestoreProjections()
            throw error
        }
        guard let value else { throw HistoryServiceError.batchNotFound }
        return value
    }

    @discardableResult
    func redo(batchID: UUID) throws -> SunclubChangeBatch {
        let batch = try fetchBatch(id: batchID)
        guard let undoneByBatchID = batch.undoneByBatchID else {
            throw HistoryServiceError.batchCannotRedo
        }
        return try undo(batchID: undoneByBatchID, kind: .redo)
    }

    func resolveConflict(_ conflictID: UUID) throws {
        let predicate = #Predicate<SunclubConflictItem> { $0.id == conflictID }
        guard let conflict = try context.fetch(FetchDescriptor(predicate: predicate)).first else {
            return
        }
        try commitRecoveryChange(rebuildsProjections: false) {
            conflict.resolvedAt = Date()
        }
    }

    func fetchBatchForSync(id: UUID) throws -> SunclubChangeBatch? {
        let predicate = #Predicate<SunclubChangeBatch> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    func fetchRecordRevisionForSync(id: UUID) throws -> DailyRecordRevision? {
        let predicate = #Predicate<DailyRecordRevision> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    func fetchSettingsRevisionForSync(id: UUID) throws -> SettingsRevision? {
        let predicate = #Predicate<SettingsRevision> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    func markBatchPublished(batchID: UUID) throws {
        guard let batch = try fetchBatchForSync(id: batchID) else {
            return
        }
        batch.isPublishedToCloud = true
        batch.cloudPublishedAt = Date()
        try context.save()
    }

    func markImportSessionPublishedIfNeeded(_ sessionID: UUID) throws {
        guard let session = try importSession(id: sessionID) else {
            return
        }

        let batchIDs = session.importedBatchIDs
        guard !batchIDs.isEmpty else {
            session.publishedAt = session.publishedAt ?? Date()
            try context.save()
            return
        }

        let predicate = #Predicate<SunclubChangeBatch> { batch in
            batch.importSessionID == sessionID
        }
        let batches = try context.fetch(FetchDescriptor(predicate: predicate))
        let publishedBatchIDs = Set(
            batches
                .filter(\.isPublishedToCloud)
                .map(\.id)
        )

        guard Set(batchIDs).isSubset(of: publishedBatchIDs) else {
            return
        }

        session.publishedAt = session.publishedAt ?? Date()
        try context.save()
    }

    func upsertRemoteBatch(_ wire: BatchWire) throws {
        let logicalOrder = Self.validLogicalOrder(wire.logicalOrder)
        if let existing = try fetchBatchForSync(id: wire.id) {
            if existing.logicalOrder == nil {
                existing.logicalOrder = logicalOrder
            }
            if existing.serverReceivedAt == nil {
                existing.serverReceivedAt = wire.serverReceivedAt
            }
            if context.hasChanges {
                try context.save()
            }
            return
        }

        context.insert(
            SunclubChangeBatch(
                id: wire.id,
                createdAt: wire.createdAt,
                logicalOrder: logicalOrder,
                serverReceivedAt: wire.serverReceivedAt,
                kind: SunclubChangeKind(rawValue: wire.kindRawValue) ?? .manualLog,
                scope: SunclubBatchScope(rawValue: wire.scopeRawValue) ?? .timeline,
                scopeIdentifier: wire.scopeIdentifier,
                authorDeviceID: wire.authorDeviceID,
                summary: wire.summary,
                isLocalOnly: false,
                isPublishedToCloud: true,
                cloudPublishedAt: Date(),
                inverseOfBatchID: wire.inverseOfBatchID,
                undoneByBatchID: wire.undoneByBatchID
            )
        )
        if let logicalOrder {
            let batchID = wire.id
            let recordPredicate = #Predicate<DailyRecordRevision> { $0.batchID == batchID }
            for revision in try context.fetch(FetchDescriptor(predicate: recordPredicate))
                where revision.logicalOrder == nil {
                revision.logicalOrder = logicalOrder
            }
            let settingsPredicate = #Predicate<SettingsRevision> { $0.batchID == batchID }
            for revision in try context.fetch(FetchDescriptor(predicate: settingsPredicate))
                where revision.logicalOrder == nil {
                revision.logicalOrder = logicalOrder
            }
        }
        try context.save()
    }

    func upsertRemoteRecordRevision(_ wire: RecordRevisionWire) throws {
        let batchLogicalOrder = try fetchBatchForSync(id: wire.batchID)?.logicalOrder
        let logicalOrder = Self.validLogicalOrder(wire.logicalOrder)
            ?? batchLogicalOrder
        if let existing = try fetchRecordRevisionForSync(id: wire.id) {
            if existing.logicalOrder == nil {
                existing.logicalOrder = logicalOrder
            }
            if existing.serverReceivedAt == nil {
                existing.serverReceivedAt = wire.serverReceivedAt
            }
            if context.hasChanges {
                try context.save()
            }
            return
        }

        context.insert(
            DailyRecordRevision(
                id: wire.id,
                batchID: wire.batchID,
                createdAt: wire.createdAt,
                logicalOrder: logicalOrder,
                serverReceivedAt: wire.serverReceivedAt,
                authorDeviceID: wire.authorDeviceID,
                startOfDay: wire.startOfDay,
                isDeleted: wire.isDeleted,
                verifiedAt: wire.verifiedAt,
                methodRawValue: wire.methodRawValue,
                verificationDuration: wire.verificationDuration,
                spfLevel: wire.spfLevel,
                notes: wire.notes,
                reapplyCount: wire.reapplyCount,
                lastReappliedAt: wire.lastReappliedAt,
                changedFields: Set(wire.changedFields.compactMap(SunclubTrackedField.init(rawValue:))),
                batchKind: SunclubChangeKind(rawValue: wire.batchKindRawValue) ?? .manualLog
            )
        )
        try context.save()
    }

    func upsertRemoteSettingsRevision(_ wire: SettingsRevisionWire) throws {
        let batchLogicalOrder = try fetchBatchForSync(id: wire.batchID)?.logicalOrder
        let logicalOrder = Self.validLogicalOrder(wire.logicalOrder)
            ?? batchLogicalOrder
        if let existing = try fetchSettingsRevisionForSync(id: wire.id) {
            if existing.logicalOrder == nil {
                existing.logicalOrder = logicalOrder
            }
            if existing.serverReceivedAt == nil {
                existing.serverReceivedAt = wire.serverReceivedAt
            }
            if context.hasChanges {
                try context.save()
            }
            return
        }

        context.insert(
            SettingsRevision(
                id: wire.id,
                batchID: wire.batchID,
                createdAt: wire.createdAt,
                logicalOrder: logicalOrder,
                serverReceivedAt: wire.serverReceivedAt,
                authorDeviceID: wire.authorDeviceID,
                snapshot: wire.snapshot,
                changedFields: Set(wire.changedFields.compactMap(SunclubTrackedField.init(rawValue:))),
                batchKind: SunclubChangeKind(rawValue: wire.batchKindRawValue) ?? .reminderSettings
            )
        )
        try context.save()
    }

    private func rebuildProjections(savingChanges: Bool = true) throws {
        try ensureSettingsProjectionExists()
        try resolveConflictsIfNeeded()

        let settings = try loadOrCreateSettings()
        let rawSettingsRevisions = try context.fetch(FetchDescriptor<SettingsRevision>())
        let settingsRevisions = Self.settingsRevisionsForProjection(rawSettingsRevisions)
        if let latestSettings = settingsRevisions.last {
            settings.apply(snapshot: latestSettings.snapshot)
        }

        let projectedRecords = try records()
        for record in projectedRecords {
            context.delete(record)
        }

        let allRevisions = Self.sortedRecordRevisions(
            try context.fetch(FetchDescriptor<DailyRecordRevision>())
        )
        let grouped = Dictionary(grouping: allRevisions) { calendar.startOfDay(for: $0.startOfDay) }
        for day in grouped.keys.sorted() {
            guard let latest = grouped[day]?.last,
                  let snapshot = latest.snapshot else {
                continue
            }
            let record = DailyRecord(
                startOfDay: snapshot.startOfDay,
                verifiedAt: snapshot.verifiedAt,
                method: snapshot.method,
                verificationDuration: snapshot.verificationDuration,
                spfLevel: snapshot.spfLevel,
                notes: snapshot.notes,
                reapplyCount: snapshot.reapplyCount,
                lastReappliedAt: snapshot.lastReappliedAt
            )
            context.insert(record)
        }

        settings.longestStreak = CalendarAnalytics.longestStreak(
            records: grouped.compactMap { $0.value.last?.snapshot?.startOfDay },
            calendar: calendar
        )
        if savingChanges {
            try context.save()
        }
    }

    private func rollbackAndRestoreProjections() {
        context.rollback()
        do {
            try rebuildProjections()
        } catch {
            context.rollback()
        }
    }

    private func seedProjectedRowsIntoHistoryIfNeeded() throws {
        let settings = try loadOrCreateSettings()
        let preference = try loadOrCreateSyncPreference()
        let existingSettingsRevisions = try context.fetch(FetchDescriptor<SettingsRevision>())
        let existingRecordRevisions = try context.fetch(FetchDescriptor<DailyRecordRevision>())
        let existingRecordDays = Set(existingRecordRevisions.map { calendar.startOfDay(for: $0.startOfDay) })
        let projectedRecords = try context.fetch(FetchDescriptor<DailyRecord>())
        let orphanRecords = projectedRecords.filter { !existingRecordDays.contains(calendar.startOfDay(for: $0.startOfDay)) }

        guard existingSettingsRevisions.isEmpty || !orphanRecords.isEmpty else {
            return
        }

        let isEmptyDefaultSeed = existingSettingsRevisions.isEmpty
            && orphanRecords.isEmpty
            && Self.isDefaultSettingsSnapshot(settings.projectionSnapshot)
        let batch = SunclubChangeBatch(
            logicalOrder: try nextLogicalOrder(),
            kind: .migrationSeed,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: preference.deviceID,
            summary: "Reconciled projected rows into history.",
            isLocalOnly: isEmptyDefaultSeed
        )
        context.insert(batch)

        if existingSettingsRevisions.isEmpty {
            context.insert(
                SettingsRevision(
                    batch: batch,
                    snapshot: settings.projectionSnapshot,
                    changedFields: Self.allSettingsFields
                )
            )
        }

        for record in orphanRecords {
            context.insert(
                DailyRecordRevision(
                    batch: batch,
                    snapshot: record.projectionSnapshot,
                    changedFields: Self.allRecordFields
                )
            )
        }

        try context.save()
    }

    private func resolveConflictsIfNeeded() throws {
        if let latestConflictBatch = try resolveSettingsConflictIfNeeded() {
            try markPendingConflict(summary: "Settings changes were auto-merged for review.", mergedBatch: latestConflictBatch, competingBatchIDs: latestConflictBatch.inverseOfBatchID.map { [$0] } ?? [], scope: .settings, scopeIdentifier: "settings")
        }

        let grouped = Dictionary(grouping: Self.sortedRecordRevisions(
            try context.fetch(FetchDescriptor<DailyRecordRevision>())
        )) { calendar.startOfDay(for: $0.startOfDay) }

        for day in grouped.keys.sorted() {
            if let latestConflictBatch = try resolveDayConflictIfNeeded(for: day, revisions: grouped[day] ?? []) {
                try markPendingConflict(
                    summary: "Conflicting changes for \(day.formatted(.dateTime.month().day())) were auto-merged.",
                    mergedBatch: latestConflictBatch,
                    competingBatchIDs: latestConflictBatch.inverseOfBatchID.map { [$0] } ?? [],
                    scope: .day,
                    scopeIdentifier: Self.scopeIdentifier(for: day)
                )
            }
        }
    }

    private func resolveSettingsConflictIfNeeded() throws -> SunclubChangeBatch? {
        let rawRevisions = try context.fetch(FetchDescriptor<SettingsRevision>())
        let revisions = Self.settingsRevisionsForProjection(rawRevisions)
        guard revisions.count >= 2 else {
            return nil
        }

        let latest = revisions[revisions.count - 1]
        let previous = revisions[revisions.count - 2]
        guard latest.batchKind != .conflictAutoMerge,
              previous.batchKind != .conflictAutoMerge,
              latest.authorDeviceID != previous.authorDeviceID,
              latest.snapshot != previous.snapshot else {
            return nil
        }

        let merged = Self.mergeSettings(
            older: previous.snapshot,
            olderChangedFields: previous.changedFields,
            newer: latest.snapshot,
            newerChangedFields: latest.changedFields
        )

        let batch = try createBatch(
            kind: .conflictAutoMerge,
            scope: .settings,
            scopeIdentifier: "settings",
            summary: "Auto-merged settings changes.",
            inverseOfBatchID: latest.batchID
        )
        context.insert(
            SettingsRevision(
                batch: batch,
                snapshot: merged,
                changedFields: previous.changedFields.union(latest.changedFields)
            )
        )
        return batch
    }

    private func resolveDayConflictIfNeeded(
        for day: Date,
        revisions: [DailyRecordRevision]
    ) throws -> SunclubChangeBatch? {
        let revisions = Self.sortedRecordRevisions(revisions)
        guard revisions.count >= 2 else {
            return nil
        }

        let latest = revisions[revisions.count - 1]
        let previous = revisions[revisions.count - 2]
        guard latest.batchKind != .deleteRecord,
              latest.batchKind != .conflictAutoMerge,
              previous.batchKind != .conflictAutoMerge,
              latest.authorDeviceID != previous.authorDeviceID,
              latest.snapshot != previous.snapshot else {
            return nil
        }

        let merged = Self.mergeRecord(
            day: day,
            older: previous,
            newer: latest
        )

        let batch = try createBatch(
            kind: .conflictAutoMerge,
            scope: .day,
            scopeIdentifier: Self.scopeIdentifier(for: day),
            summary: "Auto-merged changes for \(day.formatted(.dateTime.month().day())).",
            inverseOfBatchID: latest.batchID
        )

        if let merged {
            context.insert(
                DailyRecordRevision(
                    batch: batch,
                    snapshot: merged,
                    changedFields: previous.changedFields.union(latest.changedFields)
                )
            )
        } else {
            context.insert(
                DailyRecordRevision(
                    deletedDay: day,
                    batch: batch,
                    changedFields: previous.changedFields.union(latest.changedFields).union([.isDeleted])
                )
            )
        }
        return batch
    }

    private func markPendingConflict(
        summary: String,
        mergedBatch: SunclubChangeBatch,
        competingBatchIDs: [UUID],
        scope: SunclubConflictScope,
        scopeIdentifier: String
    ) throws {
        let predicate = #Predicate<SunclubConflictItem> {
            $0.scopeIdentifier == scopeIdentifier && $0.resolvedAt == nil
        }
        if try context.fetch(FetchDescriptor(predicate: predicate)).count > 0 {
            return
        }

        context.insert(
            SunclubConflictItem(
                scope: scope,
                scopeIdentifier: scopeIdentifier,
                summary: summary,
                mergedBatchID: mergedBatch.id,
                competingBatchIDs: competingBatchIDs
            )
        )
    }

    private func loadOrCreateSettings() throws -> Settings {
        if let existing = try context.fetch(FetchDescriptor<Settings>()).first {
            return existing
        }

        let settings = Settings()
        context.insert(settings)
        try context.save()
        return settings
    }

    private func ensureSettingsProjectionExists() throws {
        _ = try loadOrCreateSettings()
    }

    private func loadOrCreateSyncPreference() throws -> CloudSyncPreference {
        if let existing = try context.fetch(FetchDescriptor<CloudSyncPreference>()).first {
            return existing
        }

        let preference = CloudSyncPreference()
        context.insert(preference)
        try context.save()
        return preference
    }

    private func loadOrCreateCloudSyncState() throws -> CloudSyncState {
        if let existing = try context.fetch(FetchDescriptor<CloudSyncState>()).first {
            return existing
        }

        let state = CloudSyncState()
        context.insert(state)
        try context.save()
        return state
    }

    private func createBatch(
        kind: SunclubChangeKind,
        scope: SunclubBatchScope,
        scopeIdentifier: String,
        summary: String,
        isLocalOnly: Bool = false,
        inverseOfBatchID: UUID? = nil,
        importSessionID: UUID? = nil
    ) throws -> SunclubChangeBatch {
        let batch = SunclubChangeBatch(
            createdAt: Date(),
            logicalOrder: try nextLogicalOrder(),
            kind: kind,
            scope: scope,
            scopeIdentifier: scopeIdentifier,
            authorDeviceID: try loadOrCreateSyncPreference().deviceID,
            summary: summary,
            isLocalOnly: isLocalOnly,
            inverseOfBatchID: inverseOfBatchID,
            importSessionID: importSessionID
        )
        context.insert(batch)
        return batch
    }

    private func nextLogicalOrder() throws -> Int64 {
        let batchOrders = try context.fetch(FetchDescriptor<SunclubChangeBatch>())
            .compactMap(\.logicalOrder)
        let recordRevisionOrders = try context.fetch(FetchDescriptor<DailyRecordRevision>())
            .compactMap(\.logicalOrder)
        let settingsRevisionOrders = try context.fetch(FetchDescriptor<SettingsRevision>())
            .compactMap(\.logicalOrder)
        let greatestObserved = (batchOrders + recordRevisionOrders + settingsRevisionOrders)
            .filter { $0 >= 0 }
            .max() ?? 0

        guard greatestObserved < Int64.max else {
            throw HistoryServiceError.logicalOrderExhausted
        }
        return greatestObserved + 1
    }

    private func previousSettingsSnapshot(before revision: SettingsRevision) throws -> SettingsProjectionSnapshot {
        let revisions = Self.sortedSettingsRevisions(
            try context.fetch(FetchDescriptor<SettingsRevision>())
        )
        let previous = revisions.last(where: { Self.isOrderedBefore($0, revision) })
        return previous?.snapshot ?? Settings().projectionSnapshot
    }

    private func previousRecordRevision(
        for day: Date,
        before revision: DailyRecordRevision
    ) throws -> DailyRecordRevision? {
        let targetDay = calendar.startOfDay(for: day)
        let predicate = #Predicate<DailyRecordRevision> {
            $0.startOfDay == targetDay
        }
        return Self.sortedRecordRevisions(
            try context.fetch(FetchDescriptor(predicate: predicate))
        ).last(where: { Self.isOrderedBefore($0, revision) })
    }

    private func revisions(forBatchID batchID: UUID) throws -> [DailyRecordRevision] {
        let predicate = #Predicate<DailyRecordRevision> { $0.batchID == batchID }
        return try context.fetch(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.startOfDay, order: .forward)]
            )
        )
    }

    private func settingsRevision(forBatchID batchID: UUID) throws -> SettingsRevision? {
        let predicate = #Predicate<SettingsRevision> { $0.batchID == batchID }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    private func isSyntheticEmptyDefaultBatch(_ batch: SunclubChangeBatch) throws -> Bool {
        guard batch.kind == .migrationSeed else {
            return false
        }

        guard try revisions(forBatchID: batch.id).isEmpty else {
            return false
        }

        guard let settingsRevision = try settingsRevision(forBatchID: batch.id) else {
            return true
        }

        return Self.isDefaultSettingsSnapshot(settingsRevision.snapshot)
    }

    private func fetchBatch(id: UUID) throws -> SunclubChangeBatch {
        let predicate = #Predicate<SunclubChangeBatch> { $0.id == id }
        guard let batch = try context.fetch(FetchDescriptor(predicate: predicate)).first else {
            throw HistoryServiceError.batchNotFound
        }
        return batch
    }

    private static func settingsRevisionsForProjection(
        _ revisions: [SettingsRevision]
    ) -> [SettingsRevision] {
        let revisions = sortedSettingsRevisions(revisions)
        let filtered = revisions.filter { !isSyntheticDefaultSettingsRevision($0) }
        return filtered.isEmpty ? revisions : filtered
    }

    private static func sortedRecordRevisions(
        _ revisions: [DailyRecordRevision]
    ) -> [DailyRecordRevision] {
        revisions.sorted(by: isOrderedBefore)
    }

    private static func sortedSettingsRevisions(
        _ revisions: [SettingsRevision]
    ) -> [SettingsRevision] {
        revisions.sorted(by: isOrderedBefore)
    }

    private static func isOrderedBefore(
        _ lhs: DailyRecordRevision,
        _ rhs: DailyRecordRevision
    ) -> Bool {
        isOrderedBefore(
            HistoryOrderKey(
                logicalOrder: lhs.logicalOrder,
                serverReceivedAt: lhs.serverReceivedAt,
                createdAt: lhs.createdAt,
                id: lhs.id
            ),
            HistoryOrderKey(
                logicalOrder: rhs.logicalOrder,
                serverReceivedAt: rhs.serverReceivedAt,
                createdAt: rhs.createdAt,
                id: rhs.id
            )
        )
    }

    private static func isOrderedBefore(
        _ lhs: SettingsRevision,
        _ rhs: SettingsRevision
    ) -> Bool {
        isOrderedBefore(
            HistoryOrderKey(
                logicalOrder: lhs.logicalOrder,
                serverReceivedAt: lhs.serverReceivedAt,
                createdAt: lhs.createdAt,
                id: lhs.id
            ),
            HistoryOrderKey(
                logicalOrder: rhs.logicalOrder,
                serverReceivedAt: rhs.serverReceivedAt,
                createdAt: rhs.createdAt,
                id: rhs.id
            )
        )
    }

    private static func isOrderedBefore(
        _ lhs: HistoryOrderKey,
        _ rhs: HistoryOrderKey
    ) -> Bool {
        if let lhsLogicalOrder = validLogicalOrder(lhs.logicalOrder),
           let rhsLogicalOrder = validLogicalOrder(rhs.logicalOrder),
           lhsLogicalOrder != rhsLogicalOrder {
            return lhsLogicalOrder < rhsLogicalOrder
        }

        let lhsFallbackDate = lhs.serverReceivedAt ?? lhs.createdAt
        let rhsFallbackDate = rhs.serverReceivedAt ?? rhs.createdAt
        if lhsFallbackDate != rhsFallbackDate {
            return lhsFallbackDate < rhsFallbackDate
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func validLogicalOrder(_ logicalOrder: Int64?) -> Int64? {
        logicalOrder.flatMap { $0 >= 0 ? $0 : nil }
    }

    private struct HistoryOrderKey {
        let logicalOrder: Int64?
        let serverReceivedAt: Date?
        let createdAt: Date
        let id: UUID
    }

    private static func isSyntheticDefaultSettingsRevision(_ revision: SettingsRevision) -> Bool {
        guard isDefaultSettingsSnapshot(revision.snapshot) else {
            return false
        }

        switch revision.batchKind {
        case .migrationSeed, .conflictAutoMerge:
            return true
        default:
            return false
        }
    }

    private static func isMeaningfulRecovery(
        settings: SettingsProjectionSnapshot?,
        records: [DailyRecord]
    ) -> Bool {
        if !records.isEmpty {
            return true
        }

        guard let settings else {
            return false
        }

        return !isDefaultSettingsSnapshot(settings)
    }

    private static func mergeRecoveredSettings(
        current: SettingsProjectionSnapshot,
        imported: SettingsProjectionSnapshot
    ) -> SettingsProjectionSnapshot {
        let defaults = defaultSettingsSnapshot
        return SettingsProjectionSnapshot(
            hasCompletedOnboarding: current.hasCompletedOnboarding || imported.hasCompletedOnboarding,
            reminderHour: recoveredField(current: current.reminderHour, imported: imported.reminderHour, defaultValue: defaults.reminderHour),
            reminderMinute: recoveredField(current: current.reminderMinute, imported: imported.reminderMinute, defaultValue: defaults.reminderMinute),
            weeklyHour: recoveredField(current: current.weeklyHour, imported: imported.weeklyHour, defaultValue: defaults.weeklyHour),
            weeklyWeekday: recoveredField(current: current.weeklyWeekday, imported: imported.weeklyWeekday, defaultValue: defaults.weeklyWeekday),
            dailyPhraseState: recoveredOptionalField(current: current.dailyPhraseState, imported: imported.dailyPhraseState),
            weeklyPhraseState: recoveredOptionalField(current: current.weeklyPhraseState, imported: imported.weeklyPhraseState),
            smartReminderSettingsData: recoveredOptionalField(current: current.smartReminderSettingsData, imported: imported.smartReminderSettingsData),
            reapplyReminderEnabled: current.reapplyReminderEnabled || imported.reapplyReminderEnabled,
            reapplyIntervalMinutes: recoveredField(
                current: current.reapplyIntervalMinutes,
                imported: imported.reapplyIntervalMinutes,
                defaultValue: defaults.reapplyIntervalMinutes
            ),
            usesLiveUV: current.usesLiveUV || imported.usesLiveUV,
            selectedUVPlace: recoveredOptionalField(
                current: current.selectedUVPlace,
                imported: imported.selectedUVPlace
            ),
            sunscreenProfile: recoveredOptionalField(
                current: current.sunscreenProfile,
                imported: imported.sunscreenProfile
            ),
            restorablePreferences: recoveredOptionalField(
                current: current.restorablePreferences,
                imported: imported.restorablePreferences
            )
        )
    }

    private static func recoveredField<Value: Equatable>(
        current: Value,
        imported: Value,
        defaultValue: Value
    ) -> Value {
        current == defaultValue && imported != defaultValue ? imported : current
    }

    private static func recoveredOptionalField<Value>(
        current: Value?,
        imported: Value?
    ) -> Value? {
        current ?? imported
    }

    private static func isDefaultSettingsSnapshot(_ snapshot: SettingsProjectionSnapshot) -> Bool {
        snapshot == defaultSettingsSnapshot
    }

    private static var defaultSettingsSnapshot: SettingsProjectionSnapshot {
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
            usesLiveUV: false,
            selectedUVPlace: nil,
            sunscreenProfile: nil,
            restorablePreferences: nil
        )
    }

    private static func mergeSettings(
        older: SettingsProjectionSnapshot,
        olderChangedFields: Set<SunclubTrackedField>,
        newer: SettingsProjectionSnapshot,
        newerChangedFields: Set<SunclubTrackedField>
    ) -> SettingsProjectionSnapshot {
        SettingsProjectionSnapshot(
            hasCompletedOnboarding: selectField(.hasCompletedOnboarding, older: older.hasCompletedOnboarding, olderChanged: olderChangedFields, newer: newer.hasCompletedOnboarding, newerChanged: newerChangedFields),
            reminderHour: selectField(.reminderHour, older: older.reminderHour, olderChanged: olderChangedFields, newer: newer.reminderHour, newerChanged: newerChangedFields),
            reminderMinute: selectField(.reminderMinute, older: older.reminderMinute, olderChanged: olderChangedFields, newer: newer.reminderMinute, newerChanged: newerChangedFields),
            weeklyHour: selectField(.weeklyHour, older: older.weeklyHour, olderChanged: olderChangedFields, newer: newer.weeklyHour, newerChanged: newerChangedFields),
            weeklyWeekday: selectField(.weeklyWeekday, older: older.weeklyWeekday, olderChanged: olderChangedFields, newer: newer.weeklyWeekday, newerChanged: newerChangedFields),
            dailyPhraseState: selectField(.dailyPhraseState, older: older.dailyPhraseState, olderChanged: olderChangedFields, newer: newer.dailyPhraseState, newerChanged: newerChangedFields),
            weeklyPhraseState: selectField(.weeklyPhraseState, older: older.weeklyPhraseState, olderChanged: olderChangedFields, newer: newer.weeklyPhraseState, newerChanged: newerChangedFields),
            smartReminderSettingsData: selectField(.smartReminderSettingsData, older: older.smartReminderSettingsData, olderChanged: olderChangedFields, newer: newer.smartReminderSettingsData, newerChanged: newerChangedFields),
            reapplyReminderEnabled: selectField(.reapplyReminderEnabled, older: older.reapplyReminderEnabled, olderChanged: olderChangedFields, newer: newer.reapplyReminderEnabled, newerChanged: newerChangedFields),
            reapplyIntervalMinutes: selectField(.reapplyIntervalMinutes, older: older.reapplyIntervalMinutes, olderChanged: olderChangedFields, newer: newer.reapplyIntervalMinutes, newerChanged: newerChangedFields),
            usesLiveUV: selectField(.usesLiveUV, older: older.usesLiveUV, olderChanged: olderChangedFields, newer: newer.usesLiveUV, newerChanged: newerChangedFields),
            selectedUVPlace: selectField(.selectedUVPlace, older: older.selectedUVPlace, olderChanged: olderChangedFields, newer: newer.selectedUVPlace, newerChanged: newerChangedFields),
            sunscreenProfile: selectField(.sunscreenProfile, older: older.sunscreenProfile, olderChanged: olderChangedFields, newer: newer.sunscreenProfile, newerChanged: newerChangedFields),
            restorablePreferences: selectField(.restorablePreferences, older: older.restorablePreferences, olderChanged: olderChangedFields, newer: newer.restorablePreferences, newerChanged: newerChangedFields)
        )
    }

    private static func mergeRecord(
        day: Date,
        older: DailyRecordRevision,
        newer: DailyRecordRevision
    ) -> DailyRecordProjectionSnapshot? {
        let olderSnapshot = older.snapshot
        let newerSnapshot = newer.snapshot

        if olderSnapshot == nil && newerSnapshot == nil {
            return nil
        }

        if olderSnapshot == nil {
            return newerSnapshot
        }

        if newerSnapshot == nil {
            return olderSnapshot
        }

        guard let olderSnapshot,
              let newerSnapshot else {
            return nil
        }

        return DailyRecordProjectionSnapshot(
            startOfDay: day,
            verifiedAt: selectField(.verifiedAt, older: olderSnapshot.verifiedAt, olderChanged: older.changedFields, newer: newerSnapshot.verifiedAt, newerChanged: newer.changedFields),
            methodRawValue: selectField(.methodRawValue, older: olderSnapshot.methodRawValue, olderChanged: older.changedFields, newer: newerSnapshot.methodRawValue, newerChanged: newer.changedFields),
            verificationDuration: selectField(.verificationDuration, older: olderSnapshot.verificationDuration, olderChanged: older.changedFields, newer: newerSnapshot.verificationDuration, newerChanged: newer.changedFields),
            spfLevel: selectField(.spfLevel, older: olderSnapshot.spfLevel, olderChanged: older.changedFields, newer: newerSnapshot.spfLevel, newerChanged: newer.changedFields),
            notes: selectField(.notes, older: olderSnapshot.notes, olderChanged: older.changedFields, newer: newerSnapshot.notes, newerChanged: newer.changedFields),
            reapplyCount: max(olderSnapshot.reapplyCount, newerSnapshot.reapplyCount),
            lastReappliedAt: maxDate(olderSnapshot.lastReappliedAt, newerSnapshot.lastReappliedAt)
        )
    }

    private static func selectField<Value>(
        _ field: SunclubTrackedField,
        older: Value,
        olderChanged: Set<SunclubTrackedField>,
        newer: Value,
        newerChanged: Set<SunclubTrackedField>
    ) -> Value {
        if newerChanged.contains(field) {
            return newer
        }

        if olderChanged.contains(field) {
            return older
        }

        return newer
    }

    private static func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return max(lhs, rhs)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private static func scopeIdentifier(for day: Date) -> String {
        day.formatted(.iso8601.year().month().day())
    }

    private static let allRecordFields: Set<SunclubTrackedField> = [
        .verifiedAt,
        .methodRawValue,
        .verificationDuration,
        .spfLevel,
        .notes,
        .reapplyCount,
        .lastReappliedAt
    ]

    private static let allSettingsFields: Set<SunclubTrackedField> = [
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
        .usesLiveUV,
        .selectedUVPlace,
        .sunscreenProfile,
        .restorablePreferences
    ]

    private struct ImportedDomainSnapshot {
        let batches: [SunclubChangeBatch]
        let projectedSettings: Settings?
        let projectedRecords: [DailyRecord]
        let recordRevisions: [DailyRecordRevision]
        let settingsRevisions: [SettingsRevision]

        init(context: ModelContext) throws {
            batches = try context.fetch(
                FetchDescriptor<SunclubChangeBatch>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            )
            projectedSettings = try context.fetch(FetchDescriptor<Settings>()).first
            projectedRecords = try context.fetch(
                FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .forward)])
            )
            recordRevisions = try context.fetch(
                FetchDescriptor<DailyRecordRevision>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            )
            settingsRevisions = try context.fetch(
                FetchDescriptor<SettingsRevision>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            )
        }
    }

    private struct RecoveredProjectedState {
        let settings: SettingsProjectionSnapshot?
        let records: [DailyRecord]

        var hasChanges: Bool {
            settings != nil || !records.isEmpty
        }
    }
}

enum HistoryServiceError: LocalizedError {
    case staleChange
    case batchNotFound
    case batchAlreadyUndone
    case batchCannotRedo
    case importSessionNotFound
    case importUndoIncomplete
    case logicalOrderExhausted

    var errorDescription: String? {
        switch self {
        case .staleChange:
            return "This day has changed since that action. Review its current history before undoing."
        case .batchNotFound:
            return "Sunclub couldn't find that change anymore."
        case .batchAlreadyUndone:
            return "That change has already been undone."
        case .batchCannotRedo:
            return "That change can't be redone right now."
        case .importSessionNotFound:
            return "Sunclub couldn't find that import anymore."
        case .importUndoIncomplete:
            return "This backup has inconsistent history dates. Undo wasn't applied; your history is unchanged. Try another backup."
        case .logicalOrderExhausted:
            return "Sunclub couldn't assign the next history order."
        }
    }
}
