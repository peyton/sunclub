//
//  SunclubUITests.swift
//  SunclubUITests
//
//  Created by Peyton Randolph on 2/23/26.
//

import XCTest

final class SunclubUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAppearsOnLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.staticTexts["Start your routine"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingControlsStayWithinWindowBounds() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        let window = app.windows.element(boundBy: 0)
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let scanButton = app.buttons["Scan bottle barcode"]
        let trainButton = app.buttons["Train bottle"]
        let notificationsButton = app.buttons["Notifications"]
        let joinButton = app.buttons["Join Sunclub"]

        XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
        XCTAssertTrue(trainButton.waitForExistence(timeout: 5))
        XCTAssertTrue(notificationsButton.waitForExistence(timeout: 5))
        XCTAssertTrue(joinButton.waitForExistence(timeout: 5))

        print("window=\(window.frame) scan=\(scanButton.frame) train=\(trainButton.frame) notifications=\(notificationsButton.frame) join=\(joinButton.frame)")

        let inset: CGFloat = 8

        for element in [scanButton, trainButton, notificationsButton, joinButton] {
            XCTAssertGreaterThanOrEqual(element.frame.minX, window.frame.minX + inset)
            XCTAssertLessThanOrEqual(element.frame.maxX, window.frame.maxX - inset)
        }

        XCTAssertEqual(scanButton.frame.midX, window.frame.midX, accuracy: 4)
        XCTAssertEqual(joinButton.frame.midX, window.frame.midX, accuracy: 4)
    }
}
