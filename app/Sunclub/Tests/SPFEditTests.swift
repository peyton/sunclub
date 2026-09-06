import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SPFEditTests: SunclubTestCase {
    func testSPFEditPreservesReapplicationsDurationAndOtherDays() throws {
        let now = Date().addingTimeInterval(-60)
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let state = try makeAppState(clock: { now })
        XCTAssertTrue(state.saveManualRecord(for: yesterday, verifiedAt: yesterday, spfLevel: 15, notes: "Other day").succeeded)
        let other = try XCTUnwrap(state.record(for: yesterday)).projectionSnapshot
        XCTAssertTrue(state.recordVerificationSuccess(method: .manual, verificationDuration: 12, spfLevel: 30,
                                                       notes: "Keep notes", verifiedAt: now).succeeded)
        XCTAssertTrue(state.recordReapplication(performedAt: now).succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let original = record.projectionSnapshot
        XCTAssertEqual(original.verificationDuration, 12)
        XCTAssertEqual(original.reapplyCount, 1)
        XCTAssertNotNil(original.lastReappliedAt)

        XCTAssertTrue(state.updateLoggedSPF(recordID: record.id, expected: original, spf: 50).succeeded)

        var expected = original
        expected.spfLevel = 50
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, expected)
        XCTAssertEqual(state.record(for: yesterday)?.projectionSnapshot, other)
        XCTAssertEqual(state.records.count, 2)
    }

    func testUnchangedSPFReturnsNoOpReceipt() throws {
        let now = Date().addingTimeInterval(-60)
        let state = try makeAppState(clock: { now })
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: 30, notes: nil).succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let original = record.projectionSnapshot
        guard case let .success(receipt) = state.updateLoggedSPF(recordID: record.id, expected: original, spf: 30) else {
            return XCTFail("Unchanged SPF should succeed without a write.")
        }
        XCTAssertFalse(receipt.didChange)
        XCTAssertNil(receipt.batchID)
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, original)
    }

    func testDeletedAndReplacedLogRejectCapturedEdit() throws {
        let now = Date().addingTimeInterval(-60)
        let state = try makeAppState(clock: { now })
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: 30, notes: nil).succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let id = record.id
        let original = record.projectionSnapshot
        XCTAssertTrue(state.deleteRecord(for: now).succeeded)
        XCTAssertEqual(state.updateLoggedSPF(recordID: id, expected: original, spf: 50).error, .staleChange)
        XCTAssertNil(state.record(for: now))
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: 30, notes: nil).succeeded)
        let replacementRecord = try XCTUnwrap(state.record(for: now))
        let replacement = replacementRecord.projectionSnapshot
        XCTAssertEqual(replacement, original, "The replacement has the same values but a different identity.")
        XCTAssertNotEqual(replacementRecord.id, id)
        XCTAssertEqual(state.updateLoggedSPF(recordID: id, expected: original, spf: 50).error, .staleChange)
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, replacement)
    }

    func testDefaultFailureAndRetryDoNotRepeatSavedLogMutation() throws {
        let now = Date().addingTimeInterval(-60)
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        var fails = false
        let history = SunclubHistoryService(context: context) {
            if fails { throw SunclubHistoryMutationError.persistenceFailure }
        }
        let state = AppState(context: context, notificationManager: MockNotificationManager(), uvIndexService: UVIndexService(),
                             historyService: history, cloudSyncCoordinator: ProbeCloudSyncCoordinator(), clock: { now })
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: 30, notes: "Keep").succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        XCTAssertTrue(state.updateLoggedSPF(recordID: record.id, expected: record.projectionSnapshot, spf: 50).succeeded)
        let saved = try XCTUnwrap(state.record(for: now)).projectionSnapshot
        let revisionCount = try context.fetchCount(FetchDescriptor<DailyRecordRevision>())
        fails = true
        XCTAssertFalse(state.updateFutureLogSPF(50))
        XCTAssertNil(state.settings.sunscreenProfile)
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, saved)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyRecordRevision>()), revisionCount)

        fails = false
        XCTAssertTrue(state.updateFutureLogSPF(50))
        XCTAssertEqual(state.settings.sunscreenProfile?.spf, 50)
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, saved)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyRecordRevision>()), revisionCount)
    }

    func testOnlySPFChangesAndStaleEditIsRejected() throws {
        let now = Date().addingTimeInterval(-60)
        let state = try makeAppState(clock: { now })
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: 30, notes: "Beach\nAreas: Face").succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let original = record.projectionSnapshot
        let id = record.id
        XCTAssertTrue(state.updateLoggedSPF(recordID: id, expected: original, spf: 50).succeeded)
        var expected = original
        expected.spfLevel = 50
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, expected)
        XCTAssertEqual(state.updateLoggedSPF(recordID: id, expected: original, spf: 15).error, .staleChange)
        XCTAssertEqual(state.record(for: now)?.spfLevel, 50)
    }

    func testMissingSPFCanBeAddedWithoutCreatingAnotherLog() throws {
        let now = Date().addingTimeInterval(-60)
        let state = try makeAppState(clock: { now })
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: nil, notes: nil).succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        XCTAssertTrue(state.updateLoggedSPF(recordID: record.id, expected: record.projectionSnapshot, spf: 40).succeeded)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.record(for: now)?.spfLevel, 40)
        XCTAssertNil(state.settings.sunscreenProfile)
    }

    func testFutureDefaultPreservesProductDetails() throws {
        let state = try makeAppState()
        XCTAssertTrue(state.updateSunscreenProfile(.init(name: "Beach lotion", spf: 30, waterResistance: .eightyMinutes)))
        XCTAssertTrue(state.updateFutureLogSPF(50))
        XCTAssertEqual(state.settings.sunscreenProfile, .init(name: "Beach lotion", spf: 50, waterResistance: .eightyMinutes))
    }

    func testFailedSPFWritePreservesRecord() throws {
        let now = Date().addingTimeInterval(-60)
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        var fails = false
        let history = SunclubHistoryService(context: context) {
            if fails { throw SunclubHistoryMutationError.persistenceFailure }
        }
        let state = AppState(context: context, notificationManager: MockNotificationManager(), uvIndexService: UVIndexService(), historyService: history, cloudSyncCoordinator: ProbeCloudSyncCoordinator(), clock: { now })
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: 30, notes: "Keep").succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let original = record.projectionSnapshot
        fails = true
        XCTAssertFalse(state.updateLoggedSPF(recordID: record.id, expected: original, spf: 50).succeeded)
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, original)
    }
}
