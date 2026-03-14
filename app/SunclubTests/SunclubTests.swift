import Foundation
import XCTest
@testable import Sunclub

final class SunclubTests: XCTestCase {
    @MainActor
    func testDayStatusAppliesToFutureTodayAndPast() throws {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())
        let recordDate = base
        let yesterday = calendar.date(byAdding: .day, value: -1, to: base)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: base)!

        let set: Set<Date> = [recordDate]
        XCTAssertEqual(CalendarAnalytics.status(for: recordDate, with: set, now: base, calendar: calendar), .applied)
        XCTAssertEqual(CalendarAnalytics.status(for: tomorrow, with: set, now: base, calendar: calendar), .future)
        XCTAssertEqual(CalendarAnalytics.status(for: yesterday, with: set, now: base, calendar: calendar), .missed)
        let todayNoRecordSet: Set<Date> = []
        XCTAssertEqual(CalendarAnalytics.status(for: base, with: todayNoRecordSet, now: base, calendar: calendar), .todayPending)
    }

    @MainActor
    func testStreakIsContiguousFromMostRecentAppliedDay() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records = [
            today,
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!,
            calendar.date(byAdding: .day, value: -4, to: today)!
        ]

        let result = CalendarAnalytics.currentStreak(records: records, now: today, calendar: calendar)
        XCTAssertEqual(result, 3)

        let todayMissed = calendar.startOfDay(for: Date())
        let records2 = [
            calendar.date(byAdding: .day, value: -1, to: todayMissed)!,
            calendar.date(byAdding: .day, value: -2, to: todayMissed)!
        ]
        let result2 = CalendarAnalytics.currentStreak(records: records2, now: todayMissed, calendar: calendar)
        XCTAssertEqual(result2, 2)
    }

    @MainActor
    func testPhraseShuffleBagDoesNotRepeatUntilExhaustion() throws {
        let phrases = ["a", "b", "c", "d"]
        var state: [String] = []
        var encoded = Data()
        for _ in phrases {
            let response = PhraseRotation.nextPhrase(from: encoded, catalog: phrases)
            state.append(response.0)
            encoded = response.1
        }
        XCTAssertEqual(Set(state).count, 4)

        let wrapped = PhraseRotation.nextPhrase(from: encoded, catalog: phrases).0
        XCTAssertTrue(phrases.contains(wrapped))
    }
}
