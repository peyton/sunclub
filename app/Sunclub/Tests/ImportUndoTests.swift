import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class ImportUndoTests: XCTestCase {
    private let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))

    // Catches Undo Import reporting success while a backup-only day remains in the projection.
    func testUndoRemovesUnchangedBackupOnlyDaysAndRestoresOriginalHistory() throws {
        let target = try makeHistory()
        let originalDay = day.addingTimeInterval(-86_400)
        try write("Original", on: originalDay, in: target)
        let sessionID = try importBackup(into: target)
        let importedRevisions = try target.fetchContext().fetch(FetchDescriptor<DailyRecordRevision>()).map(\.id)
        XCTAssertEqual(try target.record(for: day)?.notes, "Imported")

        let undo = try target.restoreImportSession(sessionID)

        XCTAssertNil(try target.record(for: day))
        XCTAssertEqual(try target.record(for: originalDay)?.notes, "Original")
        XCTAssertEqual(try target.records().count, 1)
        XCTAssertTrue(undo.isLocalOnly)
        let revisions = try target.fetchContext().fetch(FetchDescriptor<DailyRecordRevision>())
        XCTAssertTrue(Set(importedRevisions).isSubset(of: Set(revisions.map(\.id))))
        XCTAssertTrue(revisions.contains { $0.batchID == undo.id && $0.startOfDay == day && $0.snapshot == nil })
        try target.refreshProjectedState()
        XCTAssertNil(try target.record(for: day))
    }

    // Catches a blanket deletion of every day absent from the restore point.
    func testUndoPreservesAnImportedDayEditedAfterImport() throws {
        let target = try makeHistory()
        let sessionID = try importBackup(into: target)
        try write("My later edit", on: day, in: target)

        _ = try target.restoreImportSession(sessionID)

        XCTAssertEqual(try target.record(for: day)?.notes, "My later edit")
    }

    func testUndoPreservesUnrelatedDaysLoggedAfterImport() throws {
        let target = try makeHistory()
        let sessionID = try importBackup(into: target)
        let laterDay = day.addingTimeInterval(86_400)
        try write("My new log", on: laterDay, in: target)

        _ = try target.restoreImportSession(sessionID)

        XCTAssertNil(try target.record(for: day))
        XCTAssertEqual(try target.record(for: laterDay)?.notes, "My new log")
    }

    // Snapshot equality alone cannot distinguish a new user-owned replacement from the imported revision.
    func testUndoPreservesAnIdenticalReplacementRevision() throws {
        let target = try makeHistory()
        let sessionID = try importBackup(into: target)
        _ = try target.applyDayChange(
            for: day, kind: .deleteRecord, summary: "Delete", changedFields: [.isDeleted]
        ) { _ in nil }
        try write("Imported", on: day, in: target)

        _ = try target.restoreImportSession(sessionID)

        XCTAssertEqual(try target.record(for: day)?.notes, "Imported")
    }

    // A rejected tombstone must roll back with the rest of the restore operation and remain retryable.
    func testFailedUndoKeepsImportedDaysAndRetryRemovesThem() throws {
        let gate = ImportUndoMutationGate()
        let target = try makeHistory(gate: gate)
        let sessionID = try importBackup(into: target)
        let beforeIDs = Set(try target.changeBatches().map(\.id))
        gate.rejectsChanges = true

        XCTAssertThrowsError(try target.restoreImportSession(sessionID))

        XCTAssertEqual(try target.record(for: day)?.notes, "Imported")
        XCTAssertEqual(Set(try target.changeBatches().map(\.id)), beforeIDs)
        gate.rejectsChanges = false
        _ = try target.restoreImportSession(sessionID)
        XCTAssertNil(try target.record(for: day))
    }

    func testRepeatedUndoCannotDeleteANewLogOnTheSameDay() throws {
        let target = try makeHistory()
        let sessionID = try importBackup(into: target)
        _ = try target.restoreImportSession(sessionID)
        XCTAssertNil(try target.record(for: day))
        try write("Logged after Undo", on: day, in: target)

        _ = try target.restoreImportSession(sessionID)

        XCTAssertEqual(try target.record(for: day)?.notes, "Logged after Undo")
    }

    // A restore tombstone must not be auto-merged back into its foreign-author predecessor.
    func testUndoRemainsDeletedWhenTheImportWasWrittenByAnotherDevice() throws {
        let target = try makeHistory()
        let sessionID = try importBackup(into: target)
        let preference = try target.syncPreference()
        preference.deviceID = "replacement-device"
        try target.fetchContext().save()

        _ = try target.restoreImportSession(sessionID)
        try target.refreshProjectedState()

        XCTAssertNil(try target.record(for: day))
    }

    private func makeHistory(gate: ImportUndoMutationGate? = nil) throws -> SunclubHistoryService {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let history = SunclubHistoryService(context: ModelContext(container), mutationGuard: { try gate?.check() })
        try history.bootstrapIfNeeded()
        return history
    }

    private func importBackup(into target: SunclubHistoryService) throws -> UUID {
        let source = try makeHistory()
        try write("Imported", on: day, in: source)
        let backups = SunclubBackupService()
        let document = try backups.exportDocument(from: source.fetchContext())
        let decoded = try SunclubBackupDocument(data: document.serializedData())
        return try backups.importBackupDocument(decoded, into: target.fetchContext()).importSessionID
    }

    private func write(_ notes: String, on date: Date, in history: SunclubHistoryService) throws {
        _ = try history.applyDayChange(
            for: date, kind: .historyEdit, summary: "Edit log", changedFields: [.verifiedAt, .notes]
        ) { _ in
            DailyRecordProjectionSnapshot(
                startOfDay: date, verifiedAt: date.addingTimeInterval(9 * 3_600),
                methodRawValue: VerificationMethod.manual.rawValue, verificationDuration: nil,
                spfLevel: 30, notes: notes, reapplyCount: 0, lastReappliedAt: nil
            )
        }
    }
}

private final class ImportUndoMutationGate {
    var rejectsChanges = false
    func check() throws {
        if rejectsChanges { throw CocoaError(.fileWriteUnknown) }
    }
}
