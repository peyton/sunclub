import Foundation
import SwiftData
import UIKit
import XCTest
@testable import Sunclub

@MainActor
final class SunclubWidgetTests: XCTestCase {
    func testLogTodayPresentationSupportsEveryWidgetFamily() {
        XCTAssertEqual(
            SunclubLogTodayWidgetFamily.allCases.map(\.rawValue),
            [
                "systemSmall",
                "systemMedium",
                "systemLarge",
                "systemExtraLarge",
                "accessoryInline",
                "accessoryCircular",
                "accessoryRectangular"
            ]
        )
    }

    func testLogTodaySmallOpenPresentationUsesShortIconLedCopy() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            currentUVIndex: 7,
            peakUVIndex: 9
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemSmall,
            calendar: calendar
        )

        XCTAssertEqual(presentation.state, .open)
        XCTAssertEqual(presentation.iconName, "sun.max.fill")
        XCTAssertEqual(presentation.title, "Log")
        XCTAssertEqual(presentation.subtitle, "Peak UV 9")
        XCTAssertEqual(presentation.actionText, "Tap")
        XCTAssertFalse(presentation.title.contains("Today"))
        XCTAssertLessThanOrEqual(presentation.title.count, 4)
    }

    func testLogTodayMediumPresentationAddsHabitMetrics() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            currentUVIndex: 7,
            peakUVIndex: 9,
            mostUsedSPF: 50
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemMedium,
            calendar: calendar
        )

        XCTAssertEqual(presentation.title, "Log sunscreen")
        XCTAssertEqual(presentation.detail, "Usual SPF 50")
        XCTAssertEqual(presentation.metrics.map(\.title), ["Streak", "Week", "Month", "UV"])
        XCTAssertEqual(presentation.metrics.map(\.value), ["3d", "3/7", "3/15", "9"])
    }

    func testLogTodayLargeLoggedPresentationShowsUpdateStateAndReapply() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 11)
        let lastReappliedAt = try fixedDate(calendar: calendar, hour: 10)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            lastReappliedAt: lastReappliedAt,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemLarge,
            calendar: calendar
        )

        XCTAssertEqual(presentation.state, .logged)
        XCTAssertEqual(presentation.iconName, "checkmark.seal.fill")
        XCTAssertEqual(presentation.title, "Logged today")
        XCTAssertEqual(presentation.subtitle, "4d streak")
        XCTAssertEqual(presentation.actionText, "Update")
        XCTAssertTrue(presentation.detail.hasPrefix("Reapply "))
    }

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
        let scheme = SunclubRuntimeConfiguration.urlScheme
        let summaryURL = try XCTUnwrap(URL(string: "\(scheme)://widget/open/summary"))
        let historyURL = try XCTUnwrap(URL(string: "\(scheme)://widget/open/history"))
        let updateURL = try XCTUnwrap(URL(string: "\(scheme)://widget/open/updateToday"))

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

    func testPendingRouteStoreRoundTripsAppRoutes() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SunclubWidgetSnapshotStore(userDefaults: defaults)

        store.setPendingRoute(.manualLog)

        XCTAssertEqual(store.takePendingRoute(), .manualLog)
        XCTAssertNil(store.takePendingRoute())
    }

    func testPendingRouteStoreReadsLegacyWidgetRouteValues() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SunclubWidgetSnapshotStore(userDefaults: defaults)
        defaults.set(SunclubWidgetRoute.updateToday.rawValue, forKey: SunclubWidgetDefaults.pendingRouteKey)

        XCTAssertEqual(store.takePendingRoute(), .manualLog)
    }

    func testHomeScreenQuickActionStoresManualLogRoute() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let shortcutItem = UIApplicationShortcutItem(
            type: SunclubHomeScreenQuickAction.logToday.rawValue,
            localizedTitle: "Log Today"
        )

        XCTAssertTrue(SunclubHomeScreenQuickAction.handleShortcutItem(shortcutItem, routeStore: store))
        XCTAssertEqual(store.takePendingRoute(), .manualLog)
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

    private func makeWidgetSnapshot(
        dayOffsets: [Int],
        longestStreak: Int,
        now: Date,
        calendar: Calendar,
        isOnboardingComplete: Bool = true,
        currentUVIndex: Int? = nil,
        peakUVIndex: Int? = nil,
        mostUsedSPF: Int? = nil,
        lastReappliedAt: Date? = nil,
        reapplyReminderEnabled: Bool = false,
        reapplyIntervalMinutes: Int = 120
    ) -> SunclubWidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        let recordedDays = dayOffsets.compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.sorted()
        let lastLoggedDay = recordedDays.last

        return SunclubWidgetSnapshot(
            isOnboardingComplete: isOnboardingComplete,
            lastLoggedDay: lastLoggedDay,
            lastVerifiedAt: lastLoggedDay.flatMap {
                calendar.date(byAdding: .hour, value: 9, to: $0)
            },
            lastReappliedAt: lastReappliedAt,
            recordedDays: recordedDays,
            currentStreak: 0,
            longestStreak: longestStreak,
            weeklyAppliedCount: 0,
            monthlyAppliedCount: 0,
            monthlyDayCount: 0,
            mostUsedSPF: mostUsedSPF,
            currentUVIndex: currentUVIndex,
            peakUVIndex: peakUVIndex,
            peakUVHour: peakUVIndex == nil ? nil : calendar.date(byAdding: .hour, value: 13, to: today),
            reapplyReminderEnabled: reapplyReminderEnabled,
            reapplyIntervalMinutes: reapplyIntervalMinutes
        )
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 1
        return calendar
    }

    private func fixedDate(calendar: Calendar, hour: Int = 12) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: hour))
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
