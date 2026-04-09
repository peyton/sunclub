import XCTest

final class SunclubUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsWelcome() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingAdvancesToHome() throws {
        let app = launchAndCompleteOnboarding()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.verifyNow"].exists)
        XCTAssertTrue(app.buttons["home.settingsButton"].exists)
        XCTAssertTrue(app.staticTexts["home.todayStatus"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeRoutesToWeeklySummaryAndSettings() throws {
        let app = launchHome()

        app.buttons["home.streakCard"].tap()
        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))

        app.terminate()
        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        relaunchedApp.launch()

        XCTAssertTrue(relaunchedApp.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testManualLogSuccessReturnsHome() throws {
        let app = launchHome()

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()
        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))

        app.buttons["success.done"].tap()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsShowsReminderControls() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.buttons["settings.weekdayReminderTime"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.weekendReminderTime"].exists)
        XCTAssertTrue(app.switches["settings.leaveHomeToggle"].exists)
        XCTAssertTrue(app.switches["settings.travelToggle"].exists)
        XCTAssertTrue(app.switches["settings.streakRiskToggle"].exists)
        XCTAssertTrue(app.switches["settings.reapplyToggle"].exists)
        XCTAssertTrue(app.switches["settings.liveUVToggle"].exists)
        XCTAssertTrue(app.buttons["settings.backup.export"].exists)
        XCTAssertTrue(app.buttons["settings.backup.import"].exists)
    }

    @MainActor
    func testSettingsShowsLeaveHomeSetupActionWhenEnabledWithoutHome() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=settings",
            "UITEST_LEAVE_HOME_ENABLED"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["settings.leaveHome.action"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["settings.leaveHome.action"].label, "Use Current Location as Home")
    }

