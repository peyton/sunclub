import XCTest
import UIKit

class SunclubUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func assertHomeReadyForLogState(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(waitForLabelPrefix("Today,", on: timelineHeadline(in: app)), file: file, line: line)
        let logAction = app.buttons["home.logManually"]
        XCTAssertTrue(scrollToHittableElement(logAction, in: app, attempts: 10), file: file, line: line)
        XCTAssertEqual(logAction.label, "Log sunscreen", file: file, line: line)
        XCTAssertTrue(waitForLabel("Not logged", on: app.staticTexts["timeline.todayStatus"]), file: file, line: line)
    }

    @MainActor
    func assertHomeLoggedState(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForLabelPrefix("Logged at ", on: app.staticTexts["home.todayStatus"], timeout: 10),
            "Expected the saved application's time on Today.",
            file: file, line: line
        )
        XCTAssertTrue(
            scrollToHittableElement(app.buttons["home.sunscreenLogCard"], in: app, attempts: 10),
            "Expected Edit log to remain reachable.", file: file, line: line
        )
        XCTAssertEqual(app.buttons["home.logManually"].label, "Log reapplication", file: file, line: line)
    }

    func timelineHeadline(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["timeline.headline"]
    }

    @MainActor
    func launchAndCompleteOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()
        return completeOnboarding(in: app)
    }

    @MainActor
    func launchHome() -> XCUIApplication {
        launchHome(additionalArguments: [])
    }

    @MainActor
    func launchHome(additionalArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        var launchArguments = [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING"
        ] + additionalArguments
        if !launchArguments.contains(where: { $0.hasPrefix("UITEST_ROUTE=") }) {
            launchArguments.append("UITEST_ROUTE=home")
        }
        app.launchArguments += launchArguments
        app.launch()
        return app
    }

    @MainActor
    func launchTimelineHome(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING"] + additionalArguments
        app.launch()
        return app
    }

    var liveTimelineForecastArguments: [String] {
        [
            "UITEST_CURRENT_TIME=13:00",
            "UITEST_LIVE_UV_ENABLED",
            "UITEST_LIVE_UV_AUTH=always",
            "UITEST_LIVE_UV_INDEX=7",
            "UITEST_LIVE_UV_PEAK_INDEX=10"
        ]
    }

    var accessibilityScorecardArguments: [String] {
        [
            "UITEST_FORCE_DARK_MODE",
            "UITEST_FORCE_ACCESSIBILITY_TEXT",
            "UITEST_FORCE_REDUCE_MOTION",
            "UITEST_FORCE_DIFFERENTIATE_WITHOUT_COLOR",
            "UITEST_FORCE_INCREASE_CONTRAST"
        ]
    }

    @MainActor
    func launchHistoryWithSeededRecords(route: String = "history") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=\(route)",
            "UITEST_SEED_HISTORY=editBackfill"
        ]
        app.launch()
        return app
    }

    func widgetURL(path: String) -> String {
        let scheme = automationScheme
        return "\(scheme)://widget/\(path)"
    }

    func automationURL(path: String) -> String {
        "\(automationScheme)://automation/\(path)"
    }

    func xCallbackURL(path: String) -> String {
        "\(automationScheme)://x-callback-url/\(path)"
    }

    func automationElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func automationSwitch(_ label: String, in app: XCUIApplication) -> XCUIElement {
        switch label {
        case "Allow Shortcut writes":
            app.switches["Allow Shortcut writes"]
        case "Allow URL open actions":
            app.switches["Open Sunclub from links"]
        case "Allow URL write actions":
            app.switches["Save changes from links"]
        case "Include callback result details":
            app.switches["Share result details"]
        default:
            app.switches[label]
        }
    }

    var automationScheme: String {
        Bundle.main.object(forInfoDictionaryKey: "SunclubURLScheme") as? String ?? "sunclub-dev"
    }

    func accountabilityInviteURL(displayName: String) throws -> String {
        let envelope: [String: Any] = [
            "profileID": "391D15FD-475F-4EE5-9A85-E68E27980EA8",
            "displayName": displayName,
            "relationshipToken": "uitest-relationship-token",
            "issuedAt": 800_000_000,
            "snapshot": [
                "id": "9C9E0C71-0C6B-46C2-8AC0-32E3AC1EE0E5",
                "name": displayName,
                "currentStreak": 2,
                "longestStreak": 7,
                "hasLoggedToday": false,
                "lastSharedAt": 800_000_000,
                "seasonStyleRawValue": "summerGlow"
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        let code = "SUNCLUB-ACCOUNTABILITY-\(data.base64EncodedString())"
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "+=&")
        let encodedCode = try XCTUnwrap(code.addingPercentEncoding(withAllowedCharacters: allowedCharacters))
        let scheme = automationScheme
        return "\(scheme)://accountability/invite?code=\(encodedCode)"
    }

    @discardableResult
    @MainActor
    func completeOnboarding(in app: XCUIApplication) -> XCUIApplication {
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipNotifications"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func performBackSwipe(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        // Hold at the destination before release so this models a completed back drag.
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.15)
    }

    @MainActor
    func waitForLabel(_ label: String, on element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func waitForValueContaining(_ text: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func waitForVerifiedUVForecast(
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) -> Bool {
        let card = app.buttons["home.uvIndexCard"]
        guard scrollToHittableElement(card, in: app, attempts: 10) else {
            return false
        }
        let predicate = NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "UV index ", "Apple Weather")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: card)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func manualLogSPFRow(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts["manualLog.spfState"]
    }

    @MainActor
    func waitForLabelPrefix(_ prefix: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func waitForLabelNotPrefix(_ prefix: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "NOT label BEGINSWITH %@", prefix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func assertInsightsVisible(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(app.staticTexts["Insights"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(insightsSummary(in: app).waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(navigationBackButton(in: app).exists, file: file, line: line)
        XCTAssertFalse(app.buttons["timeline.footer.today"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["home.historyCard"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["timeline.footer.settings"].exists, file: file, line: line)
    }

    @MainActor
    func navigationBackButton(in app: XCUIApplication) -> XCUIElement {
        let compatibility = app.buttons["screen.back"]
        if compatibility.exists { return compatibility }
        let namedBack = app.navigationBars.buttons["Back"]
        if namedBack.exists { return namedBack }
        return app.navigationBars.buttons["BackButton"]
    }

    func insightsSummary(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label MATCHES %@", "[0-7] days? logged in the last 7 days")
        ).firstMatch
    }

    func insightsStreak(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]+-day streak")
        ).firstMatch
    }

    @MainActor
    func openTodayEditor(in app: XCUIApplication) {
        tapHittableElement(app.buttons["home.sunscreenLogCard"], in: app, description: "Edit today's log")
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["manualLog.timePicker"].exists)
        XCTAssertFalse(app.datePickers["manualLog.datePicker"].exists)
    }

    @MainActor
    func selectHistoryDay(offset: Int, in app: XCUIApplication) {
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        expandHistoryCalendar(in: app)
        let target = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        if !Calendar.current.isDate(target, equalTo: Date(), toGranularity: .month) {
            tapHittableElement(app.buttons["history.previousMonth"], in: app)
        }
        tapHittableElement(app.buttons["history.day.\(dayIdentifier(offset: offset))"], in: app)
        XCTAssertTrue(app.buttons["history.day.\(dayIdentifier(offset: offset))"].isSelected)
    }

    @MainActor
    func openWeeklyInsights(in app: XCUIApplication) {
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        let historyScroll = app.scrollViews["history.scroll"]
        XCTAssertTrue(historyScroll.waitForExistence(timeout: 5), "Expected the selected History tab's content.")
        XCTAssertTrue(app.buttons["history.calendarToggle"].exists)
        tapHittableElement(
            app.buttons["home.streakCard"],
            in: app,
            description: "History's Weekly insights button (home.streakCard)",
            scrollSurface: historyScroll
        )
        assertInsightsVisible(in: app)
    }

    @MainActor
    func expandHistoryCalendar(in app: XCUIApplication) {
        let toggle = app.buttons["history.calendarToggle"]
        XCTAssertTrue(scrollToHittableElement(toggle, in: app, attempts: 10))
        if stringValue(of: toggle) != "Expanded" {
            toggle.tap()
        }
        XCTAssertTrue(waitForValueContaining("Expanded", on: toggle))
        XCTAssertTrue(scrollToHittableElement(app.buttons["history.previousMonth"], in: app, attempts: 10))
        XCTAssertTrue(app.otherElements["history.calendarGrid"].exists)
    }

    @MainActor
    func tapHittableElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 10,
        description: String = "Requested control",
        scrollSurface: XCUIElement? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard scrollToHittableElement(element, in: app, attempts: attempts, scrollSurface: scrollSurface) else {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Unreachable control - \(description)"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            XCTFail("\(description) was not reachable before tapping.", file: file, line: line)
            return
        }
        element.tap()
    }

    @MainActor
    func assertTodayRootVisible(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForAnyExistingElement([
                app.buttons["home.logManually"],
                app.buttons["home.sunscreenLogCard"],
                timelineHeadline(in: app)
            ], timeout: 10),
            "Expected the Today tab root after closing a pushed route.",
            file: file,
            line: line
        )
    }

    @MainActor
    func waitForAnyExistingElement(_ elements: [XCUIElement], timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if elements.contains(where: { $0.exists }) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return elements.contains(where: { $0.exists })
    }

    @MainActor
    func waitForDifferentLabel(from label: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label != %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func dragCalendarGrid(_ calendarGrid: XCUIElement, toward direction: CalendarGridDragDirection) {
        let startX = direction == .left ? 0.88 : 0.12
        let endX = direction == .left ? 0.12 : 0.88
        let start = calendarGrid.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5))
        let end = calendarGrid.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end)
    }

    func dayIdentifier(offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return Self.dayIdentifierFormatter.string(from: day)
    }

    func weekdayHeadline(offset: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        let dateText: String
        if calendar.isDate(day, equalTo: today, toGranularity: .year) {
            dateText = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        } else {
            dateText = day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        }

        switch offset {
        case -1:
            return "Yesterday, \(dateText)"
        case 0:
            return "Today, \(dateText)"
        case 1:
            return "Tomorrow, \(dateText)"
        case let days where days > 1:
            return "In \(days) days, \(dateText)"
        case let days where days < -1:
            return "\(abs(days)) days ago, \(dateText)"
        default:
            return day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        }
    }

    @MainActor
    func timelineDayChip(
        _ identifier: String,
        in app: XCUIApplication,
        direction: TimelineDayScrollDirection
    ) -> XCUIElement {
        let chip = app.descendants(matching: .any)[identifier]
        if chip.waitForExistence(timeout: 5), chip.isHittable {
            return chip
        }

        let strip = app.descendants(matching: .any)["timeline.dayStrip"]
        XCTAssertTrue(
            scrollToHittableElement(strip, in: app, attempts: 20, scrollSurface: app.scrollViews["timeline.scroll"]),
            "Expected timeline day strip to remain reachable."
        )
        if chip.waitForExistence(timeout: 2), chip.isHittable {
            return chip
        }

        for _ in 0..<6 {
            dragTimelineStrip(strip, direction: direction)
            if chip.waitForExistence(timeout: 1), chip.isHittable {
                return chip
            }
        }

        return chip
    }

    @MainActor
    func dragTimelineStrip(_ strip: XCUIElement, direction: TimelineDayScrollDirection) {
        let startX: CGFloat = direction == .future ? 0.82 : 0.18
        let endX: CGFloat = direction == .future ? 0.18 : 0.82
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5))
        let end = strip.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    func dragTimelineBody(
        _ body: XCUIElement,
        direction: TimelineDayScrollDirection,
        verticalPosition: CGFloat = 0.12
    ) {
        let startX: CGFloat = direction == .future ? 0.82 : 0.18
        let endX: CGFloat = direction == .future ? 0.18 : 0.82
        let start = body.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: verticalPosition))
        let end = body.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: verticalPosition))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    func selectNativeTab(_ tab: XCUIElement) -> Bool {
        for attempt in 0..<2 {
            if tab.exists, tab.isSelected {
                return true
            }
            guard tab.waitForExistence(timeout: 2), tab.isHittable else {
                return false
            }

            tab.tap()
            let timeout: TimeInterval = attempt == 0 ? 1 : 5
            let selected = NSPredicate(format: "isSelected == true")
            let expectation = XCTNSPredicateExpectation(predicate: selected, object: tab)
            if XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed {
                return true
            }
        }

        return tab.exists && tab.isSelected
    }

    @MainActor
    func assertSettingsTabOpens(in app: XCUIApplication) {
        XCTAssertTrue(
            selectNativeTab(app.buttons["timeline.footer.settings"]),
            "Expected Settings to open from the tab footer."
        )
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    static let dayIdentifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @MainActor
    func assertSettingsReminderControls(in app: XCUIApplication) {
        expandSettingsSection("reminders", in: app)
        XCTAssertTrue(app.buttons["settings.weekdayReminderTime"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settings.notificationStatus"].exists)
        XCTAssertTrue(app.buttons["settings.weekendReminderTime"].exists)
        XCTAssertTrue(app.switches["settings.travelToggle"].exists)
        XCTAssertTrue(scrollToElement(app.switches["settings.eveningLogReminderToggle"], in: app))
        XCTAssertFalse(app.switches["settings.streakRiskToggle"].exists)
        XCTAssertTrue(scrollToElement(app.buttons["settings.coaching.weekday"], in: app))
        returnToSettingsHome(in: app)
    }

    @MainActor
    func assertSettingsNotificationControls(in app: XCUIApplication) {
        expandSettingsSection("reminders", in: app)
        XCTAssertFalse(app.buttons["settings.notificationHealth.sendTest"].exists)
        let troubleshoot = app.buttons["settings.reminders.troubleshoot"]
        XCTAssertTrue(scrollToHittableElement(troubleshoot, in: app, attempts: 10))
        XCTAssertGreaterThanOrEqual(troubleshoot.frame.height, 44)
        tapHittableElement(troubleshoot, in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.notificationHealth.action"], in: app))
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.notificationHealth.sendTest"], in: app))
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.notificationHealth.copyDiagnostics"], in: app))
        returnToSettingsHome(in: app)
    }

    @MainActor
    func assertSettingsProgressControls(in app: XCUIApplication) {
        expandSettingsSection("reminders", in: app)
        XCTAssertTrue(scrollToHittableElement(app.switches["settings.reapplyToggle"], in: app))
        XCTAssertTrue(scrollToHittableElement(app.switches["settings.leaveHomeToggle"], in: app))
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.leaveHome.action"], in: app))
        XCTAssertEqual(app.buttons["settings.leaveHome.action"].label, "Use Current Location as Home")
        returnToSettingsHome(in: app)
    }

    @MainActor
    func assertSettingsDataControls(in app: XCUIApplication) {
        expandSettingsSection("data", in: app)
        let iCloudToggle = app.switches["settings.icloudToggle"]
        XCTAssertTrue(scrollToElement(iCloudToggle, in: app))
        XCTAssertEqual(stringValue(of: iCloudToggle), "1")
        XCTAssertTrue(app.staticTexts["iCloud sync is on"].waitForExistence(timeout: 5))

        iCloudToggle.tap()
        XCTAssertTrue(app.staticTexts["Saved only on this phone"].waitForExistence(timeout: 5))
        XCTAssertEqual(stringValue(of: iCloudToggle), "0")

        iCloudToggle.tap()
        XCTAssertTrue(app.staticTexts["iCloud sync is on"].waitForExistence(timeout: 5))
        XCTAssertEqual(stringValue(of: iCloudToggle), "1")

        XCTAssertTrue(app.buttons["settings.backup.export"].exists)
        XCTAssertTrue(app.buttons["settings.backup.import"].exists)
        returnToSettingsHome(in: app)
    }

    @MainActor
    func assertSettingsAutomationControls(in app: XCUIApplication) {
        expandSettingsSection("automation", in: app)
        for label in ["Allow Shortcut writes", "Allow URL open actions", "Allow URL write actions", "Include callback result details"] {
            XCTAssertTrue(scrollToHittableElement(automationSwitch(label, in: app), in: app))
        }
        XCTAssertFalse(app.buttons["automation.example.logToday.test"].exists)
        tapHittableElement(app.buttons["settings.automation.openCatalog"], in: app)
        XCTAssertTrue(app.staticTexts["Shortcuts & Automation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["automation.shortcuts"].exists)
        tapHittableElement(app.descendants(matching: .any)["automation.advanced"], in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["automation.example.logToday.copy"], in: app))
        XCTAssertFalse(app.buttons["automation.example.logToday.test"].exists)
        tapHittableElement(navigationBackButton(in: app), in: app)
        XCTAssertTrue(app.buttons["settings.automation.openCatalog"].waitForExistence(timeout: 5))
        returnToSettingsHome(in: app)
    }

    @MainActor
    func assertSettingsAdvancedControls(in app: XCUIApplication) {
        expandSettingsSection("advanced", in: app)
        XCTAssertTrue(scrollToHittableElement(app.switches["settings.liveUVToggle"], in: app))
        XCTAssertEqual(app.switches["settings.liveUVToggle"].label, "Use current location")
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.liveUV.chooseCity"], in: app))
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["settings.liveUV.status"], in: app))
        XCTAssertTrue(scrollToHittableElement(app.switches["settings.uvBriefingToggle"], in: app))
        XCTAssertTrue(scrollToHittableElement(app.switches["settings.extremeUVToggle"], in: app))
        returnToSettingsHome(in: app)
        expandSettingsSection("health", in: app)
        XCTAssertTrue(scrollToHittableElement(app.switches["settings.healthKitToggle"], in: app))
        returnToSettingsHome(in: app)
    }

    @MainActor
    func assertSettingsHelpControls(in app: XCUIApplication) {
        tapHittableElement(app.buttons["settings.support.quick"], in: app)
        XCTAssertTrue(app.staticTexts["Support"].waitForExistence(timeout: 5))
        for identifier in ["support.email", "support.helpCenter", "support.docs"] {
            let action = app.buttons[identifier]
            XCTAssertTrue(scrollToHittableElement(action, in: app))
            XCTAssertFalse(action.label.isEmpty)
            XCTAssertGreaterThanOrEqual(action.frame.height, 44)
        }
        returnToSettingsHome(in: app)
        tapHittableElement(app.buttons["settings.privacy.quick"], in: app)
        XCTAssertTrue(app.staticTexts["Privacy"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToHittableElement(app.buttons["privacy.exportHistory"], in: app))
        returnToSettingsHome(in: app)
    }

    @MainActor
    func assertBackupImportHarnessRestoresRecordCount(in app: XCUIApplication) {
        XCTAssertTrue(waitForLabel("History entries: 0", on: app.staticTexts["settings.backupRecordCount"]))

        XCTAssertTrue(scrollToElement(app.buttons["settings.backup.importHarness"], in: app))
        app.buttons["settings.backup.importHarness"].tap()

        XCTAssertTrue(
            waitForLabel(
                "Imported 1 day from backup. iCloud stays unchanged until you send it.",
                on: app.staticTexts["settings.backupStatus"]
            )
        )
        XCTAssertTrue(waitForLabel("History entries: 1", on: app.staticTexts["settings.backupRecordCount"]))
        XCTAssertTrue(scrollToElement(app.staticTexts["settings.icloud.pendingImports"], in: app))
        XCTAssertTrue(app.buttons["settings.icloud.publishImported"].exists)
        XCTAssertTrue(app.buttons["settings.icloud.restoreImported"].exists)
    }

    @MainActor
    func stringValue(of element: XCUIElement) -> String? {
        element.value as? String
    }

    func averageScreenshotLuminance() -> Double {
        let screenshot = XCUIScreen.main.screenshot()
        guard let image = UIImage(data: screenshot.pngRepresentation),
              let cgImage = image.cgImage else {
            XCTFail("Could not decode screenshot for luminance audit.")
            return 1
        }

        let width = 80
        let height = max(1, Int(Double(cgImage.height) * Double(width) / Double(cgImage.width)))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let pixelBufferCount = pixels.count
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                XCTFail("Could not create screenshot sampling context.")
                return 1
            }

            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            var total = 0.0
            let bytes = buffer.bindMemory(to: UInt8.self)
            for index in stride(from: 0, to: pixelBufferCount, by: 4) {
                let red = Double(bytes[index]) / 255
                let green = Double(bytes[index + 1]) / 255
                let blue = Double(bytes[index + 2]) / 255
                total += 0.2126 * red + 0.7152 * green + 0.0722 * blue
            }
            return total / Double(width * height)
        }
    }

    @MainActor
    func expandSettingsSection(_ section: String, in app: XCUIApplication) {
        let sectionIdentifier = "settings.section.\(section)"
        let sectionControl = app.descendants(matching: .any)[sectionIdentifier]
        if tapSettingsSectionControl(sectionControl, in: app, attempts: 4) {
            expandSettingsControl(sectionControl)
            return
        }

        let titlePredicate = NSPredicate(format: "label CONTAINS[c] %@", settingsSectionTitle(for: section))
        let titledControl = app.descendants(matching: .any).matching(titlePredicate).firstMatch
        XCTAssertTrue(
            tapSettingsSectionControl(titledControl, in: app, attempts: 8),
            "Expected \(settingsSectionTitle(for: section)) Settings section to be reachable."
        )
        expandSettingsControl(titledControl)
    }

    @MainActor
    func expandSettingsControl(_ sectionControl: XCUIElement) {
        sectionControl.tap()
    }

    @MainActor
    func dragFromLeftEdge(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let finish = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: finish)
    }

    @MainActor
    func tapSettingsSectionControl(
        _ sectionControl: XCUIElement,
        in app: XCUIApplication,
        attempts: Int
    ) -> Bool {
        if sectionControl.waitForExistence(timeout: 2), sectionControl.isHittable {
            return true
        }

        let firstScrollView = app.scrollViews.firstMatch
        let scrollSurface: XCUIElement = firstScrollView.exists ? firstScrollView : app

        for _ in 0..<attempts {
            scrollSurface.swipeUp()
            if sectionControl.waitForExistence(timeout: 1), sectionControl.isHittable {
                return true
            }
        }

        for _ in 0..<attempts {
            scrollSurface.swipeDown()
            if sectionControl.waitForExistence(timeout: 1), sectionControl.isHittable {
                return true
            }
        }

        return false
    }

    @MainActor
    func returnToSettingsHome(in app: XCUIApplication) {
        let backButton = navigationBackButton(in: app)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    func settingsSectionTitle(for section: String) -> String {
        switch section {
        case "reminders":
            return "Reminders"
        case "sunscreen":
            return "Sunscreen"
        case "health":
            return "Apple Health"
        case "data":
            return "iCloud & Backup"
        case "automation":
            return "Shortcuts"
        case "advanced":
            return "UV & Weather"
        case "help":
            return "Help & Legal"
        default:
            return section
        }
    }

    @MainActor
    func scrollToHittableElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 6,
        scrollSurface: XCUIElement? = nil,
        scrollDownFirst: Bool = false
    ) -> Bool {
        if element.waitForExistence(timeout: 2), element.isHittable {
            return true
        }

        let surface = scrollSurface ?? app.scrollViews.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? app
        let firstScroll: () -> Void = scrollDownFirst
            ? { self.nudgeScrollSurface(surface, direction: .scrollDown, distance: 0.6) }
            : { self.nudgeScrollSurface(surface, direction: .scrollUp, distance: 0.6) }
        let secondScroll: () -> Void = scrollDownFirst
            ? { self.nudgeScrollSurface(surface, direction: .scrollUp, distance: 0.6) }
            : { self.nudgeScrollSurface(surface, direction: .scrollDown, distance: 0.6) }
        for _ in 0..<attempts {
            firstScroll()
            if element.waitForExistence(timeout: 1), element.isHittable {
                return true
            }
        }

        for _ in 0..<attempts {
            secondScroll()
            if element.waitForExistence(timeout: 1), element.isHittable {
                return true
            }
        }

        return false
    }

    @MainActor
    func scrollToHittableElementByPosition(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int,
        scrollSurface: XCUIElement,
        directionWhenMissing: ScrollDirection = .scrollUp,
        distance: CGFloat = 0.12
    ) -> Bool {
        if element.waitForExistence(timeout: 2), element.isHittable {
            return true
        }

        for _ in 0..<attempts {
            let direction: ScrollDirection
            let navigationBar = app.navigationBars.firstMatch
            let visibleTop = max(
                scrollSurface.frame.minY,
                navigationBar.exists ? navigationBar.frame.maxY : app.frame.minY
            )
            if element.exists, element.frame.minY < visibleTop {
                direction = .scrollDown
            } else if element.exists {
                direction = .scrollUp
            } else {
                direction = directionWhenMissing
            }
            nudgeScrollSurface(scrollSurface, direction: direction, distance: distance)
            if element.waitForExistence(timeout: 0.5), element.isHittable {
                return true
            }
        }

        return false
    }

    @MainActor
    func nudgeScrollSurface(
        _ surface: XCUIElement,
        direction: ScrollDirection,
        distance: CGFloat = 0.3
    ) {
        let halfDistance = distance / 2
        let startY: CGFloat = direction == .scrollDown ? 0.5 - halfDistance : 0.5 + halfDistance
        let endY: CGFloat = direction == .scrollDown ? 0.5 + halfDistance : 0.5 - halfDistance
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    func scrollToElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 6
    ) -> Bool {
        if element.waitForExistence(timeout: 2) {
            return true
        }

        for _ in 0..<attempts {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        for _ in 0..<attempts {
            app.swipeDown()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }
}

enum CalendarGridDragDirection {
    case left
    case right
}

enum TimelineDayScrollDirection {
    case past
    case future
}

enum ScrollDirection {
    case scrollUp
    case scrollDown
}
