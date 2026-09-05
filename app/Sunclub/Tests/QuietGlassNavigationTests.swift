import SwiftUI
import UIKit
import XCTest
@testable import Sunclub

@MainActor
final class QuietGlassNavigationTests: XCTestCase {
    func testWeeklySummaryExternalRoutesReturnToHistory() {
        for route in [AppRoute.weeklySummary, .achievements, .yearInReview] {
            let router = AppRouter()
            router.open(.manualLog)
            router.open(route)

            XCTAssertEqual(router.selectedTab, .history)
            XCTAssertEqual(router.path, [.weeklySummary])
            XCTAssertTrue(router.canGoBack)
            router.goBack()
            XCTAssertEqual(router.selectedTab, .history)
            XCTAssertTrue(router.path.isEmpty)
            XCTAssertTrue(router.showsRootTabChrome)
        }
    }

    func testSwitchingTabsPreservesOpenHistoryDetailAndLoggingContext() {
        let router = AppRouter()
        let date = Date(timeIntervalSince1970: 1_783_814_400)
        router.open(.history)
        router.push(.weeklySummary)
        router.open(.manualLog, targetDate: date, targetDayPart: .morning)
        XCTAssertEqual(router.payload.targetDate, date)
        XCTAssertEqual(router.payload.targetDayPart, .morning)

        router.selectTab(.history)
        XCTAssertEqual(router.path, [.weeklySummary])
        router.selectTab(.today)
        XCTAssertEqual(router.path, [.manualLog])
        router.goHome()
        XCTAssertTrue(router.path.isEmpty)
        XCTAssertTrue(router.historyPath.isEmpty)
    }

    func testNavigationIconsResolveToBundledVectorAssets() throws {
        for icon in SunIcon.allCases {
            let image = try XCTUnwrap(UIImage(named: icon.assetName), "Missing bundled icon: \(icon.assetName)")
            XCTAssertGreaterThan(image.size.width, 0)
            XCTAssertGreaterThan(image.size.height, 0)
        }
    }
}
