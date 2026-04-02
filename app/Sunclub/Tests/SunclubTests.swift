import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class MockNotificationManager: NotificationScheduling {
    private(set) var scheduleRemindersCount = 0
    private(set) var scheduleReapplyReminderIntervals: [Int] = []
    private(set) var scheduleReapplyReminderRoutes: [AppRoute] = []
    private(set) var cancelReapplyRemindersCount = 0

    func scheduleReminders(using state: AppState) async {
        scheduleRemindersCount += 1
    }

    func scheduleReapplyReminder(intervalMinutes: Int, route: AppRoute) async {
        scheduleReapplyReminderIntervals.append(intervalMinutes)
        scheduleReapplyReminderRoutes.append(route)
    }

    func cancelReapplyReminders() async {
        cancelReapplyRemindersCount += 1
    }
}

final class SunclubTests: XCTestCase {
    @MainActor
    func testDayStatusAppliesToFutureTodayAndPast() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let set: Set<Date> = [today]
        XCTAssertEqual(CalendarAnalytics.status(for: today, with: set, now: today, calendar: calendar), .applied)
        XCTAssertEqual(CalendarAnalytics.status(for: tomorrow, with: set, now: today, calendar: calendar), .future)
        XCTAssertEqual(CalendarAnalytics.status(for: yesterday, with: set, now: today, calendar: calendar), .missed)
        XCTAssertEqual(CalendarAnalytics.status(for: today, with: [], now: today, calendar: calendar), .todayPending)
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
    func testVerificationSuccessPresentationUsesUpdatedStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual,
            verificationDuration: 1.0
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

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

