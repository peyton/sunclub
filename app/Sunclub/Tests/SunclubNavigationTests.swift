import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubNavigationTests: SunclubTestCase {
    @MainActor
    func testAppRouterGoBackRemovesCurrentRoute() {
        let router = AppRouter()

        router.open(.manualLog)
        XCTAssertEqual(router.path, [.manualLog])
        XCTAssertTrue(router.canGoBack)

        router.goBack()

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertFalse(router.canGoBack)
    }

    @MainActor
    func testAppRouteCasesExist() {
        XCTAssertEqual(AppRoute.history.rawValue, "history")
        XCTAssertEqual(AppRoute.manualLog.rawValue, "manualLog")
        XCTAssertEqual(AppRoute.reapplyCheckIn.rawValue, "reapplyCheckIn")
        XCTAssertEqual(AppRoute.backfillYesterday.rawValue, "backfillYesterday")
        XCTAssertEqual(AppRoute.weeklySummary.rawValue, "weeklySummary")
        XCTAssertEqual(AppRoute.recovery.rawValue, "recovery")
        XCTAssertEqual(AppRoute.uvForecast.rawValue, "uvForecast")
        XCTAssertEqual(AppRoute.privacy.rawValue, "privacy")
        XCTAssertEqual(AppRoute.support.rawValue, "support")
        XCTAssertEqual(AppRoute.settingsSunscreenReminders.rawValue, "settingsSunscreenReminders")
        XCTAssertEqual(AppRoute.settingsReapplyReminder.rawValue, "settingsReapplyReminder")
        XCTAssertEqual(AppRoute.settingsNotifications.rawValue, "settingsNotifications")
        XCTAssertEqual(AppRoute.settingsHealthWeather.rawValue, "settingsHealthWeather")
        XCTAssertEqual(AppRoute.settingsData.rawValue, "settingsData")
        XCTAssertEqual(AppRoute.settingsShortcuts.rawValue, "settingsShortcuts")
        XCTAssertEqual(AppRoute.settingsHelp.rawValue, "settingsHelp")
    }

    @MainActor
    func testAppRouterSwitchesPrimaryRoutesAsTabs() {
        let router = AppRouter()

        router.open(.history)
        XCTAssertEqual(router.selectedTab, .history)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertFalse(router.canGoBack)

        router.open(.weeklySummary)
        XCTAssertEqual(router.selectedTab, .history)
        XCTAssertEqual(router.path, [.weeklySummary])
        router.goBack()
        XCTAssertEqual(router.selectedTab, .history)
        XCTAssertTrue(router.path.isEmpty)

        router.open(.settings)
        XCTAssertEqual(router.selectedTab, .settings)
        XCTAssertTrue(router.path.isEmpty)
    }

    @MainActor
    func testAppRouterKeepsSettingsDetailRoutesInsideSettingsTab() {
        let router = AppRouter()

        router.open(.settings)
        router.push(.settingsSunscreenReminders)

        XCTAssertEqual(router.selectedTab, .settings)
        XCTAssertEqual(router.path, [.settingsSunscreenReminders])
        XCTAssertTrue(router.canGoBack)

        router.goBack()

        XCTAssertEqual(router.selectedTab, .settings)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertFalse(router.canGoBack)
    }

    @MainActor
    func testAppRouterKeepsPushedRoutesInsideSelectedTab() {
        let router = AppRouter()

        XCTAssertTrue(router.showsRootTabChrome)

        router.open(.settings)
        router.push(.privacy)
        XCTAssertEqual(router.selectedTab, .settings)
        XCTAssertEqual(router.path, [.privacy])
        XCTAssertTrue(router.canGoBack)
        XCTAssertFalse(router.showsRootTabChrome)

        router.selectTab(.today)
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertTrue(router.showsRootTabChrome)

        router.selectTab(.settings)
        XCTAssertEqual(router.path, [.privacy])
        XCTAssertFalse(router.showsRootTabChrome)
    }

    @MainActor
    func testAppRouterPreservesThreeIndependentTabStacks() {
        let router = AppRouter()
        let expectedPaths: [AppTab: [AppRoute]] = [
            .today: [.manualLog],
            .history: [.weeklySummary, .backfillYesterday],
            .settings: [.privacy]
        ]

        for tab in AppTab.allCases {
            router.selectTab(tab)
            router.setPath(expectedPaths[tab] ?? [], for: tab)
        }

        for tab in AppTab.allCases {
            router.selectTab(tab)
            XCTAssertEqual(router.path, expectedPaths[tab])
            XCTAssertFalse(router.showsRootTabChrome)
        }
    }

    @MainActor
    func testAppRouterPayloadSupportsLegacyAndExplicitManualLogRoutes() throws {
        let router = AppRouter()
        let target = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12)))

        router.open(.manualLog)
        XCTAssertEqual(router.path, [.manualLog])
        XCTAssertNil(router.payload.targetDate)
        XCTAssertNil(router.payload.targetDayPart)

        router.open(.manualLog, targetDate: target, targetDayPart: .night)
        XCTAssertEqual(router.path, [.manualLog])
        XCTAssertTrue(Calendar.current.isDate(router.payload.targetDate ?? Date.distantPast, inSameDayAs: target))
        XCTAssertEqual(router.payload.targetDayPart, .night)
    }
}
