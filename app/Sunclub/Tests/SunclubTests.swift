import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class MockNotificationManager: NotificationScheduling {
    private(set) var scheduleRemindersCount = 0
    private(set) var scheduleReapplyReminderIntervals: [Int] = []
    private(set) var cancelReapplyRemindersCount = 0

    func scheduleReminders(using state: AppState) async {
        scheduleRemindersCount += 1
    }

    func scheduleReapplyReminder(intervalMinutes: Int) async {
        scheduleReapplyReminderIntervals.append(intervalMinutes)
    }

    func cancelReapplyReminders() async {
        cancelReapplyRemindersCount += 1
    }
}

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

    // MARK: - Manual Verification Method Tests

    @MainActor
    func testManualVerificationMethodProperties() {
        let manual = VerificationMethod.manual
        XCTAssertEqual(manual.title, "manual")
        XCTAssertEqual(manual.displayName, "Manual Log")
        XCTAssertEqual(manual.symbolName, "hand.tap")
        XCTAssertEqual(manual.rawValue, 1)
    }

    @MainActor
    func testCameraVerificationMethodProperties() {
        let camera = VerificationMethod.camera
        XCTAssertEqual(camera.title, "camera")
        XCTAssertEqual(camera.displayName, "Live Camera")
        XCTAssertEqual(camera.symbolName, "camera.viewfinder")
        XCTAssertEqual(camera.rawValue, 0)
    }

    @MainActor
    func testMarkAppliedTodayWithManualMethod() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, verificationDuration: nil)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.method, .manual)
        XCTAssertNil(state.records.first?.verificationDuration)
    }

    // MARK: - SPF Level and Notes Tests

    @MainActor
    func testMarkAppliedTodayWithSPFLevel() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, spfLevel: 50)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.spfLevel, 50)
    }

    @MainActor
    func testMarkAppliedTodayWithNotes() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, notes: "Before morning run")
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.notes, "Before morning run")
    }

    @MainActor
    func testDailyRecordInitWithAllFields() {
        let now = Date()
        let record = DailyRecord(
            startOfDay: now,
            verifiedAt: now,
            method: .manual,
            verificationDuration: 0.5,
            spfLevel: 30,
            notes: "Test note"
        )

        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.spfLevel, 30)
        XCTAssertEqual(record.notes, "Test note")
        XCTAssertEqual(record.verificationDuration, 0.5)
    }

    @MainActor
    func testUpdateExistingRecordPreservesSPF() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .camera, spfLevel: 50)
        XCTAssertEqual(state.records.first?.spfLevel, 50)

        // Re-logging should keep SPF if new one isn't provided
        state.markAppliedToday(method: .camera, verificationDuration: 1.0)
        XCTAssertEqual(state.records.count, 1)
        // SPF is preserved because markAppliedToday only updates if non-nil
        XCTAssertEqual(state.records.first?.spfLevel, 50)
    }

    // MARK: - Longest Streak Tests

    @MainActor
    func testLongestStreakUpdatesOnNewRecord() throws {
        let state = try makeAppState()
        XCTAssertEqual(state.longestStreak, 0)

        state.markAppliedToday(method: .camera)
        XCTAssertEqual(state.longestStreak, 1)
    }

    @MainActor
    func testLongestStreakTracksMaximum() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build a 3-day streak
        for offset in stride(from: -2, through: 0, by: 1) {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let record = DailyRecord(
                startOfDay: day,
                verifiedAt: calendar.date(byAdding: .hour, value: 8, to: day) ?? day,
                method: .camera
            )
            state.modelContext.insert(record)
        }
        state.refresh()

        // Trigger longest streak update by marking today again
        state.markAppliedToday(method: .camera)
        XCTAssertGreaterThanOrEqual(state.longestStreak, 3)
    }

    @MainActor
    func testLongestStreakNeverDecreases() throws {
        let state = try makeAppState()

        // Set a manual longest streak
        state.settings.longestStreak = 10
        state.save()

        // Mark today (streak of 1)
        state.markAppliedToday(method: .camera)
        XCTAssertEqual(state.longestStreak, 10, "Longest streak should never decrease")
    }

    @MainActor
    func testLongestStreakBackfillsFromHistoricalRecords() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in stride(from: -5, through: -3, by: 1) {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let record = DailyRecord(
                startOfDay: day,
                verifiedAt: calendar.date(byAdding: .hour, value: 8, to: day) ?? day,
                method: .camera
            )
            state.modelContext.insert(record)
        }

        state.refresh()

        XCTAssertEqual(state.longestStreak, 3)
    }

    // MARK: - Delete Record Tests

    @MainActor
    func testDeleteRecordRemovesRecord() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .camera)
        XCTAssertEqual(state.records.count, 1)

        state.deleteRecord(for: Date())
        XCTAssertEqual(state.records.count, 0)
    }

    @MainActor
    func testDeleteRecordForNonexistentDayDoesNothing() throws {
        let state = try makeAppState()
        let calendar = Calendar.current

        state.markAppliedToday(method: .camera)
        XCTAssertEqual(state.records.count, 1)

        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        state.deleteRecord(for: yesterday)
        XCTAssertEqual(state.records.count, 1, "Deleting a non-existent day should have no effect")
    }

    @MainActor
    func testDeletingTodayCancelsPendingReapplyReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.markAppliedToday(method: .camera)
        state.deleteRecord(for: Date())

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
    }

    // MARK: - Reapplication Settings Tests

    @MainActor
    func testUpdateReapplySettingsPersists() throws {
        let state = try makeAppState()

        state.updateReapplySettings(enabled: true, intervalMinutes: 90)
        XCTAssertTrue(state.settings.reapplyReminderEnabled)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 90)
    }

    @MainActor
    func testUpdateReapplySettingsClampsInterval() throws {
        let state = try makeAppState()

        state.updateReapplySettings(enabled: true, intervalMinutes: 10)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 30, "Minimum interval should be 30 minutes")

        state.updateReapplySettings(enabled: true, intervalMinutes: 600)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 480, "Maximum interval should be 480 minutes")
    }

    @MainActor
    func testReapplySettingsDefaultValues() throws {
        let state = try makeAppState()

        XCTAssertFalse(state.settings.reapplyReminderEnabled)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 120)
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

    // MARK: - UV Index Service Tests

    @MainActor
    func testUVLevelFromIndex() {
        XCTAssertEqual(UVLevel.from(index: 0), .low)
        XCTAssertEqual(UVLevel.from(index: 2), .low)
        XCTAssertEqual(UVLevel.from(index: 3), .moderate)
        XCTAssertEqual(UVLevel.from(index: 5), .moderate)
        XCTAssertEqual(UVLevel.from(index: 6), .high)
        XCTAssertEqual(UVLevel.from(index: 7), .high)
        XCTAssertEqual(UVLevel.from(index: 8), .veryHigh)
        XCTAssertEqual(UVLevel.from(index: 10), .veryHigh)
        XCTAssertEqual(UVLevel.from(index: 11), .extreme)
        XCTAssertEqual(UVLevel.from(index: 15), .extreme)
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
    func testUVReadingIsStale() {
        let fresh = UVReading(index: 5, timestamp: Date())
        XCTAssertFalse(fresh.isStale)

        let stale = UVReading(index: 5, timestamp: Date().addingTimeInterval(-7200))
        XCTAssertTrue(stale.isStale)
    }

    @MainActor
    func testUVReadingProperties() {
        let reading = UVReading(index: 7)
        XCTAssertEqual(reading.index, 7)
        XCTAssertEqual(reading.level, .high)
        XCTAssertEqual(reading.level.displayName, "High")
        XCTAssertFalse(reading.level.shortAdvice.isEmpty)
        XCTAssertFalse(reading.level.symbolName.isEmpty)
    }

    @MainActor
    func testUVIndexServiceFetchSetsReading() {
        let service = UVIndexService()
        XCTAssertNil(service.currentReading)

        service.fetchUVIndex()
        XCTAssertNotNil(service.currentReading)
        XCTAssertFalse(service.isLoading)
    }

    @MainActor
    func testUVIndexServiceDoesNotRefetchWhenFresh() {
        let service = UVIndexService()
        service.fetchUVIndex()
        let firstReading = service.currentReading

        service.fetchUVIndex()
        XCTAssertEqual(service.currentReading, firstReading, "Should not refetch when reading is fresh")
    }

    // MARK: - Calendar Analytics Extended Tests

    @MainActor
    func testMonthGridReturnsCorrectNumberOfCells() {
        let calendar = Calendar.current
        let today = Date()
        let grid = CalendarAnalytics.monthGridDays(for: today, calendar: calendar)

        // Grid should be a multiple of 7
        XCTAssertEqual(grid.count % 7, 0)
        // Minimum 28 cells (4 weeks), maximum 42 cells (6 weeks)
        XCTAssertGreaterThanOrEqual(grid.count, 28)
        XCTAssertLessThanOrEqual(grid.count, 42)
    }

    @MainActor
    func testWeeklyReportMissedCount() {
        let report = WeeklyReport(
            startDate: Date(),
            endDate: Date(),
            appliedCount: 3,
            totalDays: 7,
            missedDays: ["Mon", "Tue", "Wed", "Thu"],
            streak: 2
        )

        XCTAssertEqual(report.missedCount, 4)
    }

    @MainActor
    func testStreakIsZeroWithNoRecords() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        XCTAssertEqual(CalendarAnalytics.currentStreak(records: [], now: today, calendar: calendar), 0)
    }

    // MARK: - Settings Default Values Tests

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

    // MARK: - Verification Method Exhaustive Tests

    @MainActor
    func testVerificationMethodCaseIterable() {
        let allCases = VerificationMethod.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.camera))
        XCTAssertTrue(allCases.contains(.manual))
    }

    @MainActor
    func testVerificationMethodRoundTripsThroughRawValue() {
        for method in VerificationMethod.allCases {
            let rawValue = method.rawValue
            XCTAssertEqual(VerificationMethod(rawValue: rawValue), method)
        }
    }

    @MainActor
    func testDailyRecordMethodRoundTrips() {
        let now = Date()
        let record = DailyRecord(startOfDay: now, verifiedAt: now, method: .manual)
        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.methodRawValue, 1)

        record.method = .camera
        XCTAssertEqual(record.method, .camera)
        XCTAssertEqual(record.methodRawValue, 0)
    }

    // MARK: - AppRoute Tests

    @MainActor
    func testAppRouteNewCasesExist() {
        let historyRoute = AppRoute.history
        XCTAssertEqual(historyRoute.rawValue, "history")
        XCTAssertEqual(historyRoute.id, "history")

        let manualLogRoute = AppRoute.manualLog
        XCTAssertEqual(manualLogRoute.rawValue, "manualLog")
        XCTAssertEqual(manualLogRoute.id, "manualLog")
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
            method: .camera
        )
        let todayRecord = DailyRecord(
            startOfDay: today,
            verifiedAt: calendar.date(byAdding: .hour, value: 9, to: today) ?? today,
            method: .camera
        )
        state.modelContext.insert(yesterdayRecord)
        state.modelContext.insert(todayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .camera, verificationDuration: 0.8)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertFalse(state.verificationSuccessPresentation?.isPersonalBest ?? true)
    }

    // MARK: - Integration: Manual Log + Streak Update

    @MainActor
    func testManualLogUpdatesStreakAndLongestStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Add yesterday's record
        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .camera
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        // Manual log today
        state.recordVerificationSuccess(method: .manual, verificationDuration: nil)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertGreaterThanOrEqual(state.longestStreak, 2)
        XCTAssertEqual(state.record(for: today)?.method, .manual)
    }

    // MARK: - Helpers

    @MainActor
    private func makeAppState(
        notificationManager: NotificationScheduling = NotificationManager.shared
    ) throws -> AppState {
        let schema = Schema([DailyRecord.self, Settings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return AppState(context: ModelContext(container), notificationManager: notificationManager)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeConfigFile(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: url)
    }
}
