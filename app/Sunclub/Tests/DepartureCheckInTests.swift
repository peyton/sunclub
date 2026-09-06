import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class DepartureCheckInTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private let now = Date(timeIntervalSince1970: 1_800_014_400)

    private func makeHistory() throws -> SunclubHistoryService {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let history = SunclubHistoryService(context: ModelContext(container), calendar: calendar)
        try history.bootstrapIfNeeded()
        return history
    }

    func testDepartureIsDurableIdempotentAndNeverAnApplication() throws {
        let history = try makeHistory()
        XCTAssertNotNil(try history.recordDeparture(at: now))
        XCTAssertNil(try history.recordDeparture(at: now.addingTimeInterval(60)))
        XCTAssertTrue(try history.records().isEmpty)
        XCTAssertFalse(try history.isEffectivelyEmptyForInitialICloudRestore())
        let reopened = SunclubHistoryService(context: history.fetchContext(), calendar: calendar)
        XCTAssertEqual(try reopened.departureCheckIns().count, 1)
        let snapshot = try XCTUnwrap(reopened.departureCheckIns().first)
        XCTAssertEqual(snapshot.resolution, .unconfirmed)
        XCTAssertFalse(snapshot.isActive(at: now.addingTimeInterval(86400), calendar: calendar))
    }

    func testConfirmationUsesActualTimeAndUndoesTogether() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        let checkIn = try XCTUnwrap(history.departureCheckIns().first)
        let appliedAt = now.addingTimeInterval(-900)
        let batch = try XCTUnwrap(history.resolveDeparture(id: checkIn.id,
            action: .confirm(appliedAt: appliedAt, spfLevel: 50, notes: " Face "), now: now))
        XCTAssertEqual(try history.record(for: now)?.verifiedAt, appliedAt)
        XCTAssertEqual(try history.record(for: now)?.notes, "Face")
        XCTAssertEqual(try history.departureCheckIns().first?.linkedApplicationAt, appliedAt)
        XCTAssertNil(try history.resolveDeparture(id: checkIn.id,
            action: .confirm(appliedAt: now, spfLevel: 30, notes: nil), now: now))
        _ = try history.undoChangeIfCurrent(batchID: batch.id)
        XCTAssertNil(try history.record(for: now))
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .unconfirmed)
    }

    func testFailedConfirmationRollsBackBothWrites() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        let checkIn = try XCTUnwrap(history.departureCheckIns().first)
        let failing = SunclubHistoryService(context: history.fetchContext(), calendar: calendar) {
            throw NSError(domain: "SaveFailure", code: 1)
        }
        XCTAssertThrowsError(try failing.resolveDeparture(id: checkIn.id,
            action: .confirm(appliedAt: now, spfLevel: nil, notes: nil), now: now))
        XCTAssertNil(try history.record(for: now))
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .unconfirmed)
    }

    func testSnoozePersistsAndDismissalDoesNotLog() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        let checkIn = try XCTUnwrap(history.departureCheckIns().first)
        _ = try history.resolveDeparture(id: checkIn.id, action: .snooze(until: now.addingTimeInterval(900)), now: now)
        try history.refreshProjectedState()
        XCTAssertFalse(try XCTUnwrap(history.departureCheckIns().first).isActive(at: now, calendar: calendar))
        _ = try history.resolveDeparture(id: checkIn.id, action: .dismiss, now: now)
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .dismissed)
        XCTAssertTrue(try history.records().isEmpty)
    }

    func testCloudBatchRoundTripAndOldPayloadDecode() throws {
        let source = try makeHistory()
        let batch = try XCTUnwrap(source.recordDeparture(at: now))
        let wire = BatchWire(batch: batch, departureCheckInRevisions: try source.departureCheckInWires(for: batch.id))
        let decoded = try JSONDecoder().decode(BatchWire.self, from: JSONEncoder().encode(wire))
        let target = try makeHistory()
        try target.upsertRemoteBatch(decoded)
        try target.upsertRemoteBatch(decoded)
        XCTAssertEqual(try target.departureCheckIns(), try source.departureCheckIns())
        let legacy = try JSONDecoder().decode(BatchWire.self, from: JSONEncoder().encode(BatchWire(batch: batch)))
        XCTAssertNil(legacy.departureCheckInRevisions)
    }

    func testImportUndoPreservesLaterLocalResolution() throws {
        let source = try makeHistory()
        _ = try source.recordDeparture(at: now)
        let target = try makeHistory()
        let result = try target.importDomainData(from: source.fetchContext(), sourceDescription: "Check-ins")
        let checkIn = try XCTUnwrap(target.departureCheckIns().first)
        _ = try target.resolveDeparture(id: checkIn.id, action: .dismiss, now: now)
        _ = try target.restoreImportSession(result.importSessionID)
        XCTAssertEqual(try target.departureCheckIns().first?.resolution, .dismissed)
    }

    func testImportUndoRemovesOnlyImportedCheckIn() throws {
        let source = try makeHistory()
        _ = try source.recordDeparture(at: now)
        let target = try makeHistory()
        let result = try target.importDomainData(from: source.fetchContext(), sourceDescription: "Check-ins")
        XCTAssertEqual(try target.departureCheckIns().count, 1)
        _ = try target.restoreImportSession(result.importSessionID)
        XCTAssertTrue(try target.departureCheckIns().isEmpty)
    }

    func testBackupRoundTripRetainsCheckInsWithoutInflatingRecordCount() throws {
        let source = try makeHistory()
        _ = try source.recordDeparture(at: now)
        let backup = SunclubBackupService()
        let document = try backup.exportDocument(from: source.fetchContext())
        let decoded = try SunclubBackupDocument(data: document.serializedData())
        let target = try makeHistory()
        let summary = try backup.importBackupDocument(decoded, into: target.fetchContext())
        XCTAssertEqual(summary.restoredRecordCount, 0)
        XCTAssertEqual(summary.restoredCheckInCount, 1)
        XCTAssertEqual(try target.departureCheckIns(), try source.departureCheckIns())
    }

    func testLoggingFromAnySurfaceResolvesAndUndoRestoresCheckIn() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        let mutation = SunclubMutationService(history: history, calendar: calendar)
        let result = try mutation.upsert(.init(day: now, verifiedAt: now, method: .quickLog,
            spfLevel: 30, notes: nil, replaceOptionalFields: false, preserveExistingDuration: false,
            kind: .manualLog, summary: "Widget log"))
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .confirmed)
        _ = try history.undoChangeIfCurrent(batchID: XCTUnwrap(result.batch).id)
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .unconfirmed)
    }

    func testLateDuplicateDepartureDoesNotEraseConfirmedApplication() throws {
        let first = try makeHistory()
        _ = try first.recordDeparture(at: now)
        let checkIn = try XCTUnwrap(first.departureCheckIns().first)
        _ = try first.resolveDeparture(id: checkIn.id,
            action: .confirm(appliedAt: now, spfLevel: nil, notes: nil), now: now)
        let second = try makeHistory()
        let duplicate = try XCTUnwrap(second.recordDeparture(at: now.addingTimeInterval(60)))
        duplicate.logicalOrder = 100
        try first.upsertRemoteBatch(BatchWire(batch: duplicate,
            departureCheckInRevisions: second.departureCheckInWires(for: duplicate.id)))
        XCTAssertEqual(try first.departureCheckIns().count, 1)
        XCTAssertEqual(try first.departureCheckIns().first?.resolution, .confirmed)
        let deletion = try XCTUnwrap(first.deleteAllRecords())
        _ = try first.undo(batchID: deletion.id)
        XCTAssertEqual(try first.departureCheckIns().first?.id, checkIn.id)
        XCTAssertEqual(try first.departureCheckIns().first?.resolution, .confirmed)
        XCTAssertNotNil(try first.record(for: now))
    }

    func testDeletingHistoryIncludesUnconfirmedCheckInsAndCanBeUndone() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        let deletion = try XCTUnwrap(history.deleteAllRecords())
        XCTAssertTrue(try history.departureCheckIns().isEmpty)
        _ = try history.undo(batchID: deletion.id)
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .unconfirmed)
    }

    func testFutureConfirmationFailsAndPriorDayActionsDoNotChangeHistory() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        let checkIn = try XCTUnwrap(history.departureCheckIns().first)
        XCTAssertThrowsError(try history.resolveDeparture(id: checkIn.id,
            action: .confirm(appliedAt: now.addingTimeInterval(1), spfLevel: nil, notes: nil), now: now))
        XCTAssertNil(try history.resolveDeparture(id: checkIn.id, action: .dismiss, now: now.addingTimeInterval(86400)))
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .unconfirmed)
        XCTAssertTrue(try history.records().isEmpty)
    }

    func testConfirmationUndoRejectsLaterRemoteCheckInOnlyRevision() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        var checkIn = try XCTUnwrap(history.departureCheckIns().first)
        let confirmation = try XCTUnwrap(history.resolveDeparture(id: checkIn.id,
            action: .confirm(appliedAt: now, spfLevel: nil, notes: nil), now: now))
        let remote = SunclubChangeBatch(logicalOrder: 100, kind: .departureCheckIn, scope: .day,
            scopeIdentifier: "remote", authorDeviceID: "other-device", summary: "Dismissed on another device")
        checkIn.resolution = .dismissed
        let revision = try DepartureCheckInRevision(batchID: remote.id, day: checkIn.day, snapshot: checkIn)
        try history.upsertRemoteBatch(BatchWire(batch: remote,
            departureCheckInRevisions: [DepartureCheckInRevisionWire(revision: revision)]))
        XCTAssertFalse(try history.canUndoChangeIfCurrent(batchID: confirmation.id))
        XCTAssertThrowsError(try history.undoChangeIfCurrent(batchID: confirmation.id))
        XCTAssertNotNil(try history.record(for: now))
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .dismissed)
    }

    func testImportUnconfirmedAndDeletedHistoryPreservesLocalResolution() throws {
        for deletesImportedCheckIn in [false, true] {
            let target = try makeHistory()
            _ = try target.recordDeparture(at: now)
            let local = try XCTUnwrap(target.departureCheckIns().first)
            _ = try target.resolveDeparture(id: local.id, action: .dismiss, now: now)
            let source = try makeHistory()
            _ = try source.recordDeparture(at: now)
            if deletesImportedCheckIn {
                _ = try source.deleteAllRecords()
            }
            for batch in try source.changeBatches() { batch.logicalOrder = (batch.logicalOrder ?? 0) + 100 }
            try source.fetchContext().save()
            let result = try target.importDomainData(from: source.fetchContext(), sourceDescription: "Old backup")
            XCTAssertEqual(try target.departureCheckIns().first?.id, local.id)
            XCTAssertEqual(try target.departureCheckIns().first?.resolution, .dismissed)
            _ = try target.restoreImportSession(result.importSessionID)
            XCTAssertEqual(try target.departureCheckIns().first?.resolution, .dismissed)
        }
    }

    func testImportUndoUsesEffectiveOwnerAfterIgnoredRemoteDuplicate() throws {
        let source = try makeHistory()
        _ = try source.recordDeparture(at: now)
        let original = try XCTUnwrap(source.departureCheckIns().first)
        _ = try source.resolveDeparture(id: original.id,
            action: .confirm(appliedAt: now, spfLevel: nil, notes: nil), now: now)
        let target = try makeHistory()
        let imported = try target.importDomainData(from: source.fetchContext(), sourceDescription: "Confirmed backup")
        let remote = try makeHistory()
        let batch = try XCTUnwrap(remote.recordDeparture(at: now))
        batch.logicalOrder = 100
        try target.upsertRemoteBatch(BatchWire(batch: batch,
            departureCheckInRevisions: remote.departureCheckInWires(for: batch.id)))
        XCTAssertEqual(try target.departureCheckIns().first?.id, original.id)
        _ = try target.restoreImportSession(imported.importSessionID)
        XCTAssertTrue(try target.departureCheckIns().isEmpty)
    }

    func testOfflineSameIdentitySnoozeCannotReopenConfirmedCheckIn() throws {
        let history = try makeHistory()
        _ = try history.recordDeparture(at: now)
        var staleSnapshot = try XCTUnwrap(history.departureCheckIns().first)
        _ = try history.resolveDeparture(id: staleSnapshot.id,
            action: .confirm(appliedAt: now, spfLevel: nil, notes: nil), now: now)
        staleSnapshot.snoozedUntil = now.addingTimeInterval(900)
        let remote = SunclubChangeBatch(logicalOrder: 100, kind: .departureCheckIn, scope: .day,
            scopeIdentifier: "offline", authorDeviceID: "offline-device", summary: "Snoozed while offline")
        let revision = try DepartureCheckInRevision(batchID: remote.id, day: staleSnapshot.day, snapshot: staleSnapshot)
        try history.upsertRemoteBatch(BatchWire(batch: remote,
            departureCheckInRevisions: [DepartureCheckInRevisionWire(revision: revision)]))
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .confirmed)
        XCTAssertNil(try history.departureCheckIns().first?.snoozedUntil)
        let deletion = try XCTUnwrap(history.applyDayChange(for: now, kind: .deleteRecord,
            summary: "Delete mistaken log", changedFields: [.isDeleted]) { _ in nil })
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .unconfirmed)
        _ = try history.undoChangeIfCurrent(batchID: deletion.id)
        XCTAssertEqual(try history.departureCheckIns().first?.resolution, .confirmed)
    }

    func testV5MigrationPreservesRecordsAndAddsEmptyCheckInHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        do {
            let schema = Schema(versionedSchema: SunclubSchemaV5.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            let context = ModelContext(container)
            context.insert(DailyRecord(startOfDay: calendar.startOfDay(for: now), verifiedAt: now, method: .manual, spfLevel: 50))
            try context.save()
        }
        let migrated = try SunclubModelContainerFactory.makeDiskBackedContainer(url: url)
        let history = SunclubHistoryService(context: ModelContext(migrated), calendar: calendar)
        XCTAssertEqual(try history.records().first?.spfLevel, 50)
        XCTAssertTrue(try history.departureCheckIns().isEmpty)
        XCTAssertNotNil(try history.recordDeparture(at: now.addingTimeInterval(86400)))
    }
}
