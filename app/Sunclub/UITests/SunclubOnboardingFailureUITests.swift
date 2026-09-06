import XCTest

final class SunclubOnboardingFailureUITests: SunclubUITestCase {
    @MainActor
    func testSchedulingFailureRetriesAutomaticallyAfterSavingSetup() {
        let app = launchNotificationSetup(scheduling: "fail-once")
        tapHittableElement(app.buttons["onboarding.enableNotifications"], in: app)
        assertTodayRootVisible(in: app)
        XCTAssertFalse(app.buttons["onboarding.enableNotifications"].exists)
    }

    @MainActor
    func testPersistentSchedulingFailureOffersTruthfulContinueToToday() {
        let app = launchNotificationSetup(scheduling: "fail-always")

        tapHittableElement(app.buttons["onboarding.enableNotifications"], in: app)

        let error = app.descendants(matching: .any)["onboarding.completionError"]
        XCTAssertTrue(
            error.waitForExistence(timeout: 10),
            "A reminder failure must remain actionable after setup has been saved."
        )
        XCTAssertTrue(error.label.contains("could not be scheduled"))
        XCTAssertFalse(error.label.localizedCaseInsensitiveContains("disabled"))
        XCTAssertTrue(error.label.contains("retry automatically"))
        XCTAssertFalse(app.buttons["onboarding.enableNotifications"].exists)
        let continueButton = app.buttons["onboarding.skipNotifications"]
        XCTAssertTrue(waitForLabel("Continue to Today", on: continueButton))
        XCTAssertTrue(continueButton.isEnabled)

        tapHittableElement(continueButton, in: app)

        assertTodayRootVisible(in: app)
        XCTAssertFalse(error.exists)
        XCTAssertFalse(app.buttons["welcome.getStarted"].exists)
        XCTAssertFalse(app.buttons["onboarding.skipNotifications"].exists)
    }

    @MainActor
    private func launchNotificationSetup(scheduling: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_ONBOARDING_NOTIFICATIONS=\(scheduling)"
        ]
        app.launch()
        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        tapHittableElement(app.buttons["welcome.getStarted"], in: app)
        XCTAssertTrue(app.buttons["onboarding.enableNotifications"].waitForExistence(timeout: 5))
        return app
    }
}
