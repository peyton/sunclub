import XCTest

final class ApplicationTimePolishUITests: SunclubUITestCase {
    @MainActor
    func testTodayTimeOpensEditorAndProtectsDraftOnCancel() throws {
        let app = launchHome(additionalArguments: ["UITEST_SEED_HISTORY=todayLogged", "UITEST_CURRENT_TIME=13:00"])
        tapHittableElement(app.buttons["home.todayStatus"], in: app)
        let save = app.buttons["manualLog.logToday"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(save.frame.height, 44)
        XCTAssertGreaterThan(save.frame.width, 200)
        XCTAssertFalse(app.buttons["manualLog.spf.30"].exists)
        expandLogDetails(in: app, prefix: "manualLog")
        tapHittableElement(app.buttons["manualLog.spf.30"], in: app)
        tapHittableElement(navigationBackButton(in: app), in: app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Discard confirmation"
        attachment.lifetime = .keepAlways
        add(attachment)
        let keep = app.buttons["Keep editing"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        keep.tap()
        XCTAssertTrue(app.buttons["manualLog.spf.30"].isSelected)
        tapHittableElement(save, in: app)
        XCTAssertTrue(waitForLabel("SPF 30", on: app.buttons["home.editSPF"]))
    }

    @MainActor
    func testHistoryRowOpensBothSavedTimesWithoutExposingOptionalFields() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history", "UITEST_SEED_HISTORY=reapplyToday", "UITEST_CURRENT_TIME=13:00"
        ])
        tapHittableElement(app.buttons["history.application.reapplication"], in: app)
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["historyEditor.timePicker"].exists)
        XCTAssertTrue(app.datePickers["historyEditor.reapplicationTimePicker"].exists)
        XCTAssertFalse(app.buttons["historyEditor.spf.30"].exists)
        tapHittableElement(app.buttons["historyEditor.save"], in: app)
        XCTAssertTrue(waitForLabel("Logged, 2 applications", on: app.staticTexts["history.statusTitle"]))
    }

    @MainActor
    func testEmptyTodayOffersEarlierLogWithoutFirstSavingNow() throws {
        let app = launchHome()
        let earlier = app.buttons["home.sunscreenLogCard"]
        XCTAssertTrue(waitForLabel("Log earlier", on: earlier))
        tapHittableElement(earlier, in: app)
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        tapHittableElement(navigationBackButton(in: app), in: app)
        assertHomeReadyForLogState(app)
    }
}
