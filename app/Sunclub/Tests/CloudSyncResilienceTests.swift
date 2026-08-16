import CloudKit
import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class CloudSyncResilienceTests: XCTestCase {
    func testMalformedRecordDoesNotBlockValidBatchAndRemainsDegradedUntilCorrected() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()
        let coordinator = CloudSyncCoordinator(historyService: historyService)
        let zoneID = CKRecordZone.ID(zoneName: "sunclub-history", ownerName: CKCurrentUserDefaultName)

        let validDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let validBatch = SunclubChangeBatch(
            kind: .manualLog,
            scope: .day,
            scopeIdentifier: validDay.formatted(.iso8601.year().month().day()),
            authorDeviceID: "remote-device",
            summary: "Remote log"
        )
        let validRevision = DailyRecordRevision(
            batch: validBatch,
            snapshot: DailyRecordProjectionSnapshot(
                startOfDay: validDay,
                verifiedAt: validDay.addingTimeInterval(9 * 3_600),
                methodRawValue: VerificationMethod.manual.rawValue,
                verificationDuration: nil,
                spfLevel: 50,
                notes: "Remote",
                reapplyCount: 0,
                lastReappliedAt: nil
            ),
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes]
        )
        let malformedBatchID = UUID()
        let malformedRecordID = CKRecord.ID(
            recordName: "batch.\(malformedBatchID.uuidString)",
            zoneID: zoneID
        )

        await coordinator.applyFetchedRecordsForTesting([
            cloudRecord(
                type: "ChangeBatch",
                name: "batch.\(validBatch.id.uuidString)",
                zoneID: zoneID,
                payload: try JSONEncoder().encode(BatchWire(batch: validBatch))
            ),
            cloudRecord(
                type: "DailyRecordRevision",
                name: "record-revision.\(validRevision.id.uuidString)",
                zoneID: zoneID,
                payload: try JSONEncoder().encode(RecordRevisionWire(revision: validRevision))
            ),
            cloudRecord(
                type: "ChangeBatch",
                recordID: malformedRecordID,
                payload: Data("not-json".utf8)
            )
        ])

        let appliedRecord = try XCTUnwrap(try historyService.record(for: validDay))
        XCTAssertEqual(appliedRecord.spfLevel, 50)
        XCTAssertEqual(try historyService.syncPreference().status, .error)
        XCTAssertTrue(try XCTUnwrap(historyService.syncPreference().lastSyncErrorDescription).contains("1 invalid record"))
        XCTAssertNotNil(try historyService.cloudSyncState().unresolvedCloudRecordFailuresData)

        let relaunchedCoordinator = CloudSyncCoordinator(historyService: historyService)
        await relaunchedCoordinator.applyFetchedRecordsForTesting([])
        XCTAssertEqual(try historyService.syncPreference().status, .error)

        let correctedBatch = SunclubChangeBatch(
            id: malformedBatchID,
            kind: .historyEdit,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: "remote-device",
            summary: "Corrected remote record"
        )
        await relaunchedCoordinator.applyFetchedRecordsForTesting([
            cloudRecord(
                type: "ChangeBatch",
                recordID: malformedRecordID,
                payload: try JSONEncoder().encode(BatchWire(batch: correctedBatch))
            )
        ])

        XCTAssertEqual(try historyService.syncPreference().status, .idle)
        XCTAssertNil(try historyService.syncPreference().lastSyncErrorDescription)
        XCTAssertNil(try historyService.cloudSyncState().unresolvedCloudRecordFailuresData)
    }

    func testMissingHistoryPayloadIsQuarantinedUntilCorrected() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        try historyService.bootstrapIfNeeded()
        let coordinator = CloudSyncCoordinator(historyService: historyService)
        let zoneID = CKRecordZone.ID(zoneName: "sunclub-history", ownerName: CKCurrentUserDefaultName)
        let batchID = UUID()
        let recordID = CKRecord.ID(recordName: "batch.\(batchID.uuidString)", zoneID: zoneID)

        await coordinator.applyFetchedRecordsForTesting([
            CKRecord(recordType: "ChangeBatch", recordID: recordID)
        ])

        XCTAssertEqual(try historyService.syncPreference().status, .error)
        XCTAssertNotNil(try historyService.cloudSyncState().unresolvedCloudRecordFailuresData)

        let correctedBatch = SunclubChangeBatch(
            id: batchID,
            kind: .manualLog,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: "remote-device",
            summary: "Corrected payload"
        )
        await coordinator.applyFetchedRecordsForTesting([
            cloudRecord(
                type: "ChangeBatch",
                recordID: recordID,
                payload: try JSONEncoder().encode(BatchWire(batch: correctedBatch))
            )
        ])

        XCTAssertEqual(try historyService.syncPreference().status, .idle)
        XCTAssertNil(try historyService.cloudSyncState().unresolvedCloudRecordFailuresData)
    }

    private func cloudRecord(
        type: String,
        name: String,
        zoneID: CKRecordZone.ID,
        payload: Data
    ) -> CKRecord {
        cloudRecord(
            type: type,
            recordID: CKRecord.ID(recordName: name, zoneID: zoneID),
            payload: payload
        )
    }

    private func cloudRecord(type: String, recordID: CKRecord.ID, payload: Data) -> CKRecord {
        let record = CKRecord(recordType: type, recordID: recordID)
        record["payload"] = payload as NSData
        return record
    }
}
