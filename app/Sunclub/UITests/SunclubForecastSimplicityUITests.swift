import XCTest

final class SunclubForecastSimplicityUITests: SunclubUITestCase {
    @MainActor
    func testForecastAtAccessibilitySizeShowsPeakAndBottomAttribution() {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments + [
            "UITEST_FORCE_ACCESSIBILITY_TEXT"
        ])
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        tapHittableElement(app.buttons["home.uvIndexCard"], in: app)
        let hero = app.descendants(matching: .any)["uvForecast.hero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertTrue(hero.label.contains("Current UV"))
        XCTAssertTrue(scrollToElement(app.staticTexts["uvForecast.dailyPeak"], in: app))
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["uvForecast.tips"], in: app, attempts: 30))
        XCTAssertTrue(scrollToHittableElement(app.buttons["timeline.weatherKitAttribution"], in: app), app.debugDescription)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Cached'")).firstMatch.exists)
    }

    @MainActor
    func testGaugeVerticalDragScrollsWithoutOpeningForecast() {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments + [
            "UITEST_FORCE_ACCESSIBILITY_TEXT"
        ])
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        let gauge = app.buttons["home.uvIndexCard"]
        let initialPosition = gauge.frame.minY

        // At accessibility sizes the card can extend behind the native tab bar.
        // Start inside its visible portion so the drag cannot select another tab.
        let todayTab = app.buttons["timeline.footer.today"]
        let viewport = app.scrollViews["timeline.scroll"].frame.intersection(CGRect(
            x: app.frame.minX, y: app.frame.minY,
            width: app.frame.width, height: todayTab.frame.minY - app.frame.minY
        ))
        let visibleGauge = gauge.frame.intersection(viewport).insetBy(dx: 8, dy: 8)
        XCTAssertFalse(visibleGauge.isEmpty, "The gauge must be visible above the tab bar.")
        let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: visibleGauge.midX - app.frame.minX, dy: visibleGauge.midY - app.frame.minY
        ))
        let end = start.withOffset(CGVector(dx: 0, dy: -80))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)

        XCTAssertTrue(todayTab.isSelected, "Dragging the gauge must keep Today selected.")
        XCTAssertFalse(app.descendants(matching: .any)["uvForecast.hero"].exists)
        XCTAssertLessThan(gauge.frame.minY, initialPosition - 10, "Dragging the gauge must scroll Today.")
        XCTAssertTrue(scrollToHittableElement(app.buttons["home.logManually"], in: app))
        XCTAssertTrue(scrollToHittableElement(gauge, in: app, scrollDownFirst: true))
        tapHittableElement(gauge, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["uvForecast.hero"].waitForExistence(timeout: 5))
        tapHittableElement(navigationBackButton(in: app), in: app)
        assertTodayRootVisible(in: app)
    }

    // Verifies current UV parity and preserves History while exercising both return paths.
    @MainActor
    func testTodayForecastUsesCurrentDataAndPreservesHistoryThroughBackAndSwipe() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments + [
            "UITEST_SEED_HISTORY=editBackfill"
        ])
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        selectHistoryDay(offset: -1, in: app)

        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let expectedForecastDate = today.formatted(.dateTime.month(.wide).day().year())
        let expectedHistoryDate = yesterday.formatted(.dateTime.weekday(.wide).month(.wide).day())

        for useBackSwipe in [false, true] {
            XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))
            XCTAssertTrue(waitForLabel(weekdayHeadline(offset: 0), on: timelineHeadline(in: app)))
            XCTAssertTrue(waitForVerifiedUVForecast(in: app))
            let gauge = app.buttons["home.uvIndexCard"]
            let gaugeLabel = gauge.label
            let readingPrefix = gaugeLabel.prefix(while: { $0 != "," })
            let currentIndex = try XCTUnwrap(
                readingPrefix.split(separator: " ").last.flatMap { Int($0) },
                "Expected a numeric current UV reading on Today: \(gaugeLabel)"
            )
            tapHittableElement(gauge, in: app)

            let date = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", expectedForecastDate)
            ).firstMatch
            XCTAssertTrue(date.waitForExistence(timeout: 5), "Today's UV destination must show the current local date after browsing History.")
            let hero = app.descendants(matching: .any)["uvForecast.hero"]
            XCTAssertTrue(hero.waitForExistence(timeout: 5))
            XCTAssertTrue(
                waitForLabelPrefix("UV Index \(currentIndex),", on: hero),
                "Forecast must keep Today's current UV reading: \(gaugeLabel)"
            )
            XCTAssertFalse(app.descendants(matching: .any)["uvForecast.unavailable"].exists)
            XCTAssertTrue(app.buttons["uvForecast.docs"].exists)
            XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["uvForecast.hourly"], in: app))

            if useBackSwipe {
                performBackSwipe(in: app)
            } else {
                tapHittableElement(navigationBackButton(in: app), in: app)
            }
            assertTodayRootVisible(in: app)
            XCTAssertTrue(app.buttons["timeline.footer.today"].isSelected)
            XCTAssertTrue(waitForLabel(weekdayHeadline(offset: 0), on: timelineHeadline(in: app)))

            XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
            let selectedDay = app.buttons["history.day.\(dayIdentifier(offset: -1))"]
            XCTAssertTrue(scrollToHittableElement(selectedDay, in: app, attempts: 10))
            XCTAssertTrue(selectedDay.isSelected, "Opening Today's forecast must not change History's date.")
            let historyDate = app.staticTexts["history.selectedDate"]
            XCTAssertTrue(scrollToElement(historyDate, in: app))
            XCTAssertTrue(waitForLabel(expectedHistoryDate, on: historyDate))
        }
    }
}
