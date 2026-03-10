//
//  sun_dayUITests.swift
//  sun-dayUITests
//
//  Created by Peyton Randolph on 2/23/26.
//

import XCTest

final class sun_dayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAppearsOnLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.staticTexts["Three quick steps"].waitForExistence(timeout: 5))
    }
}
