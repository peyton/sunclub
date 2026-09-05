import Foundation
import XCTest
@testable import Sunclub

final class HistoryWeekPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        value.firstWeekday = 2
        return value
    }

    func testDefaultSelectionUsesTheInjectedReferenceDay() {
        let now = date(2026, 9, 4, hour: 10)
        XCTAssertEqual(
            HistoryWeekPresentation.initialSelection(preselectedDay: nil, referenceDate: now, calendar: calendar),
            date(2026, 9, 4)
        )
    }

    func testExternalPreselectionKeepsTheRequestedPastDay() {
        XCTAssertEqual(
            HistoryWeekPresentation.initialSelection(
                preselectedDay: date(2024, 2, 29, hour: 16),
                referenceDate: date(2026, 9, 4),
                calendar: calendar
            ),
            date(2024, 2, 29)
        )
    }

    func testFuturePreselectionCannotExposeFutureEditing() {
        let now = date(2026, 9, 4, hour: 10)
        XCTAssertEqual(
            HistoryWeekPresentation.initialSelection(
                preselectedDay: date(2026, 9, 5), referenceDate: now, calendar: calendar
            ),
            date(2026, 9, 4)
        )
    }

    func testSelectedWeekCrossesMonthBoundaryAndOmitsFutureDaysFromSummary() {
        let week = HistoryWeekPresentation(
            selectedDay: date(2026, 9, 4),
            recordDays: Set([date(2026, 8, 31), date(2026, 9, 1), date(2026, 9, 3), date(2026, 9, 4), date(2026, 9, 5)]),
            today: date(2026, 9, 4, hour: 10),
            eligibleFrom: date(2026, 8, 1),
            calendar: calendar
        )
        XCTAssertEqual(week.days.first, date(2026, 8, 31))
        XCTAssertEqual(week.days.last, date(2026, 9, 6))
        XCTAssertEqual(week.days.count, 7)
        XCTAssertEqual(week.eligibleDayCount, 5)
        XCTAssertEqual(week.loggedDayCount, 4)
    }

    func testSummaryCountsEachDayOnceAndStartsWhenTrackingBegan() {
        let week = HistoryWeekPresentation(
            selectedDay: date(2026, 9, 4),
            recordDays: Set([date(2026, 9, 3, hour: 8), date(2026, 9, 3, hour: 10)]),
            today: date(2026, 9, 4),
            eligibleFrom: date(2026, 9, 3, hour: 8),
            calendar: calendar
        )
        XCTAssertEqual(week.eligibleDayCount, 2)
        XCTAssertEqual(week.loggedDayCount, 1)
    }

    func testWeekBeforeTrackingHasNoEligibleDays() {
        let week = HistoryWeekPresentation(
            selectedDay: date(2026, 8, 10), recordDays: [], today: date(2026, 9, 4),
            eligibleFrom: date(2026, 9, 1), calendar: calendar
        )
        XCTAssertEqual(week.eligibleDayCount, 0)
        XCTAssertEqual(week.loggedDayCount, 0)
    }

    func testWeekHonorsSundayFirstCalendarAcrossTheYearBoundary() {
        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let week = HistoryWeekPresentation(
            selectedDay: date(2027, 1, 1), recordDays: [], today: date(2027, 1, 1),
            eligibleFrom: date(2026, 12, 1), calendar: sundayCalendar
        )
        XCTAssertEqual(week.days.first, date(2026, 12, 27))
        XCTAssertEqual(week.days.last, date(2027, 1, 2))
        XCTAssertEqual(week.eligibleDayCount, 6)
    }

    func testWeekUsesCalendarDaysAcrossDaylightSavingTime() {
        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let week = HistoryWeekPresentation(
            selectedDay: date(2026, 3, 8), recordDays: [], today: date(2026, 3, 14),
            eligibleFrom: date(2026, 3, 1), calendar: sundayCalendar
        )
        XCTAssertEqual(week.days, (8...14).map { date(2026, 3, $0) })
        XCTAssertEqual(week.days[1].timeIntervalSince(week.days[0]), 23 * 60 * 60)
        XCTAssertEqual(week.eligibleDayCount, 7)
    }

    func testMonthNavigationDoesNotSkipShortMonthsAndReturnsToToday() {
        let now = date(2024, 3, 31, hour: 10)
        let previous = HistoryWeekPresentation.selectionAfterMovingMonth(
            from: now, by: -1, referenceDate: now, calendar: calendar
        )
        XCTAssertEqual(previous, date(2024, 2, 1))
        XCTAssertEqual(
            HistoryWeekPresentation.selectionAfterMovingMonth(
                from: date(2024, 2, 29), by: 1, referenceDate: now, calendar: calendar
            ),
            date(2024, 3, 31)
        )
        XCTAssertNil(HistoryWeekPresentation.selectionAfterMovingMonth(
            from: now, by: 1, referenceDate: now, calendar: calendar
        ))
        XCTAssertNil(HistoryWeekPresentation.selectionAfterMovingMonth(
            from: now, by: 0, referenceDate: now, calendar: calendar
        ))
    }

    func testApplicationRowsUseOnlySavedTimestampsAndSummarizeEarlierReapplications() {
        let first = date(2026, 9, 4, hour: 8)
        let latest = date(2026, 9, 4, hour: 14)
        let applications = HistoryApplicationPresentation(verifiedAt: first, reapplyCount: 3, lastReappliedAt: latest)
        XCTAssertEqual(applications.applicationCount, 4)
        XCTAssertEqual(applications.timestamps.map(\.date), [latest, first])
        XCTAssertEqual(applications.timestamps.map(\.kind), [.reapplication, .application])
        XCTAssertEqual(applications.untimedReapplicationCount, 2)
    }

    func testMissingReapplicationTimeDoesNotInventARow() {
        let applications = HistoryApplicationPresentation(
            verifiedAt: date(2026, 9, 4, hour: 8), reapplyCount: 2, lastReappliedAt: nil
        )
        XCTAssertEqual(applications.applicationCount, 3)
        XCTAssertEqual(applications.timestamps.count, 1)
        XCTAssertEqual(applications.untimedReapplicationCount, 2)
    }

    func testZeroOrNegativeReapplyCountIgnoresStaleReapplicationTime() {
        for count in [0, -1] {
            let applications = HistoryApplicationPresentation(
                verifiedAt: date(2026, 9, 4, hour: 8), reapplyCount: count,
                lastReappliedAt: date(2026, 9, 4, hour: 10)
            )
            XCTAssertEqual(applications.applicationCount, 1)
            XCTAssertEqual(applications.timestamps.map(\.kind), [.application])
            XCTAssertEqual(applications.untimedReapplicationCount, 0)
        }
    }

    func testMatchingApplicationTimesKeepDistinctStableRows() {
        let time = date(2026, 9, 4, hour: 8)
        let applications = HistoryApplicationPresentation(verifiedAt: time, reapplyCount: 1, lastReappliedAt: time)
        XCTAssertEqual(applications.timestamps.map(\.kind), [.reapplication, .application])
        XCTAssertEqual(Set(applications.timestamps.map(\.id)).count, 2)
        XCTAssertEqual(applications.applicationCount, 2)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
