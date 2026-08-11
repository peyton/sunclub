import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class HistoryServiceTransactionTests: XCTestCase {
    func testInjectedMutationFailureRollsBackDaySettingsAndBulkMutations() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let seedService = SunclubHistoryService(context: context)
        try seedService.bootstrapIfNeeded()

        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        try seedService.applyDayChange(
            for: day,
            kind: .manualLog,
            summary: "Seeded a log.",
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        ) { _ in
            Self.recordSnapshot(day: day, spfLevel: 30, notes: "Original")
        }

        let batchCountBeforeFailures = try context.fetchCount(FetchDescriptor<SunclubChangeBatch>())
        let revisionCountBeforeFailures = try context.fetchCount(FetchDescriptor<DailyRecordRevision>())
        var guardCallCount = 0
        let failingService = SunclubHistoryService(context: context) {
            guardCallCount += 1
            throw TestMutationError.injected
        }

        XCTAssertThrowsError(
            try failingService.applyDayChange(
                for: day,
                kind: .historyEdit,
                summary: "Edited a log.",
                changedFields: [.spfLevel, .notes]
            ) { existing in
                var updated = existing
                updated?.spfLevel = 50
                updated?.notes = "Should roll back"
                return updated
            }
        ) { error in
            XCTAssertEqual(error as? TestMutationError, .injected)
        }
        XCTAssertEqual(try XCTUnwrap(failingService.record(for: day)).spfLevel, 30)
        XCTAssertEqual(try XCTUnwrap(failingService.record(for: day)).notes, "Original")

        XCTAssertThrowsError(
            try failingService.applySettingsChange(
                kind: .reminderSettings,
                summary: "Changed reminder time.",
                changedFields: [.reminderHour]
            ) { settings in
                settings.reminderHour = 17
            }
        ) { error in
            XCTAssertEqual(error as? TestMutationError, .injected)
        }
        XCTAssertEqual(try failingService.settings().reminderHour, 8)

        XCTAssertThrowsError(try failingService.deleteAllRecords()) { error in
            XCTAssertEqual(error as? TestMutationError, .injected)
        }
        XCTAssertEqual(try failingService.records().count, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SunclubChangeBatch>()), batchCountBeforeFailures)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyRecordRevision>()), revisionCountBeforeFailures)
        XCTAssertEqual(guardCallCount, 3)
    }

    func testDeleteAllRecordsCommitsOneTimelineBatchWithEveryDeletion() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()

        let firstDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let secondDay = Calendar.current.date(byAdding: .day, value: 1, to: firstDay)!
        for (day, spfLevel) in [(firstDay, 30), (secondDay, 50)] {
            try historyService.applyDayChange(
                for: day,
                kind: .manualLog,
                summary: "Seeded a log.",
                changedFields: [.verifiedAt, .methodRawValue, .spfLevel]
            ) { _ in
                Self.recordSnapshot(day: day, spfLevel: spfLevel, notes: nil)
            }
        }

        let batchCountBeforeDelete = try context.fetchCount(FetchDescriptor<SunclubChangeBatch>())
        let deleteBatch = try XCTUnwrap(historyService.deleteAllRecords())

        XCTAssertEqual(deleteBatch.kind, .deleteRecord)
        XCTAssertEqual(deleteBatch.scope, .timeline)
        XCTAssertEqual(deleteBatch.scopeIdentifier, "timeline")
        XCTAssertTrue(try historyService.records().isEmpty)
        XCTAssertEqual(try historyService.settings().longestStreak, 0)
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<SunclubChangeBatch>()),
            batchCountBeforeDelete + 1
        )

        let deleteBatchID = deleteBatch.id
        let deletionRevisions = try context.fetch(
            FetchDescriptor<DailyRecordRevision>(
                predicate: #Predicate { $0.batchID == deleteBatchID },
                sortBy: [SortDescriptor(\.startOfDay, order: .forward)]
            )
        )
        XCTAssertEqual(deletionRevisions.count, 2)
        XCTAssertTrue(deletionRevisions.allSatisfy { $0.batchKind == .deleteRecord })
        XCTAssertTrue(deletionRevisions.allSatisfy { $0.snapshot == nil })
        XCTAssertTrue(deletionRevisions.allSatisfy { RecordRevisionWire(revision: $0).isDeleted })
        XCTAssertEqual(deletionRevisions.map(\.startOfDay), [firstDay, secondDay])

        let freshService = SunclubHistoryService(context: ModelContext(container))
        XCTAssertTrue(try freshService.records().isEmpty)
        XCTAssertNil(try historyService.deleteAllRecords())
        XCTAssertEqual(
            try context.fetchCount(FetchDescriptor<SunclubChangeBatch>()),
            batchCountBeforeDelete + 1
        )
    }

    func testLegacyRemoteServerOrderingWinsOverSkewedDeviceClocks() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()

        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let serverBase = Date(timeIntervalSince1970: 2_000_000_000)
        let firstServerDate = serverBase
        let secondServerDate = serverBase.addingTimeInterval(1)
        let clockFarAhead = serverBase.addingTimeInterval(365 * 24 * 60 * 60)
        let clockFarBehind = serverBase.addingTimeInterval(-365 * 24 * 60 * 60)

        let firstBatch = Self.remoteBatch(createdAt: clockFarAhead, summary: "First server edit")
        let secondBatch = Self.remoteBatch(createdAt: clockFarBehind, summary: "Second server edit")
        let firstRecordRevision = DailyRecordRevision(
            batch: firstBatch,
            snapshot: Self.recordSnapshot(day: day, spfLevel: 30, notes: "First"),
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        )
        let secondRecordRevision = DailyRecordRevision(
            batch: secondBatch,
            snapshot: Self.recordSnapshot(day: day, spfLevel: 50, notes: "Second"),
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        )
        let firstSettingsRevision = SettingsRevision(
            batch: firstBatch,
            snapshot: Self.settingsSnapshot(reminderHour: 9),
            changedFields: [.reminderHour]
        )
        let secondSettingsRevision = SettingsRevision(
            batch: secondBatch,
            snapshot: Self.settingsSnapshot(reminderHour: 11),
            changedFields: [.reminderHour]
        )

        var firstBatchWire = BatchWire(batch: firstBatch)
        firstBatchWire.serverReceivedAt = firstServerDate
        var secondBatchWire = BatchWire(batch: secondBatch)
        secondBatchWire.serverReceivedAt = secondServerDate
        var firstRecordWire = RecordRevisionWire(revision: firstRecordRevision)
        firstRecordWire.serverReceivedAt = firstServerDate
        var secondRecordWire = RecordRevisionWire(revision: secondRecordRevision)
        secondRecordWire.serverReceivedAt = secondServerDate
        var firstSettingsWire = SettingsRevisionWire(revision: firstSettingsRevision)
        firstSettingsWire.serverReceivedAt = firstServerDate
        var secondSettingsWire = SettingsRevisionWire(revision: secondSettingsRevision)
        secondSettingsWire.serverReceivedAt = secondServerDate

        try historyService.upsertRemoteBatch(firstBatchWire)
        try historyService.upsertRemoteRecordRevision(firstRecordWire)
        try historyService.upsertRemoteSettingsRevision(firstSettingsWire)
        try historyService.upsertRemoteBatch(secondBatchWire)
        try historyService.upsertRemoteRecordRevision(secondRecordWire)
        try historyService.upsertRemoteSettingsRevision(secondSettingsWire)
        try historyService.refreshProjectedState()

        let projectedRecord = try XCTUnwrap(historyService.record(for: day))
        XCTAssertEqual(projectedRecord.spfLevel, 50)
        XCTAssertEqual(projectedRecord.notes, "Second")
        XCTAssertEqual(try historyService.settings().reminderHour, 11)
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchRecordRevisionForSync(id: firstRecordRevision.id)).createdAt,
            clockFarAhead
        )
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchRecordRevisionForSync(id: secondRecordRevision.id)).createdAt,
            clockFarBehind
        )
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchRecordRevisionForSync(id: firstRecordRevision.id)).serverReceivedAt,
            firstServerDate
        )
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchRecordRevisionForSync(id: secondRecordRevision.id)).serverReceivedAt,
            secondServerDate
        )
        let storedFirstBatch = try XCTUnwrap(historyService.fetchBatchForSync(id: firstBatch.id))
        let storedSecondBatch = try XCTUnwrap(historyService.fetchBatchForSync(id: secondBatch.id))
        XCTAssertEqual(storedFirstBatch.createdAt, clockFarAhead)
        XCTAssertEqual(storedFirstBatch.serverReceivedAt, firstServerDate)
        XCTAssertNil(storedFirstBatch.logicalOrder)
        XCTAssertEqual(storedSecondBatch.createdAt, clockFarBehind)
        XCTAssertEqual(storedSecondBatch.serverReceivedAt, secondServerDate)
        XCTAssertNil(storedSecondBatch.logicalOrder)
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchSettingsRevisionForSync(id: firstSettingsRevision.id)).serverReceivedAt,
            firstServerDate
        )
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchSettingsRevisionForSync(id: secondSettingsRevision.id)).serverReceivedAt,
            secondServerDate
        )
    }

    func testLogicalOrderWinsOverServerAndSourceClockSkew() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()

        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let serverBase = Date(timeIntervalSince1970: 2_000_000_000)
        let clockFarAhead = serverBase.addingTimeInterval(365 * 24 * 60 * 60)
        let clockFarBehind = serverBase.addingTimeInterval(-365 * 24 * 60 * 60)
        let firstBatch = Self.remoteBatch(
            createdAt: clockFarAhead,
            logicalOrder: 40,
            summary: "First logical edit"
        )
        let secondBatch = Self.remoteBatch(
            createdAt: clockFarBehind,
            logicalOrder: 41,
            summary: "Second logical edit"
        )
        let firstRecordRevision = DailyRecordRevision(
            batch: firstBatch,
            snapshot: Self.recordSnapshot(day: day, spfLevel: 30, notes: "First"),
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        )
        let secondRecordRevision = DailyRecordRevision(
            batch: secondBatch,
            snapshot: Self.recordSnapshot(day: day, spfLevel: 50, notes: "Second"),
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        )
        let firstSettingsRevision = SettingsRevision(
            batch: firstBatch,
            snapshot: Self.settingsSnapshot(reminderHour: 9),
            changedFields: [.reminderHour]
        )
        let secondSettingsRevision = SettingsRevision(
            batch: secondBatch,
            snapshot: Self.settingsSnapshot(reminderHour: 11),
            changedFields: [.reminderHour]
        )

        var firstBatchWire = BatchWire(batch: firstBatch)
        firstBatchWire.serverReceivedAt = serverBase.addingTimeInterval(10)
        var secondBatchWire = BatchWire(batch: secondBatch)
        secondBatchWire.serverReceivedAt = serverBase
        var firstRecordWire = RecordRevisionWire(revision: firstRecordRevision)
        firstRecordWire.serverReceivedAt = serverBase.addingTimeInterval(10)
        var secondRecordWire = RecordRevisionWire(revision: secondRecordRevision)
        secondRecordWire.serverReceivedAt = serverBase
        var firstSettingsWire = SettingsRevisionWire(revision: firstSettingsRevision)
        firstSettingsWire.serverReceivedAt = serverBase.addingTimeInterval(10)
        var secondSettingsWire = SettingsRevisionWire(revision: secondSettingsRevision)
        secondSettingsWire.serverReceivedAt = serverBase

        try historyService.upsertRemoteBatch(secondBatchWire)
        try historyService.upsertRemoteRecordRevision(secondRecordWire)
        try historyService.upsertRemoteSettingsRevision(secondSettingsWire)
        try historyService.upsertRemoteBatch(firstBatchWire)
        try historyService.upsertRemoteRecordRevision(firstRecordWire)
        try historyService.upsertRemoteSettingsRevision(firstSettingsWire)
        try historyService.refreshProjectedState()

        let projectedRecord = try XCTUnwrap(historyService.record(for: day))
        XCTAssertEqual(projectedRecord.spfLevel, 50)
        XCTAssertEqual(projectedRecord.notes, "Second")
        XCTAssertEqual(try historyService.settings().reminderHour, 11)
        let storedSecondBatch = try XCTUnwrap(historyService.fetchBatchForSync(id: secondBatch.id))
        XCTAssertEqual(storedSecondBatch.createdAt, clockFarBehind)
        XCTAssertEqual(storedSecondBatch.serverReceivedAt, serverBase)
        XCTAssertEqual(storedSecondBatch.logicalOrder, 41)
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchRecordRevisionForSync(id: secondRecordRevision.id)).logicalOrder,
            41
        )
        XCTAssertEqual(
            try XCTUnwrap(historyService.fetchSettingsRevisionForSync(id: secondSettingsRevision.id)).logicalOrder,
            41
        )
    }

    func testEqualOrderAndTimestampsUseRevisionIDAsStableTieBreak() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()

        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let timestamp = Date(timeIntervalSince1970: 2_000_000_000)
        let lowerBatchID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000010"))
        let higherBatchID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000020"))
        let lowerRevisionID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000011"))
        let higherRevisionID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000021"))
        let lowerSettingsRevisionID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000012"))
        let higherSettingsRevisionID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000022"))
        let lowerBatch = Self.remoteBatch(
            id: lowerBatchID,
            createdAt: timestamp,
            logicalOrder: 7,
            summary: "Lower UUID"
        )
        let higherBatch = Self.remoteBatch(
            id: higherBatchID,
            createdAt: timestamp,
            logicalOrder: 7,
            summary: "Higher UUID"
        )
        let lowerRecord = Self.recordRevision(
            id: lowerRevisionID,
            batch: lowerBatch,
            snapshot: Self.recordSnapshot(day: day, spfLevel: 30, notes: "Lower")
        )
        let higherRecord = Self.recordRevision(
            id: higherRevisionID,
            batch: higherBatch,
            snapshot: Self.recordSnapshot(day: day, spfLevel: 50, notes: "Higher")
        )
        let lowerSettings = SettingsRevision(
            id: lowerSettingsRevisionID,
            batchID: lowerBatch.id,
            createdAt: timestamp,
            logicalOrder: 7,
            authorDeviceID: lowerBatch.authorDeviceID,
            snapshot: Self.settingsSnapshot(reminderHour: 9),
            changedFields: [.reminderHour],
            batchKind: lowerBatch.kind
        )
        let higherSettings = SettingsRevision(
            id: higherSettingsRevisionID,
            batchID: higherBatch.id,
            createdAt: timestamp,
            logicalOrder: 7,
            authorDeviceID: higherBatch.authorDeviceID,
            snapshot: Self.settingsSnapshot(reminderHour: 11),
            changedFields: [.reminderHour],
            batchKind: higherBatch.kind
        )

        var lowerBatchWire = BatchWire(batch: lowerBatch)
        lowerBatchWire.serverReceivedAt = timestamp
        var higherBatchWire = BatchWire(batch: higherBatch)
        higherBatchWire.serverReceivedAt = timestamp
        var lowerRecordWire = RecordRevisionWire(revision: lowerRecord)
        lowerRecordWire.serverReceivedAt = timestamp
        var higherRecordWire = RecordRevisionWire(revision: higherRecord)
        higherRecordWire.serverReceivedAt = timestamp
        var lowerSettingsWire = SettingsRevisionWire(revision: lowerSettings)
        lowerSettingsWire.serverReceivedAt = timestamp
        var higherSettingsWire = SettingsRevisionWire(revision: higherSettings)
        higherSettingsWire.serverReceivedAt = timestamp

        try historyService.upsertRemoteBatch(higherBatchWire)
        try historyService.upsertRemoteRecordRevision(higherRecordWire)
        try historyService.upsertRemoteSettingsRevision(higherSettingsWire)
        try historyService.upsertRemoteBatch(lowerBatchWire)
        try historyService.upsertRemoteRecordRevision(lowerRecordWire)
        try historyService.upsertRemoteSettingsRevision(lowerSettingsWire)
        try historyService.refreshProjectedState()

        XCTAssertEqual(try XCTUnwrap(historyService.record(for: day)).notes, "Higher")
        XCTAssertEqual(try historyService.settings().reminderHour, 11)
    }

    func testLocalBatchAndRevisionsIncrementGreatestObservedLogicalOrder() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()

        let remoteBatch = Self.remoteBatch(
            createdAt: Date(timeIntervalSince1970: 2_000_000_000),
            logicalOrder: 50,
            summary: "Observed remote order"
        )
        try historyService.upsertRemoteBatch(BatchWire(batch: remoteBatch))

        let localBatch = try XCTUnwrap(
            historyService.applySettingsChange(
                kind: .reminderSettings,
                summary: "Changed reminder time.",
                changedFields: [.reminderHour]
            ) { settings in
                settings.reminderHour = 10
            }
        )
        XCTAssertEqual(localBatch.logicalOrder, 51)

        let batchID = localBatch.id
        let revision = try XCTUnwrap(
            try context.fetch(
                FetchDescriptor<SettingsRevision>(predicate: #Predicate { $0.batchID == batchID })
            ).first
        )
        XCTAssertEqual(revision.logicalOrder, 51)
        XCTAssertNil(revision.serverReceivedAt)
    }

    func testWireRoundTripPreservesLogicalAndServerMetadataAndDecodesLegacyPayloads() throws {
        let timestamp = Date(timeIntervalSince1970: 2_000_000_000)
        let batch = SunclubChangeBatch(
            createdAt: timestamp.addingTimeInterval(-10),
            logicalOrder: 42,
            serverReceivedAt: timestamp,
            kind: .historyEdit,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: "remote-device",
            summary: "Round trip"
        )
        let record = DailyRecordRevision(
            batch: batch,
            snapshot: Self.recordSnapshot(day: timestamp, spfLevel: 50, notes: "Round trip"),
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        )
        let settings = SettingsRevision(
            batch: batch,
            snapshot: Self.settingsSnapshot(reminderHour: 10),
            changedFields: [.reminderHour]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let decodedBatch = try decoder.decode(BatchWire.self, from: encoder.encode(BatchWire(batch: batch)))
        let decodedRecord = try decoder.decode(
            RecordRevisionWire.self,
            from: encoder.encode(RecordRevisionWire(revision: record))
        )
        let decodedSettings = try decoder.decode(
            SettingsRevisionWire.self,
            from: encoder.encode(SettingsRevisionWire(revision: settings))
        )
        XCTAssertEqual(decodedBatch.logicalOrder, 42)
        XCTAssertEqual(decodedBatch.serverReceivedAt, timestamp)
        XCTAssertEqual(decodedRecord.logicalOrder, 42)
        XCTAssertEqual(decodedRecord.serverReceivedAt, timestamp)
        XCTAssertEqual(decodedSettings.logicalOrder, 42)
        XCTAssertEqual(decodedSettings.serverReceivedAt, timestamp)

        let legacyBatch = Self.remoteBatch(createdAt: timestamp, summary: "Legacy")
        let decodedLegacy = try decoder.decode(
            BatchWire.self,
            from: encoder.encode(BatchWire(batch: legacyBatch))
        )
        XCTAssertNil(decodedLegacy.logicalOrder)
        XCTAssertNil(decodedLegacy.serverReceivedAt)
    }

    func testTombstoneWireDerivesDeletionFromMissingSnapshot() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let revision = DailyRecordRevision(
            batchID: UUID(),
            createdAt: day,
            authorDeviceID: "legacy-device",
            startOfDay: day,
            isDeleted: false,
            verifiedAt: nil,
            methodRawValue: nil,
            verificationDuration: nil,
            spfLevel: nil,
            notes: nil,
            reapplyCount: 0,
            lastReappliedAt: nil,
            changedFields: [.isDeleted],
            batchKind: .deleteRecord
        )

        XCTAssertFalse(revision.isDeleted)
        XCTAssertNil(revision.snapshot)
        XCTAssertTrue(RecordRevisionWire(revision: revision).isDeleted)
    }

    private static func recordSnapshot(
        day: Date,
        spfLevel: Int,
        notes: String?
    ) -> DailyRecordProjectionSnapshot {
        DailyRecordProjectionSnapshot(
            startOfDay: day,
            verifiedAt: day.addingTimeInterval(9 * 60 * 60),
            methodRawValue: VerificationMethod.manual.rawValue,
            verificationDuration: nil,
            spfLevel: spfLevel,
            notes: notes,
            reapplyCount: 0,
            lastReappliedAt: nil
        )
    }

    private static func settingsSnapshot(reminderHour: Int) -> SettingsProjectionSnapshot {
        SettingsProjectionSnapshot(
            hasCompletedOnboarding: true,
            reminderHour: reminderHour,
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

    private static func recordRevision(
        id: UUID,
        batch: SunclubChangeBatch,
        snapshot: DailyRecordProjectionSnapshot
    ) -> DailyRecordRevision {
        DailyRecordRevision(
            id: id,
            batchID: batch.id,
            createdAt: batch.createdAt,
            logicalOrder: batch.logicalOrder,
            serverReceivedAt: batch.serverReceivedAt,
            authorDeviceID: batch.authorDeviceID,
            startOfDay: snapshot.startOfDay,
            isDeleted: false,
            verifiedAt: snapshot.verifiedAt,
            methodRawValue: snapshot.methodRawValue,
            verificationDuration: snapshot.verificationDuration,
            spfLevel: snapshot.spfLevel,
            notes: snapshot.notes,
            reapplyCount: snapshot.reapplyCount,
            lastReappliedAt: snapshot.lastReappliedAt,
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes],
            batchKind: batch.kind
        )
    }

    private static func remoteBatch(
        id: UUID = UUID(),
        createdAt: Date,
        logicalOrder: Int64? = nil,
        summary: String
    ) -> SunclubChangeBatch {
        SunclubChangeBatch(
            id: id,
            createdAt: createdAt,
            logicalOrder: logicalOrder,
            kind: .historyEdit,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: "remote-device",
            summary: summary
        )
    }
}

private enum TestMutationError: Error, Equatable {
    case injected
}
