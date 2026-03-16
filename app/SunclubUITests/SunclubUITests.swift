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
        XCTAssertTrue(app.staticTexts.matching(identifier: "home.activeProductName").firstMatch.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Verified!"].waitForExistence(timeout: 5))

        app.buttons["success.done"].tap()
        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsCanAddAndSwitchProducts() throws {
        let app = launchAndCompleteOnboarding()

        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.buttons["settings.addProduct"].waitForExistence(timeout: 5))
        app.buttons["settings.addProduct"].tap()

        XCTAssertTrue(app.buttons["scan.skip"].waitForExistence(timeout: 5))
        app.buttons["scan.skip"].tap()

        XCTAssertTrue(app.buttons["training.capturePhoto"].waitForExistence(timeout: 5))
        for _ in 0..<5 {
            app.buttons["training.capturePhoto"].tap()
        }

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.switchProduct"].exists)
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
        XCTAssertTrue(app.buttons["scan.demoBarcode"].waitForExistence(timeout: 5))
        app.buttons["scan.demoBarcode"].tap()
        app.buttons["scan.continue"].tap()

        XCTAssertTrue(app.buttons["training.capturePhoto"].waitForExistence(timeout: 5))
        for _ in 0..<5 {
            app.buttons["training.capturePhoto"].tap()
        }

        XCTAssertTrue(app.buttons["onboarding.enableNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.enableNotifications"].tap()

        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
        return app
    }
}
