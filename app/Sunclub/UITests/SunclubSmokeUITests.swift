import XCTest

final class SunclubSmokeUITests: SunclubUITestCase {
    @MainActor
    func testOnboardingCanSkipNotifications() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipUV"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipUV"].tap()
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
        XCTAssertTrue(app.staticTexts["Sunscreen & Reminders"].waitForExistence(timeout: 5))

        dragFromLeftEdge(in: app)

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["screen.back"].exists)
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
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertLessThan(averageScreenshotLuminance(), 0.70)

        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.settings"]))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        expandSettingsSection("reminders", in: app)
        XCTAssertTrue(app.buttons["settings.weekdayReminderTime"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAccessibilityScorecardCoreTasksRemainUsable() throws {
        let app = launchHome(additionalArguments: accessibilityScorecardArguments + [
            "UITEST_UV_INDEX=8",
            "UITEST_SEED_ACCOUNTABILITY_FRIEND"
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
        let todayTab = app.buttons["timeline.footer.today"]
        XCTAssertFalse(
            logAction.frame.intersects(todayTab.frame),
            "Expected the in-content log action to remain clear of the native tabs."
        )
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertFalse(app.buttons["home.streakCard"].exists)
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(timelineHeadline(in: app).waitForExistence(timeout: 5))

        openWeeklyInsights(in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["weekly.viewFullHistory"], in: app, attempts: 10))
        app.buttons["screen.back"].tap()
        XCTAssertTrue(app.buttons["home.historyCard"].isSelected)

        assertSettingsTabOpens(in: app)
        XCTAssertFalse(app.buttons["settings.sharing"].exists)
        expandSettingsSection("progress", in: app)
        let reapplyToggle = app.switches["settings.reapplyToggle"]
        XCTAssertTrue(scrollToHittableElement(reapplyToggle, in: app, attempts: 10), "Expected the reapply toggle to be reachable in accessibility mode.")
        if stringValue(of: reapplyToggle) != "1" {
            reapplyToggle.tap()
        }
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.reapplyInterval.120"], in: app, attempts: 10), "Expected enabled reapply settings to show reachable interval controls.")

        XCTAssertTrue(app.buttons["screen.back"].waitForExistence(timeout: 5), "Expected Settings detail back button after editing reapply settings.")
        app.buttons["screen.back"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5), "Expected to return to the Settings tab root.")
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]),
            "Expected Today tab home action after leaving Settings."
        )
        tapHittableElement(logAction, in: app)
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
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        tapHittableElement(app.buttons["manualLog.logToday"], in: app)

        assertHomeLoggedState(app)
    }

    @MainActor
    func testHistoryCanEditExistingRecord() throws {
        let app = launchHistoryWithSeededRecords(route: "historyEditToday")
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))

        app.buttons["historyEditor.spf.70"].tap()
        app.buttons["historyEditor.save"].tap()

        XCTAssertTrue(waitForLabel("SPF 70", on: app.staticTexts["historyHarness.spf"]))
    }

    @MainActor
    func testHistoryCanBackfillMissedDay() throws {
        let app = launchHistoryWithSeededRecords(route: "historyBackfillTwoDaysAgo")
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel("SPF 30 selected", on: app.staticTexts["historyEditor.spfState"], timeout: 10))

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
        let currentStreak = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Current run 2 days.")
        ).firstMatch
        XCTAssertTrue(scrollToElement(currentStreak, in: app, attempts: 10), "Expected the restored streak in weekly insights after undo.")
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
        XCTAssertTrue(app.navigationBars["Sunscreen Logged"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["timeline.footer.today"].exists)
        XCTAssertFalse(app.buttons["home.logManually"].exists)
        XCTAssertTrue(app.buttons["success.done"].exists)
        XCTAssertTrue(scrollToElement(app.buttons["success.addDetails"], in: app))

        app.buttons["success.addDetails"].tap()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        if app.buttons["screen.back"].waitForExistence(timeout: 2) {
            app.buttons["screen.back"].tap()
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
        app.buttons["screen.back"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        let todayStatus = app.staticTexts["home.todayStatus"]
        XCTAssertFalse(todayStatus.exists)
        XCTAssertFalse(app.buttons["home.loggedPrimaryAction"].exists)
        assertHomeReadyForLogState(app)
    }
}
