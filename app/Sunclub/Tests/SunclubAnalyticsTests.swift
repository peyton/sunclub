import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubAnalyticsTests: SunclubTestCase {
    @MainActor
    func testDayStatusUsesFirstRecordEligibilityForFutureTodayAndPast() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let firstRecord = calendar.date(byAdding: .day, value: -2, to: today)!
        let beforeTracking = calendar.date(byAdding: .day, value: -3, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let set: Set<Date> = [firstRecord]
        XCTAssertEqual(CalendarAnalytics.status(for: firstRecord, with: set, now: today, calendar: calendar), .applied)
        XCTAssertEqual(CalendarAnalytics.status(for: tomorrow, with: set, now: today, calendar: calendar), .future)
        XCTAssertEqual(CalendarAnalytics.status(for: yesterday, with: set, now: today, calendar: calendar), .missed)
        XCTAssertEqual(CalendarAnalytics.status(for: beforeTracking, with: set, now: today, calendar: calendar), .untracked)
        XCTAssertEqual(CalendarAnalytics.status(for: today, with: set, now: today, calendar: calendar), .todayPending)
        XCTAssertEqual(CalendarAnalytics.status(for: today, with: [], now: today, calendar: calendar), .todayPending)
    }

    @MainActor
    func testDayStatusKeepsPreEligibilityDaysNeutral() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let eligibilityStart = calendar.date(byAdding: .day, value: -2, to: today)!
        let earlierDay = calendar.date(byAdding: .day, value: -3, to: today)!

        XCTAssertEqual(
            CalendarAnalytics.status(
                for: earlierDay,
                with: [],
                now: today,
                eligibleFrom: eligibilityStart,
                calendar: calendar
            ),
            .untracked
        )
        XCTAssertEqual(
            CalendarAnalytics.status(
                for: eligibilityStart,
                with: [],
                now: today,
                eligibleFrom: eligibilityStart,
                calendar: calendar
            ),
            .missed
        )
    }

    @MainActor
    func testEligibilityStartsAtEarliestOnboardingOrFirstRecord() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let onboarding = calendar.date(byAdding: .day, value: -4, to: today)!
        let firstRecord = calendar.date(byAdding: .day, value: -2, to: today)!

        XCTAssertEqual(
            CalendarAnalytics.eligibilityStart(
                records: [firstRecord],
                onboardingCompletedAt: onboarding,
                now: today,
                calendar: calendar
            ),
            onboarding
        )
        XCTAssertEqual(
            CalendarAnalytics.eligibilityStart(
                records: [firstRecord],
                now: today,
                calendar: calendar
            ),
            firstRecord
        )
    }

    @MainActor
    func testWeeklyReportUsesFirstRecordAsDefaultEligibility() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let report = CalendarAnalytics.weeklyReport(
            records: [yesterday],
            now: today,
            calendar: calendar
        )

        XCTAssertEqual(report.totalDays, 2)
        XCTAssertEqual(report.appliedCount, 1)
        XCTAssertEqual(report.missedCount, 1)
    }

    @MainActor
    func testStreakIsContiguousFromMostRecentAppliedDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records = [
            today,
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!,
            calendar.date(byAdding: .day, value: -4, to: today)!
        ]

        XCTAssertEqual(CalendarAnalytics.currentStreak(records: records, now: today, calendar: calendar), 3)
    }

    @MainActor
    func testCurrentStreakDaysReturnsEmptyHistory() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        XCTAssertEqual(CalendarAnalytics.currentStreakDays(records: [], now: today, calendar: calendar), [])
    }

    @MainActor
    func testCurrentStreakDaysIncludesTodayWhenLogged() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        XCTAssertEqual(
            CalendarAnalytics.currentStreakDays(records: [today, yesterday, twoDaysAgo], now: today, calendar: calendar),
            [twoDaysAgo, yesterday, today]
        )
    }

    @MainActor
    func testCurrentStreakDaysFallsBackToYesterdayWhenTodayPending() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        XCTAssertEqual(
            CalendarAnalytics.currentStreakDays(records: [yesterday, twoDaysAgo], now: today, calendar: calendar),
            [twoDaysAgo, yesterday]
        )
    }

    @MainActor
    func testCurrentStreakDaysStopsAtGap() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!

        XCTAssertEqual(
            CalendarAnalytics.currentStreakDays(records: [today, yesterday, twoDaysAgo, fourDaysAgo], now: today, calendar: calendar),
            [twoDaysAgo, yesterday, today]
        )
    }

    @MainActor
    func testPhraseShuffleBagDoesNotRepeatUntilExhaustion() {
        let phrases = ["a", "b", "c", "d"]
        var state = Data()
        var seen: [String] = []

        for _ in phrases {
            let next = PhraseRotation.nextPhrase(from: state, catalog: phrases)
            seen.append(next.0)
            state = next.1
        }

        XCTAssertEqual(Set(seen).count, 4)
    }

    @MainActor
    func testWeeklySummaryFormattingUsesSpacedFraction() {
        let report = WeeklyReport(
            startDate: Date(),
            endDate: Date(),
            appliedCount: 7,
            totalDays: 7,
            missedDays: [],
            streak: 7
        )

        XCTAssertEqual(report.appliedSummaryText, "7 / 7")
    }

    @MainActor
    func testSunscreenUsageInsightsReturnsMostUsedSPF() {
        let records = [
            makeDailyRecord(dayOffset: 0, spfLevel: 50),
            makeDailyRecord(dayOffset: 1, spfLevel: 30),
            makeDailyRecord(dayOffset: 2, spfLevel: 50),
            makeDailyRecord(dayOffset: 3, spfLevel: nil)
        ]

        let insights = SunscreenUsageAnalytics.insights(from: records)

        XCTAssertEqual(insights.mostUsedSPF?.level, 50)
        XCTAssertEqual(insights.mostUsedSPF?.count, 2)
        XCTAssertEqual(insights.mostUsedSPF?.totalLoggedCount, 3)
    }

    @MainActor
    func testSunscreenUsageInsightsBreaksSPFTiesByRecency() {
        let records = [
            makeDailyRecord(dayOffset: 4, spfLevel: 30),
            makeDailyRecord(dayOffset: 1, spfLevel: 30),
            makeDailyRecord(dayOffset: 2, spfLevel: 50),
            makeDailyRecord(dayOffset: 0, spfLevel: 50)
        ]

        let insights = SunscreenUsageAnalytics.insights(from: records)

        XCTAssertEqual(insights.mostUsedSPF?.level, 50)
    }

    @MainActor
    func testSunscreenUsageInsightsReturnsRecentTrimmedNotesNewestFirst() {
        let records = [
            makeDailyRecord(dayOffset: 0, notes: "  Before beach walk  "),
            makeDailyRecord(dayOffset: 1, notes: "Applied before morning run"),
            makeDailyRecord(dayOffset: 2, notes: "   "),
            makeDailyRecord(dayOffset: 3, notes: nil)
        ]

        let insights = SunscreenUsageAnalytics.insights(from: records, recentNotesLimit: 2)

        XCTAssertEqual(insights.recentNotes.map(\.text), [
            "Before beach walk",
            "Applied before morning run"
        ])
    }

    @MainActor
    func testMonthlyReviewInsightsHighlightBestHardestWeekdayAndMostCommonSPF() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }

        let records = [
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 1), verifiedAt: date(year: 2026, month: 4, day: 1, hour: 9), method: .manual, spfLevel: 50),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 3), verifiedAt: date(year: 2026, month: 4, day: 3, hour: 9), method: .manual, spfLevel: 50),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 5), verifiedAt: date(year: 2026, month: 4, day: 5, hour: 10), method: .manual, spfLevel: 30),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 7), verifiedAt: date(year: 2026, month: 4, day: 7, hour: 9), method: .manual, spfLevel: 50),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 8), verifiedAt: date(year: 2026, month: 4, day: 8, hour: 9), method: .manual, spfLevel: 30),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 10), verifiedAt: date(year: 2026, month: 4, day: 10, hour: 9), method: .manual, spfLevel: 50)
        ]

        let insights = MonthlyReviewAnalytics.insights(
            from: records,
            month: date(year: 2026, month: 4, day: 15),
            now: date(year: 2026, month: 4, day: 10, hour: 12),
            calendar: calendar
        )

        XCTAssertEqual(insights.bestWeekday?.weekday, 4)
        XCTAssertEqual(insights.hardestWeekday?.weekday, 5)
        XCTAssertEqual(insights.mostCommonSPF?.level, 50)
        XCTAssertEqual(insights.mostCommonSPF?.count, 4)
    }
}
