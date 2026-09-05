import XCTest

final class SunclubSimplicityUITests: SunclubUITestCase {
    @MainActor
    func testTodayLogsWithOneTapAndUndoRestoresEmptyDay() {
        let app = launchHome()
        tapHittableElement(app.buttons["home.logManually"], in: app)
        XCTAssertTrue(app.buttons["home.undoLog"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["manualLog.logToday"].exists)
        tapHittableElement(app.buttons["home.undoLog"], in: app)
        XCTAssertTrue(app.staticTexts["timeline.todayStatus"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTodayCannotScrubToAnotherDate() {
        let app = launchTimelineHome()
        let headline = timelineHeadline(in: app)
        let originalDate = headline.label
        app.scrollViews["timeline.scroll"].swipeRight()
        XCTAssertEqual(headline.label, originalDate)
        app.scrollViews["timeline.scroll"].swipeLeft()
        XCTAssertEqual(headline.label, originalDate)
        XCTAssertFalse(app.buttons["timeline.backToToday"].exists)
    }

    @MainActor
    func testInsightsBackButtonAndSwipePreserveHistory() {
        let app = launchTimelineHome()
        openWeeklyInsights(in: app)
        navigationBackButton(in: app).tap()
        XCTAssertTrue(app.buttons["history.calendarToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.historyCard"].isSelected)
        openWeeklyInsights(in: app)
        performBackSwipe(in: app)
        XCTAssertTrue(app.buttons["history.calendarToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.historyCard"].isSelected)
    }

    @MainActor
    func testInsightsIsReadOnlyAndLeavesEditingInHistory() {
        let app = launchTimelineHome()
        openWeeklyInsights(in: app)
        XCTAssertFalse(app.buttons["weekly.day.\(dayIdentifier())"].exists)
        XCTAssertFalse(app.buttons["weekly.viewFullHistory"].exists)
        XCTAssertTrue(insightsSummary(in: app).exists)
    }

    @MainActor
    func testRapidDoubleTapCreatesOnlyOneApplication() {
        let app = launchHome()
        let logAction = app.buttons["home.logManually"]
        XCTAssertTrue(scrollToHittableElement(logAction, in: app))
        logAction.doubleTap()
        XCTAssertTrue(app.buttons["home.undoLog"].waitForExistence(timeout: 5))
        tapHittableElement(app.buttons["home.undoLog"], in: app)
        XCTAssertTrue(app.staticTexts["timeline.todayStatus"].waitForExistence(timeout: 5))
        XCTAssertEqual(logAction.label, "Log sunscreen")
    }

    @MainActor
    func testInsightsBackPreservesSelectedHistoryDate() {
        let app = launchHistoryWithSeededRecords()
        selectHistoryDay(offset: -1, in: app)
        tapHittableElement(app.buttons["home.streakCard"], in: app)
        XCTAssertTrue(insightsSummary(in: app).waitForExistence(timeout: 5))
        navigationBackButton(in: app).tap()
        let expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            .formatted(.dateTime.weekday(.wide).month(.wide).day())
        XCTAssertTrue(waitForLabel(expectedDate, on: app.staticTexts["history.selectedDate"]))
        let selectedDay = app.buttons["history.day.\(dayIdentifier(offset: -1))"]
        XCTAssertTrue(scrollToHittableElement(selectedDay, in: app, attempts: 10))
        XCTAssertTrue(selectedDay.isSelected)
    }
}