        state.markAppliedToday(method: .manual, verificationDuration: 1.2)
        state.markAppliedToday(method: .manual, verificationDuration: 2.4)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.verificationDuration, 2.4)
    }

    @MainActor
    func testManualVerificationMethodProperties() {
        let manual = VerificationMethod.manual
        XCTAssertEqual(manual.title, "manual")
        XCTAssertEqual(manual.displayName, "Manual Log")
        XCTAssertEqual(manual.symbolName, "hand.tap")
        XCTAssertEqual(manual.rawValue, 1)
    }

    @MainActor
    func testVerificationMethodCaseIterable() {
        let allCases = VerificationMethod.allCases
        XCTAssertEqual(allCases, [.manual])
    }

    @MainActor
    func testVerificationMethodRoundTripsThroughRawValue() {
        XCTAssertEqual(VerificationMethod(rawValue: VerificationMethod.manual.rawValue), .manual)
    }

    @MainActor
    func testMarkAppliedTodayWithManualMethod() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.method, .manual)
        XCTAssertNil(state.records.first?.verificationDuration)
    }

    @MainActor
    func testMarkAppliedTodayWithSPFAndNotes() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, spfLevel: 50, notes: "Before morning run")

        XCTAssertEqual(state.records.first?.spfLevel, 50)
        XCTAssertEqual(state.records.first?.notes, "Before morning run")
    }

    @MainActor
    func testSaveManualRecordBackfillsPastDay() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        state.saveManualRecord(for: yesterday, spfLevel: 70, notes: "After lunch")

        let record = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertEqual(record.spfLevel, 70)
        XCTAssertEqual(record.notes, "After lunch")
        XCTAssertTrue(calendar.isDate(record.startOfDay, inSameDayAs: yesterday))
        XCTAssertTrue(calendar.isDate(record.verifiedAt, inSameDayAs: yesterday))
        XCTAssertEqual(state.dayStatus(for: yesterday), .applied)
    }

    @MainActor
    func testUpdateExistingRecordPreservesSPF() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, spfLevel: 50)
        state.markAppliedToday(method: .manual, verificationDuration: 1.0)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.spfLevel, 50)
    }

    @MainActor
    func testSaveManualRecordCanClearOptionalFieldsAndPreserveDuration() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let existingVerifiedAt = calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday
        let existing = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: existingVerifiedAt,
            method: .manual,
            verificationDuration: 1.5,
            spfLevel: 50,
            notes: "Before run"
        )
        state.modelContext.insert(existing)
        state.refresh()

        state.saveManualRecord(for: yesterday, spfLevel: nil, notes: "")

        let updated = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertNil(updated.spfLevel)
        XCTAssertNil(updated.notes)
        XCTAssertEqual(updated.verificationDuration, 1.5)
        XCTAssertEqual(updated.verifiedAt, existingVerifiedAt)
    }

    @MainActor
    func testLongestStreakUpdatesOnNewRecord() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.longestStreak, 1)
    }

    @MainActor
    func testLongestStreakTracksMaximum() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in stride(from: -2, through: 0, by: 1) {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let record = DailyRecord(
                startOfDay: day,
                verifiedAt: calendar.date(byAdding: .hour, value: 8, to: day) ?? day,
                method: .manual
            )
            state.modelContext.insert(record)
        }
        state.refresh()
        state.markAppliedToday(method: .manual)

        XCTAssertGreaterThanOrEqual(state.longestStreak, 3)
    }

    @MainActor
    func testLongestStreakNeverDecreases() throws {
        let state = try makeAppState()
        state.settings.longestStreak = 10
        state.save()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.longestStreak, 10)
    }

    @MainActor
    func testRefreshNormalizesLegacyCameraMethodToManual() throws {
        let state = try makeAppState()
        let today = Calendar.current.startOfDay(for: Date())

        let record = DailyRecord(startOfDay: today, verifiedAt: today, method: .manual)
        record.methodRawValue = 0
        state.modelContext.insert(record)

        state.refresh()

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.method, .manual)
        XCTAssertEqual(state.records.first?.methodRawValue, VerificationMethod.manual.rawValue)
    }

    @MainActor
    func testDeleteTodayRecordCancelsReapplyReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.markAppliedToday(method: .manual)
        state.deleteRecord(for: Date())

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
    }

    @MainActor
    func testDeleteNonTodayRecordDoesNotCancelReapplyReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        state.markAppliedToday(method: .manual)
        state.deleteRecord(for: yesterday)

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 0)
    }

    @MainActor
    func testRecordVerificationSuccessSetsPresentation() throws {
        let state = try makeAppState()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 1)
        XCTAssertTrue(state.verificationSuccessPresentation?.isPersonalBest ?? false)
    }

    @MainActor
    func testRecordVerificationSuccessPersistsSPFAndNotes() throws {
        let state = try makeAppState()

        state.recordVerificationSuccess(method: .manual, spfLevel: 30, notes: "Pool day")

        let record = try XCTUnwrap(state.record(for: Date()))
        XCTAssertEqual(record.spfLevel, 30)
        XCTAssertEqual(record.notes, "Pool day")
    }

    @MainActor
    func testUpdateReapplySettingsPersistsAndClamps() throws {
        let state = try makeAppState()

        state.updateReapplySettings(enabled: true, intervalMinutes: 10)
        XCTAssertTrue(state.settings.reapplyReminderEnabled)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 30)

        state.updateReapplySettings(enabled: true, intervalMinutes: 600)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 480)
    }

    @MainActor
    func testDisablingReapplyCancelsPendingReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.updateReapplySettings(enabled: true, intervalMinutes: 90)
        state.updateReapplySettings(enabled: false, intervalMinutes: 90)

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
    }

    @MainActor
    func testScheduleReapplyReminderUsesPreferredCheckInRoute() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.updateReapplySettings(enabled: true, intervalMinutes: 90)
        state.scheduleReapplyReminder()

        await Task.yield()
        XCTAssertEqual(notificationManager.scheduleReapplyReminderIntervals, [90])
        XCTAssertEqual(notificationManager.scheduleReapplyReminderRoutes, [.manualLog])
    }

    @MainActor
    func testUVLevelFromIndex() {
        XCTAssertEqual(UVLevel.from(index: 0), .low)
        XCTAssertEqual(UVLevel.from(index: 3), .moderate)
        XCTAssertEqual(UVLevel.from(index: 6), .high)
        XCTAssertEqual(UVLevel.from(index: 8), .veryHigh)
        XCTAssertEqual(UVLevel.from(index: 11), .extreme)
    }

    @MainActor
    func testUVLevelShouldShowBanner() {
        XCTAssertFalse(UVLevel.low.shouldShowBanner)
        XCTAssertTrue(UVLevel.moderate.shouldShowBanner)
        XCTAssertTrue(UVLevel.high.shouldShowBanner)
        XCTAssertTrue(UVLevel.veryHigh.shouldShowBanner)
        XCTAssertTrue(UVLevel.extreme.shouldShowBanner)
        XCTAssertFalse(UVLevel.unknown.shouldShowBanner)
    }

    @MainActor
    func testSettingsDefaultValues() {
        let settings = Settings()
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 8)
        XCTAssertEqual(settings.reminderMinute, 0)
        XCTAssertEqual(settings.weeklyHour, 18)
        XCTAssertEqual(settings.weeklyWeekday, 1)
        XCTAssertNil(settings.dailyPhraseState)
        XCTAssertNil(settings.weeklyPhraseState)
        XCTAssertEqual(settings.longestStreak, 0)
        XCTAssertFalse(settings.reapplyReminderEnabled)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 120)
    }

    @MainActor
    func testDailyRecordMethodRoundTrips() {
        let now = Date()
        let record = DailyRecord(startOfDay: now, verifiedAt: now, method: .manual)
        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.methodRawValue, 1)

        record.methodRawValue = 999
        XCTAssertEqual(record.method, .manual)
    }

    @MainActor
    func testAppRouteCasesExist() {
        XCTAssertEqual(AppRoute.history.rawValue, "history")
        XCTAssertEqual(AppRoute.manualLog.rawValue, "manualLog")
        XCTAssertEqual(AppRoute.weeklySummary.rawValue, "weeklySummary")
    }

    @MainActor
    func testPreferredCheckInRouteIsManualLog() throws {
        let state = try makeAppState()
        XCTAssertEqual(state.preferredCheckInRoute, .manualLog)
    }

    @MainActor
    func testPersonalBestBannerOnlyShowsOnImprovement() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual
        )
        let todayRecord = DailyRecord(
            startOfDay: today,
            verifiedAt: calendar.date(byAdding: .hour, value: 9, to: today) ?? today,
            method: .manual
        )
        state.modelContext.insert(yesterdayRecord)
        state.modelContext.insert(todayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertFalse(state.verificationSuccessPresentation?.isPersonalBest ?? true)
    }

    @MainActor
    func testManualLogUpdatesStreakAndLongestStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertGreaterThanOrEqual(state.longestStreak, 2)
        XCTAssertEqual(state.record(for: today)?.method, .manual)
    }

    @MainActor
    private func makeAppState(
        notificationManager: NotificationScheduling = NotificationManager.shared
    ) throws -> AppState {
        let schema = Schema([DailyRecord.self, Settings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager
        )
    }
}
