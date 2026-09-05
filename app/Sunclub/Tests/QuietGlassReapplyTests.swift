import XCTest
@testable import Sunclub

@MainActor
final class QuietGlassReapplyTests: SunclubTestCase {
    func testLoggedDayCanRecordReapplicationWithoutEnablingReminders() throws {
        let state = try makeAppState()
        state.updateReapplySettings(enabled: false, intervalMinutes: 120)
        state.markAppliedToday(method: .manual, spfLevel: 50)
        let originalTime = try XCTUnwrap(state.record(for: state.referenceDate)?.verifiedAt)

        XCTAssertNotNil(state.reapplyCheckInPresentation)
        XCTAssertTrue(state.recordReapplication().succeeded)

        let record = try XCTUnwrap(state.record(for: state.referenceDate))
        XCTAssertEqual(record.reapplyCount, 1)
        XCTAssertNotNil(record.lastReappliedAt)
        XCTAssertEqual(record.verifiedAt, originalTime)
        XCTAssertFalse(state.settings.reapplyReminderEnabled)
    }
}
