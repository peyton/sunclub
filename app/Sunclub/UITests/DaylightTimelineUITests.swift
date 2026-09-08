import XCTest

final class DaylightTimelineUITests: SunclubUITestCase {
    @MainActor
    func testLoggingStaysAboveUVAndUndoRestoresEmptyTimeline() throws {
        let app = launchHome(additionalArguments: ["UITEST_CURRENT_TIME=10:40"])
        assertHomeReadyForLogState(app)
        let action = app.buttons["home.logManually"]
        let forecast = app.buttons["home.uvIndexCard"]
        XCTAssertLessThan(action.frame.maxY, forecast.frame.minY)
        capture(app, name: "Daylight Today empty")
        tapHittableElement(action, in: app)
        assertHomeLoggedState(app)
        XCTAssertTrue(app.staticTexts["home.timelineNow"].exists)
        capture(app, name: "Daylight Today logged")
        tapHittableElement(app.buttons["home.undoLog"], in: app)
        assertHomeReadyForLogState(app)
    }

    @MainActor
    func testAccessibleDarkTimelineKeepsLoggingAndHistoryEditingReachable() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_CURRENT_TIME=13:00", "UITEST_SEED_HISTORY=reapplyToday",
            "UITEST_FORCE_DARK_MODE", "UITEST_FORCE_ACCESSIBILITY_TEXT",
            "UITEST_FORCE_REDUCE_MOTION", "UITEST_FORCE_INCREASE_CONTRAST",
            "UITEST_FORCE_DIFFERENTIATE_WITHOUT_COLOR"
        ])
        assertHomeLoggedState(app)
        let action = app.buttons["home.logManually"]
        XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        XCTAssertTrue(action.isHittable)
        capture(app, name: "Daylight accessible dark Today")
        tapHittableElement(app.buttons["home.historyCard"], in: app)
        tapHittableElement(app.buttons["history.application.reapplication"], in: app)
        XCTAssertTrue(app.datePickers["historyEditor.reapplicationTimePicker"].waitForExistence(timeout: 5))
        capture(app, name: "Daylight accessible editor")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
