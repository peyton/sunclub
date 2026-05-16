import XCTest
import UIKit

final class SunclubUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func assertHomeReadyForLogState(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let timelineHeadline = timelineHeadline(in: app)
        let hasTimelinePrompt = timelineHeadline.waitForExistence(timeout: 5)
            && timelineHeadline.label.hasPrefix("Today,")
        XCTAssertTrue(
            hasTimelinePrompt && app.buttons["home.logManually"].exists,
            "Expected timeline ready-to-log state.",
            file: file,
            line: line
        )
    }

    private func assertHomeLoggedState(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let timelineStatus = app.staticTexts["home.todayStatus"]
        let loggedCard = app.buttons["home.sunscreenLogCard"]
        let legacyLoggedAction = app.buttons["home.loggedPrimaryAction"]
        let hasLoggedAction = loggedCard.waitForExistence(timeout: 5)
            || legacyLoggedAction.exists
        let hasTimelineLoggedState = timelineStatus.waitForExistence(timeout: 5)
            && timelineStatus.label == "Sunscreen Logged"
            && hasLoggedAction
        XCTAssertTrue(
            hasTimelineLoggedState,
            "Expected timeline logged state.",
            file: file,
            line: line
        )
    }

    private func timelineHeadline(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["timeline.headline"]
    }

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
    }

    @MainActor
    func testOnboardingCanSkipNotifications() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.buttons["welcome.getStarted"].waitForExistence(timeout: 5))
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipLocation"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipLocation"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipNotifications"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
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
    func testHomeUVCardOpensForecastDetail() throws {
        let app = launchHome()

        XCTAssertTrue(app.buttons["home.uvIndexCard"].waitForExistence(timeout: 5))
        app.buttons["home.uvIndexCard"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["uvForecast.hero"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["uvForecast.hourly"].exists)
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
        XCTAssertTrue(scrollToElement(app.buttons["privacy.deleteHistory"], in: app))

        app.buttons["privacy.deleteHistory"].tap()
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

        XCTAssertTrue(app.buttons["timeline.footer.today"].waitForExistence(timeout: 5))
        app.buttons["timeline.footer.today"].tap()
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
        XCTAssertTrue(app.buttons["timeline.footer.today"].exists)
        app.buttons["timeline.footer.today"].tap()

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(waitForLabel("History entries: 1", on: exportApp.staticTexts["settings.backupRecordCount"]))
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
    func testHomeShowsManualLogButton() throws {
        let app = launchHome()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
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

        app.buttons["timeline.footer.settings"].tap()
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

        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["timeline.footer.settings"].exists)
        XCTAssertTrue(app.buttons["home.streakCard"].exists)
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(timelineHeadline(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToHittableElement(app.buttons["timeline.footer.settings"], in: app, attempts: 10), "Expected Settings footer to remain reachable with accessibility settings enabled.")

        app.buttons["timeline.footer.settings"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5), "Expected Settings to open from the tab footer.")
        XCTAssertFalse(app.buttons["settings.sharing"].exists)
        expandSettingsSection("progress", in: app)
        let reapplyToggle = app.switches["settings.reapplyToggle"]
        XCTAssertTrue(scrollToHittableElement(reapplyToggle, in: app, attempts: 10), "Expected the reapply toggle to be reachable in accessibility mode.")
        if stringValue(of: reapplyToggle) != "1" {
            reapplyToggle.tap()
        }
        XCTAssertTrue(scrollToElement(app.buttons["settings.reapplyInterval.120"], in: app, attempts: 10), "Expected enabled reapply settings to show interval controls.")

        XCTAssertTrue(app.buttons["screen.back"].waitForExistence(timeout: 5), "Expected Settings detail back button after editing reapply settings.")
        app.buttons["screen.back"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5), "Expected to return to the Settings tab root.")
        XCTAssertTrue(app.buttons["timeline.footer.today"].waitForExistence(timeout: 5), "Expected Today tab footer to remain reachable from Settings.")
        app.buttons["timeline.footer.today"].tap()
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5), "Expected Today tab home action after leaving Settings.")

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5), "Expected manual log action to remain reachable in accessibility mode.")
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

        app.buttons["timeline.footer.settings"].tap()
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
        app.buttons["timeline.footer.settings"].tap()
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

        app.buttons["timeline.footer.settings"].tap()
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
        XCTAssertTrue(app.buttons["onboarding.skipLocation"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipLocation"].tap()
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
        XCTAssertTrue(todayStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(todayStatus.label, "Sunscreen Logged")

        let detail = app.staticTexts["timeline.statusDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.label.contains("SPF") || detail.label.contains("Optional"))
        XCTAssertFalse(app.descendants(matching: .any)["home.uvStatus"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.uvForecastExposureCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.sunExposureCard"].exists)
    }

    @MainActor
    func testManualLogFlowReturnsHomeLogged() throws {
        let app = launchHome()

        app.buttons["home.logManually"].tap()
        XCTAssertTrue(app.buttons["manualLog.logToday"].waitForExistence(timeout: 5))
        app.buttons["manualLog.logToday"].tap()

        assertHomeLoggedState(app)
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

        app.buttons["home.historyCard"].tap()
        XCTAssertTrue(scrollToElement(app.staticTexts["history.monthTitle"], in: app))
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
        XCTAssertTrue(scrollToHittableElement(deleteButton, in: app))
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

        app.buttons["historyEditor.spf.70"].tap()
        app.buttons["historyEditor.save"].tap()

        XCTAssertTrue(waitForLabel("SPF 70", on: app.staticTexts["historyHarness.spf"]))
    }

    @MainActor
    func testHistoryCanBackfillMissedDay() throws {
        let app = launchHistoryWithSeededRecords(route: "historyBackfillTwoDaysAgo")
        XCTAssertTrue(app.buttons["historyEditor.save"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel("SPF 30 selected", on: app.staticTexts["historyEditor.spfState"]))

        app.buttons["historyEditor.spf.50"].tap()
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
        XCTAssertTrue(app.buttons["timeline.footer.today"].waitForExistence(timeout: 5))
        app.buttons["timeline.footer.today"].tap()

        assertHomeLoggedState(app)

        let streakCard = app.buttons["home.streakCard"]
        XCTAssertTrue(streakCard.waitForExistence(timeout: 5), "Expected streak affordance after undo.")
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
    func testReapplyCheckInFlowLogsCompletionAndReturnsHome() throws {
        let app = launchHome(additionalArguments: [
            "UITEST_ROUTE=reapplyCheckIn",
            "UITEST_SEED_HISTORY=todayLogged",
            "UITEST_REAPPLY_ENABLED"
        ])

        XCTAssertTrue(app.buttons["reapply.log"].waitForExistence(timeout: 5))
        app.buttons["reapply.log"].tap()

        assertHomeLoggedState(app)
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
        app.buttons["timeline.footer.today"].tap()

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
    func testWidgetLogTodayURLShowsSuccessUpdatesHomeAndOffersAddDetails() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "UITEST_MODE",
            "UITEST_COMPLETE_ONBOARDING",
            "UITEST_URL=\(widgetURL(path: "log-today"))"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["success.title"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.historyCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["home.uvForecastExposureCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["home.sunExposureCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.todayStatus"].exists
            || app.staticTexts["home.todayStatus"].exists)
        XCTAssertTrue(app.staticTexts["Log"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.forecast.part.morning"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.forecast.part.afternoon"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["timeline.forecast.part.evening"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["timeline.forecast.part.night"].exists)
    }

    @MainActor
    func testTimelineFutureDayShowsTomorrowForecast() throws {
        let app = launchTimelineHome(additionalArguments: liveTimelineForecastArguments)
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
        let tomorrowIdentifier = "timeline.day.\(dayIdentifier(offset: 1))"
        let tomorrowRow = app.buttons[tomorrowIdentifier]

        XCTAssertTrue(tomorrowRow.waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["home.logManually"].waitForExistence(timeout: 5))
        let headline = timelineHeadline(in: app)
        XCTAssertTrue(waitForLabelPrefix("Today,", on: headline))
        let swipeSurface = app.descendants(matching: .any)["home.uvForecastExposureCard"]
        XCTAssertTrue(swipeSurface.waitForExistence(timeout: 5))

        dragTimelineBody(swipeSurface, direction: .future)
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
    func testTimelineAfterMidnightManualLogUsesSelectedDayContext() throws {
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
        XCTAssertTrue(app.descendants(matching: .any)["timeline.forecast.part.morning"].exists)
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
    private func launchTimelineHome(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_MODE", "UITEST_COMPLETE_ONBOARDING"] + additionalArguments
        app.launch()
        return app
    }

    private var liveTimelineForecastArguments: [String] {
        [
            "UITEST_CURRENT_TIME=13:00",
            "UITEST_LIVE_UV_ENABLED",
            "UITEST_LIVE_UV_AUTH=always",
            "UITEST_LIVE_UV_INDEX=7",
            "UITEST_LIVE_UV_PEAK_INDEX=10"
        ]
    }

    private var accessibilityScorecardArguments: [String] {
        [
            "UITEST_FORCE_DARK_MODE",
            "UITEST_FORCE_ACCESSIBILITY_TEXT",
            "UITEST_FORCE_REDUCE_MOTION",
            "UITEST_FORCE_DIFFERENTIATE_WITHOUT_COLOR",
            "UITEST_FORCE_INCREASE_CONTRAST"
        ]
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
        let scheme = automationScheme
        return "\(scheme)://widget/\(path)"
    }

    private func automationURL(path: String) -> String {
        "\(automationScheme)://automation/\(path)"
    }

    private func xCallbackURL(path: String) -> String {
        "\(automationScheme)://x-callback-url/\(path)"
    }

    private func automationElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func automationSwitch(_ label: String, in app: XCUIApplication) -> XCUIElement {
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

    private var automationScheme: String {
        Bundle.main.object(forInfoDictionaryKey: "SunclubURLScheme") as? String ?? "sunclub-dev"
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
        let scheme = automationScheme
        return "\(scheme)://accountability/invite?code=\(encodedCode)"
    }

    @discardableResult
    @MainActor
    private func completeOnboarding(in app: XCUIApplication) -> XCUIApplication {
        app.buttons["welcome.getStarted"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipLocation"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipLocation"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipNotifications"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skipNotifications"].tap()

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
    private func waitForValueContaining(_ text: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func manualLogSPFRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["manualLog.spfRow"]
    }

    @MainActor
    private func waitForLabelPrefix(_ prefix: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func waitForLabelNotPrefix(_ prefix: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "NOT label BEGINSWITH %@", prefix)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func assertInsightsVisible(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.staticTexts["Insights"].waitForExistence(timeout: 5),
            "Expected the Insights tab root.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertTodayRootVisible(
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
    private func waitForAnyExistingElement(_ elements: [XCUIElement], timeout: TimeInterval = 5) -> Bool {
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
    private func waitForDifferentLabel(from label: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label != %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func dragCalendarGrid(_ calendarGrid: XCUIElement, toward direction: CalendarGridDragDirection) {
        let startX = direction == .left ? 0.88 : 0.12
        let endX = direction == .left ? 0.12 : 0.88
        let start = calendarGrid.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5))
        let end = calendarGrid.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: end)
    }

    private func dayIdentifier(offset: Int = 0) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return Self.dayIdentifierFormatter.string(from: day)
    }

    private func weekdayHeadline(offset: Int) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        let dateText: String
        if calendar.isDate(day, equalTo: today, toGranularity: .year) {
            dateText = day.formatted(.dateTime.month(.wide).day())
        } else {
            dateText = day.formatted(.dateTime.month(.wide).day().year())
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
    private func timelineDayChip(
        _ identifier: String,
        in app: XCUIApplication,
        direction: TimelineDayScrollDirection
    ) -> XCUIElement {
        let chip = app.descendants(matching: .any)[identifier]
        if chip.waitForExistence(timeout: 2) {
            return chip
        }

        let strip = app.descendants(matching: .any)["timeline.dayStrip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5), "Expected timeline day strip to exist.")

        for _ in 0..<6 {
            dragTimelineStrip(strip, direction: direction)
            if chip.waitForExistence(timeout: 1) {
                return chip
            }
        }

        return chip
    }

    @MainActor
    private func dragTimelineStrip(_ strip: XCUIElement, direction: TimelineDayScrollDirection) {
        let startX: CGFloat = direction == .future ? 0.82 : 0.18
        let endX: CGFloat = direction == .future ? 0.18 : 0.82
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5))
        let end = strip.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    @MainActor
    private func dragTimelineBody(_ body: XCUIElement, direction: TimelineDayScrollDirection) {
        let startX: CGFloat = direction == .future ? 0.82 : 0.18
        let endX: CGFloat = direction == .future ? 0.18 : 0.82
        let start = body.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.12))
        let end = body.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: 0.12))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private static let dayIdentifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    @MainActor
    private func assertSettingsReminderControls(in app: XCUIApplication) {
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
    private func assertSettingsNotificationControls(in app: XCUIApplication) {
        let notificationsRow = app.buttons["settings.reference.notifications"]
        XCTAssertTrue(scrollToElement(notificationsRow, in: app))
        notificationsRow.tap()
        XCTAssertTrue(app.staticTexts["Notifications"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollToElement(app.buttons["settings.notificationHealth.action"], in: app))
        returnToSettingsHome(in: app)
    }

    @MainActor
    private func assertSettingsProgressControls(in app: XCUIApplication) {
        expandSettingsSection("progress", in: app)
        XCTAssertTrue(app.switches["settings.reapplyToggle"].exists)
        returnToSettingsHome(in: app)
    }

    @MainActor
    private func assertSettingsDataControls(in app: XCUIApplication) {
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
    private func assertSettingsAutomationControls(in app: XCUIApplication) {
        expandSettingsSection("automation", in: app)
        XCTAssertTrue(scrollToElement(automationSwitch("Allow Shortcut writes", in: app), in: app))
        XCTAssertTrue(scrollToElement(automationSwitch("Allow URL open actions", in: app), in: app))
        XCTAssertTrue(scrollToElement(automationSwitch("Allow URL write actions", in: app), in: app))
        XCTAssertTrue(scrollToElement(automationSwitch("Include callback result details", in: app), in: app))
        XCTAssertTrue(scrollToElement(app.buttons["automation.example.logToday.copy"], in: app))
        XCTAssertTrue(app.buttons["automation.example.logToday.test"].exists)
        XCTAssertTrue(scrollToElement(app.buttons["settings.automation.openCatalog"], in: app))
        returnToSettingsHome(in: app)
    }

    @MainActor
    private func assertSettingsAdvancedControls(in app: XCUIApplication) {
        expandSettingsSection("advanced", in: app)
        XCTAssertTrue(scrollToElement(app.switches["settings.leaveHomeToggle"], in: app))
        XCTAssertTrue(scrollToElement(app.buttons["settings.leaveHome.action"], in: app))
        XCTAssertEqual(app.buttons["settings.leaveHome.action"].label, "Use Current Location as Home")
        XCTAssertTrue(app.switches["settings.uvBriefingToggle"].exists)
        XCTAssertTrue(app.switches["settings.extremeUVToggle"].exists)
        XCTAssertTrue(scrollToElement(app.switches["settings.healthKitToggle"], in: app))
        XCTAssertTrue(scrollToElement(app.switches["settings.liveUVToggle"], in: app))
        XCTAssertTrue(scrollToElement(app.descendants(matching: .any)["settings.liveUV.status"], in: app))
        returnToSettingsHome(in: app)
    }

    @MainActor
    private func assertSettingsHelpControls(in app: XCUIApplication) {
        XCTAssertTrue(scrollToHittableElement(app.buttons["settings.section.help"], in: app))
        expandSettingsSection("help", in: app)
        XCTAssertTrue(scrollToElement(app.buttons["settings.support"], in: app))
        XCTAssertTrue(app.buttons["settings.privacyPolicy"].exists)
        XCTAssertTrue(app.buttons["settings.emailSupport"].exists)
        returnToSettingsHome(in: app)
    }

    @MainActor
    private func assertBackupImportHarnessRestoresRecordCount(in app: XCUIApplication) {
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
    private func stringValue(of element: XCUIElement) -> String? {
        element.value as? String
    }

    private func averageScreenshotLuminance() -> Double {
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
    private func expandSettingsSection(_ section: String, in app: XCUIApplication) {
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
    private func expandSettingsControl(_ sectionControl: XCUIElement) {
        sectionControl.tap()
    }

    @MainActor
    private func dragFromLeftEdge(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let finish = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: finish)
    }

    @MainActor
    private func tapSettingsSectionControl(
        _ sectionControl: XCUIElement,
        in app: XCUIApplication,
        attempts: Int
    ) -> Bool {
        if sectionControl.waitForExistence(timeout: 2), sectionControl.isHittable {
            return true
        }

        for _ in 0..<attempts {
            app.swipeUp()
            if sectionControl.waitForExistence(timeout: 1), sectionControl.isHittable {
                return true
            }
        }

        for _ in 0..<attempts {
            app.swipeDown()
            if sectionControl.waitForExistence(timeout: 1), sectionControl.isHittable {
                return true
            }
        }

        return false
    }

    @MainActor
    private func returnToSettingsHome(in app: XCUIApplication) {
        let backButton = app.buttons["screen.back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    private func settingsSectionTitle(for section: String) -> String {
        switch section {
        case "reminders":
            return "Reminders"
        case "progress":
            return "Reapply Reminder"
        case "data":
            return "Data & Export"
        case "automation":
            return "Connect Shortcuts"
        case "advanced":
            return "UV & Weather"
        case "help":
            return "Help & Legal"
        default:
            return section
        }
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

private enum CalendarGridDragDirection {
    case left
    case right
}

private enum TimelineDayScrollDirection {
    case past
    case future
}
