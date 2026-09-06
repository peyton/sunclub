import XCTest

final class SunclubUITests: SunclubUITestCase {
    @MainActor
    func testLaunchShowsWelcome() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["sunclub"].exists)
        XCTAssertFalse(app.staticTexts["Daily sunscreen, made routine."].exists)
        XCTAssertFalse(app.staticTexts["Log sunscreen. Know today's UV. Reapply on time."].exists)
    }

    @MainActor
    func testOnboardingAdvancesToHome() throws {
        let app = launchAndCompleteOnboarding()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.verifyNow"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        assertHomeReadyForLogState(app)
        XCTAssertEqual(app.buttons.matching(identifier: "home.logManually").count, 1)
        XCTAssertFalse(app.buttons["home.dailyPlan.action"].exists)
    }

    @MainActor
    func testCitySelectionRemainsAvailableAfterOptionalOnboarding() throws {
        let app = launchAndCompleteOnboarding()
        assertHomeReadyForLogState(app)
        assertSettingsTabOpens(in: app)
        expandSettingsSection("advanced", in: app)
        tapHittableElement(app.buttons["settings.liveUV.chooseCity"], in: app)
        XCTAssertTrue(app.textFields["citySearch.query"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["citySearch.submit"].exists)
        tapHittableElement(app.buttons["citySearch.cancel"], in: app)
        XCTAssertTrue(app.switches["settings.liveUVToggle"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryRoutesToWeeklySummaryAndSettings() throws {
        let app = launchHome()

        openWeeklyInsights(in: app)
        navigationBackButton(in: app).tap()
        XCTAssertTrue(app.buttons["home.historyCard"].isSelected)
        assertSettingsTabOpens(in: app)
    }

    @MainActor
    func testAchievementsRouteOpensInsightsInsteadOfBadges() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=achievements",
            "UITEST_SEED_HISTORY=achievementProgress"
        ])

        assertInsightsVisible(in: app)
        XCTAssertFalse(app.staticTexts["achievement.progress.morningGlow.summary"].exists)
        XCTAssertFalse(app.staticTexts["Achievements"].exists)
    }

    @MainActor
    func testOneTapLogCanBeEditedAndReturnsHome() throws {
        let app = launchHome()
        tapHittableElement(app.buttons["home.logManually"], in: app)
        assertHomeLoggedState(app)
        XCTAssertTrue(app.buttons["home.undoLog"].exists)
        XCTAssertFalse(app.buttons["manualLog.logToday"].exists)
        openTodayEditor(in: app)
        tapHittableElement(app.buttons["manualLog.spf.50"], in: app)
        tapHittableElement(app.buttons["manualLog.logToday"], in: app)
        assertHomeLoggedState(app)
        XCTAssertTrue(waitForLabelPrefix("SPF 50", on: app.staticTexts["timeline.statusDetail"]))
    }

    @MainActor
    func testSettingsShowsReminderControls() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=settings",
            "UITEST_LEAVE_HOME_ENABLED",
            "UITEST_SEED_HISTORY=reminderCoaching",
            "UITEST_NOTIFICATION_HEALTH=stale"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        for identifier in [
            "settings.section.sunscreen", "settings.section.reminders", "settings.section.advanced",
            "settings.section.health", "settings.section.data", "settings.section.automation",
            "settings.privacy.quick", "settings.support.quick"
        ] {
            XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1)
        }
        XCTAssertTrue(app.buttons["settings.section.data"].exists)
        XCTAssertTrue(app.buttons["settings.section.automation"].exists)
        XCTAssertTrue(app.buttons["settings.section.advanced"].exists)
        XCTAssertFalse(app.staticTexts["App Preferences"].exists)
        XCTAssertFalse(app.buttons["settings.reference.appearance"].exists)
        XCTAssertFalse(app.buttons["settings.reference.units"].exists)

        assertSettingsSunscreenControls(in: app)
        assertSettingsReminderControls(in: app)
        assertSettingsNotificationControls(in: app)
        assertSettingsProgressControls(in: app)
        assertSettingsDataControls(in: app)
        assertSettingsAutomationControls(in: app)
        assertSettingsAdvancedControls(in: app)
        assertSettingsHelpControls(in: app)
    }

    @MainActor
    private func assertSettingsSunscreenControls(in app: XCUIApplication) {
        expandSettingsSection("sunscreen", in: app)
        let productName = app.textFields["settings.sunscreen.name"]
        XCTAssertTrue(productName.waitForExistence(timeout: 5))
        XCTAssertTrue(app.steppers["settings.sunscreen.spf"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["settings.sunscreen.waterResistance"].exists)
        productName.tap()
        productName.typeText("Daily sunscreen")
        tapHittableElement(app.buttons["settings.sunscreen.save"], in: app)
        XCTAssertTrue(waitForLabel("Sunscreen saved.", on: app.staticTexts["settings.sunscreen.feedback"]))

        returnToSettingsHome(in: app)
        expandSettingsSection("sunscreen", in: app)
        XCTAssertEqual(stringValue(of: productName), "Daily sunscreen")
        tapHittableElement(app.buttons["settings.sunscreen.remove"], in: app)
        XCTAssertTrue(waitForLabel(
            "Saved sunscreen removed. Your logs are unchanged.",
            on: app.staticTexts["settings.sunscreen.feedback"]
        ))
        XCTAssertFalse(app.buttons["settings.sunscreen.remove"].exists)
        returnToSettingsHome(in: app)
    }

    @MainActor
    func testPrivacyShowsExportDeleteControlsAndAccurateConfirmation() throws {
        let app = launchHome(additionalArguments: ["UITEST_ROUTE=privacy"])

        XCTAssertTrue(app.staticTexts["Privacy"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.buttons["privacy.exportHistory"], in: app))
        let deleteHistory = app.buttons["privacy.deleteHistory"]
        XCTAssertTrue(scrollToHittableElement(deleteHistory, in: app))
        app.swipeUp()
        XCTAssertTrue(deleteHistory.isHittable)

        deleteHistory.tap()
        XCTAssertTrue(app.staticTexts["Delete sunscreen history?"].waitForExistence(timeout: 5))
        let confirmationCopy = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@",
            "If iCloud Sync is on, the deletion syncs to your devices."
        )).firstMatch
        XCTAssertTrue(confirmationCopy.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete History"].exists)
    }

    @MainActor
    func testSettingsLiveUVToggleReturnsToTimeline() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=settings",
            "UITEST_LIVE_UV_INDEX=8",
            "UITEST_LIVE_UV_AUTH=always",
            "UITEST_LIVE_UV_PEAK_INDEX=10"
        ]
        app.launch()

        expandSettingsSection("advanced", in: app)

        let liveUVToggle = app.switches["settings.liveUVToggle"]
        XCTAssertTrue(scrollToHittableElement(liveUVToggle, in: app))
        liveUVToggle.tap()

        let liveUVAction = app.buttons["settings.liveUV.action"]
        XCTAssertTrue(scrollToElement(liveUVAction, in: app))
        if liveUVAction.isHittable {
            liveUVAction.tap()
        }

        let backButton = navigationBackButton(in: app)
        XCTAssertTrue(scrollToHittableElement(backButton, in: app))
        backButton.tap()

        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.uvIndexCard"].exists)
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
    func testSettingsTabTapReturnsHomeWithoutPushing() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        XCTAssertFalse(navigationBackButton(in: app).exists)
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNativeTabAndNavigationChromeHideForSettingsDetail() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertFalse(app.buttons["home.streakCard"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertFalse(app.buttons["home.logManually"].exists)

        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        app.buttons["settings.section.reminders"].tap()

        XCTAssertTrue(app.staticTexts["Reminders"].waitForExistence(timeout: 5))
        XCTAssertTrue(navigationBackButton(in: app).exists)
        XCTAssertFalse(app.buttons["timeline.footer.today"].exists)
        XCTAssertFalse(app.buttons["home.historyCard"].exists)
        XCTAssertFalse(app.buttons["timeline.footer.settings"].exists)
        XCTAssertFalse(app.buttons["home.logManually"].exists)

        navigationBackButton(in: app).tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.today"].exists)
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertFalse(app.buttons["home.logManually"].exists)
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))
        XCTAssertTrue(scrollToHittableElement(app.buttons["home.logManually"], in: app))
    }

    @MainActor
    func testNativeTabShellPreservesHistoryMonthAcrossDetailPushAndPop() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_HISTORY=monthlyReview",
            "UITEST_FORCE_DARK_MODE",
            "UITEST_FORCE_INCREASE_CONTRAST"
        ])

        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        expandHistoryCalendar(in: app)
        let monthTitle = app.staticTexts["history.monthTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let currentMonth = monthTitle.label
        tapHittableElement(app.buttons["history.previousMonth"], in: app)
        XCTAssertTrue(waitForDifferentLabel(from: currentMonth, on: monthTitle))
        let selectedMonth = monthTitle.label

        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.settings"]))
        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        app.buttons["settings.section.reminders"].tap()
        XCTAssertTrue(app.staticTexts["Reminders"].waitForExistence(timeout: 5))
        navigationBackButton(in: app).tap()

        XCTAssertTrue(app.buttons["home.historyCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        XCTAssertEqual(stringValue(of: app.buttons["history.calendarToggle"]), "Expanded")
        XCTAssertTrue(waitForLabel(selectedMonth, on: monthTitle))
    }

    @MainActor
    func testHomeShowsManualLogButton() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testQuietGlassKeepsThreeNativeTabsAndLogActionInTodayContent() throws {
        let app = launchHome()
        let todayTab = app.buttons["timeline.footer.today"]
        let historyTab = app.buttons["home.historyCard"]
        let settingsTab = app.buttons["timeline.footer.settings"]
        let logToday = app.buttons["home.logManually"]

        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 3)
        XCTAssertEqual(todayTab.label, "Today")
        XCTAssertEqual(historyTab.label, "History")
        XCTAssertEqual(settingsTab.label, "Settings")
        XCTAssertEqual(todayTab.frame.midY, historyTab.frame.midY, accuracy: 8)
        XCTAssertEqual(todayTab.frame.midY, settingsTab.frame.midY, accuracy: 8)
        XCTAssertLessThan(todayTab.frame.midX, historyTab.frame.midX)
        XCTAssertLessThan(historyTab.frame.midX, settingsTab.frame.midX)
        XCTAssertTrue(todayTab.isSelected)
        XCTAssertFalse(app.tabBars.buttons["home.logManually"].exists)
        XCTAssertFalse(app.tabBars.buttons["home.streakCard"].exists)
        XCTAssertTrue(scrollToHittableElement(logToday, in: app))
        XCTAssertEqual(app.buttons.matching(identifier: "home.logManually").count, 1)
        XCTAssertLessThanOrEqual(logToday.frame.maxY, todayTab.frame.minY)
        XCTAssertGreaterThanOrEqual(logToday.frame.width, 44)
        XCTAssertGreaterThanOrEqual(logToday.frame.height, 44)
        XCTAssertTrue(logToday.isHittable)
    }

    @MainActor
    func testHomeKeepsAdvancedActionsOffSimplifiedSurface() throws {
        let app = launchHome()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.streakCard"].exists)
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertFalse(app.buttons["home.exploreToggle"].exists)
        XCTAssertFalse(app.buttons["home.uvBriefingToggle"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.uvStatus"].exists)
        XCTAssertFalse(app.otherElements["home.exploreGrid"].exists)
        XCTAssertFalse(app.buttons["home.feature.skinHealthReport"].exists)
        XCTAssertFalse(app.buttons["home.feature.productScanner"].exists)
        XCTAssertFalse(app.buttons["home.feature.automation"].exists)
    }

    @MainActor
    func testProductScannerRouteOpensManualLog() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=productScanner",
            "UITEST_CAMERA_AUTH=denied"
        ])

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["productScanner.openSettings"].exists)
        XCTAssertFalse(app.buttons["productScanner.pickPhoto"].exists)
    }

    @MainActor
    func testProductScannerPrefillOverridesUsualSPF() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=productScanner",
            "UITEST_SEED_HISTORY=manualSuggestions",
            "UITEST_MANUAL_LOG_PREFILL_SPF_70"
        ])

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        let spfRow = manualLogSPFRow(in: app)
        XCTAssertTrue(spfRow.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel("SPF 70 selected", on: spfRow))
        XCTAssertTrue(app.buttons["manualLog.spf.70"].isSelected)
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
    func testHomeKeepsLoggedStateSimpleWithHighUVOverride() throws {
        let app = launchHome(additionalArguments: ["UITEST_UV_INDEX=7", "UITEST_SEED_HISTORY=todayLogged"])
        assertHomeLoggedState(app)
        let detail = app.staticTexts["timeline.statusDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.label.contains("SPF 50"))
        XCTAssertTrue(app.buttons["home.uvIndexCard"].exists)
        XCTAssertFalse(app.buttons["home.dailyPlan.action"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.uvForecastExposureCard"].exists)
        openTodayEditor(in: app)
        XCTAssertTrue(waitForLabel("SPF 50 selected", on: manualLogSPFRow(in: app)))
        XCTAssertFalse(app.buttons["reapply.log"].exists)
        tapHittableElement(navigationBackButton(in: app), in: app)
        assertHomeLoggedState(app)
    }

    @MainActor
    func testLoggedTodayPrimaryAddsReapplicationWithRemindersOff() throws {
        let app = launchHome(additionalArguments: ["UITEST_SEED_HISTORY=todayLogged", "UITEST_CURRENT_TIME=13:00"])
        let originalTime = try XCTUnwrap(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()))
            .formatted(date: .omitted, time: .shortened)
        let reapplicationTime = try XCTUnwrap(Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date()))
            .formatted(date: .omitted, time: .shortened)

        assertHomeLoggedState(app)
        XCTAssertFalse(app.buttons["home.reapplyReminder"].exists)
        tapHittableElement(app.buttons["home.logManually"], in: app)
        XCTAssertFalse(app.buttons["reapply.log"].exists)
        XCTAssertTrue(waitForLabel("Logged at \(reapplicationTime)", on: app.staticTexts["home.todayStatus"]))
        XCTAssertTrue(app.buttons["home.undoLog"].exists)
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        XCTAssertTrue(waitForLabel("Logged, 2 applications", on: app.staticTexts["history.statusTitle"]))

        let reapplication = app.descendants(matching: .any)["history.application.reapplication"]
        let originalApplication = app.descendants(matching: .any)["history.application.application"]
        XCTAssertTrue(scrollToElement(reapplication, in: app))
        XCTAssertTrue(reapplication.label.contains(reapplicationTime))
        XCTAssertTrue(reapplication.label.contains("Reapplied"))
        XCTAssertTrue(scrollToElement(originalApplication, in: app))
        XCTAssertTrue(originalApplication.label.contains(originalTime))
        XCTAssertTrue(originalApplication.label.contains("SPF 50"))
        XCTAssertFalse(app.buttons["history.application.reapplication"].exists)

        assertSettingsTabOpens(in: app)
        expandSettingsSection("reminders", in: app)
        let reapplyToggle = app.switches["settings.reapplyToggle"]
        XCTAssertTrue(scrollToHittableElement(reapplyToggle, in: app))
        XCTAssertEqual(stringValue(of: reapplyToggle), "0")
    }

    @MainActor
    func testManualLogShowsSmartReuseSuggestions() throws {
        let app = launchHome(additionalArguments: ["UITEST_SEED_HISTORY=manualSuggestions"])
        tapHittableElement(app.buttons["home.logManually"], in: app)
        assertHomeLoggedState(app)
        openTodayEditor(in: app)
        XCTAssertTrue(waitForLabel("SPF 50 selected", on: manualLogSPFRow(in: app)))
        tapHittableElement(app.buttons["manualLog.noteSnippet.0"], in: app)
        let notesField = app.textFields["manualLog.notesField"]
        XCTAssertEqual(notesField.value as? String, "Before lunch")
        tapHittableElement(app.buttons["manualLog.logToday"], in: app)
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        XCTAssertTrue(waitForLabel("Before lunch", on: app.staticTexts["history.dayNote"]))
    }

    @MainActor
    func testHistoryDefaultsToWeekStripAndCanExpandCalendar() throws {
        let app = launchAndCompleteOnboarding()

        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        let calendarToggle = app.buttons["history.calendarToggle"]
        XCTAssertTrue(calendarToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(stringValue(of: calendarToggle), "Collapsed")
        XCTAssertTrue(app.descendants(matching: .any)["history.weekStrip"].exists)
        XCTAssertFalse(app.otherElements["history.calendarGrid"].exists)
        XCTAssertFalse(app.buttons["history.previousMonth"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["history.monthStats"].exists)
        XCTAssertTrue(app.staticTexts["history.statusTitle"].exists)

        expandHistoryCalendar(in: app)
        XCTAssertFalse(app.descendants(matching: .any)["history.weekStrip"].exists)
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["history.monthStats"], in: app, attempts: 10))

        tapHittableElement(calendarToggle, in: app)
        XCTAssertTrue(waitForValueContaining("Collapsed", on: calendarToggle))
        XCTAssertTrue(app.descendants(matching: .any)["history.weekStrip"].exists)
        XCTAssertFalse(app.otherElements["history.calendarGrid"].exists)
    }

    @MainActor
    func testInsightsBackPreservesHistorySelectionAndMonthlySummary() throws {
        let app = launchHome(additionalArguments: ["UITEST_SEED_HISTORY=achievementProgress"])
        selectHistoryDay(offset: -1, in: app)
        let selectedDate = app.staticTexts["history.selectedDate"].label
        openWeeklyInsights(in: app)
        XCTAssertFalse(app.buttons["weekly.viewFullHistory"].exists)
        tapHittableElement(navigationBackButton(in: app), in: app)
        XCTAssertTrue(app.buttons["home.historyCard"].isSelected)
        XCTAssertTrue(waitForLabel(selectedDate, on: app.staticTexts["history.selectedDate"]))
        XCTAssertEqual(stringValue(of: app.buttons["history.calendarToggle"]), "Expanded")
        XCTAssertTrue(scrollToElement(app.staticTexts["Month summary"], in: app))
        openWeeklyInsights(in: app)
        performBackSwipe(in: app)
        XCTAssertTrue(waitForLabel(selectedDate, on: app.staticTexts["history.selectedDate"]))
    }

    @MainActor
    func testHistoryCalendarSwipesToPreviousMonth() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=monthlyReview"
        ])

        expandHistoryCalendar(in: app)
        let monthTitle = app.staticTexts["history.monthTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let initialMonth = monthTitle.label

        let calendarGrid = app.otherElements["history.calendarGrid"]
        XCTAssertTrue(scrollToHittableElement(calendarGrid, in: app))
        dragCalendarGrid(calendarGrid, toward: .right)

        XCTAssertTrue(waitForDifferentLabel(from: initialMonth, on: monthTitle))
    }

    @MainActor
    func testHistoryCalendarSwipesForwardWithoutOpeningFutureMonth() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=monthlyReview"
        ])

        expandHistoryCalendar(in: app)
        let monthTitle = app.staticTexts["history.monthTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let currentMonth = monthTitle.label

        let calendarGrid = app.otherElements["history.calendarGrid"]
        XCTAssertTrue(scrollToHittableElement(calendarGrid, in: app))
        XCTAssertFalse(app.buttons["history.nextMonth"].isEnabled)
        dragCalendarGrid(calendarGrid, toward: .left)
        XCTAssertTrue(waitForLabel(currentMonth, on: monthTitle))

        dragCalendarGrid(calendarGrid, toward: .right)
        XCTAssertTrue(waitForDifferentLabel(from: currentMonth, on: monthTitle))
        dragCalendarGrid(calendarGrid, toward: .left)
        XCTAssertTrue(waitForLabel(currentMonth, on: monthTitle))
    }

    @MainActor
    func testHistoryShowsMonthlyReviewInsights() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=monthlyReview"
        ])

        expandHistoryCalendar(in: app)
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["history.legend.logged"], in: app, attempts: 8))
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["history.legend.notLogged"], in: app, attempts: 8))
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["history.legend.future"], in: app, attempts: 8))
        tapHittableElement(app.buttons["history.monthPatternsToggle"], in: app, attempts: 14)
        XCTAssertTrue(scrollToElement(app.staticTexts["Best Day"], in: app, attempts: 14))
        XCTAssertTrue(app.staticTexts["Hardest Day"].exists)
        XCTAssertTrue(app.staticTexts["Most Used SPF"].exists)
    }

    @MainActor
    func testInsightsLoggedDayIsReadOnlyAndHistoryOwnsEditing() throws {
        let app = launchHome(additionalArguments: ["UITEST_ROUTE=weeklySummary", "UITEST_SEED_HISTORY=todayLogged"])
        assertInsightsVisible(in: app)
        XCTAssertTrue(waitForLabel("1 day logged in the last 7 days", on: insightsSummary(in: app)))
        XCTAssertTrue(scrollToElement(insightsStreak(in: app), in: app))
        XCTAssertEqual(insightsStreak(in: app).label, "1-day streak")
        XCTAssertFalse(app.buttons["weekly.day.\(dayIdentifier())"].exists)
        XCTAssertFalse(app.buttons["historyEditor.save"].exists)
        tapHittableElement(navigationBackButton(in: app), in: app)
        tapHittableElement(app.buttons["history.editRecord"], in: app)
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["historyEditor.timePicker"].exists)
    }

    @MainActor
    func testHistoryDeletePreservesSelectionForBackfill() throws {
        let app = launchHistoryWithSeededRecords(route: "history")
        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(stringValue(of: app.buttons["history.calendarToggle"]), "Collapsed")

        let todayButton = app.buttons["history.day.\(dayIdentifier())"]
        tapHittableElement(todayButton, in: app)
        XCTAssertTrue(todayButton.isSelected)
        let selectedDate = app.staticTexts["history.selectedDate"].label

        XCTAssertTrue(app.staticTexts["history.statusTitle"].waitForExistence(timeout: 5))
        let deleteButton = app.buttons["history.deleteRecord"]
        XCTAssertTrue(scrollToHittableElement(deleteButton, in: app, attempts: 12))
        deleteButton.tap()
        let confirmDeleteButton = app.sheets.buttons["Delete"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 2))
        confirmDeleteButton.tap()

        XCTAssertTrue(scrollToHittableElement(app.buttons["history.backfillRecord"], in: app))
        XCTAssertTrue(app.staticTexts["history.statusTitle"].exists)
        XCTAssertEqual(app.staticTexts["history.selectedDate"].label, selectedDate)

        tapHittableElement(app.buttons["history.undoDelete"], in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["history.editRecord"], in: app))
        XCTAssertFalse(app.buttons["history.backfillRecord"].exists)
        XCTAssertFalse(app.buttons["history.undoDelete"].exists)
        XCTAssertEqual(app.staticTexts["history.selectedDate"].label, selectedDate)
    }

    @MainActor
    func testHistoryGroupedApplicationsRemainEditableWithAccessibilityText() throws {
        let app = launchHome(additionalArguments: accessibilityScorecardArguments + [
            "UITEST_ROUTE=history",
            "UITEST_SEED_HISTORY=reapplyToday",
            "UITEST_CURRENT_TIME=13:00"
        ])

        let firstApplication = app.descendants(matching: .any)["history.application.application"]
        let reapplication = app.descendants(matching: .any)["history.application.reapplication"]
        XCTAssertTrue(scrollToHittableElement(firstApplication, in: app, attempts: 12))
        XCTAssertGreaterThanOrEqual(firstApplication.frame.height, 44)
        XCTAssertFalse(firstApplication.label.isEmpty)
        XCTAssertTrue(scrollToHittableElement(reapplication, in: app, attempts: 12))
        XCTAssertGreaterThanOrEqual(reapplication.frame.height, 44)
        XCTAssertTrue(reapplication.label.contains("Reapplied"))
        XCTAssertTrue(waitForLabel("Logged, 2 applications", on: app.staticTexts["history.statusTitle"]))

        XCTAssertFalse(app.buttons["history.application.reapplication"].exists)
        tapHittableElement(app.buttons["history.editRecord"], in: app)
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))
        tapHittableElement(app.buttons["historyEditor.spf.70"], in: app)
        tapHittableElement(app.buttons["historyEditor.save"], in: app)

        XCTAssertTrue(scrollToHittableElement(reapplication, in: app, attempts: 12))
        XCTAssertTrue(reapplication.label.contains("SPF 70"))
        XCTAssertTrue(firstApplication.exists)
        XCTAssertTrue(waitForLabel("Logged, 2 applications", on: app.staticTexts["history.statusTitle"]))
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
        XCTAssertTrue(scrollToElement(app.staticTexts["recovery.conflict.summary"], in: app, attempts: 10))
        XCTAssertTrue(app.buttons["recovery.conflict.undo"].exists)
        XCTAssertTrue(app.buttons["recovery.conflict.resolve"].exists)
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

        let bottomSaveButton = app.buttons["manualLog.logToday"]
        XCTAssertTrue(scrollToHittableElement(bottomSaveButton, in: app))
        navigationBackButton(in: app).tap()

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
        XCTAssertEqual(logButton.label, "Save")
    }

    @MainActor
    func testWeeklyNotificationRouteOpensWeeklySummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        assertInsightsVisible(in: app)
    }

    @MainActor
    func testWeeklySummaryRoutePopsToHistoryThenReturnsHomeWithTodayTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        assertInsightsVisible(in: app)
        navigationBackButton(in: app).tap()
        XCTAssertTrue(app.buttons["history.calendarToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.historyCard"].isSelected)
        XCTAssertFalse(navigationBackButton(in: app).exists)
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLogTodayQuickActionOpensTodayWithoutLogging() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_SHORTCUT_TYPE=app.peyton.sunclub.log-today"
        ]
        app.launch()

        assertTodayRootVisible(in: app)
        let logButton = app.buttons["home.logManually"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 10))
        XCTAssertEqual(logButton.label, "Log sunscreen")
        XCTAssertFalse(app.buttons["manualLog.logToday"].exists)
        XCTAssertFalse(app.buttons["home.undoLog"].exists)

        tapHittableElement(logButton, in: app)
        assertHomeLoggedState(app)
        XCTAssertTrue(app.buttons["home.undoLog"].exists)
    }

    @MainActor
    func testHighUVLoggedStateKeepsReapplyReminderReachable() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_CURRENT_TIME=13:00", "UITEST_UV_INDEX=7",
            "UITEST_REAPPLY_ENABLED", "UITEST_REAPPLY_INTERVAL=120"
        ])
        tapHittableElement(app.buttons["home.logManually"], in: app)
        assertHomeLoggedState(app)
        let reminder = app.buttons["home.reapplyReminder"]
        XCTAssertTrue(scrollToHittableElement(reminder, in: app))
        XCTAssertTrue(reminder.label.contains("Reapply around"), reminder.label)
        reminder.tap()
        XCTAssertTrue(app.buttons["reapply.log"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToHittableElement(app.buttons["reapply.log"], in: app))
    }

    @MainActor
    func testWeeklySummaryShowsOnlySevenDayCountAndStreak() throws {
        let app = launchHome(additionalArguments: ["UITEST_ROUTE=weeklySummary", "UITEST_SEED_USAGE_INSIGHTS"])
        assertInsightsVisible(in: app)
        XCTAssertTrue(scrollToElement(insightsSummary(in: app), in: app))
        XCTAssertTrue(scrollToElement(insightsStreak(in: app), in: app))
        XCTAssertFalse(app.descendants(matching: .any)["weekly.nextStep"].exists)
        XCTAssertFalse(app.buttons["weekly.viewFullHistory"].exists)
        XCTAssertFalse(insightsSummary(in: app).label.contains("%"))
    }

    @MainActor
    func testAutomationXCallbackOpenRouteOpensCatalog() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_URL=\(xCallbackURL(path: "open?route=automation"))"
        ])
        XCTAssertTrue(app.staticTexts["Shortcuts & Automation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["automation.shortcuts"].exists)
        tapHittableElement(app.buttons["automation.openPermissions"], in: app)
        XCTAssertTrue(scrollToHittableElement(automationSwitch("Allow URL write actions", in: app), in: app))
        tapHittableElement(navigationBackButton(in: app), in: app)
        XCTAssertTrue(app.staticTexts["Shortcuts & Automation"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAutomationXCallbackLogTodayLogsDayWhenURLWritesAreEnabled() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL=\(xCallbackURL(path: "log-today?spf=50&notes=UITest"))"
        ]
        app.launch()

        if app.buttons["success.done"].waitForExistence(timeout: 5) {
            app.buttons["success.done"].tap()
        }
        assertHomeLoggedState(app)
    }

    @MainActor
    func testTimelineHomeIsDefaultAfterOnboarding() throws {
        let app = launchTimelineHome()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertEqual(app.buttons["timeline.footer.today"].label, "Today")
        XCTAssertEqual(app.buttons["home.historyCard"].label, "History")
        XCTAssertFalse(app.descendants(matching: .any)["timeline.dayStrip"].exists)
    }

    @MainActor
    func testTimelineHomeKeepsDefaultLogSurfaceSimple() throws {
        let app = launchTimelineHome()
        let logAction = app.buttons["home.logManually"]
        XCTAssertTrue(scrollToHittableElement(logAction, in: app, attempts: 10))
        XCTAssertEqual(logAction.label, "Log sunscreen")
        XCTAssertEqual(app.buttons.matching(identifier: "home.logManually").count, 1)
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.dailyPlan"].exists)
        XCTAssertFalse(app.buttons["home.dailyPlan.action"].exists)
        XCTAssertTrue(app.buttons["home.uvIndexCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.uvForecastExposureCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.sunExposureCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.todayStatus"].exists
            || app.staticTexts["home.todayStatus"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.morning"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.afternoon"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.evening"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.night"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.dayStrip"].exists)
        XCTAssertFalse(app.buttons["timeline.backToToday"].exists)
    }

    @MainActor
    func testTodayOpensForecastDetailWithoutChangingDate() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        let originalDate = timelineHeadline(in: app).label
        tapHittableElement(app.buttons["home.uvIndexCard"], in: app)
        XCTAssertTrue(app.descendants(matching: .any)["uvForecast.hero"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["uvForecast.hourly"], in: app))
        tapHittableElement(navigationBackButton(in: app), in: app)
        XCTAssertTrue(waitForLabel(originalDate, on: timelineHeadline(in: app)))
        assertHomeReadyForLogState(app)
    }

    @MainActor
    func testHistorySelectionDoesNotRetargetTodaysOneTapLog() throws {
        let app = launchTimelineHome(additionalArguments: ["UITEST_CURRENT_TIME=13:00"])
        selectHistoryDay(offset: -1, in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["history.backfillRecord"], in: app))
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))
        tapHittableElement(app.buttons["home.logManually"], in: app)
        assertHomeLoggedState(app)
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        XCTAssertTrue(app.buttons["history.day.\(dayIdentifier(offset: -1))"].isSelected)
        XCTAssertTrue(scrollToHittableElement(app.buttons["history.backfillRecord"], in: app))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        if !Calendar.current.isDate(yesterday, equalTo: Date(), toGranularity: .month) {
            tapHittableElement(app.buttons["history.nextMonth"], in: app)
        }
        tapHittableElement(app.buttons["history.day.\(dayIdentifier())"], in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["history.editRecord"], in: app))
    }

    @MainActor
    func testAccessibilityTextCanOpenForecastAndReturnToToday() throws {
        let app = launchTimelineHome(additionalArguments: accessibilityScorecardArguments + liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app, timeout: 15))
        tapHittableElement(app.buttons["home.uvIndexCard"], in: app)
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["uvForecast.hero"], in: app, attempts: 10))
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["uvForecast.hourly"], in: app, attempts: 10))
        XCTAssertFalse(navigationBackButton(in: app).label.isEmpty)
        tapHittableElement(navigationBackButton(in: app), in: app)
        assertHomeReadyForLogState(app)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.dayStrip"].exists)
    }

    @MainActor
    func testTodayHorizontalSwipesKeepTheCurrentDayAndLogAction() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        let headline = timelineHeadline(in: app)
        let originalDate = headline.label
        let surface = app.buttons["home.uvIndexCard"]
        XCTAssertTrue(scrollToHittableElement(surface, in: app))
        surface.swipeLeft()
        XCTAssertEqual(headline.label, originalDate)
        surface.swipeRight()
        XCTAssertEqual(headline.label, originalDate)
        assertHomeReadyForLogState(app)
        XCTAssertFalse(app.buttons["timeline.backToToday"].exists)
    }

    @MainActor
    func testHistoryFutureDayCannotOpenALogEditor() throws {
        let app = launchHome()
        XCTAssertTrue(selectNativeTab(app.buttons["home.historyCard"]))
        expandHistoryCalendar(in: app)
        let selectedDate = app.staticTexts["history.selectedDate"].label
        let tomorrow = app.buttons["history.day.\(dayIdentifier(offset: 1))"]
        XCTAssertTrue(scrollToElement(tomorrow, in: app))
        XCTAssertFalse(tomorrow.isEnabled)
        XCTAssertEqual(app.staticTexts["history.selectedDate"].label, selectedDate)
        XCTAssertFalse(app.buttons["historyEditor.save"].exists)
        XCTAssertTrue(scrollToHittableElement(app.buttons["history.backfillRecord"], in: app))
    }

    @MainActor
    func testHistoryAfterMidnightCanLogYesterdayWithoutLoggingToday() throws {
        let app = launchTimelineHome(additionalArguments: ["UITEST_CURRENT_TIME=00:30"])
        selectHistoryDay(offset: -1, in: app)
        let selectedDate = app.staticTexts["history.selectedDate"].label
        tapHittableElement(app.buttons["history.backfillRecord"], in: app)
        let save = app.buttons["historyEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled)
        XCTAssertEqual(app.staticTexts["historyEditor.timestamp"].label, selectedDate)
        XCTAssertFalse(app.datePickers["historyEditor.datePicker"].exists)
        XCTAssertFalse(app.buttons["historyEditor.area.Face"].isSelected)
        XCTAssertFalse(app.buttons["historyEditor.area.Neck"].isSelected)
        tapHittableElement(save, in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["history.editRecord"], in: app))
        XCTAssertTrue(waitForLabel(selectedDate, on: app.staticTexts["history.selectedDate"]))
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))
        assertHomeReadyForLogState(app)
    }

    @MainActor
    func testHistoryWeeklyInsightsPopsBackToHistory() throws {
        let app = launchTimelineHome()
        openWeeklyInsights(in: app)
        performBackSwipe(in: app)
        XCTAssertTrue(app.buttons["history.calendarToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.historyCard"].isSelected)
        XCTAssertFalse(navigationBackButton(in: app).exists)
    }
}
