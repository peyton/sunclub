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

        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.settingsButton"].exists)
        XCTAssertTrue(app.staticTexts["home.todayStatus"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeRoutesToWeeklySummaryAndSettings() throws {
        let app = launchAndCompleteOnboarding()

        app.buttons["home.streakCard"].tap()
        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunchedApp = launchAndCompleteOnboarding()

        relaunchedApp.buttons["home.settingsButton"].tap()
        XCTAssertTrue(relaunchedApp.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testVerifyFlowShowsSuccessAndReturnsHome() throws {
        let app = launchAndCompleteOnboarding()

        app.buttons["home.verifyNow"].tap()
        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))

        app.buttons["success.done"].tap()
        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsReminderControls() throws {
        let app = launchAndCompleteOnboarding()

        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.buttons["settings.notificationTime"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.manageSubscription"].exists)
    }

    @MainActor
    func testDailyNotificationRouteOpensCamera() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE_VERIFY_CAMERA", "UITEST_HOLD_VERIFY_SCREEN"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verify.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWeeklyNotificationRouteOpensWeeklySummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE_WEEKLY_SUMMARY"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchAndCompleteOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()
        return completeOnboarding(in: app)
    }

    @discardableResult
    @MainActor
    private func completeOnboarding(in app: XCUIApplication) -> XCUIApplication {
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.enableNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.enableNotifications"].tap()

        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
        return app
    }
}
