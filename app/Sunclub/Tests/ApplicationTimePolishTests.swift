import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class ApplicationTimePolishTests: SunclubTestCase {
    private var now: Date {
        Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!
    }

    func testManualTimestampCannotBelongToAnotherDay() throws {
        let state = try makeAppState(clock: { self.now })
        let yesterday = now.addingTimeInterval(-86400)
        XCTAssertFalse(state.saveManualRecord(for: now, verifiedAt: yesterday, spfLevel: 30, notes: nil).succeeded)
        XCTAssertNil(state.record(for: now))
    }

    func testReapplicationCannotPrecedeFirstApplication() throws {
        let state = try makeAppState(clock: { self.now })
        let first = now.addingTimeInterval(-3600)
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: first, spfLevel: 30, notes: nil).succeeded)
        XCTAssertFalse(state.recordReapplication(performedAt: first.addingTimeInterval(-60)).succeeded)
        XCTAssertEqual(state.record(for: now)?.reapplyCount, 0)
    }

    func testReapplicationCannotBelongToAnotherDay() throws {
        let state = try makeAppState(clock: { self.now })
        let yesterday = now.addingTimeInterval(-86400)
        XCTAssertTrue(state.saveManualRecord(for: yesterday, verifiedAt: yesterday, spfLevel: 30, notes: nil).succeeded)
        XCTAssertFalse(state.recordReapplication(for: yesterday, performedAt: now).succeeded)
        XCTAssertEqual(state.record(for: yesterday)?.reapplyCount, 0)
    }
    func testTimeEditIsAtomicPreservesCountAndRejectsStaleDraft() throws {
        let state = try makeAppState(clock: { self.now })
        let first = now.addingTimeInterval(-7200)
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: first, spfLevel: 30, notes: "Keep").succeeded)
        XCTAssertTrue(state.recordReapplication(performedAt: now.addingTimeInterval(-1800)).succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let original = record.projectionSnapshot
        let corrected = now.addingTimeInterval(-3600)
        let result = state.saveEditedRecord(for: now, recordID: record.id, expected: original,
                                           verifiedAt: first, lastReappliedAt: corrected, spfLevel: 50, notes: "Keep")
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(state.record(for: now)?.lastReappliedAt, corrected)
        XCTAssertEqual(state.record(for: now)?.reapplyCount, 1)
        XCTAssertEqual(state.record(for: now)?.spfLevel, 50)
        XCTAssertEqual(state.saveEditedRecord(for: now, recordID: record.id, expected: original,
                                             verifiedAt: first, lastReappliedAt: corrected, spfLevel: 15, notes: nil).error, .staleChange)
        XCTAssertEqual(state.record(for: now)?.spfLevel, 50)
    }

    func testTimeEditRejectsInvalidOrderWithoutSavingOtherFields() throws {
        let state = try makeAppState(clock: { self.now })
        let first = now.addingTimeInterval(-7200)
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: first, spfLevel: 30, notes: "Keep").succeeded)
        XCTAssertTrue(state.recordReapplication(performedAt: now.addingTimeInterval(-3600)).succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let original = record.projectionSnapshot
        XCTAssertFalse(state.saveEditedRecord(for: now, recordID: record.id, expected: original,
                                              verifiedAt: now, lastReappliedAt: original.lastReappliedAt,
                                              spfLevel: 50, notes: nil).succeeded)
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, original)
    }

    func testDeletedLogCannotBeRecreatedByOpenEditor() throws {
        let state = try makeAppState(clock: { self.now })
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: now, spfLevel: 30, notes: nil).succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let id = record.id
        let original = record.projectionSnapshot
        XCTAssertTrue(state.deleteRecord(for: now).succeeded)
        XCTAssertEqual(state.saveEditedRecord(for: now, recordID: id, expected: original,
                                             verifiedAt: now, lastReappliedAt: nil, spfLevel: 50, notes: nil).error, .staleChange)
        XCTAssertNil(state.record(for: now))
    }

    func testEarlierReapplicationDoesNotMoveLatestTimeBackward() throws {
        let state = try makeAppState(clock: { self.now })
        let first = now.addingTimeInterval(-7200)
        XCTAssertTrue(state.saveManualRecord(for: now, verifiedAt: first, spfLevel: 30, notes: nil).succeeded)
        XCTAssertTrue(state.recordReapplication(performedAt: now).succeeded)
        XCTAssertTrue(state.recordReapplication(performedAt: now.addingTimeInterval(-3600)).succeeded)
        XCTAssertEqual(state.record(for: now)?.lastReappliedAt, now)
        XCTAssertEqual(state.record(for: now)?.reapplyCount, 2)
    }

    func testUnchangedEditHasNoRevisionAndFailedEditRetainsEntireLog() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        var fails = false
        let history = SunclubHistoryService(context: context) {
            if fails { throw SunclubHistoryMutationError.persistenceFailure }
        }
        let state = AppState(context: context, notificationManager: MockNotificationManager(), uvIndexService: UVIndexService(),
                             historyService: history, cloudSyncCoordinator: ProbeCloudSyncCoordinator(), clock: { self.now })
        XCTAssertTrue(state.saveEditedRecord(for: now, recordID: nil, expected: nil,
                                            verifiedAt: now, lastReappliedAt: nil, spfLevel: 30, notes: "Keep").succeeded)
        let record = try XCTUnwrap(state.record(for: now))
        let original = record.projectionSnapshot
        let count = try context.fetchCount(FetchDescriptor<DailyRecordRevision>())
        guard case let .success(receipt) = state.saveEditedRecord(for: now, recordID: record.id, expected: original,
                                                                  verifiedAt: now, lastReappliedAt: nil, spfLevel: 30, notes: "Keep") else {
            return XCTFail("Unchanged edit should succeed")
        }
        XCTAssertFalse(receipt.didChange)
        XCTAssertNil(receipt.batchID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyRecordRevision>()), count)
        fails = true
        XCTAssertFalse(state.saveEditedRecord(for: now, recordID: record.id, expected: original,
                                              verifiedAt: now.addingTimeInterval(-60), lastReappliedAt: nil,
                                              spfLevel: 50, notes: "Changed").succeeded)
        XCTAssertEqual(state.record(for: now)?.projectionSnapshot, original)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DailyRecordRevision>()), count)
    }

}
