import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubWidgetTests: XCTestCase {
    func testSnapshotShowsTodayOpenWhenLatestRecordIsYesterday() {
        let snapshot = makeSnapshot(dayOffsets: [1, 2, 3], longestStreak: 7)

        XCTAssertFalse(snapshot.hasLoggedToday())
        XCTAssertEqual(snapshot.streakValue(), 3)
        XCTAssertEqual(snapshot.weeklyValue(), 3)
    }

    func testSnapshotShowsLoggedTodayAndRetainsStreak() {
        let snapshot = makeSnapshot(dayOffsets: [0, 1, 2, 3], longestStreak: 8)

        XCTAssertTrue(snapshot.hasLoggedToday())
        XCTAssertEqual(snapshot.streakValue(), 4)
    }

    func testSnapshotResetsStreakAfterMissedYesterday() {
        let snapshot = makeSnapshot(dayOffsets: [2, 3, 4], longestStreak: 9)

        XCTAssertFalse(snapshot.hasLoggedToday())
        XCTAssertEqual(snapshot.streakValue(), 0)
    }

    func testSnapshotCalculatesMonthlyCountsFromRecordedDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentMonthRecord = makeRecord(day: today, spfLevel: 50)
        let olderRecord = makeRecord(day: calendar.date(byAdding: .month, value: -1, to: today) ?? today, spfLevel: 30)

        let settings = Settings()
        settings.hasCompletedOnboarding = true
        let snapshot = SunclubWidgetSnapshotBuilder.make(settings: settings, records: [currentMonthRecord, olderRecord])

        XCTAssertEqual(snapshot.monthlyAppliedValue(now: today, calendar: calendar), 1)
        XCTAssertGreaterThanOrEqual(snapshot.monthlyDayValue(now: today, calendar: calendar), 1)
        XCTAssertEqual(snapshot.mostUsedSPF, 50)
    }

    func testSnapshotDayStatusUsesStoredCalendarHistory() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let snapshot = makeSnapshot(dayOffsets: [1], longestStreak: 4)

        XCTAssertEqual(snapshot.dayStatus(for: today, now: today, calendar: calendar), .todayPending)
        XCTAssertEqual(snapshot.dayStatus(for: yesterday, now: today, calendar: calendar), .applied)
        XCTAssertEqual(snapshot.dayStatus(for: tomorrow, now: today, calendar: calendar), .future)
    }

    func testSunclubDeepLinkParsesWidgetRoutes() throws {
        let summaryURL = try XCTUnwrap(URL(string: "sunclub://widget/open/summary"))
        let historyURL = try XCTUnwrap(URL(string: "sunclub://widget/open/history"))
        let updateURL = try XCTUnwrap(URL(string: "sunclub://widget/open/updateToday"))

        XCTAssertEqual(SunclubDeepLink(url: summaryURL), .widgetRoute(.summary))
        XCTAssertEqual(SunclubDeepLink(url: historyURL), .widgetRoute(.history))
        XCTAssertEqual(SunclubDeepLink(url: updateURL), .widgetRoute(.updateToday))
    }

    func testWidgetSummaryRouteOpensWeeklySummary() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetRoute(.summary), appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.path, [.weeklySummary])
    }

    func testWidgetHistoryRouteOpensHistory() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetRoute(.history), appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.path, [.history])
    }

    func testWidgetUpdateRouteOpensManualLog() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetRoute(.updateToday), appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.path, [.manualLog])
    }

    private func makeSnapshot(dayOffsets: [Int], longestStreak: Int) -> SunclubWidgetSnapshot {
        let settings = Settings()
        settings.hasCompletedOnboarding = true
        settings.longestStreak = longestStreak

        let records = dayOffsets.map { offset in
            makeRecord(day: Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date())) ?? Date())
        }

        return SunclubWidgetSnapshotBuilder.make(settings: settings, records: records)
    }

    private func makeRecord(day: Date, spfLevel: Int? = 50) -> DailyRecord {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay

        return DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: spfLevel
        )
    }

    private func makeAppState(
        notificationManager: NotificationScheduling? = nil
    ) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager ?? NotificationManager.shared
        )
    }
}
