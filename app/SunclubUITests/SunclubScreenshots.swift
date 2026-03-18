import XCTest

final class SunclubScreenshots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppScreens() throws {
        captureWelcome()
        captureHome()
        captureWeeklySummary()
        captureVerifyCamera()
        captureSuccess()
        captureSettings()
    }

    @MainActor
    private func captureWelcome() {
        let app = launch(arguments: ["UITEST_MODE"])
        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        snapshot("01_Welcome")
        app.terminate()
    }

    @MainActor
    private func captureHome() {
        let app = launch(arguments: ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING"])
        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
        snapshot("02_Home")
        app.terminate()
    }

    @MainActor
    private func captureWeeklySummary() {
        let app = launch(arguments: ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE_WEEKLY_SUMMARY"])
        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
        snapshot("03_WeeklySummary")
        app.terminate()
    }

    @MainActor
    private func captureVerifyCamera() {
        let app = launch(arguments: ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE_VERIFY_CAMERA", "UITEST_HOLD_VERIFY_SCREEN"])
        XCTAssertTrue(app.staticTexts["verify.title"].waitForExistence(timeout: 5))
        snapshot("04_VerifyCamera")
        app.terminate()
    }

    @MainActor
    private func captureSuccess() {
        let app = launch(arguments: ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE_VERIFY_CAMERA"])
        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))
        snapshot("05_Success")
        app.terminate()
    }

    @MainActor
    private func captureSettings() {
        let app = launch(arguments: ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING"])
        XCTAssertTrue(app.buttons["home.verifyNow"].waitForExistence(timeout: 5))
        app.buttons["home.settingsButton"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        snapshot("06_Settings")
        app.terminate()
    }

    @MainActor
    private func launch(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += arguments
        app.launch()
        return app
    }
}
