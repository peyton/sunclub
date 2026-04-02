import Foundation
import SwiftData

struct SunclubImportResult: Equatable {
    let importedBatchCount: Int
    let importSessionID: UUID
    let restorePointBatchID: UUID
}

struct CloudPublishResult: Equatable {
    let importSessionID: UUID
    let publishedBatchCount: Int
}

@MainActor
final class SunclubHistoryService {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func fetchContext() -> ModelContext {
        context
    }

    func bootstrapIfNeeded() throws {
        let settings = try loadOrCreateSettings()
        let preference = try loadOrCreateSyncPreference()
        _ = try loadOrCreateCloudSyncState()

        let existingBatchCount = try context.fetch(FetchDescriptor<SunclubChangeBatch>()).count
        if existingBatchCount == 0 {
            let batch = SunclubChangeBatch(
                kind: .migrationSeed,
                scope: .timeline,
                scopeIdentifier: "timeline",
                authorDeviceID: preference.deviceID,
                summary: "Initialized Sunclub history."
            )
            context.insert(batch)
            context.insert(
                SettingsRevision(
                    batch: batch,
                    snapshot: settings.projectionSnapshot,
                    changedFields: Self.allSettingsFields
                )
            )

            let records = try context.fetch(FetchDescriptor<DailyRecord>())
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

        let batch = try createBatch(
            kind: kind,
            scope: .settings,
            scopeIdentifier: "settings",
            summary: summary,
            isLocalOnly: isLocalOnly
        )
        context.insert(SettingsRevision(batch: batch, snapshot: snapshot, changedFields: changedFields))
        try context.save()
        try rebuildProjections()
        return batch
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

        try context.save()
        try rebuildProjections()
        return batch
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
                    authorDeviceID: revision.authorDeviceID,
                    startOfDay: revision.startOfDay,
                    isDeleted: revision.isDeleted,
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
        guard let session = try importSessions(limit: 50).first(where: { $0.id == sessionID }) else {
            throw HistoryServiceError.importSessionNotFound
        }

        let restorePointRevisions = try revisions(forBatchID: session.restorePointBatchID)
        let restorePointSettings = try settingsRevision(forBatchID: session.restorePointBatchID)

        let batch = try createBatch(
            kind: .restore,
            scope: .timeline,
            scopeIdentifier: "timeline",
            summary: "Restored the local state from before the import.",
            isLocalOnly: true
        )

        if let restorePointSettings {
            context.insert(
                SettingsRevision(
                    batch: batch,
                    snapshot: restorePointSettings.snapshot,
                    changedFields: Self.allSettingsFields
                )
            )
        }

        let snapshotsByDay = Dictionary(uniqueKeysWithValues: restorePointRevisions.compactMap { revision in
            revision.snapshot.map { (calendar.startOfDay(for: revision.startOfDay), $0) }
        })
        let currentRecords = try records()
        for record in currentRecords {
            let day = calendar.startOfDay(for: record.startOfDay)
            if snapshotsByDay[day] == nil {
                context.insert(DailyRecordRevision(deletedDay: day, batch: batch))
            }
        }

        for snapshot in snapshotsByDay.values {
            context.insert(
                DailyRecordRevision(
                    batch: batch,
                    snapshot: snapshot,
                    changedFields: Self.allRecordFields
                )
            )
        }

        try context.save()
        try rebuildProjections()
        return batch
    }

    @discardableResult
    func publishImportedChanges(for sessionID: UUID) throws -> CloudPublishResult {
        guard let session = try importSessions(limit: 50).first(where: { $0.id == sessionID }) else {
            throw HistoryServiceError.importSessionNotFound
        }

        let predicate = #Predicate<SunclubChangeBatch> { batch in
            batch.importSessionID == sessionID
        }
        let batches = try context.fetch(FetchDescriptor(predicate: predicate))
        for batch in batches {
            batch.isLocalOnly = false
            batch.isPublishedToCloud = false
        }
        session.publishRequestedAt = Date()
        try context.save()

        return CloudPublishResult(
            importSessionID: sessionID,
            publishedBatchCount: batches.count
        )
    }

    @discardableResult
    func undo(batchID: UUID, kind: SunclubChangeKind = .undo) throws -> SunclubChangeBatch {
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
            let previousSettings = try previousSettingsSnapshot(before: settingsRevision.createdAt)
            context.insert(
                SettingsRevision(
                    batch: inverseBatch,
                    snapshot: previousSettings,
                    changedFields: Self.allSettingsFields
                )
            )
        }

