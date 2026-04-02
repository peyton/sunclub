import XCTest

final class SunclubUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsWelcome() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingAdvancesToHome() throws {
        let app = launchAndCompleteOnboarding()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.verifyNow"].exists)
        XCTAssertTrue(app.buttons["home.settingsButton"].exists)
        XCTAssertTrue(app.staticTexts["home.todayStatus"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeRoutesToWeeklySummaryAndSettings() throws {
        let app = launchHome()

        app.buttons["home.streakCard"].tap()
        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        relaunchedApp.launch()

        XCTAssertTrue(relaunchedApp.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testManualLogSuccessReturnsHome() throws {
        let app = launchHome()

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()
        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))

        app.buttons["success.done"].tap()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsReminderControls() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.buttons["settings.notificationTime"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.manageSubscription"].exists)
        XCTAssertTrue(app.switches["settings.reapplyToggle"].exists)
    }

    @MainActor
    func testSettingsEdgeSwipeReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.buttons["settings.notificationTime"].waitForExistence(timeout: 5))

        performBackSwipe(in: app)

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeShowsManualLogButton() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeShowsHistoryCard() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.historyCard"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeShowsHighUVStatusFromLaunchOverride() throws {
        let app = launchHome(additionalArguments: ["UITEST_UV_INDEX=7"])

        let uvStatus = app.otherElements["home.uvStatus"]
        XCTAssertTrue(uvStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(uvStatus.label, "UV is high today")

        let detail = app.staticTexts["home.todayDetail"]
        XCTAssertTrue(detail.exists)
        XCTAssertTrue(detail.label.contains("reapply sooner"))
    }

    @MainActor
    func testManualLogFlowShowsSuccess() throws {
        let app = launchHome()

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()

        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryViewShowsCalendar() throws {
        let app = launchHome()

        app.buttons["home.historyCard"].tap()
        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["history.previousMonth"].exists)
    }

    @MainActor
    func testDailyNotificationRouteOpensManualLog() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=manualLog"]
        app.launch()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWeeklyNotificationRouteOpensWeeklySummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHighUVReapplyReminderNoteUsesStrongerCopy() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_UV_INDEX=7",
            "UITEST_REAPPLY_ENABLED",
            "UITEST_REAPPLY_INTERVAL=120"
        ])

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()

        let reapplyNote = app.otherElements["success.reapplyNote"]
        XCTAssertTrue(reapplyNote.waitForExistence(timeout: 5))
        XCTAssertTrue(reapplyNote.label.contains("High UV today"))
        XCTAssertTrue(reapplyNote.label.contains("1h 30m"))
    }

    @MainActor
    private func launchAndCompleteOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()
        return completeOnboarding(in: app)
    }

    @MainActor
    private func launchHome() -> XCUIApplication {
        launchHome(additionalArguments: [])
    }

    @MainActor
    private func launchHome(additionalArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING"] + additionalArguments
        app.launch()
        return app
    }

    @discardableResult
    @MainActor
    private func completeOnboarding(in app: XCUIApplication) -> XCUIApplication {
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.enableNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.enableNotifications"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func performBackSwipe(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
