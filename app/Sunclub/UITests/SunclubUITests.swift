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
    func testVerifyFlowShowsSuccessAndReturnsHome() throws {
        let app = launchHome(scanEnabled: true)

        app.buttons["home.verifyNow"].tap()
        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))

        app.buttons["success.done"].tap()
        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
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
    func testVerifyFlowPromptsForModelDownloadWhenUnavailable() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "FEATURE_ENABLE_BOTTLE_SCAN",
            "UITEST_ROUTE_VERIFY_CAMERA",
            "UITEST_REQUIRE_MODEL_DOWNLOAD"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["verify.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["verify.downloadModel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["verify.logManual"].exists)
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
    func testDailyNotificationRouteFallsBackToManualLogWhenBottleScanIsDisabled() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE_VERIFY_CAMERA", "UITEST_HOLD_VERIFY_SCREEN"]
        app.launch()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["verify.title"].exists)
    }

    @MainActor
    func testDailyNotificationRouteOpensCameraWhenBottleScanIsEnabled() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "FEATURE_ENABLE_BOTTLE_SCAN",
            "UITEST_ROUTE_VERIFY_CAMERA",
            "UITEST_HOLD_VERIFY_SCREEN"
        ]
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

    @MainActor
    private func launchHome() -> XCUIApplication {
        return launchHome(scanEnabled: false)
    }

    @MainActor
    private func launchHome(scanEnabled: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING"]
        if scanEnabled {
            app.launchArguments.append("FEATURE_ENABLE_BOTTLE_SCAN")
        }
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
}
