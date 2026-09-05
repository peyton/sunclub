import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class ImportUndoRepresentationTests: XCTestCase {
    private let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))

    // Import-generated conflict merges are not independent user edits.
    func testUndoRemovesAnImportedOnlyDayAfterImportGeneratesAMerge() throws {
        let target = try makeHistory()
        let document = try rawBackup(.differingProjection)
        let summary = try SunclubBackupService().importBackupDocument(document, into: target.fetchContext())
        XCTAssertNotNil(try target.record(for: day))
        XCTAssertTrue(try target.changeBatches().contains { $0.kind == .conflictAutoMerge })

        _ = try target.restoreImportSession(summary.importSessionID)
        try target.refreshProjectedState()

        XCTAssertNil(try target.record(for: day))
    }

    func testUndoPreservesALaterIndependentMerge() throws {
        let target = try makeHistory()
        let summary = try SunclubBackupService().importBackupDocument(
            rawBackup(.differingProjection), into: target.fetchContext()
        )
        _ = try target.applyDayChange(
            for: day, kind: .historyEdit, summary: "Later edit", changedFields: [.notes]
        ) { snapshot in
            var edited = snapshot
            edited?.notes = "My first edit"
            return edited
        }
        let preference = try target.syncPreference()
        preference.deviceID = "another-user-device"
        try target.fetchContext().save()
        let laterEdit = try target.applyDayChange(
            for: day, kind: .historyEdit, summary: "Another edit", changedFields: [.notes]
        ) { snapshot in
            var edited = snapshot
            edited?.notes = "My latest edit"
            return edited
        }
        XCTAssertEqual(try target.record(for: day)?.notes, "My latest edit")
        let laterID = try XCTUnwrap(laterEdit?.id)
        XCTAssertTrue(try target.changeBatches().contains {
            $0.kind == .conflictAutoMerge && $0.inverseOfBatchID == laterID
        })

        _ = try target.restoreImportSession(summary.importSessionID)

        XCTAssertEqual(try target.record(for: day)?.notes, "My latest edit")
    }

    // Normalizing an unknown persisted method to manual must not make an import look like a later edit.
    func testUndoRemovesAnImportedOnlyDayWithAnUnknownMethod() throws {
        let target = try makeHistory()
        let summary = try SunclubBackupService().importBackupDocument(
            rawBackup(.unknownMethod), into: target.fetchContext()
        )
        XCTAssertEqual(try target.record(for: day)?.method, .manual)

        _ = try target.restoreImportSession(summary.importSessionID)
        try target.refreshProjectedState()

        XCTAssertNil(try target.record(for: day))
    }

    // Never report a successful Undo when inconsistent imported ordering prevents it from taking effect.
    func testUndoRejectsInconsistentOrderingAtomically() throws {
        let target = try makeHistory()
        let summary = try SunclubBackupService().importBackupDocument(
            rawBackup(.futureUnorderedRevision), into: target.fetchContext()
        )
        XCTAssertNotNil(try target.record(for: day))
        let beforeIDs = Set(try target.changeBatches().map(\.id))

        XCTAssertThrowsError(try target.restoreImportSession(summary.importSessionID)) { error in
            guard case HistoryServiceError.importUndoIncomplete = error else {
                return XCTFail("Expected an incomplete-Undo error, received \(error)")
            }
        }
        try target.refreshProjectedState()

        XCTAssertEqual(try target.record(for: day)?.notes, "Projected value")
        XCTAssertEqual(Set(try target.changeBatches().map(\.id)), beforeIDs)
    }

    // Automatic recovery of a user's older store is not a user-selected backup import to roll back.
    func testUndoLegacyRecoveryPreservesRecoveredOriginalHistory() throws {
        let source = try makeHistory()
        _ = try source.applyDayChange(
            for: day, kind: .manualLog, summary: "Original history", changedFields: [.verifiedAt, .notes]
        ) { _ in self.record().projectionSnapshot }
        let target = try makeHistory()
        let session = try XCTUnwrap(target.recoverLegacyDomainData(
            from: source.fetchContext(), sourceDescription: "Original legacy store"
        ))
        XCTAssertNotNil(try target.record(for: day))

        _ = try target.restoreImportSession(session.importSessionID)
        try target.refreshProjectedState()

        XCTAssertEqual(try target.record(for: day)?.notes, "Projected value")
    }

    private enum Representation {
        case differingProjection
        case unknownMethod
        case futureUnorderedRevision
    }

    private func rawBackup(_ representation: Representation) throws -> SunclubBackupDocument {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent(SunclubBackupService.storeFilename)
        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)
        let projected = record()
        if representation == .unknownMethod { projected.methodRawValue = 99 }
        context.insert(projected)
        if representation != .unknownMethod {
            let unordered = representation == .futureUnorderedRevision
            let batch = SunclubChangeBatch(
                createdAt: unordered ? Date().addingTimeInterval(366 * 86_400) : day,
                logicalOrder: unordered ? nil : 1,
                kind: unordered ? .conflictAutoMerge : .historyEdit,
                scope: .day, scopeIdentifier: "backup-day", authorDeviceID: "backup-device",
                summary: "Imported history"
            )
            var historical = projected.projectionSnapshot
            if representation == .differingProjection { historical.notes = "Historical value" }
            context.insert(batch)
            context.insert(DailyRecordRevision(batch: batch, snapshot: historical, changedFields: [.verifiedAt, .notes]))
        }
        try context.save()
        let files = try SunclubBackupService.storeFiles(at: storeURL)
        let document = SunclubBackupDocument(payload: SunclubBackupPayload(
            createdAt: Date(), schemaVersion: "5.0.0", storeFiles: files
        ))
        return try SunclubBackupDocument(data: document.serializedData())
    }

    private func makeHistory() throws -> SunclubHistoryService {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let history = SunclubHistoryService(context: ModelContext(container))
        try history.bootstrapIfNeeded()
        return history
    }

    private func record() -> DailyRecord {
        DailyRecord(startOfDay: day, verifiedAt: day.addingTimeInterval(9 * 3_600), method: .manual,
                    spfLevel: 30, notes: "Projected value")
    }
}
