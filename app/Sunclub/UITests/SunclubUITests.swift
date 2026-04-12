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
        XCTAssertFalse(app.buttons["accountabilityOnboarding.next"].exists)
        XCTAssertFalse(app.buttons["home.accountabilityNudge.setup"].exists)
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
    func testAchievementsShowClearProgressMeters() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=achievements",
            "UITEST_SEED_HISTORY=achievementProgress"
        ])

        let morningSummary = app.staticTexts["achievement.progress.morningGlow.summary"]
        XCTAssertTrue(scrollToElement(morningSummary, in: app, attempts: 10))
        XCTAssertTrue(morningSummary.label.contains("80%"))
        XCTAssertTrue(morningSummary.label.contains("4/5"))

        let morningStatus = app.staticTexts["achievement.progress.morningGlow.status"]
        XCTAssertTrue(waitForLabel("1 left", on: morningStatus))

        let firstReapplyStatus = app.staticTexts["achievement.progress.firstReapply.status"]
        XCTAssertTrue(scrollToElement(firstReapplyStatus, in: app, attempts: 10))
        XCTAssertEqual(firstReapplyStatus.label, "Unlocked")
    }

    @MainActor
    func testManualLogSuccessReturnsHome() throws {
        let app = launchHome()

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()
        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))

        app.buttons["success.done"].tap()
        let todayStatus = app.staticTexts["home.todayStatus"]
        XCTAssertTrue(todayStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(todayStatus.label, "Today's log is in")
        XCTAssertTrue(app.buttons["home.loggedPrimaryAction"].exists)
    }

    @MainActor
    func testSettingsShowsReminderControls() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.section.progress"].exists)
        XCTAssertTrue(app.buttons["settings.section.data"].exists)
        XCTAssertTrue(app.buttons["settings.section.advanced"].exists)
        XCTAssertFalse(app.buttons["settings.weekdayReminderTime"].exists)

        expandSettingsSection("reminders", in: app)
        XCTAssertTrue(app.buttons["settings.weekdayReminderTime"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.weekendReminderTime"].exists)
        XCTAssertTrue(app.switches["settings.travelToggle"].exists)
        XCTAssertTrue(app.switches["settings.streakRiskToggle"].exists)

        expandSettingsSection("progress", in: app)
        XCTAssertTrue(app.switches["settings.reapplyToggle"].exists)

        expandSettingsSection("data", in: app)
        XCTAssertTrue(scrollToElement(app.switches["settings.icloudToggle"], in: app))
        XCTAssertTrue(app.buttons["settings.backup.export"].exists)
        XCTAssertTrue(app.buttons["settings.backup.import"].exists)

        expandSettingsSection("advanced", in: app)
        XCTAssertTrue(scrollToElement(app.switches["settings.leaveHomeToggle"], in: app))
        XCTAssertTrue(app.switches["settings.liveUVToggle"].exists)
        XCTAssertTrue(app.switches["settings.uvBriefingToggle"].exists)
        XCTAssertTrue(app.switches["settings.extremeUVToggle"].exists)

        XCTAssertTrue(scrollToElement(app.buttons["settings.section.help"], in: app))
        expandSettingsSection("help", in: app)
        XCTAssertTrue(scrollToElement(app.buttons["settings.support"], in: app))
        XCTAssertTrue(app.buttons["settings.privacyPolicy"].exists)
        XCTAssertTrue(app.buttons["settings.emailSupport"].exists)
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

        expandSettingsSection("advanced", in: app)
        XCTAssertTrue(scrollToElement(app.buttons["settings.leaveHome.action"], in: app))
        XCTAssertEqual(app.buttons["settings.leaveHome.action"].label, "Use Current Location as Home")
    }

    @MainActor
    func testSettingsShowsICloudSyncEnabledByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        expandSettingsSection("data", in: app)
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

        expandSettingsSection("data", in: app)
        let iCloudToggle = app.switches["settings.icloudToggle"]
        XCTAssertTrue(scrollToElement(iCloudToggle, in: app))
        XCTAssertEqual(stringValue(of: iCloudToggle), "1")

        iCloudToggle.tap()
        XCTAssertTrue(app.staticTexts["Saved only on this phone"].waitForExistence(timeout: 5))
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

        expandSettingsSection("reminders", in: app)
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

        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))

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

        expandSettingsSection("data", in: exportApp)
        XCTAssertTrue(waitForLabel("History entries: 1", on: exportApp.staticTexts["settings.backupRecordCount"]))
        expandSettingsSection("reminders", in: exportApp)
        let exportTravelToggle = exportApp.switches["settings.travelToggle"]
        XCTAssertTrue(scrollToElement(exportTravelToggle, in: exportApp))
        XCTAssertEqual(stringValue(of: exportTravelToggle), "1")
        exportTravelToggle.tap()
        XCTAssertEqual(stringValue(of: exportTravelToggle), "0")

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
        assertBackupImportRestoresHistoryAndSettings(in: importApp)
    }

    @MainActor
    func testHomeShowsManualLogButton() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHomeKeepsAdvancedActionsBehindExplore() throws {
        let app = launchHome()

        XCTAssertTrue(app.buttons["home.streakCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.exploreToggle"].exists)
        XCTAssertFalse(app.otherElements["home.exploreGrid"].exists)
        XCTAssertFalse(app.buttons["home.feature.friends"].exists)
        XCTAssertFalse(app.buttons["home.feature.skinHealthReport"].exists)
        XCTAssertFalse(app.buttons["home.feature.productScanner"].exists)

        app.buttons["home.exploreToggle"].tap()

        XCTAssertTrue(app.otherElements["home.exploreGrid"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.feature.achievements"].exists)
        XCTAssertTrue(app.buttons["home.feature.friends"].exists)
        XCTAssertTrue(scrollToElement(app.buttons["home.feature.skinHealthReport"], in: app))
        XCTAssertTrue(scrollToElement(app.buttons["home.feature.productScanner"], in: app))
    }

    @MainActor
    func testHomeShowsOptionalAccountabilityNudgeAfterThreeLoggedDays() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_RESET_ACCOUNTABILITY",
            "UITEST_SEED_HISTORY=achievementProgress"
        ])

        XCTAssertTrue(scrollToElement(app.buttons["home.accountabilityNudge.setup"], in: app))
        XCTAssertTrue(app.buttons["home.accountabilityNudge.dismiss"].exists)
    }

    @MainActor
    func testHomeShowsAccountabilityCardFrontAndCenterForFriends() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_ACCOUNTABILITY_FRIEND"
        ])

        XCTAssertTrue(app.otherElements["home.accountabilityCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.accountabilityPoke"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.accountabilityFriendStrip"].exists)
        XCTAssertFalse(app.otherElements["home.exploreGrid"].exists)
    }

    @MainActor
    func testHomeShowsActiveAccountabilitySetupFrontAndCenter() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_ACCOUNTABILITY_ACTIVE"
        ])

        XCTAssertTrue(app.otherElements["home.accountabilityCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bring in backup"].exists)
        XCTAssertTrue(app.buttons["home.accountabilityPoke"].exists)
    }

    @MainActor
    func testAccountabilityHubShowsAddInviteCodeAndPokeActions() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=friends",
            "UITEST_SEED_ACCOUNTABILITY_FRIEND"
        ])

        XCTAssertTrue(app.buttons["friends.activate"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.buttons["Poke"], in: app))
        XCTAssertTrue(app.buttons["Refresh"].exists)
        XCTAssertFalse(app.buttons["Poke by Message"].exists)
        XCTAssertFalse(app.buttons["Remove Friend"].exists)

        XCTAssertTrue(scrollToElement(app.buttons["friends.add.toggle"], in: app))
        app.buttons["friends.add.toggle"].tap()
        XCTAssertTrue(app.buttons["friends.add.nearby"].exists)
        XCTAssertTrue(app.buttons["friends.add.share"].exists)
        XCTAssertTrue(app.buttons["friends.add.paste"].exists)
        XCTAssertTrue(scrollToElement(app.staticTexts["friends.backupCode"], in: app))
    }

    @MainActor
    func testInviteDeepLinkImportsAfterFirstOpenOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_URL=\(try accountabilityInviteURL(displayName: "Maya"))"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.enableNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.enableNotifications"].tap()

        XCTAssertTrue(app.buttons["friends.activate"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["Maya"], in: app))
        XCTAssertTrue(app.buttons["Poke"].exists)
    }

    @MainActor
    func testHomeDoesNotShowDuplicateRecoveryActionsForNewUsers() throws {
        let app = launchHome()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.recovery.logToday"].exists)
        XCTAssertFalse(app.buttons["home.recovery.backfillYesterday"].exists)
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

        XCTAssertTrue(app.buttons["manualLog.detailsToggle"].waitForExistence(timeout: 5))
        app.buttons["manualLog.detailsToggle"].tap()
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
    func testWeeklySummaryOpensFullHistoryWithStreakContext() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_HISTORY=achievementProgress"
        ])

        app.buttons["home.streakCard"].tap()
        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["weekly.viewFullHistory"].waitForExistence(timeout: 5))

        app.buttons["weekly.viewFullHistory"].tap()
        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["history.streakContext"].exists)
        XCTAssertTrue(app.staticTexts["history.currentStreakValue"].exists)

        app.buttons["screen.back"].tap()
        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryCalendarSwipesToPreviousMonth() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=monthlyReview"
        ])

        let monthTitle = app.staticTexts["history.monthTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let initialMonth = monthTitle.label

        let calendarGrid = app.otherElements["history.calendarGrid"]
        XCTAssertTrue(calendarGrid.waitForExistence(timeout: 5))
        calendarGrid.swipeRight()

        XCTAssertTrue(waitForDifferentLabel(from: initialMonth, on: monthTitle))
    }

    @MainActor
    func testHistoryCalendarSwipesForwardWithoutOpeningFutureMonth() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=monthlyReview"
        ])

        let monthTitle = app.staticTexts["history.monthTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let currentMonth = monthTitle.label

        let calendarGrid = app.otherElements["history.calendarGrid"]
        XCTAssertTrue(calendarGrid.waitForExistence(timeout: 5))
        calendarGrid.swipeLeft()
        XCTAssertTrue(waitForLabel(currentMonth, on: monthTitle, timeout: 2))

        calendarGrid.swipeRight()
        XCTAssertTrue(waitForDifferentLabel(from: currentMonth, on: monthTitle))
        calendarGrid.swipeLeft()
        XCTAssertTrue(waitForLabel(currentMonth, on: monthTitle))
    }

    @MainActor
    func testHistoryShowsMonthlyReviewInsights() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=monthlyReview"
        ])

        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Logged"].exists)
        XCTAssertTrue(app.staticTexts["Not logged"].exists)
        XCTAssertTrue(app.staticTexts["Future"].exists)
        let patternsButton = app.buttons["Show Patterns"]
        XCTAssertTrue(scrollToElement(patternsButton, in: app, attempts: 8))
        patternsButton.tap()
        XCTAssertTrue(app.staticTexts["Best Day"].exists)
        XCTAssertTrue(app.staticTexts["Hardest Day"].exists)
        XCTAssertTrue(app.staticTexts["Most Used SPF"].exists)
    }

    @MainActor
    func testWeeklySummaryAppliedDayOpensHistoryEditor() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=weeklySummary",
            "UITEST_SEED_HISTORY=todayLogged"
        ])

        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
        let todayButton = app.buttons["weekly.day.\(dayIdentifier())"]
        XCTAssertTrue(todayButton.waitForExistence(timeout: 5))
        todayButton.tap()

        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryDeletePreservesSelectionForBackfill() throws {
        let app = launchHistoryWithSeededRecords(route: "history")
        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))

        let todayButton = app.buttons["history.day.\(dayIdentifier())"]
        XCTAssertTrue(todayButton.waitForExistence(timeout: 5))
        todayButton.tap()

        XCTAssertTrue(app.staticTexts["history.statusTitle"].waitForExistence(timeout: 5))
        let deleteButton = app.buttons["history.deleteRecord"]
        XCTAssertTrue(scrollToElement(deleteButton, in: app))
        deleteButton.tap()
        let confirmDeleteButton = app.sheets.buttons["Delete"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 2))
        confirmDeleteButton.tap()

        XCTAssertTrue(scrollToElement(app.buttons["history.backfillRecord"], in: app))
        XCTAssertTrue(app.staticTexts["history.statusTitle"].exists)
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

        XCTAssertTrue(app.staticTexts["Recovery & Changes"].waitForExistence(timeout: 5))
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
        XCTAssertEqual(todayStatus.label, "Today's log is in")

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
    func testWidgetManualLogRouteBackButtonReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL=\(widgetURL(path: "open/updateToday"))"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["screen.back"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWidgetUpdateRouteShowsUpdateTodayWhenAlreadyLogged() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_SEED_HISTORY=todayLogged",
            "UITEST_URL=\(widgetURL(path: "open/updateToday"))"
        ]
        app.launch()

        let logButton = app.buttons["manualLog.logToday"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))
        XCTAssertEqual(logButton.label, "Update Today")
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

        XCTAssertTrue(app.buttons["home.loggedPrimaryAction"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWeeklyNotificationRouteOpensWeeklySummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWeeklySummaryBackButtonReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Weekly Summary"].waitForExistence(timeout: 5))
        app.buttons["screen.back"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLogTodayQuickActionOpensManualLogAndReturnsHome() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_SHORTCUT_TYPE=app.peyton.sunclub.log-today"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["screen.back"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
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

        expandSettingsSection("reminders", in: app)
        XCTAssertTrue(scrollToElement(app.buttons["settings.coaching.weekday"], in: app))
        XCTAssertTrue(app.buttons["settings.notificationHealth.action"].exists)
        expandSettingsSection("advanced", in: app)
        XCTAssertTrue(scrollToElement(app.switches["settings.liveUVToggle"], in: app))
    }

    @MainActor
    func testSettingsLiveUVToggleUsesMockedLiveWeatherDataEndToEnd() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=settings",
            "UITEST_CURRENT_TIME=11:00",
            "UITEST_LIVE_UV_INDEX=8",
            "UITEST_LIVE_UV_PEAK_INDEX=11"
        ]
        app.launch()

        expandSettingsSection("advanced", in: app)
        let liveUVToggle = app.switches["settings.liveUVToggle"]
        XCTAssertTrue(scrollToElement(liveUVToggle, in: app))
        XCTAssertEqual(stringValue(of: liveUVToggle), "0")

        liveUVToggle.tap()

        XCTAssertTrue(app.staticTexts["Live UV is on"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Live WeatherKit UV"].waitForExistence(timeout: 5))

        app.buttons["screen.back"].tap()

        let uvHeadline = app.staticTexts["home.uvHeadline"]
        XCTAssertTrue(uvHeadline.waitForExistence(timeout: 5))
        XCTAssertEqual(uvHeadline.label, "UV is very high today")
        XCTAssertTrue(app.staticTexts["home.todayDetail"].label.contains("reapply sooner"))
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
        XCTAssertEqual(todayStatus.label, "Today's log is in")
    }

    @MainActor
    func testWidgetLogTodaySuccessOffersAddDetails() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL=\(widgetURL(path: "log-today"))"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.buttons["success.addDetails"], in: app))

        app.buttons["success.addDetails"].tap()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
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

    private func accountabilityInviteURL(displayName: String) throws -> String {
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
        let scheme = Bundle.main.object(forInfoDictionaryKey: "SunclubURLScheme") as? String ?? "sunclub"
        return "\(scheme)://accountability/invite?code=\(encodedCode)"
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
    private func waitForDifferentLabel(from label: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label != %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func dayIdentifier(offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return Self.dayIdentifierFormatter.string(from: day)
    }

    private static let dayIdentifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @MainActor
    private func assertBackupImportRestoresHistoryAndSettings(in app: XCUIApplication) {
        XCTAssertTrue(waitForLabel("History entries: 0", on: app.staticTexts["settings.backupRecordCount"]))
        expandSettingsSection("reminders", in: app)
        let travelToggle = app.switches["settings.travelToggle"]
        XCTAssertTrue(scrollToElement(travelToggle, in: app))
        XCTAssertEqual(stringValue(of: travelToggle), "1")

        XCTAssertTrue(scrollToElement(app.buttons["settings.backup.importHarness"], in: app))
        app.buttons["settings.backup.importHarness"].tap()

        XCTAssertTrue(
            waitForLabel(
                "Imported 1 day from backup. iCloud stays unchanged until you send it.",
                on: app.staticTexts["settings.backupStatus"]
            )
        )
        XCTAssertTrue(waitForLabel("History entries: 1", on: app.staticTexts["settings.backupRecordCount"]))
        XCTAssertEqual(stringValue(of: travelToggle), "0")
        XCTAssertTrue(scrollToElement(app.staticTexts["settings.icloud.pendingImports"], in: app))
        XCTAssertTrue(app.buttons["settings.icloud.publishImported"].exists)
        XCTAssertTrue(app.buttons["settings.icloud.restoreImported"].exists)
    }

    @MainActor
    private func stringValue(of element: XCUIElement) -> String? {
        element.value as? String
    }

    @MainActor
    private func expandSettingsSection(_ section: String, in app: XCUIApplication) {
        let sectionButton = app.buttons["settings.section.\(section)"]
        XCTAssertTrue(scrollToHittableElement(sectionButton, in: app, attempts: 8))
        sectionButton.tap()
    }

    @MainActor
    private func scrollToHittableElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 6
    ) -> Bool {
        if element.waitForExistence(timeout: 2), element.isHittable {
            return true
        }

        for _ in 0..<attempts {
            app.swipeUp()
            if element.waitForExistence(timeout: 1), element.isHittable {
                return true
            }
        }

        for _ in 0..<attempts {
            app.swipeDown()
            if element.waitForExistence(timeout: 1), element.isHittable {
                return true
            }
        }

        return false
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
