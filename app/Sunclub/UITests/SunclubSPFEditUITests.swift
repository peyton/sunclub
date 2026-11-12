import XCTest
import UIKit

final class SunclubSPFEditUITests: SunclubUITestCase {
    @MainActor
    func testSPFSaveStaysVisibleAndRetainsDraftAfterResizing() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = launchTimelineHome(additionalArguments: ["UITEST_SEED_HISTORY=todayLogged"])
        tapHittableElement(app.buttons["home.editSPF"], in: app)
        let save = app.buttons["spfEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isHittable, "Save must be reachable without scrolling the default sheet.")
        XCTAssertTrue(app.frame.contains(save.frame), "The entire Save button must fit in the default sheet.")

        let selectedSPF = app.buttons["spfEditor.quick.15"]
        selectedSPF.tap()
        XCTAssertTrue(selectedSPF.isSelected)

        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            XCTAssertTrue(save.isHittable, "Save must remain reachable after resizing without scrolling.")
            XCTAssertTrue(app.frame.contains(save.frame), "The entire Save button must fit after resizing.")
            XCTAssertTrue(selectedSPF.isSelected, "Resizing must retain the unsaved SPF selection.")
        }

        // Native toolbar buttons expose their hittable point through tap().
        // Frame-derived offsets do not describe the platform's touch region.
        save.tap()
        XCTAssertTrue(waitForLabel("SPF 15", on: app.buttons["home.editSPF"]))
        XCTAssertFalse(save.exists)

        tapHittableElement(app.buttons["home.editSPF"], in: app)
        app.buttons["spfEditor.quick.30"].tap()
        XCTAssertTrue(save.isHittable)
        XCTAssertTrue(app.frame.contains(save.frame))
        save.tap()
        XCTAssertTrue(waitForLabel("SPF 30", on: app.buttons["home.editSPF"]))
        XCTAssertFalse(save.exists)
    }

    @MainActor
    func testDirectSPFEditCancelsThenSavesWithoutLeavingToday() throws {
        let app = launchTimelineHome(additionalArguments: ["UITEST_SEED_HISTORY=todayLogged"])
        let edit = app.buttons["home.editSPF"]
        XCTAssertTrue(scrollToHittableElement(edit, in: app))
        let original = edit.label
        tapHittableElement(edit, in: app)
        let stepper = app.steppers["spfEditor.value"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.buttons["spfEditor.value-Increment"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitForLabel(original, on: edit))

        tapHittableElement(edit, in: app)
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.buttons["spfEditor.value-Increment"].tap()
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
        stepper.buttons["spfEditor.value-Increment"].tap()
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