    @MainActor
    func testSettingsShowsICloudSyncEnabledByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        let iCloudToggle = app.switches["settings.icloudToggle"]
        XCTAssertTrue(scrollToElement(iCloudToggle, in: app))
        XCTAssertEqual(stringValue(of: iCloudToggle), "1")
        XCTAssertTrue(app.staticTexts["iCloud sync is on"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsCanPauseAndResumeICloudSync() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        let iCloudToggle = app.switches["settings.icloudToggle"]
        XCTAssertTrue(scrollToElement(iCloudToggle, in: app))
        XCTAssertEqual(stringValue(of: iCloudToggle), "1")

        iCloudToggle.tap()
        XCTAssertTrue(app.staticTexts["iCloud sync is paused"].waitForExistence(timeout: 5))
        XCTAssertEqual(stringValue(of: iCloudToggle), "0")

        iCloudToggle.tap()
        XCTAssertTrue(app.staticTexts["iCloud sync is on"].waitForExistence(timeout: 5))
        XCTAssertEqual(stringValue(of: iCloudToggle), "1")
    }

    @MainActor
    func testWeekdayReminderPickerOpensFromSettings() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        let weekdayButton = app.buttons["settings.weekdayReminderTime"]
        XCTAssertTrue(weekdayButton.waitForExistence(timeout: 5))

        weekdayButton.tap()

        XCTAssertTrue(app.buttons["Save Time"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsEdgeSwipeReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.buttons["settings.weekdayReminderTime"].waitForExistence(timeout: 5))

        performBackSwipe(in: app)

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
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

        XCTAssertTrue(waitForLabel("History entries: 1", on: exportApp.staticTexts["settings.backupRecordCount"]))
        let exportTravelToggle = exportApp.switches["settings.travelToggle"]
        XCTAssertEqual(stringValue(of: exportTravelToggle), "1")
        exportTravelToggle.tap()
        XCTAssertEqual(stringValue(of: exportTravelToggle), "0")

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

        XCTAssertTrue(waitForLabel("History entries: 0", on: importApp.staticTexts["settings.backupRecordCount"]))
        let importTravelToggle = importApp.switches["settings.travelToggle"]
        XCTAssertEqual(stringValue(of: importTravelToggle), "1")

        importApp.buttons["settings.backup.importHarness"].tap()

        XCTAssertTrue(
            waitForLabel(
                "Imported 1 day from backup. iCloud stays unchanged until you publish these changes.",
                on: importApp.staticTexts["settings.backupStatus"]
            )
        )
        XCTAssertTrue(waitForLabel("History entries: 1", on: importApp.staticTexts["settings.backupRecordCount"]))
        XCTAssertEqual(stringValue(of: importTravelToggle), "0")
        XCTAssertTrue(scrollToElement(importApp.staticTexts["settings.icloud.pendingImports"], in: importApp))
        XCTAssertTrue(importApp.buttons["settings.icloud.publishImported"].exists)
        XCTAssertTrue(importApp.buttons["settings.icloud.restoreImported"].exists)
    }

    @MainActor
    func testHomeShowsManualLogButton() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeShowsRecoveryActionsWhenTodayAndYesterdayNeedAttention() throws {
        let app = launchHome()

        XCTAssertTrue(app.buttons["home.recovery.logToday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.recovery.backfillYesterday"].exists)
    }

    @MainActor
    func testHomeShowsHistoryCard() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.historyCard"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeShowsHighUVStatusFromLaunchOverride() throws {
        let app = launchHome(additionalArguments: ["UITEST_UV_INDEX=7"])

        let uvHeadline = app.staticTexts["home.uvHeadline"]
        XCTAssertTrue(uvHeadline.waitForExistence(timeout: 5))
        XCTAssertEqual(uvHeadline.label, "UV is high today")

        let detail = app.staticTexts["home.todayDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.label.contains("reapply sooner"))
    }

    @MainActor
    func testManualLogFlowShowsSuccess() throws {
        let app = launchHome()

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()

        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testManualLogShowsSmartReuseSuggestions() throws {
        let app = launchHome(additionalArguments: ["UITEST_SEED_HISTORY=manualSuggestions"])

        app.buttons["home.logManually"].tap()

        XCTAssertTrue(app.buttons["manualLog.sameAsLastTime"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["manualLog.noteSnippet.0"].exists)
        app.buttons["manualLog.noteSnippet.0"].tap()

        let notesField = app.textFields["manualLog.notesField"]
        XCTAssertEqual(notesField.value as? String, "Before lunch")
    }

    @MainActor
    func testHistoryViewShowsCalendar() throws {
        let app = launchHome()

        app.buttons["home.historyCard"].tap()
        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["history.previousMonth"].exists)
    }

    @MainActor
    func testHistoryShowsMonthlyReviewInsights() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=monthlyReview"
        ])

        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["Best Weekday"], in: app, attempts: 8))
        XCTAssertTrue(app.staticTexts["Hardest Weekday"].exists)
        XCTAssertTrue(app.staticTexts["Most Common SPF"].exists)
    }

    @MainActor
    func testHistoryCanEditExistingRecord() throws {
        let app = launchHistoryWithSeededRecords(route: "historyEditToday")
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))

        app.buttons["70"].tap()
        app.buttons["historyEditor.save"].tap()

        XCTAssertTrue(waitForLabel("SPF 70", on: app.staticTexts["historyHarness.spf"]))
    }

    @MainActor
    func testHistoryCanBackfillMissedDay() throws {
        let app = launchHistoryWithSeededRecords(route: "historyBackfillTwoDaysAgo")
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))

        app.buttons["50"].tap()
        app.buttons["historyEditor.save"].tap()

        XCTAssertTrue(waitForLabel("SPF 50", on: app.staticTexts["historyHarness.spf"]))
    }

    @MainActor
    func testRecoveryShowsConflictReviewActions() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=recovery",
            "UITEST_SEED_HISTORY=conflictDay"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Recovery"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["recovery.conflict.summary"], in: app))
        XCTAssertTrue(app.buttons["recovery.conflict.undo"].exists)
        XCTAssertTrue(app.buttons["recovery.conflict.resolve"].exists)
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

        let todayStatus = app.staticTexts["home.todayStatus"]
        XCTAssertTrue(todayStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(todayStatus.label, "Already logged today")

        let streakValue = app.staticTexts["home.streakValue"]
        XCTAssertTrue(streakValue.waitForExistence(timeout: 5))
        XCTAssertEqual(streakValue.label, "2")
    }

    @MainActor
    func testDailyNotificationRouteOpensManualLog() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=manualLog"]
        app.launch()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReapplyCheckInFlowLogsCompletionAndReturnsHome() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=reapplyCheckIn",
            "UITEST_SEED_HISTORY=todayLogged",
            "UITEST_REAPPLY_ENABLED"
        ])

        XCTAssertTrue(app.buttons["reapply.log"].waitForExistence(timeout: 5))
        app.buttons["reapply.log"].tap()

        XCTAssertTrue(app.buttons["home.reapplyCard"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWeeklyNotificationRouteOpensWeeklySummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHighUVReapplyReminderNoteUsesStrongerCopy() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_CURRENT_TIME=13:00",
            "UITEST_UV_INDEX=7",
            "UITEST_REAPPLY_ENABLED",
            "UITEST_REAPPLY_INTERVAL=120"
        ])

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()

        let reapplyMessage = app.staticTexts["success.reapplyMessage"]
        XCTAssertTrue(reapplyMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(reapplyMessage.label.contains("High UV today"))
        XCTAssertTrue(reapplyMessage.label.contains("1h 30m"))
    }

    @MainActor
    func testWeeklySummaryShowsUsageInsights() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=weeklySummary",
            "UITEST_SEED_USAGE_INSIGHTS"
        ]
        app.launch()

        let mostUsedSPF = app.staticTexts["SPF 50"]
        XCTAssertTrue(scrollToElement(mostUsedSPF, in: app))
        XCTAssertEqual(mostUsedSPF.label, "SPF 50")

        let recentNote = app.staticTexts["Before beach walk"]
        XCTAssertTrue(scrollToElement(recentNote, in: app))
        XCTAssertEqual(recentNote.label, "Before beach walk")
    }

    @MainActor
    func testSettingsShowsReminderCoachingAndNotificationHealth() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=settings",
            "UITEST_SEED_HISTORY=reminderCoaching",
            "UITEST_NOTIFICATION_HEALTH=stale"
        ]
        app.launch()

        XCTAssertTrue(scrollToElement(app.buttons["settings.coaching.weekday"], in: app))
        XCTAssertTrue(app.buttons["settings.notificationHealth.action"].exists)
        XCTAssertTrue(app.switches["settings.liveUVToggle"].exists)
    }

    @MainActor
    func testWidgetLogTodayURLShowsSuccessAndUpdatesHome() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL=\(widgetURL(path: "log-today"))"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))

        app.buttons["success.done"].tap()

        let todayStatus = app.staticTexts["home.todayStatus"]
        XCTAssertTrue(todayStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(todayStatus.label, "Already logged today")
    }

    @MainActor
    private func launchAndCompleteOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()
        return completeOnboarding(in: app)
    }

    @MainActor
    private func launchHome() -> XCUIApplication {
        launchHome(additionalArguments: [])
    }

    @MainActor
    private func launchHome(additionalArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING"] + additionalArguments
        app.launch()
        return app
    }

    @MainActor
    private func launchHistoryWithSeededRecords(route: String = "history") -> XCUIApplication {
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

    private func widgetURL(path: String) -> String {
        let scheme = Bundle.main.object(forInfoDictionaryKey: "SunclubURLScheme") as? String ?? "sunclub"
        return "\(scheme)://widget/\(path)"
    }

    @discardableResult
    @MainActor
    private func completeOnboarding(in app: XCUIApplication) -> XCUIApplication {
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.enableNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.enableNotifications"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func performBackSwipe(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    private func waitForLabel(_ label: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func stringValue(of element: XCUIElement) -> String? {
        element.value as? String
    }

    @MainActor
    private func scrollToElement(
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
