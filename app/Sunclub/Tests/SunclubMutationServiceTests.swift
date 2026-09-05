import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubMutationServiceTests: XCTestCase {
    func testEditClearsOptionalFieldsAndPreservesVerificationDurationAndReapplication() throws {
        let service = try makeService()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try service.upsert(.init(day: day, verifiedAt: day, method: .manual,
            duration: 12, spfLevel: 50, notes: " Face ", replaceOptionalFields: false,
            preserveExistingDuration: false, kind: .manualLog, summary: "Initial"))
        _ = try service.reapply(on: day, at: day, summary: "Reapply")
        let result = try service.upsert(.init(day: day, verifiedAt: day, method: .manual,
            spfLevel: nil, notes: "  ", replaceOptionalFields: true,
            preserveExistingDuration: true, kind: .historyEdit, summary: "Edit"))
        let record = try XCTUnwrap(service.history.record(for: day))
        XCTAssertNil(record.spfLevel)
        XCTAssertNil(record.notes)
        XCTAssertEqual(record.verificationDuration, 12)
        XCTAssertEqual(record.reapplyCount, 1)
        XCTAssertEqual(record.lastReappliedAt, day)
        XCTAssertEqual(result.batch?.kind, .historyEdit)
        XCTAssertEqual(result.batch?.summary, "Edit")
    }

    func testRepeatedIdenticalWriteHasNoBatchAndDoesNotRunFollowThrough() throws {
        let service = try makeService()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let request = SunclubMutationService.RecordRequest(day: day, verifiedAt: day,
            method: .quickLog, spfLevel: 30, notes: nil, replaceOptionalFields: false,
            preserveExistingDuration: false, kind: .manualLog, summary: "Log")
        var effectCount = 0
        let first = try service.upsert(request)
        service.followThrough(first.batch) { _ in effectCount += 1 }
        let repeated = try service.upsert(request)
        service.followThrough(repeated.batch) { _ in effectCount += 1 }
        XCTAssertNotNil(first.batch)
        XCTAssertNil(repeated.batch)
        XCTAssertEqual(effectCount, 1)
        XCTAssertEqual(try service.history.records().count, 1)
    }

    func testFailedWritePreservesExistingRecordAndDoesNotRunFollowThrough() throws {
        let service = try makeService()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try service.upsert(.init(day: day, verifiedAt: day, method: .manual,
            spfLevel: 50, notes: "Existing", replaceOptionalFields: false,
            preserveExistingDuration: false, kind: .manualLog, summary: "Log"))
        let failing = SunclubMutationService(history: SunclubHistoryService(context: service.history.fetchContext()) {
            throw NSError(domain: "MutationFailure", code: 1)
        })
        var effectCount = 0
        XCTAssertThrowsError(try {
            let result = try failing.upsert(.init(day: day, verifiedAt: day, method: .quickLog,
                spfLevel: 15, notes: nil, replaceOptionalFields: true,
                preserveExistingDuration: false, kind: .historyEdit, summary: "Fail"))
            failing.followThrough(result.batch) { _ in effectCount += 1 }
        }())
        XCTAssertEqual(try service.history.record(for: day)?.spfLevel, 50)
        XCTAssertEqual(try service.history.record(for: day)?.notes, "Existing")
        XCTAssertEqual(effectCount, 0)
    }

    func testReminderAndReapplySettingsReturnNoBatchForSameValues() throws {
        let service = try makeService()
        let settings = try service.history.settings()
        let reminder = settings.smartReminderSettings
        _ = try service.updateReminder(reminder, summary: "Reminder")
        XCTAssertNil(try service.updateReminder(reminder, summary: "Repeated"))
        XCTAssertNil(try service.updateReapply(enabled: settings.reapplyReminderEnabled,
            intervalMinutes: settings.reapplyIntervalMinutes, summary: "Repeated"))
    }

    private func makeService() throws -> SunclubMutationService {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let history = SunclubHistoryService(context: ModelContext(container))
        try history.bootstrapIfNeeded()
        return SunclubMutationService(history: history)
    }
}
