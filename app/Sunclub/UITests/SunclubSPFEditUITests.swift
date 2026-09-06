import XCTest

final class SunclubSPFEditUITests: SunclubUITestCase {
    @MainActor
    func testDirectSPFEditCancelsThenSavesWithoutLeavingToday() throws {
        let app = launchTimelineHome(additionalArguments: ["UITEST_SEED_HISTORY=todayLogged"])
        let edit = app.buttons["home.editSPF"]
        XCTAssertTrue(scrollToHittableElement(edit, in: app))
        let original = edit.label
        tapHittableElement(edit, in: app)
        let stepper = app.steppers["spfEditor.value"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.buttons["Increment"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitForLabel(original, on: edit))

        tapHittableElement(edit, in: app)
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.buttons["Increment"].tap()
        let newSPF = try XCTUnwrap(stepper.label.split(separator: " ").last.flatMap { Int($0) })
        tapHittableElement(app.buttons["spfEditor.save"], in: app)
        XCTAssertTrue(waitForLabel("SPF \(newSPF)", on: edit))
        XCTAssertEqual(app.buttons["home.logManually"].label, "Log reapplication")
        XCTAssertFalse(app.buttons["spfEditor.save"].exists)
    }

    @MainActor
    func testSPFEditCanSetFutureLogDefault() throws {
        let app = launchTimelineHome(additionalArguments: ["UITEST_SEED_HISTORY=todayLogged"])
        tapHittableElement(app.buttons["home.editSPF"], in: app)
        let stepper = app.steppers["spfEditor.value"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.buttons["Increment"].tap()
        let newSPF = try XCTUnwrap(stepper.label.split(separator: " ").last.flatMap { Int($0) })
        app.switches["spfEditor.useForFutureLogs"].tap()
        tapHittableElement(app.buttons["spfEditor.save"], in: app)
        XCTAssertTrue(waitForLabel("SPF \(newSPF)", on: app.buttons["home.editSPF"]))
        assertSettingsTabOpens(in: app)
        expandSettingsSection("sunscreen", in: app)
        let savedSPF = app.steppers["settings.sunscreen.spf"]
        XCTAssertTrue(savedSPF.waitForExistence(timeout: 5))
        XCTAssertTrue(savedSPF.label.contains("\(newSPF)"))
    }
}
