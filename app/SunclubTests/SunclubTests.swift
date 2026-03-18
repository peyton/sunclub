import Foundation
import SwiftData
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
        XCTAssertEqual(CalendarAnalytics.status(for: base, with: [], now: base, calendar: calendar), .todayPending)
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

        XCTAssertEqual(CalendarAnalytics.currentStreak(records: records, now: today, calendar: calendar), 3)

        let records2 = [
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!
        ]
        XCTAssertEqual(CalendarAnalytics.currentStreak(records: records2, now: today, calendar: calendar), 2)
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
        XCTAssertTrue(phrases.contains(PhraseRotation.nextPhrase(from: encoded, catalog: phrases).0))
    }

    @MainActor
    func testVerificationSuccessPresentationUsesUpdatedStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .camera,
            verificationDuration: 1.0
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .camera, verificationDuration: 0.8)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 2)
        XCTAssertEqual(state.verificationSuccessPresentation?.detail, "You're on a 2-day streak.")
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
    func testUpdateDailyReminderPersistsToSettings() throws {
        let state = try makeAppState()

        state.updateDailyReminder(hour: 9, minute: 45)

        XCTAssertEqual(state.settings.reminderHour, 9)
        XCTAssertEqual(state.settings.reminderMinute, 45)
    }

    @MainActor
    func testMarkAppliedTodayUpdatesExistingRecordInsteadOfDuplicating() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .camera, verificationDuration: 1.2)
        XCTAssertEqual(state.records.count, 1)

        state.markAppliedToday(method: .camera, verificationDuration: 2.4)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.verificationDuration, 2.4)
    }

    @MainActor
    func testSunscreenResponseParserRecognizesYesAndNo() {
        XCTAssertEqual(SunscreenResponseParser.parse("YES"), .yes)
        XCTAssertEqual(SunscreenResponseParser.parse(" yes.\n"), .yes)
        XCTAssertEqual(SunscreenResponseParser.parse("NO"), .no)
        XCTAssertEqual(SunscreenResponseParser.parse(" no... "), .no)
    }

    @MainActor
    func testSunscreenResponseParserFallsBackToNoForUnexpectedOutput() {
        XCTAssertEqual(SunscreenResponseParser.parse("maybe"), .no)
        XCTAssertEqual(SunscreenResponseParser.parse(""), .no)
        XCTAssertEqual(SunscreenResponseParser.parse("There might be sunscreen"), .no)
    }


    @MainActor
    func testSunscreenResponseParserSanitizesUnexpectedOutputIntoStableTokens() {
        XCTAssertEqual(SunscreenResponseParser.sanitized(" yes!!! \n"), "YES")
        XCTAssertEqual(SunscreenResponseParser.sanitized("no, sunscreen not found"), "NO SUNSCREEN NOT FOUND")
    }

    @MainActor
    private func makeAppState() throws -> AppState {
        let schema = Schema([DailyRecord.self, Settings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return AppState(context: ModelContext(container))
    }
}
