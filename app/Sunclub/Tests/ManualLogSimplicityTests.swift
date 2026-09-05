import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class ManualLogSimplicityTests: SunclubTestCase {
    // Catches truncation that silently loses either the draft or selected coverage.
    func testLongDraftRetainsProseAndEverySelectedAreaForValidation() {
        let prose = String(repeating: "x", count: 270)

        let serialized = SunManualLogInput.notesWithCoveredAreas(
            prose, areas: ["Face", "Neck", "Ears", "Body"]
        )

        XCTAssertEqual(serialized, prose + "\nAreas: Face, Neck, Ears, Body")
        XCTAssertEqual(SunManualLogInput.coveredAreas(in: serialized), ["Face", "Neck", "Ears", "Body"])
        XCTAssertEqual(SunManualLogInput.notesRemovingCoveredAreas(serialized), prose)
    }

    // Catches Save accepting a payload that persistence would truncate after adding coverage.
    func testCoverageChangeRequiresCorrectionBeforeOversizedDraftCanSave() {
        let prose = String(repeating: "x", count: 251)
        XCTAssertNotNil(SunManualLogInput.validatedNotesWithCoveredAreas(prose, areas: []))
        XCTAssertNil(SunManualLogInput.validatedNotesWithCoveredAreas(prose, areas: ["Face", "Neck", "Ears", "Body"]))
    }

    // Catches off-by-one capacity handling: 250 prose + newline + 29 metadata characters fits.
    func testCoverageMetadataFitsAtSerializedNoteBoundary() {
        let prose = String(repeating: "x", count: 250)
        XCTAssertEqual(
            SunManualLogInput.validatedNotesWithCoveredAreas(prose, areas: ["Face", "Neck", "Ears", "Body"]),
            prose + "\nAreas: Face, Neck, Ears, Body"
        )
    }

    // Catches accepting a partial list as metadata and deleting ordinary prose.
    func testIncompleteOrUnknownAreasLinesRemainOrdinaryProse() {
        let examples = [
            "Areas: Face, shoulders",
            "Areas: Face,",
            "Areas:",
            "Areas: Face needs another application",
            "Areas: Face,, Neck"
        ]

        for prose in examples {
            XCTAssertEqual(SunManualLogInput.notesRemovingCoveredAreas(prose), prose)
            XCTAssertTrue(SunManualLogInput.coveredAreas(in: prose).isEmpty)
        }
    }

    // Catches recognizing an Areas line embedded in a paragraph as structured data.
    func testOnlyTrailingCompleteAreasMetadataIsRemoved() {
        let prose = "Areas: Face\nRemember to cover the ears tomorrow."

        XCTAssertEqual(SunManualLogInput.notesRemovingCoveredAreas(prose), prose)
        XCTAssertTrue(SunManualLogInput.coveredAreas(in: prose).isEmpty)
        XCTAssertEqual(
            SunManualLogInput.notesRemovingCoveredAreas(prose + "\nAreas: Neck, Ears"),
            prose
        )
        XCTAssertEqual(SunManualLogInput.coveredAreas(in: prose + "\nAreas: Neck, Ears"), ["Neck", "Ears"])
    }

    // Catches dropping an ordinary Areas-prefixed note while adding selected coverage.
    func testSerializingCoveragePreservesAreasPrefixedProse() {
        XCTAssertEqual(
            SunManualLogInput.notesWithCoveredAreas("Areas: shoulders need attention", areas: ["Body"]),
            "Areas: shoulders need attention\nAreas: Body"
        )
    }

    // Catches inventing coverage for older records or requiring a nonempty selection.
    func testUnspecifiedCoverageRemainsUnspecified() {
        XCTAssertTrue(SunManualLogInput.coveredAreas(in: "Morning walk").isEmpty)
        XCTAssertEqual(SunManualLogInput.notesWithCoveredAreas("Morning walk", areas: []), "Morning walk")
        XCTAssertEqual(SunManualLogInput.notesWithCoveredAreas("", areas: []), "")
    }

    // Catches displaying internal metadata in the explicit-reuse suggestion.
    func testReuseSuggestionDisplaysOnlyProse() throws {
        let record = fixtureRecord(day: 3, spf: 50, notes: "Beach walk\nAreas: Ears, Body")

        let suggestion = try XCTUnwrap(ManualLogSuggestionEngine.suggestions(from: [record]).sameAsLastTime)

        XCTAssertEqual(suggestion.spfLevel, 50)
        XCTAssertEqual(suggestion.note, "Beach walk")
        XCTAssertEqual(suggestion.detail, "SPF 50 · Beach walk")
    }

    // Catches reuse retaining a previous SPF/coverage or pasting serialized metadata as prose.
    func testExplicitReuseReplacesAllFieldsIncludingMissingSPF() {
        let suggestion = ManualLogReuseSuggestion(spfLevel: nil, note: "Beach walk\nAreas: Body")
        var spf: Int? = 70
        var notes = "Old draft"
        var areas: Set<String> = ["Face", "Neck"]

        suggestion.apply(toSPF: &spf, notes: &notes, areas: &areas)

        XCTAssertNil(spf)
        XCTAssertEqual(notes, "Beach walk")
        XCTAssertEqual(areas, ["Body"])
    }

    // Catches absent notes/coverage in an explicitly reused log retaining unrelated draft values.
    func testExplicitReuseClearsMissingNotesAndCoverage() {
        let suggestion = ManualLogReuseSuggestion(spfLevel: 30, note: nil)
        var spf: Int? = 70
        var notes = "Old draft"
        var areas: Set<String> = ["Face", "Neck"]

        suggestion.apply(toSPF: &spf, notes: &notes, areas: &areas)

        XCTAssertEqual(spf, 30)
        XCTAssertEqual(notes, "")
        XCTAssertTrue(areas.isEmpty)
    }

    // Catches suggesting metadata-only notes and treating identical prose as distinct.
    func testNoteSuggestionsIgnoreCoverageMetadataWhenDeduplicating() {
        let records = [
            fixtureRecord(day: 4, spf: 50, notes: "Morning walk\nAreas: Face"),
            fixtureRecord(day: 3, notes: "Beach walk\nAreas: Ears"),
            fixtureRecord(day: 2, notes: "Beach walk\nAreas: Body"),
            fixtureRecord(day: 1, notes: "Areas: Face, Neck")
        ]

        XCTAssertEqual(ManualLogSuggestionEngine.suggestions(from: records).noteSnippets, ["Beach walk"])
    }

    // Catches copying personal notes into automatic one-tap defaults.
    func testOneTapDefaultsReuseCoverageWithoutFreeFormNotes() {
        let records = [fixtureRecord(day: 3, spf: 50, notes: "Personal appointment\nAreas: Ears, Body")]

        let defaults = SunManualLogDefaultResolver.oneTapDefaults(from: records)

        XCTAssertEqual(defaults.spfLevel, 50)
        XCTAssertEqual(defaults.coveredAreas, ["Ears", "Body"])
        XCTAssertEqual(defaults.oneTapNotes, "Areas: Ears, Body")
    }

    // Catches routing editor Save through additive logging, which retains cleared values.
    func testExplicitEditPersistsClearedSPFAndNotes() throws {
        let state = try isolatedState()
        let timestamp = localDate(day: 3, hour: 9)
        _ = try savedReceipt(state.saveManualRecord(for: timestamp, verifiedAt: timestamp, spfLevel: 50, notes: "Morning walk"))

        let receipt = try savedReceipt(state.saveManualRecord(for: timestamp, verifiedAt: timestamp, spfLevel: nil, notes: ""))

        let record = try XCTUnwrap(state.record(for: timestamp))
        XCTAssertTrue(receipt.didChange)
        XCTAssertNil(record.spfLevel)
        XCTAssertNil(record.notes)
        XCTAssertEqual(record.verifiedAt, timestamp)
    }

    // Catches accidentally resolving the save target again from mutable History selection.
    func testFixedContextSavesOriginalDayAfterHistorySelectionChanges() throws {
        let state = try isolatedState()
        let timestamp = localDate(day: 2, hour: 9)
        let context = AppLogContext(date: timestamp, dayPart: .morning, source: .history)
        state.selectDay(localDate(day: 3, hour: 9))

        _ = try savedReceipt(state.saveManualRecord(
            for: context.date, dayPart: context.dayPart, verifiedAt: timestamp, spfLevel: nil, notes: "Original day"
        ))

        XCTAssertEqual(state.record(for: timestamp)?.notes, "Original day")
        XCTAssertNil(state.record(for: localDate(day: 3, hour: 9)))
    }

    // Catches extra revisions or success presentation when the saved values are unchanged.
    func testUnchangedSaveHasNoChangedReceiptOrSuccessPresentation() throws {
        let state = try isolatedState()
        let timestamp = localDate(day: 3, hour: 9)
        _ = try savedReceipt(state.saveManualRecord(for: timestamp, verifiedAt: timestamp, spfLevel: nil, notes: nil))
        state.clearVerificationSuccessPresentation()

        let receipt = try savedReceipt(state.saveManualRecord(for: timestamp, verifiedAt: timestamp, spfLevel: nil, notes: nil))

        XCTAssertFalse(receipt.didChange)
        XCTAssertNil(receipt.batchID)
        XCTAssertNil(state.verificationSuccessPresentation)
        XCTAssertEqual(state.records.count, 1)
    }

    // Catches an unchanged editor save changing a one-tap log's method and creating a revision.
    func testUnchangedEditOfQuickLogDoesNotCreateAnotherRevision() throws {
        let state = try isolatedState()
        let timestamp = localDate(day: 3, hour: 9)
        _ = try savedReceipt(state.recordApplication(
            for: .quickLog, part: .morning, on: timestamp, source: .quickLog,
            verifiedAt: timestamp, spfLevel: 50, notes: "Areas: Face"
        ))

        let receipt = try savedReceipt(state.saveManualRecord(
            for: timestamp, verifiedAt: timestamp, spfLevel: 50, notes: "Areas: Face"
        ))

        XCTAssertFalse(receipt.didChange)
        XCTAssertNil(receipt.batchID)
        XCTAssertEqual(state.record(for: timestamp)?.method, .quickLog)
    }

    // Catches receipt Undo Delete restoring old content over a replacement log.
    func testStaleDeleteUndoDoesNotOverwriteReplacementLog() throws {
        let state = try isolatedState()
        let timestamp = localDate(day: 3, hour: 9)
        _ = try savedReceipt(state.saveManualRecord(for: timestamp, verifiedAt: timestamp, spfLevel: 30, notes: "Original"))
        let deletion = try savedReceipt(state.deleteRecord(for: timestamp))
        let deletionID = try XCTUnwrap(deletion.batchID)
        _ = try savedReceipt(state.saveManualRecord(for: timestamp, verifiedAt: timestamp, spfLevel: 70, notes: "Replacement"))

        XCTAssertFalse(state.canUndoChangeIfCurrent(batchID: deletionID))
        if case .success = state.undoChangeIfCurrent(batchID: deletionID) {
            XCTFail("A stale deletion receipt must be rejected")
        }

        XCTAssertEqual(state.record(for: timestamp)?.spfLevel, 70)
        XCTAssertEqual(state.record(for: timestamp)?.notes, "Replacement")
    }

    private func localDate(day: Int, hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    private func savedReceipt(_ result: SunclubHistoryMutationResult) throws -> SunclubHistoryMutationReceipt {
        switch result {
        case let .success(receipt): return receipt
        case let .failure(error): throw error
        }
    }

    private func fixtureRecord(day: Int, spf: Int? = nil, notes: String?) -> DailyRecord {
        let timestamp = localDate(day: day, hour: 9)
        return DailyRecord(
            startOfDay: Calendar.current.startOfDay(for: timestamp),
            verifiedAt: timestamp,
            method: .manual,
            spfLevel: spf,
            notes: notes
        )
    }

    private func isolatedState() throws -> AppState {
        let suiteName = "manual-log-simplicity-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let now = localDate(day: 4, hour: 14)
        return try makeAppState(
            notificationManager: MockNotificationManager(),
            cloudSyncCoordinator: ProbeCloudSyncCoordinator(),
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: defaults),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            ),
            widgetSnapshotStore: SunclubWidgetSnapshotStore(userDefaults: defaults),
            clock: { now }
        )
    }
}
