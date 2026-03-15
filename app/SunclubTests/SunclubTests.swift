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

        state.recordVerificationSuccess(
            method: .video,
            barcode: "12345",
            featureDistance: 0.12,
            barcodeConfidence: nil
        )

        XCTAssertEqual(state.currentStreak, 1)
        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 1)
        XCTAssertEqual(state.verificationSuccessPresentation?.detail, "Your streak is now 1 day")
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
    func testRetrainingClearsAndRebuildsTrainingAssets() throws {
        let state = try makeAppState()

        state.addTrainingFeature(Data("one".utf8), width: 1, height: 1)
        state.addTrainingFeature(Data("two".utf8), width: 1, height: 1)
        XCTAssertEqual(state.trainingAssets.count, 2)

        state.clearTrainingData()
        XCTAssertEqual(state.trainingAssets.count, 0)

        state.addTrainingFeature(Data("three".utf8), width: 1, height: 1)
        XCTAssertEqual(state.trainingAssets.count, 1)
    }

    @MainActor
    private func makeAppState() throws -> AppState {
        let schema = Schema([DailyRecord.self, TrainingAsset.self, Settings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return AppState(context: ModelContext(container))
    }
}
