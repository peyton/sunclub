import XCTest

final class DepartureCheckInUITests: SunclubUITestCase {
    @MainActor
    func testConfirmEarlierApplicationAndUndo() {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_FORCE_DEPARTURE_CHECK_IN"]
        app.launch()
        let confirm = app.buttons["home.checkIn.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        tapHittableElement(confirm, in: app)
        let earlier = app.buttons["checkIn.confirm.30"]
        XCTAssertTrue(earlier.waitForExistence(timeout: 5))
        tapHittableElement(earlier, in: app)
        XCTAssertTrue(app.staticTexts["Sunscreen logged"].waitForExistence(timeout: 5))
        tapHittableElement(app.buttons["Undo"], in: app)
        XCTAssertTrue(app.buttons["checkIn.confirm.30"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDismissDoesNotLogSunscreen() {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_FORCE_DEPARTURE_CHECK_IN"]
        app.launch()
        let dismiss = app.buttons["home.checkIn.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 10))
        tapHittableElement(dismiss, in: app)
        XCTAssertFalse(app.buttons["home.checkIn.confirm"].exists)
        XCTAssertEqual(app.buttons["home.logManually"].label, "Log sunscreen")
    }

    @MainActor
    func testCheckInActionsRemainAccessibleAtLargestText() {
        let app = launchTimelineHome(additionalArguments: accessibilityScorecardArguments + [
            "UITEST_FORCE_DEPARTURE_CHECK_IN"
        ])
        let confirm = app.buttons["home.checkIn.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertTrue(scrollToHittableElement(confirm, in: app))
        XCTAssertEqual(confirm.label, "Already applied")
        tapHittableElement(confirm, in: app)
        let earlier = app.buttons["checkIn.confirm.30"]
        XCTAssertTrue(scrollToHittableElement(earlier, in: app))
        XCTAssertEqual(earlier.label, "30 min ago")
        let dismiss = app.buttons["checkIn.dismiss"]
        XCTAssertTrue(scrollToHittableElement(dismiss, in: app))
        tapHittableElement(dismiss, in: app)
        XCTAssertFalse(app.buttons["home.checkIn.confirm"].exists)
    }


    @MainActor
    func testHistoryLabelsDepartureAsUnconfirmedWithoutAnApplication() {
        let app = launchTimelineHome(additionalArguments: ["UITEST_FORCE_DEPARTURE_CHECK_IN"])
        XCTAssertTrue(app.buttons["home.checkIn.confirm"].waitForExistence(timeout: 10))
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        let day = app.buttons["history.day.\(dayIdentifier(offset: 0))"]
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertTrue(day.label.contains("Unconfirmed sunscreen check-in"))
        XCTAssertTrue(scrollToElement(app.staticTexts["Unconfirmed"], in: app))
        XCTAssertFalse(app.staticTexts["Application confirmed"].exists)
    }

}