        for revision in try revisions(forBatchID: batch.id) {
            if let previous = try previousRecordRevision(for: revision.startOfDay, before: revision.createdAt)?.snapshot {
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
        try context.save()
        try rebuildProjections()
        return inverseBatch
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
        conflict.resolvedAt = Date()
        try context.save()
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
        if try fetchBatchForSync(id: wire.id) != nil {
            return
        }

        context.insert(
            SunclubChangeBatch(
                id: wire.id,
                createdAt: wire.createdAt,
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
        try context.save()
    }

    func upsertRemoteRecordRevision(_ wire: RecordRevisionWire) throws {
        if try fetchRecordRevisionForSync(id: wire.id) != nil {
            return
        }

        context.insert(
            DailyRecordRevision(
                id: wire.id,
                batchID: wire.batchID,
                createdAt: wire.createdAt,
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
        if try fetchSettingsRevisionForSync(id: wire.id) != nil {
            return
        }

        context.insert(
            SettingsRevision(
                id: wire.id,
                batchID: wire.batchID,
                createdAt: wire.createdAt,
                authorDeviceID: wire.authorDeviceID,
                snapshot: wire.snapshot,
                changedFields: Set(wire.changedFields.compactMap(SunclubTrackedField.init(rawValue:))),
                batchKind: SunclubChangeKind(rawValue: wire.batchKindRawValue) ?? .reminderSettings
            )
        )
        try context.save()
    }

    private func rebuildProjections() throws {
        try ensureSettingsProjectionExists()
        try resolveConflictsIfNeeded()

        let settings = try loadOrCreateSettings()
        let settingsRevisions = try context.fetch(
            FetchDescriptor<SettingsRevision>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )
        if let latestSettings = settingsRevisions.last {
            settings.apply(snapshot: latestSettings.snapshot)
        }

        let projectedRecords = try records()
        for record in projectedRecords {
            context.delete(record)
        }

        let allRevisions = try context.fetch(
            FetchDescriptor<DailyRecordRevision>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
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
        try context.save()
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

        let batch = SunclubChangeBatch(
            kind: .migrationSeed,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: preference.deviceID,
            summary: "Reconciled projected rows into history."
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
        var didCreateMerge = false

        if let latestConflictBatch = try resolveSettingsConflictIfNeeded() {
            didCreateMerge = true
            try markPendingConflict(summary: "Settings changes were auto-merged for review.", mergedBatch: latestConflictBatch, competingBatchIDs: latestConflictBatch.inverseOfBatchID.map { [$0] } ?? [], scope: .settings, scopeIdentifier: "settings")
        }

        let grouped = Dictionary(grouping: try context.fetch(
            FetchDescriptor<DailyRecordRevision>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )) { calendar.startOfDay(for: $0.startOfDay) }

        for day in grouped.keys.sorted() {
            if let latestConflictBatch = try resolveDayConflictIfNeeded(for: day, revisions: grouped[day] ?? []) {
                didCreateMerge = true
                try markPendingConflict(
                    summary: "Conflicting changes for \(day.formatted(.dateTime.month().day())) were auto-merged.",
                    mergedBatch: latestConflictBatch,
                    competingBatchIDs: latestConflictBatch.inverseOfBatchID.map { [$0] } ?? [],
                    scope: .day,
                    scopeIdentifier: Self.scopeIdentifier(for: day)
                )
            }
        }

        if didCreateMerge {
            try context.save()
        }
    }

    private func resolveSettingsConflictIfNeeded() throws -> SunclubChangeBatch? {
        let revisions = try context.fetch(
            FetchDescriptor<SettingsRevision>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )
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
        guard revisions.count >= 2 else {
            return nil
        }

        let latest = revisions[revisions.count - 1]
        let previous = revisions[revisions.count - 2]
        guard latest.batchKind != .conflictAutoMerge,
              previous.batchKind != .conflictAutoMerge,
              latest.authorDeviceID != previous.authorDeviceID,
              latest.snapshot != previous.snapshot || latest.isDeleted != previous.isDeleted else {
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
        let createdAt = try nextBatchCreationDate()
        let batch = SunclubChangeBatch(
            createdAt: createdAt,
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

    private func nextBatchCreationDate() throws -> Date {
        let now = Date()
        let latestCreatedAt = try context.fetch(
            FetchDescriptor<SunclubChangeBatch>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ).first?.createdAt

        guard let latestCreatedAt, latestCreatedAt >= now else {
            return now
        }

        return latestCreatedAt.addingTimeInterval(0.001)
    }

    private func previousSettingsSnapshot(before date: Date) throws -> SettingsProjectionSnapshot {
        let revisions = try context.fetch(
            FetchDescriptor<SettingsRevision>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        )
        let previous = revisions.last(where: { $0.createdAt < date })
        return previous?.snapshot ?? Settings().projectionSnapshot
    }

    private func previousRecordRevision(for day: Date, before date: Date) throws -> DailyRecordRevision? {
        let targetDay = calendar.startOfDay(for: day)
        let predicate = #Predicate<DailyRecordRevision> {
            $0.startOfDay == targetDay && $0.createdAt < date
        }
        return try context.fetch(
            FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        ).last
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

    private func fetchBatch(id: UUID) throws -> SunclubChangeBatch {
        let predicate = #Predicate<SunclubChangeBatch> { $0.id == id }
        guard let batch = try context.fetch(FetchDescriptor(predicate: predicate)).first else {
            throw HistoryServiceError.batchNotFound
        }
        return batch
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
            usesLiveUV: selectField(.usesLiveUV, older: older.usesLiveUV, olderChanged: olderChangedFields, newer: newer.usesLiveUV, newerChanged: newerChangedFields)
        )
    }

    private static func mergeRecord(
        day: Date,
        older: DailyRecordRevision,
        newer: DailyRecordRevision
    ) -> DailyRecordProjectionSnapshot? {
        if older.isDeleted && newer.isDeleted {
            return nil
        }

        if older.isDeleted, let snapshot = newer.snapshot {
            return snapshot
        }

        if newer.isDeleted, let snapshot = older.snapshot {
            return snapshot
        }

        guard let olderSnapshot = older.snapshot,
              let newerSnapshot = newer.snapshot else {
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
        .usesLiveUV
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
}

enum HistoryServiceError: LocalizedError {
    case batchNotFound
    case batchAlreadyUndone
    case batchCannotRedo
    case importSessionNotFound

    var errorDescription: String? {
        switch self {
        case .batchNotFound:
            return "Sunclub couldn't find that change anymore."
        case .batchAlreadyUndone:
            return "That change has already been undone."
        case .batchCannotRedo:
            return "That change can't be redone right now."
        case .importSessionNotFound:
            return "Sunclub couldn't find that import anymore."
        }
    }
}
