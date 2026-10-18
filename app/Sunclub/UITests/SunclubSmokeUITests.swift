import XCTest
import UIKit

final class SunclubSmokeUITests: SunclubUITestCase {
    @MainActor
    func testTodayKeepsLoggedStateAndReachableControlsAfterResizing() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = launchHome(additionalArguments: accessibilityScorecardArguments)
        let logAction = app.buttons["home.logManually"]
        XCTAssertTrue(scrollToHittableElement(logAction, in: app, attempts: 10))
        logAction.tap()
        assertHomeLoggedState(app)

        for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            assertHomeLoggedState(app)
            XCTAssertTrue(scrollToFullyVisibleElement(logAction, in: app))
            XCTAssertGreaterThanOrEqual(logAction.frame.width, 44)
            XCTAssertGreaterThanOrEqual(logAction.frame.height, 44)
            XCTAssertTrue(app.frame.contains(logAction.frame), "Log action \(logAction.frame) must fit the resized window \(app.frame).")
            for (identifier, title) in [
                ("timeline.footer.today", "Today"),
                ("home.historyCard", "History"),
                ("timeline.footer.settings", "Settings")
            ] {
                let tabButton = nativeTabButton(identifier, title: title, in: app)
                XCTAssertTrue(tabButton.waitForExistence(timeout: 5), "Missing native \(title) tab after rotation.")
                XCTAssertTrue(tabButton.isHittable, "Native \(title) tab must remain reachable.")
                XCTAssertFalse(logAction.frame.intersects(tabButton.frame))
            }
        }
    }

    @MainActor
    func testOnboardingCanSkipNotifications() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        app.buttons["welcome.getStarted"].tap()
        XCTAssertFalse(app.buttons["onboarding.skipUV"].exists)
        XCTAssertTrue(app.buttons["onboarding.skipNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipNotifications"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeUVCardOpensForecastDetail() throws {
        let app = launchHome(additionalArguments: liveTimelineForecastArguments)

        let uvCard = app.buttons["home.uvIndexCard"]
        XCTAssertTrue(
            waitForVerifiedUVForecast(in: app),
            "Expected the deterministic Apple Weather fixture to finish loading."
        )
        XCTAssertTrue(
            scrollToHittableElement(uvCard, in: app, attempts: 10),
            "Expected the UV gauge to remain reachable on Today."
        )
        uvCard.tap()

        XCTAssertTrue(app.descendants(matching: .any)["uvForecast.hero"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["uvForecast.hourly"].exists)
    }

    @MainActor
    func testSettingsDetailCanPopWithLeftEdgeSwipe() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        app.buttons["settings.section.reminders"].tap()
        XCTAssertTrue(app.staticTexts["Reminders"].waitForExistence(timeout: 5))

        dragFromLeftEdge(in: app)

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        XCTAssertFalse(navigationBackButton(in: app).exists)
    }

    @MainActor
    func testBackupHarnessExportsAndImportsHistoryAndSettings() throws {
        let backupURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: backupURL) }

        let exportApp = XCUIApplication()
        exportApp.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=settings",
            "UITEST_SEED_HISTORY=editBackfill",
            "UITEST_EXPORT_BACKUP_URL=\(backupURL.path)"
        ]
        exportApp.launch()

        expandSettingsSection("data", in: exportApp)
        XCTAssertTrue(waitForLabel("History entries: 1", on: exportApp.staticTexts["settings.backupRecordCount"], timeout: 15))
        XCTAssertTrue(scrollToElement(exportApp.buttons["settings.backup.exportHarness"], in: exportApp))
        exportApp.buttons["settings.backup.exportHarness"].tap()
        XCTAssertTrue(waitForLabel("Backup exported.", on: exportApp.staticTexts["settings.backupStatus"]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        exportApp.terminate()

        let importApp = XCUIApplication()
        importApp.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=settings",
            "UITEST_IMPORT_BACKUP_URL=\(backupURL.path)"
        ]
        importApp.launch()

        expandSettingsSection("data", in: importApp)
        assertBackupImportHarnessRestoresRecordCount(in: importApp)
    }

    @MainActor
    func testDarkModeHomeAndSettingsRemainUsable() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_FORCE_DARK_MODE",
            "UITEST_UV_INDEX=7"
        ])

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline.footer.settings"].waitForExistence(timeout: 5))
        XCTAssertLessThan(averageScreenshotLuminance(), 0.70)

        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.settings"]))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        expandSettingsSection("reminders", in: app)
        XCTAssertTrue(app.buttons["settings.weekdayReminderTime"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAccessibilityScorecardCoreTasksRemainUsable() throws {
        let app = launchHome(additionalArguments: accessibilityScorecardArguments + [
            "UITEST_UV_INDEX=8"
        ])

        let logAction = app.buttons["home.logManually"]
        XCTAssertTrue(
            scrollToHittableElement(logAction, in: app, attempts: 10),
            "Expected Today's primary log action to remain reachable with accessibility text."
        )
        attachScorecardScreenshot(app, checkpoint: "Larger Text primary action")
        XCTAssertEqual(app.buttons.matching(identifier: "home.logManually").count, 1)
        XCTAssertGreaterThanOrEqual(logAction.frame.width, 44)
        XCTAssertGreaterThanOrEqual(logAction.frame.height, 44)
        XCTAssertFalse(logAction.label.isEmpty)
        let todayTab = nativeTabButton("timeline.footer.today", title: "Today", in: app)
        XCTAssertFalse(
            logAction.frame.intersects(todayTab.frame),
            "Expected the in-content log action to remain clear of the native tabs."
        )
        XCTAssertTrue(nativeTabButton("timeline.footer.settings", title: "Settings", in: app).exists)
        XCTAssertFalse(app.buttons["home.streakCard"].exists)
        XCTAssertTrue(nativeTabButton("home.historyCard", title: "History", in: app).exists)
        XCTAssertTrue(timelineHeadline(in: app).waitForExistence(timeout: 5))

        openWeeklyInsights(in: app)
        XCTAssertTrue(scrollToElement(insightsStreak(in: app), in: app, attempts: 10))
        XCTAssertFalse(app.buttons["weekly.viewFullHistory"].exists)
        navigationBackButton(in: app).tap()
        XCTAssertTrue(nativeTabButton("home.historyCard", title: "History", in: app).isSelected)

        assertSettingsTabOpens(in: app)
        XCTAssertFalse(app.buttons["settings.sharing"].exists)
        expandSettingsSection("reminders", in: app)
        let reapplyToggle = app.switches["settings.reapplyToggle"]
        XCTAssertTrue(scrollToHittableElement(reapplyToggle, in: app, attempts: 10), "Expected the reapply toggle to be reachable in accessibility mode.")
        // A large-text switch can be reported hittable with only the edge of
        // its label visible. Bring the entire control into the window first.
        let settingsScroll = app.scrollViews.firstMatch
        for _ in 0..<6 where !app.frame.insetBy(dx: 0, dy: 24).contains(reapplyToggle.frame) {
            nudgeScrollSurface(settingsScroll, direction: .scrollUp, distance: 0.2)
        }
        XCTAssertTrue(app.frame.contains(reapplyToggle.frame))
        if stringValue(of: reapplyToggle) != "1" {
            reapplyToggle.tap()
        }
        XCTAssertTrue(waitForValueContaining("1", on: reapplyToggle), "Reapply switch must turn on before choosing an interval.")
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.reapplyInterval.120"], in: app, attempts: 10), "Expected enabled reapply settings to show reachable interval controls.")

        XCTAssertTrue(navigationBackButton(in: app).waitForExistence(timeout: 5), "Expected Settings detail back button after editing reapply settings.")
        navigationBackButton(in: app).tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5), "Expected to return to the Settings tab root.")
        XCTAssertTrue(selectNativeTab(nativeTabButton("timeline.footer.today", title: "Today", in: app)),
            "Expected Today tab home action after leaving Settings."
        )
        tapHittableElement(logAction, in: app)
        assertHomeLoggedState(app)
        openTodayEditor(in: app)
        let saveLog = app.buttons["manualLog.logToday"]
        XCTAssertTrue(scrollToHittableElement(saveLog, in: app, attempts: 10), "Expected manual log action to remain reachable in accessibility mode.")
        XCTAssertGreaterThanOrEqual(saveLog.frame.height, 44)
        saveLog.tap()
        assertHomeLoggedState(app)
        attachScorecardScreenshot(app, checkpoint: "Larger Text logged summary")
    }

    @MainActor
    private func attachScorecardScreenshot(_ app: XCUIApplication, checkpoint: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accessibility scorecard - \(checkpoint)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testManualLogFlowReturnsHomeLogged() throws {
        let app = launchHome()

        tapHittableElement(app.buttons["home.logManually"], in: app)
        assertHomeLoggedState(app)
        openTodayEditor(in: app)
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        tapHittableElement(app.buttons["manualLog.logToday"], in: app)

        assertHomeLoggedState(app)
    }

    @MainActor
    func testHistoryCanEditExistingRecord() throws {
        let app = launchHistoryWithSeededRecords(route: "historyEditToday")
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))

        expandLogDetails(in: app, prefix: "historyEditor")
        app.buttons["historyEditor.spf.70"].tap()
        app.buttons["historyEditor.save"].tap()

        XCTAssertTrue(waitForLabel("SPF 70", on: app.staticTexts["historyHarness.spf"]))
    }

    @MainActor
    func testHistoryCanBackfillMissedDay() throws {
        let app = launchHistoryWithSeededRecords(route: "historyBackfillTwoDaysAgo")
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))
        expandLogDetails(in: app, prefix: "historyEditor")
        XCTAssertTrue(app.buttons["historyEditor.spf.30"].isSelected)

        app.buttons["historyEditor.spf.50"].tap()
        app.buttons["historyEditor.save"].tap()

        XCTAssertTrue(waitForLabel("SPF 50", on: app.staticTexts["historyHarness.spf"]))
    }

    @MainActor
    func testRecoveryUndoRestoresTodayAndStreak() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=recovery",
            "UITEST_SEED_HISTORY=undoDeleteToday"
        ]
        app.launch()

        let undoButton = app.buttons["recovery.batch.0.undo"]
        XCTAssertTrue(scrollToElement(undoButton, in: app))

        undoButton.tap()

        performBackSwipe(in: app)
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))

        assertHomeLoggedState(app)

        openWeeklyInsights(in: app)
        let currentStreak = insightsStreak(in: app)
        XCTAssertTrue(scrollToElement(currentStreak, in: app, attempts: 10), "Expected the restored streak in weekly insights after undo.")
        XCTAssertEqual(currentStreak.label, "2-day streak")
    }

    @MainActor
    func testReapplyCheckInFlowLogsCompletionAndReturnsHome() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=reapplyCheckIn",
            "UITEST_SEED_HISTORY=todayLogged",
            "UITEST_REAPPLY_ENABLED"
        ])

        XCTAssertTrue(app.buttons["reapply.log"].waitForExistence(timeout: 10))
        app.buttons["reapply.log"].tap()

        assertHomeLoggedState(app)
    }

    @MainActor
    func testWidgetLogTodayURLShowsSuccessUpdatesHomeAndOffersAddDetails() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL=\(widgetURL(path: "log-today"))"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sunscreen Logged"].exists)
        XCTAssertFalse(app.buttons["timeline.footer.today"].exists)
        XCTAssertFalse(app.buttons["home.logManually"].exists)
        XCTAssertTrue(app.buttons["success.done"].exists)
        XCTAssertTrue(scrollToElement(app.buttons["success.addDetails"], in: app))

        app.buttons["success.addDetails"].tap()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        if navigationBackButton(in: app).waitForExistence(timeout: 2) {
            navigationBackButton(in: app).tap()
        }
        if app.buttons["success.done"].waitForExistence(timeout: 2) {
            app.buttons["success.done"].tap()
        }
        assertHomeLoggedState(app)
    }

    @MainActor
    func testDisabledURLWritesRouteToManualLogWithoutMutatingHistory() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL_WRITES_DISABLED",
            "UITEST_URL=\(automationURL(path: "log-today?spf=50&notes=Blocked"))"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        navigationBackButton(in: app).tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        let todayStatus = app.buttons["home.todayStatus"]
        XCTAssertFalse(todayStatus.exists)
        XCTAssertFalse(app.buttons["home.loggedPrimaryAction"].exists)
        assertHomeReadyForLogState(app)
    }
}
