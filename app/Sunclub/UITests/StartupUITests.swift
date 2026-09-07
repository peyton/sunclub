import XCTest

final class StartupUITests: SunclubUITestCase {
    @MainActor
    func testPersistentStoreFailureDoesNotCrashOrShowRecoveryControlsOrEmptyApp() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_MODE", "UITEST_FORCE_STORE_OPEN_FAILURE"]
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertFalse(app.buttons["startup.retry"].exists)
        XCTAssertFalse(app.buttons["home.logManually"].exists)
        XCTAssertFalse(app.buttons["welcome.getStarted"].exists)
        XCTAssertFalse(app.staticTexts["Unable to open Sunclub"].exists)
    }

    @MainActor
    func testTransientStartupFailureRecoversOnFirstForegroundActivation() throws {
        let app = launchHome(additionalArguments: ["UITEST_FORCE_STORE_OPEN_FAILURE_ONCE"])
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["startup.retry"].exists)
    }
}
