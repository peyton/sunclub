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
        XCTAssertFalse(app.buttons["accountabilityOnboarding.next"].exists)
        XCTAssertFalse(app.buttons["home.accountabilityNudge.setup"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.dailyPlan"].exists)
        XCTAssertTrue(app.buttons["home.dailyPlan.action"].exists)
    }

    @MainActor
    func testOnboardingChooseCityOpensAppleMapsSearch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipLocation"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipLocation"].tap()

        XCTAssertTrue(app.textFields["citySearch.query"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["citySearch.submit"].exists)
        XCTAssertTrue(app.buttons["citySearch.cancel"].exists)
    }

    @MainActor
    func testHomeRoutesToWeeklySummaryAndSettings() throws {
        let app = launchHome()

        app.buttons["home.streakCard"].tap()
        assertInsightsVisible(in: app)

        app.terminate()
        let relaunchedApp = XCUIApplication()
        relaunchedApp.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        relaunchedApp.launch()

        XCTAssertTrue(relaunchedApp.staticTexts["Settings"].waitForExistence(timeout: 5))
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
    func testManualLogSuccessReturnsHome() throws {
        let app = launchHome()

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()
        assertHomeLoggedState(app)
        XCTAssertTrue(app.buttons["home.sunscreenLogCard"].exists)
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
        XCTAssertTrue(app.buttons["settings.section.progress"].exists)
        XCTAssertTrue(app.buttons["settings.section.data"].exists)
        XCTAssertTrue(app.buttons["settings.section.automation"].exists)
        XCTAssertTrue(app.buttons["settings.section.advanced"].exists)
        XCTAssertFalse(app.staticTexts["App Preferences"].exists)
        XCTAssertFalse(app.buttons["settings.reference.appearance"].exists)
        XCTAssertFalse(app.buttons["settings.reference.units"].exists)

        assertSettingsReminderControls(in: app)
        assertSettingsNotificationControls(in: app)
        assertSettingsProgressControls(in: app)
        assertSettingsDataControls(in: app)
        assertSettingsAutomationControls(in: app)
        assertSettingsAdvancedControls(in: app)
        assertSettingsHelpControls(in: app)
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

        let backButton = app.buttons["screen.back"]
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
        XCTAssertFalse(app.buttons["screen.back"].exists)
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNativeTabAndNavigationChromeHideForSettingsDetail() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=settings"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline.footer.today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(app.buttons["home.streakCard"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertTrue(app.buttons["home.logManually"].exists)

        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        app.buttons["settings.section.reminders"].tap()

        XCTAssertTrue(app.navigationBars["Sunscreen & Reminders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["screen.back"].exists)
        XCTAssertFalse(app.buttons["timeline.footer.today"].exists)
        XCTAssertFalse(app.buttons["home.logManually"].exists)

        app.buttons["screen.back"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline.footer.today"].exists)
        XCTAssertTrue(app.buttons["home.logManually"].exists)
    }

    @MainActor
    func testNativeTabShellPreservesHistoryMonthAcrossDetailPushAndPop() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_HISTORY=monthlyReview",
            "UITEST_FORCE_DARK_MODE",
            "UITEST_FORCE_INCREASE_CONTRAST"
        ])

        app.buttons["home.historyCard"].tap()
        let monthTitle = app.staticTexts["history.monthTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        let currentMonth = monthTitle.label
        app.buttons["history.previousMonth"].tap()
        XCTAssertTrue(waitForDifferentLabel(from: currentMonth, on: monthTitle))
        let selectedMonth = monthTitle.label

        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.settings"]))
        XCTAssertTrue(app.buttons["settings.section.reminders"].waitForExistence(timeout: 5))
        app.buttons["settings.section.reminders"].tap()
        XCTAssertTrue(app.navigationBars["Sunscreen & Reminders"].waitForExistence(timeout: 5))
        app.buttons["screen.back"].tap()

        XCTAssertTrue(app.buttons["home.historyCard"].waitForExistence(timeout: 5))
        app.buttons["home.historyCard"].tap()
        XCTAssertTrue(waitForLabel(selectedMonth, on: monthTitle))
    }

    @MainActor
    func testHomeShowsManualLogButton() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLiquidGlassTabBarKeepsLogTodayInTrailingTabRow() throws {
        let app = launchHome()
        let timelineTab = app.buttons["timeline.footer.today"]
        let settingsTab = app.buttons["timeline.footer.settings"]
        let logToday = app.buttons["home.logManually"]

        XCTAssertTrue(timelineTab.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        XCTAssertEqual(
            logToday.frame.midY,
            timelineTab.frame.midY,
            accuracy: 8,
            "Expected Log Today and the navigation tabs to share one bottom row."
        )
        XCTAssertGreaterThan(
            logToday.frame.minX - settingsTab.frame.maxX,
            8,
            "Expected visible separation between the navigation group and Log Today."
        )
        XCTAssertGreaterThanOrEqual(logToday.frame.height, 44)
        XCTAssertTrue(logToday.isHittable)
    }

    @MainActor
    func testHomeKeepsAdvancedActionsOffSimplifiedSurface() throws {
        let app = launchHome()

        XCTAssertTrue(app.buttons["home.streakCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertFalse(app.buttons["home.exploreToggle"].exists)
        XCTAssertFalse(app.buttons["home.uvBriefingToggle"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.uvStatus"].exists)
        XCTAssertFalse(app.otherElements["home.exploreGrid"].exists)
        XCTAssertFalse(app.buttons["home.feature.friends"].exists)
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
        XCTAssertTrue(waitForValueContaining("70", on: spfRow))
        XCTAssertFalse((spfRow.value as? String ?? "").contains("50"))
    }

    @MainActor
    func testHomeKeepsAccountabilityOffP0Settings() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_RESET_ACCOUNTABILITY",
            "UITEST_SEED_HISTORY=achievementProgress"
        ])

        let hasPrimaryHomeAction = app.buttons["home.logManually"].waitForExistence(timeout: 5)
            || app.buttons["home.sunscreenLogCard"].waitForExistence(timeout: 2)
        XCTAssertTrue(hasPrimaryHomeAction)
        XCTAssertFalse(app.buttons["home.accountabilityNudge.setup"].exists)
        XCTAssertFalse(app.buttons["home.accountabilityNudge.dismiss"].exists)
        XCTAssertTrue(scrollToHittableElement(app.buttons["timeline.footer.settings"], in: app))

        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.settings"]))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.sharing"].exists)
    }

    @MainActor
    func testSeededAccountabilityDoesNotSurfaceFriendsInP0() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_ACCOUNTABILITY_FRIEND"
        ])

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["home.accountabilityCard"].exists)
        XCTAssertFalse(app.buttons["home.accountabilityAction"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.accountabilityFriendStrip"].exists)
        XCTAssertFalse(app.otherElements["home.exploreGrid"].exists)

        XCTAssertTrue(scrollToHittableElement(app.buttons["timeline.footer.settings"], in: app))
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.settings"]))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.sharing"].exists)
        XCTAssertFalse(app.buttons["friends.activate"].exists)
    }

    @MainActor
    func testActiveAccountabilityDoesNotSurfaceSetupInP0() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_ACCOUNTABILITY_ACTIVE"
        ])

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["home.accountabilityCard"].exists)
        XCTAssertFalse(app.staticTexts["Bring in backup"].exists)
        XCTAssertFalse(app.buttons["home.accountabilityAction"].exists)
        XCTAssertTrue(scrollToHittableElement(app.buttons["timeline.footer.settings"], in: app))

        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.settings"]))
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.sharing"].exists)
        XCTAssertFalse(app.buttons["friends.activate"].exists)
    }

    @MainActor
    func testFriendsRouteIsQuarantinedToSettings() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=friends",
            "UITEST_SEED_ACCOUNTABILITY_FRIEND"
        ])

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["friends.activate"].exists)
        XCTAssertFalse(app.buttons["friends.add.toggle"].exists)
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
        XCTAssertTrue(app.buttons["onboarding.skipUV"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipUV"].tap()
        XCTAssertTrue(app.buttons["onboarding.enableNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.enableNotifications"].tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["friends.activate"].exists)
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
        let app = launchHome(additionalArguments: [
            "UITEST_UV_INDEX=7",
            "UITEST_SEED_HISTORY=todayLogged"
        ])

        let todayStatus = app.staticTexts["home.todayStatus"]
        XCTAssertTrue(todayStatus.waitForExistence(timeout: 10))
        XCTAssertEqual(todayStatus.label, "Sunscreen Logged")

        let detail = app.staticTexts["timeline.statusDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.label.contains("SPF") || detail.label.contains("Optional"))
        XCTAssertFalse(app.descendants(matching: .any)["home.uvStatus"].exists)
        XCTAssertTrue(app.buttons["home.uvIndexCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.dailyPlan"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.uvForecastExposureCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.sunExposureCard"].exists)
    }

    @MainActor
    func testManualLogShowsSmartReuseSuggestions() throws {
        let app = launchHome(additionalArguments: ["UITEST_SEED_HISTORY=manualSuggestions"])

        app.buttons["home.logManually"].tap()

        let spfRow = manualLogSPFRow(in: app)
        XCTAssertTrue(spfRow.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValueContaining("50", on: spfRow))
        XCTAssertTrue(scrollToElement(app.buttons["manualLog.noteSnippet.0"], in: app))
        app.buttons["manualLog.noteSnippet.0"].tap()

        let notesField = app.textFields["manualLog.notesField"]
        XCTAssertEqual(notesField.value as? String, "Before lunch")
    }

    @MainActor
    func testHistoryViewShowsCalendar() throws {
        let app = launchAndCompleteOnboarding()

        let historyCard = app.buttons["home.historyCard"]
        XCTAssertTrue(
            scrollToHittableElement(historyCard, in: app, attempts: 10),
            "Expected the History footer action to remain reachable below the contextual Home card."
        )
        historyCard.tap()
        XCTAssertTrue(
            scrollToElement(app.staticTexts["history.monthTitle"], in: app, attempts: 10),
            "Expected the monthly calendar to remain reachable below the History summary."
        )
        XCTAssertTrue(app.buttons["history.previousMonth"].exists)
    }

    @MainActor
    func testWeeklySummaryOpensFullHistoryWithMonthlySummary() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_SEED_HISTORY=achievementProgress"
        ])

        app.buttons["home.streakCard"].tap()
        assertInsightsVisible(in: app)
        XCTAssertTrue(scrollToHittableElement(app.buttons["weekly.viewFullHistory"], in: app))

        app.buttons["weekly.viewFullHistory"].tap()
        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["Month summary"], in: app))
        XCTAssertFalse(app.otherElements["history.streakContext"].exists)
        XCTAssertFalse(app.buttons["screen.back"].exists)

        app.buttons["home.streakCard"].tap()
        assertInsightsVisible(in: app)
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
        dragCalendarGrid(calendarGrid, toward: .right)

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

        XCTAssertTrue(app.staticTexts["history.monthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.staticTexts["Logged"], in: app, attempts: 8))
        XCTAssertTrue(scrollToElement(app.staticTexts["Not logged"], in: app, attempts: 8))
        XCTAssertTrue(scrollToElement(app.staticTexts["Future"], in: app, attempts: 8))
        XCTAssertTrue(scrollToElement(app.staticTexts["Best Day"], in: app, attempts: 14))
        XCTAssertTrue(app.staticTexts["Hardest Day"].exists)
        XCTAssertTrue(app.staticTexts["Most Used SPF"].exists)
    }

    @MainActor
    func testWeeklySummaryAppliedDayOpensHistoryEditor() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=weeklySummary",
            "UITEST_SEED_HISTORY=todayLogged"
        ])

        assertInsightsVisible(in: app)
        let todayButton = app.buttons["weekly.day.\(dayIdentifier())"]
        XCTAssertTrue(todayButton.waitForExistence(timeout: 5))
        todayButton.tap()

        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.datePickers["historyEditor.timePicker"].exists)
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
        XCTAssertTrue(scrollToHittableElement(deleteButton, in: app, attempts: 12))
        deleteButton.tap()
        let confirmDeleteButton = app.sheets.buttons["Delete"]
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 2))
        confirmDeleteButton.tap()

        XCTAssertTrue(scrollToElement(app.buttons["history.backfillRecord"], in: app))
        XCTAssertTrue(app.staticTexts["history.statusTitle"].exists)
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
        let topSaveButton = app.buttons["manualLog.saveTop"]
        XCTAssertTrue(
            bottomSaveButton.waitForExistence(timeout: 5) || topSaveButton.waitForExistence(timeout: 2)
        )
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
        XCTAssertEqual(logButton.label, "Save Log")
    }

    @MainActor
    func testWeeklyNotificationRouteOpensWeeklySummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        assertInsightsVisible(in: app)
    }

    @MainActor
    func testWeeklySummaryTabRouteReturnsHomeWithTodayTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING", "UITEST_ROUTE=weeklySummary"]
        app.launch()

        assertInsightsVisible(in: app)
        XCTAssertFalse(app.buttons["screen.back"].exists)
        XCTAssertTrue(selectNativeTab(app.buttons["timeline.footer.today"]))

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

        XCTAssertTrue(
            app.buttons["manualLog.logToday"].waitForExistence(timeout: 10),
            "Expected the home-screen quick action to open manual logging."
        )
        let backButton = app.buttons["screen.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        assertTodayRootVisible(in: app)
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

        let detail = app.staticTexts["timeline.statusDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.label.contains("Reapply in"))
    }

    @MainActor
    func testWeeklySummaryShowsRoutineInsights() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_ROUTE=weeklySummary",
            "UITEST_SEED_USAGE_INSIGHTS"
        ]
        app.launch()

        let consistency = app.staticTexts["weekly.summaryValue"]
        XCTAssertTrue(scrollToElement(consistency, in: app))
        XCTAssertTrue(consistency.label.hasSuffix("%"))

        let nextStep = app.descendants(matching: .any)["weekly.nextStep"]
        XCTAssertTrue(scrollToElement(nextStep, in: app))
    }

    @MainActor
    func testAutomationXCallbackOpenRouteOpensCatalog() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL=\(xCallbackURL(path: "open?route=automation"))"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Shortcuts"].waitForExistence(timeout: 5))
        XCTAssertTrue(automationElement("automation.hero", in: app).exists)
        XCTAssertTrue(scrollToElement(automationSwitch("Allow URL write actions", in: app), in: app))
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
        XCTAssertEqual(app.buttons["timeline.footer.today"].label, "Timeline")
        XCTAssertEqual(app.buttons["home.historyCard"].label, "History")
        XCTAssertTrue(app.otherElements["timeline.dayStrip"].exists
            || app.scrollViews["timeline.dayStrip"].exists
            || app.descendants(matching: .any)["timeline.dayStrip"].exists)
    }

    @MainActor
    func testTimelineHomeKeepsDefaultLogSurfaceSimple() throws {
        let app = launchTimelineHome()
        let contextualAction = app.buttons["home.logManually"]
        XCTAssertTrue(contextualAction.waitForExistence(timeout: 5))
        XCTAssertTrue(contextualAction.isHittable)
        XCTAssertEqual(contextualAction.label, "Log Today")
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.dailyPlan"].exists)
        XCTAssertTrue(app.buttons["home.dailyPlan.action"].exists)
        XCTAssertTrue(app.buttons["home.uvIndexCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.uvForecastExposureCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.sunExposureCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.todayStatus"].exists
            || app.staticTexts["home.todayStatus"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.morning"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.afternoon"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.evening"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.night"].exists)
    }

    @MainActor
    func testTimelineFutureDayShowsTomorrowForecast() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        let tomorrowIdentifier = "timeline.day.\(dayIdentifier(offset: 1))"
        let tomorrowChip = timelineDayChip(tomorrowIdentifier, in: app, direction: .future)
        XCTAssertTrue(tomorrowChip.exists)
        tomorrowChip.tap()

        let headline = timelineHeadline(in: app)
        XCTAssertTrue(headline.waitForExistence(timeout: 3))
        XCTAssertEqual(headline.label, weekdayHeadline(offset: 1))
        XCTAssertTrue(app.staticTexts["UV Forecast"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["timeline.forecast.part.afternoon"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.morning"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.evening"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.night"].exists)
        XCTAssertTrue(app.buttons["timeline.backToToday"].exists)

        headline.tap()
        XCTAssertTrue(waitForLabelPrefix("Today,", on: headline))
    }

    @MainActor
    func testTimelineFutureManualLogActionFallsBackToToday() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        let tomorrowIdentifier = "timeline.day.\(dayIdentifier(offset: 1))"
        let tomorrowChip = timelineDayChip(tomorrowIdentifier, in: app, direction: .future)
        XCTAssertTrue(tomorrowChip.exists)
        tomorrowChip.tap()

        let headline = timelineHeadline(in: app)
        XCTAssertTrue(waitForLabel(weekdayHeadline(offset: 1), on: headline))
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 3))
        app.buttons["home.logManually"].tap()

        let saveButton = app.buttons["manualLog.logToday"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["manualLog.validation"].exists)
        let timestamp = app.staticTexts["manualLog.timestamp"]
        XCTAssertTrue(timestamp.waitForExistence(timeout: 3))
        XCTAssertTrue(timestamp.label.hasPrefix("Today,"))
    }

    @MainActor
    func testTimelineAccessibilityTextCanBrowseFutureForecast() throws {
        let app = launchTimelineHome(additionalArguments: accessibilityScorecardArguments + liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app, timeout: 15))
        let tomorrowIdentifier = "timeline.day.\(dayIdentifier(offset: 1))"
        let tomorrowRow = app.descendants(matching: .any)[tomorrowIdentifier]
        let timelineScroll = app.scrollViews["timeline.scroll"]
        XCTAssertTrue(timelineScroll.waitForExistence(timeout: 5))
        XCTAssertTrue(
            scrollToHittableElementByPosition(
                timelineHeadline(in: app),
                in: app,
                attempts: 160,
                scrollSurface: timelineScroll,
                directionWhenMissing: .scrollDown,
                distance: 0.6
            ),
            "Expected the timeline to return to its top before browsing future days."
        )
        XCTAssertTrue(
            scrollToHittableElementByPosition(
                tomorrowRow,
                in: app,
                attempts: 60,
                scrollSurface: timelineScroll
            ),
            "Expected tomorrow's forecast row to remain operable."
        )
        tomorrowRow.tap()

        let headline = timelineHeadline(in: app)
        XCTAssertTrue(waitForLabel(weekdayHeadline(offset: 1), on: headline))
        XCTAssertTrue(app.buttons["timeline.backToToday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["timeline.forecast.part.afternoon"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.morning"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.evening"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.night"].exists)
    }

    @MainActor
    func testTimelineScreenSwipeMovesSelectedDay() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        let headline = timelineHeadline(in: app)
        XCTAssertTrue(waitForLabelPrefix("Today,", on: headline))
        let swipeSurface = app.buttons["home.uvIndexCard"]
        XCTAssertTrue(
            scrollToHittableElement(swipeSurface, in: app, attempts: 6),
            "Expected the compact UV card to remain reachable before swiping the timeline."
        )
        app.swipeUp()
        XCTAssertTrue(swipeSurface.isHittable)

        dragTimelineBody(swipeSurface, direction: .future, verticalPosition: 0.5)
        XCTAssertTrue(waitForLabelNotPrefix("Today,", on: headline))
        XCTAssertTrue(app.buttons["timeline.backToToday"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["home.uvIndexCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.uvForecastExposureCard"].exists)

        let futureSwipeSurface = app.descendants(matching: .any)["timeline.contentPager"]
        XCTAssertTrue(futureSwipeSurface.waitForExistence(timeout: 5))
        dragTimelineBody(futureSwipeSurface, direction: .past)
        XCTAssertTrue(waitForLabelPrefix("Today,", on: headline))
    }

    @MainActor
    func testTimelineFutureScrollStopsAtLastForecastDay() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments)
        XCTAssertTrue(waitForVerifiedUVForecast(in: app))
        let lastForecastIdentifier = "timeline.day.\(dayIdentifier(offset: 6))"
        let beyondForecastIdentifier = "timeline.day.\(dayIdentifier(offset: 7))"
        let lastForecastChip = timelineDayChip(lastForecastIdentifier, in: app, direction: .future)

        XCTAssertTrue(lastForecastChip.exists)
        XCTAssertFalse(app.descendants(matching: .any)[beyondForecastIdentifier].exists)

        let headline = timelineHeadline(in: app)
        lastForecastChip.tap()
        XCTAssertTrue(waitForLabel(weekdayHeadline(offset: 6), on: headline))

        let pager = app.descendants(matching: .any)["timeline.contentPager"]
        XCTAssertTrue(pager.waitForExistence(timeout: 5))
        dragTimelineBody(pager, direction: .future)
        dragTimelineBody(pager, direction: .future)

        XCTAssertTrue(waitForLabel(weekdayHeadline(offset: 6), on: headline, timeout: 2))
        XCTAssertFalse(waitForLabel(weekdayHeadline(offset: 7), on: headline, timeout: 1))
    }

    @MainActor
    func testTimelineAfterMidnightContextualTabActionReturnsToTodayLog() throws {
        let app = launchTimelineHome(additionalArguments: ["UITEST_CURRENT_TIME=00:30"])
        let yesterdayIdentifier = "timeline.day.\(dayIdentifier(offset: -1))"
        let yesterdayChip = timelineDayChip(yesterdayIdentifier, in: app, direction: .past)
        XCTAssertTrue(yesterdayChip.exists)
        yesterdayChip.tap()

        let headline = timelineHeadline(in: app)
        XCTAssertTrue(headline.waitForExistence(timeout: 3))
        XCTAssertEqual(headline.label, weekdayHeadline(offset: -1))
        let selectedStatus = app.staticTexts["timeline.dayStatus"]
        XCTAssertTrue(selectedStatus.waitForExistence(timeout: 3))
        XCTAssertEqual(selectedStatus.label, "No sunscreen logged")
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.morning"].exists)
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 3))
        app.buttons["home.logManually"].tap()

        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["manualLog.logToday"].label, "Save Log")
    }

    @MainActor
    func testTimelineWeeklyPillOpensWeeklySummary() throws {
        let app = launchTimelineHome()
        let weeklyPill = app.buttons["home.streakCard"]
        XCTAssertTrue(weeklyPill.waitForExistence(timeout: 5))
        weeklyPill.tap()
        assertInsightsVisible(in: app)
    }
}
