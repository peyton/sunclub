import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class PreImportSettingsUndoTests: XCTestCase {
    private let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))

    // Recent Updates still exposes settings batches created before the import.
    func testUndoImportReplaysUndoAndRedoOfPreImportSettings() throws {
        for scenario in [(steps: 1, hour: 8, weekly: 18), (steps: 2, hour: 6, weekly: 22), (steps: 3, hour: 8, weekly: 18)] {
            let history = try makeHistory()
            let edit = try XCTUnwrap(history.applySettingsChange(
                kind: .reminderSettings, summary: "Before import", changedFields: [.reminderHour]
            ) { $0.reminderHour = 6 })
            let session = try importBackup(into: history)
            _ = try history.applySettingsChange(
                kind: .reminderSettings, summary: "After import", changedFields: [.weeklyHour]
            ) { $0.weeklyHour = 22 }
            _ = try history.undo(batchID: edit.id)
            if scenario.steps > 1 {
                let redo = try history.redo(batchID: edit.id)
                if scenario.steps > 2 { _ = try history.undo(batchID: redo.id) }
            }

            _ = try history.restoreImportSession(session)
            try history.refreshProjectedState()

            XCTAssertEqual(try history.settings().reminderHour, scenario.hour)
            XCTAssertEqual(try history.settings().weeklyHour, scenario.weekly)
            XCTAssertFalse(try history.settings().usesLiveUV)
            XCTAssertNil(try history.record(for: day))
        }
    }

    // Imported historical revisions can sort between the original target and its predecessor.
    func testPreImportCheckpointExcludesInterleavedImportedSnapshots() throws {
        let (history, session, edit) = try interleavedImport()
        _ = try history.undo(batchID: edit.id)
        XCTAssertEqual(try history.settings().reminderHour, 10)
        XCTAssertTrue(try history.settings().usesLiveUV)

        _ = try history.restoreImportSession(session)
        try history.refreshProjectedState()

        XCTAssertEqual(try history.settings().reminderHour, 8)
        XCTAssertEqual(try history.settings().weeklyHour, 21)
        XCTAssertFalse(try history.settings().usesLiveUV)
        XCTAssertNil(try history.record(for: day))
    }

    func testPreImportCheckpointRejectsMismatchedImportOwnershipAtomically() throws {
        let (history, session, edit) = try interleavedImport()
        _ = try history.undo(batchID: edit.id)
        let cloned = try XCTUnwrap(history.changeBatches().first {
            $0.importSessionID == session && $0.kind == .reminderSettings
        })
        cloned.importSessionID = nil
        try history.fetchContext().save()
        let before = try history.settings().projectionSnapshot
        let beforeIDs = Set(try history.changeBatches().map(\.id))

        XCTAssertThrowsError(try history.restoreImportSession(session))

        XCTAssertEqual(try history.settings().projectionSnapshot, before)
        XCTAssertEqual(Set(try history.changeBatches().map(\.id)), beforeIDs)
        XCTAssertEqual(try history.record(for: day)?.notes, "Imported")
    }

    func testPreImportInverseWithChangedRawSnapshotFailsAtomically() throws {
        let history = try makeHistory()
        let edit = try XCTUnwrap(history.applySettingsChange(
            kind: .reminderSettings, summary: "Before import", changedFields: [.reminderHour]
        ) { $0.reminderHour = 6 })
        let session = try importBackup(into: history)
        let undo = try history.undo(batchID: edit.id)
        let inverse = try XCTUnwrap(history.settingsRevision(forBatchID: undo.id))
        inverse.reminderHour = 23
        try history.fetchContext().save()
        try history.refreshProjectedState()
        let before = try history.settings().projectionSnapshot
        let beforeIDs = Set(try history.changeBatches().map(\.id))

        XCTAssertThrowsError(try history.restoreImportSession(session))

        XCTAssertEqual(try history.settings().projectionSnapshot, before)
        XCTAssertEqual(Set(try history.changeBatches().map(\.id)), beforeIDs)
        XCTAssertEqual(try history.record(for: day)?.notes, "Imported")
    }

    private func makeHistory() throws -> SunclubHistoryService {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let history = SunclubHistoryService(context: ModelContext(container))
        try history.bootstrapIfNeeded()
        return history
    }

    private func interleavedImport() throws -> (SunclubHistoryService, UUID, SunclubChangeBatch) {
        let history = try makeHistory()
        _ = try history.applySettingsChange(
            kind: .reminderSettings, summary: "Earlier local choice", changedFields: [.weeklyHour]
        ) { $0.weeklyHour = 21 }
        let edit = try XCTUnwrap(history.applySettingsChange(
            kind: .reminderSettings, summary: "Before import", changedFields: [.reminderHour]
        ) { $0.reminderHour = 6 })
        edit.logicalOrder = 100
        try XCTUnwrap(history.settingsRevision(forBatchID: edit.id)).logicalOrder = 100
        try history.fetchContext().save()
        return (history, try importBackup(into: history, settingsOrder: 50), edit)
    }

    private func importBackup(into history: SunclubHistoryService, settingsOrder: Int64 = 0) throws -> UUID {
        let source = try makeHistory()
        let edit = try XCTUnwrap(source.applySettingsChange(
            kind: .reminderSettings, summary: "Imported settings", changedFields: [.reminderHour, .usesLiveUV]
        ) {
            $0.reminderHour = 10
            $0.usesLiveUV = true
        })
        if settingsOrder > 0 {
            edit.logicalOrder = settingsOrder
            try XCTUnwrap(source.settingsRevision(forBatchID: edit.id)).logicalOrder = settingsOrder
        }
        _ = try source.applyDayChange(
            for: day, kind: .historyEdit, summary: "Imported log", changedFields: [.verifiedAt, .notes]
        ) { _ in
            DailyRecordProjectionSnapshot(
                startOfDay: self.day, verifiedAt: self.day.addingTimeInterval(9 * 3_600),
                methodRawValue: VerificationMethod.manual.rawValue, verificationDuration: nil,
                spfLevel: 30, notes: "Imported", reapplyCount: 0, lastReappliedAt: nil
            )
        }
        let backups = SunclubBackupService()
        let document = try backups.exportDocument(from: source.fetchContext())
        return try backups.importBackupDocument(
            SunclubBackupDocument(data: document.serializedData()), into: history.fetchContext()
        ).importSessionID
    }
}
