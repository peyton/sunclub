import Foundation
import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import Sunclub

@MainActor
final class AutomationTests: XCTestCase {
    func testAutomationDeepLinksRoundTripDirectAndXCallbackActions() throws {
        let day = try makeDate(year: 2026, month: 4, day: 14)
        let friendID = try XCTUnwrap(UUID(uuidString: "D2A26E1B-7E95-4F45-A103-83D1A8C1E656"))
        let callback = SunclubXCallback(
            successURL: URL(string: "shortcuts://callback/success")!,
            errorURL: URL(string: "shortcuts://callback/error")!,
            cancelURL: URL(string: "shortcuts://callback/cancel")!
        )

        var actions: [SunclubAutomationAction] = [
            .logToday(spfLevel: 50, notes: "Beach walk"),
            .saveLog(day: day, time: ReminderTime(hour: 7, minute: 45), spfLevel: 30, notes: "Before run"),
            .reapply,
            .status,
            .timeSinceLastApplication,
            .setReminder(kind: .weekday, time: ReminderTime(hour: 8, minute: 30)),
            .setReminder(kind: .weekend, time: ReminderTime(hour: 10, minute: 15)),
            .setReapply(enabled: true, intervalMinutes: 120),
            .importFriend(code: "sunclub-invite-code"),
            .pokeFriend(id: friendID)
        ]
        actions.append(contentsOf: SunclubAutomationToggle.allCases.map { .setToggle($0, enabled: false) })
        actions.append(contentsOf: SunclubAutomationRoute.allCases.map { .open($0) })

        for action in actions {
            let directURL = SunclubAutomationRequest(action: action, callback: nil).url
            guard case let .automation(directRequest) = SunclubDeepLink(url: directURL) else {
                return XCTFail("Expected automation deeplink for \(directURL)")
            }
            XCTAssertEqual(directRequest.action, action)
            XCTAssertNil(directRequest.callback)

            let callbackURL = SunclubAutomationRequest(action: action, callback: callback).url
            guard case let .automation(callbackRequest) = SunclubDeepLink(url: callbackURL) else {
                return XCTFail("Expected x-callback automation deeplink for \(callbackURL)")
            }
            XCTAssertEqual(callbackRequest.action, action)
            XCTAssertEqual(callbackRequest.callback, callback)
        }
    }

    func testCallbackURLsEncodeDetailsAndRespectDetailsToggle() throws {
        let baseURL = URL(string: "shortcuts://run-shortcut?name=Done")!
        let result = SunclubAutomationResult(
            action: "status",
            status: "ok",
            message: "Today is logged.",
            currentStreak: 7,
            longestStreak: 12,
            todayLogged: true,
            weeklyApplied: 5,
            recordDate: "2026-04-14",
            friend: "Maya",
            route: "automation",
            lastAppliedAt: "2026-04-14T15:30:00.000Z",
            minutesSinceLastApplication: 42
        )

        let detailedSuccess = SunclubXCallbackResponse.successURL(
            baseURL: baseURL,
            result: result,
            includesDetails: true
        )
        XCTAssertEqual(queryValue("name", in: detailedSuccess), "Done")
        XCTAssertEqual(queryValue("action", in: detailedSuccess), "status")
        XCTAssertEqual(queryValue("status", in: detailedSuccess), "ok")
        XCTAssertEqual(queryValue("message", in: detailedSuccess), "Today is logged.")
        XCTAssertEqual(queryValue("currentStreak", in: detailedSuccess), "7")
        XCTAssertEqual(queryValue("todayLogged", in: detailedSuccess), "true")
        XCTAssertEqual(queryValue("weeklyApplied", in: detailedSuccess), "5")
        XCTAssertEqual(queryValue("recordDate", in: detailedSuccess), "2026-04-14")
        XCTAssertEqual(queryValue("friend", in: detailedSuccess), "Maya")
        XCTAssertEqual(queryValue("route", in: detailedSuccess), "automation")
        XCTAssertEqual(queryValue("lastAppliedAt", in: detailedSuccess), "2026-04-14T15:30:00.000Z")
        XCTAssertEqual(queryValue("minutesSinceLastApplication", in: detailedSuccess), "42")

        let minimalSuccess = SunclubXCallbackResponse.successURL(
            baseURL: baseURL,
            result: result,
            includesDetails: false
        )
        XCTAssertEqual(queryValue("action", in: minimalSuccess), "status")
        XCTAssertEqual(queryValue("status", in: minimalSuccess), "ok")
        XCTAssertNil(queryValue("message", in: minimalSuccess))
        XCTAssertNil(queryValue("currentStreak", in: minimalSuccess))

        let detailedError = SunclubXCallbackResponse.errorURL(
            baseURL: baseURL,
            action: "log-today",
            error: .urlWriteActionsDisabled,
            includesDetails: true
        )
        XCTAssertEqual(queryValue("action", in: detailedError), "log-today")
        XCTAssertEqual(queryValue("status", in: detailedError), "error")
        XCTAssertEqual(queryValue("errorCode", in: detailedError), "urlWriteActionsDisabled")
        XCTAssertEqual(queryValue("errorMessage", in: detailedError), "URL write actions are off in Sunclub Automation settings.")

        let minimalError = SunclubXCallbackResponse.errorURL(
            baseURL: baseURL,
            action: "log-today",
            error: .urlWriteActionsDisabled,
            includesDetails: false
        )
        XCTAssertEqual(queryValue("action", in: minimalError), "log-today")
        XCTAssertEqual(queryValue("status", in: minimalError), "error")
        XCTAssertNil(queryValue("errorCode", in: minimalError))
        XCTAssertNil(queryValue("errorMessage", in: minimalError))
    }

    func testAutomationDeepLinksAcceptProductionAndDevelopmentSchemes() throws {
        for scheme in ["sunclub", "sunclub-dev"] {
            let url = try XCTUnwrap(URL(string: "\(scheme)://x-callback-url/open?route=automation"))
            guard case let .automation(request) = SunclubDeepLink(url: url) else {
                return XCTFail("Expected automation deeplink for \(scheme)")
            }
            XCTAssertEqual(request.action, .open(.automation))
        }
    }

    func testAutomationCatalogURLExamplesStayParseable() throws {
        let friendID = try XCTUnwrap(UUID(uuidString: "D2A26E1B-7E95-4F45-A103-83D1A8C1E656"))
        let examples: [(String, SunclubAutomationAction)] = [
            ("sunclub://automation/log-today?spf=50&notes=Beach%20bag", .logToday(spfLevel: 50, notes: "Beach bag")),
            ("sunclub://automation/status", .status),
            ("sunclub://automation/time-since-last-application", .timeSinceLastApplication),
            ("sunclub://automation/open?route=settings", .open(.settings)),
            ("sunclub://automation/save-log?date=2026-04-13&time=08:30&spf=50&notes=Morning", .saveLog(day: try makeDate(year: 2026, month: 4, day: 13), time: ReminderTime(hour: 8, minute: 30), spfLevel: 50, notes: "Morning")),
            ("sunclub://automation/reapply", .reapply),
            ("sunclub://automation/set-reminder?kind=weekday&time=08:30", .setReminder(kind: .weekday, time: ReminderTime(hour: 8, minute: 30))),
            ("sunclub://automation/set-reapply?enabled=true&interval=90", .setReapply(enabled: true, intervalMinutes: 90)),
            ("sunclub://automation/set-toggle?name=dailyUVBriefing&enabled=true", .setToggle(.dailyUVBriefing, enabled: true)),
            ("sunclub://automation/import-friend?code=sunclub-invite-code", .importFriend(code: "sunclub-invite-code")),
            ("sunclub://automation/poke-friend?id=\(friendID.uuidString)", .pokeFriend(id: friendID))
        ]

        for (urlString, expectedAction) in examples {
            let url = try XCTUnwrap(URL(string: urlString))
            guard case let .automation(request) = SunclubDeepLink(url: url) else {
                return XCTFail("Expected automation deeplink for \(urlString)")
            }
            XCTAssertEqual(request.action, expectedAction)
        }
    }

    func testMalformedAutomationLinksFailBeforeCreatingRequests() throws {
        let malformedURLs = [
            "sunclub://automation/not-a-real-action",
            "sunclub://automation/log-today?spf=strong",
            "sunclub://automation/save-log?date=tomorrow&spf=50",
            "sunclub://automation/save-log?date=2026-02-31&spf=50",
            "sunclub://automation/save-log?date=2026-04-13&time=25:30",
            "sunclub://automation/set-reapply?enabled=true&interval=later",
            "sunclub://automation/open?route=unknown",
            "sunclub://automation/poke-friend?id=not-a-uuid"
        ]

        for urlString in malformedURLs {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNil(SunclubDeepLink(url: url), urlString)
        }
    }

    func testGrowthSettingsDecodeOlderPayloadWithDefaultAutomationPreferences() throws {
        let decoded = try JSONDecoder().decode(SunclubGrowthSettings.self, from: Data(#"{}"#.utf8))

        XCTAssertEqual(decoded.automation, SunclubAutomationPreferences())
        XCTAssertTrue(decoded.automation.shortcutWritesEnabled)
        XCTAssertTrue(decoded.automation.urlOpenActionsEnabled)
        XCTAssertTrue(decoded.automation.urlWriteActionsEnabled)
        XCTAssertTrue(decoded.automation.callbackResultDetailsEnabled)
    }

    func testURLWriteToggleBlocksWritesButKeepsOpenActionsAvailable() throws {
        let harness = try makeHarness()
        harness.state.completeOnboarding()
        var preferences = harness.state.automationPreferences
        preferences.urlWriteActionsEnabled = false
        harness.state.updateAutomationPreferences(preferences)
        let router = AppRouter()

        let writeURL = SunclubAutomationRequest(
            action: .logToday(spfLevel: 50, notes: "Blocked write"),
            callback: nil
        ).url
        XCTAssertTrue(SunclubDeepLinkHandler.handle(url: writeURL, appState: harness.state, router: router))
        XCTAssertTrue(harness.state.records.isEmpty)
        XCTAssertEqual(router.path, [.manualLog])

        let openURL = SunclubAutomationRequest(action: .open(.automation), callback: nil).url
        XCTAssertTrue(SunclubDeepLinkHandler.handle(url: openURL, appState: harness.state, router: router))
        XCTAssertEqual(router.path, [.automation])
        XCTAssertTrue(harness.state.records.isEmpty)
    }

    func testURLOpenToggleBlocksOpenRoutingToAutomationSettings() throws {
        let harness = try makeHarness()
        harness.state.completeOnboarding()
        var preferences = harness.state.automationPreferences
        preferences.urlOpenActionsEnabled = false
        harness.state.updateAutomationPreferences(preferences)
        let router = AppRouter()

        let openURL = SunclubAutomationRequest(action: .open(.history), callback: nil).url
        XCTAssertTrue(SunclubDeepLinkHandler.handle(url: openURL, appState: harness.state, router: router))

        XCTAssertEqual(router.path, [.automation])
    }

    func testShortcutWriteToggleBlocksWritesButAllowsOpenActions() throws {
        let harness = try makeHarness()
        harness.state.completeOnboarding()
        var preferences = harness.state.automationPreferences
        preferences.shortcutWritesEnabled = false
        harness.state.updateAutomationPreferences(preferences)

        XCTAssertThrowsError(
            try harness.state.performAutomationAction(
                .logToday(spfLevel: 50, notes: "Shortcut write"),
                invocation: .shortcut
            )
        ) { error in
            XCTAssertEqual(error as? SunclubAutomationError, .shortcutWritesDisabled)
        }
        XCTAssertTrue(harness.state.records.isEmpty)

        let result = try harness.state.performAutomationAction(.open(.automation), invocation: .shortcut)
        XCTAssertEqual(result.status, "opened")
        XCTAssertEqual(result.route, "automation")
    }

    func testLogSaveAndReapplyAutomationUseRevisionHistoryAndRefreshWidgets() throws {
        let now = try makeDate(year: 2026, month: 7, day: 12, hour: 13)
        let harness = try makeHarness(clock: { now })
        harness.state.completeOnboarding()

        let logResult = try harness.state.performAutomationAction(
            .logToday(spfLevel: 50, notes: "  Beach bag  "),
            invocation: .url
        )

        XCTAssertEqual(logResult.action, "log-today")
        XCTAssertEqual(logResult.status, "ok")
        XCTAssertEqual(logResult.message, "Logged sunscreen for today.")
        XCTAssertEqual(logResult.recordDate, dateString(now))
        XCTAssertEqual(harness.state.records.count, 1)
        let todayRecord = try XCTUnwrap(harness.state.record(for: now))
        XCTAssertEqual(todayRecord.method, .quickLog)
        XCTAssertEqual(todayRecord.spfLevel, 50)
        XCTAssertEqual(todayRecord.notes, "Beach bag")
        XCTAssertTrue(harness.state.changeBatches.contains { $0.kind == .manualLog && $0.summary == "Logged sunscreen from automation." })
        XCTAssertTrue(harness.widgetStore.load().hasLoggedToday(now: now))
        XCTAssertEqual(harness.widgetStore.load().mostUsedSPF, 50)

        let updateResult = try harness.state.performAutomationAction(.logToday(spfLevel: nil, notes: nil), invocation: .url)
        XCTAssertEqual(updateResult.message, "Updated today's sunscreen log.")
        XCTAssertEqual(harness.state.records.count, 1)
        let updatedTodayRecord = try XCTUnwrap(harness.state.record(for: now))
        XCTAssertEqual(updatedTodayRecord.spfLevel, 50)
        XCTAssertEqual(updatedTodayRecord.notes, "Beach bag")

        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let backfillResult = try harness.state.performAutomationAction(
            .saveLog(
                day: yesterday,
                time: ReminderTime(hour: 8, minute: 45),
                spfLevel: 30,
                notes: "Backfilled"
            ),
            invocation: .url
        )
        XCTAssertEqual(backfillResult.message, "Backfilled sunscreen log.")
        XCTAssertEqual(harness.state.records.count, 2)
        let yesterdayRecord = try XCTUnwrap(harness.state.record(for: yesterday))
        XCTAssertEqual(yesterdayRecord.spfLevel, 30)
        XCTAssertEqual(yesterdayRecord.notes, "Backfilled")
        XCTAssertEqual(Calendar.current.component(.hour, from: yesterdayRecord.verifiedAt), 8)
        XCTAssertEqual(Calendar.current.component(.minute, from: yesterdayRecord.verifiedAt), 45)
        XCTAssertTrue(harness.state.changeBatches.contains { $0.kind == .historyBackfill })

        let editResult = try harness.state.performAutomationAction(
            .saveLog(day: yesterday, time: nil, spfLevel: nil, notes: nil),
            invocation: .url
        )
        XCTAssertEqual(editResult.message, "Updated sunscreen log.")
        let clearedYesterdayRecord = try XCTUnwrap(harness.state.record(for: yesterday))
        XCTAssertNil(clearedYesterdayRecord.spfLevel)
        XCTAssertNil(clearedYesterdayRecord.notes)
        XCTAssertTrue(harness.state.changeBatches.contains { $0.kind == .historyEdit })

        _ = try harness.state.performAutomationAction(.reapply, invocation: .url)
        let reappliedTodayRecord = try XCTUnwrap(harness.state.record(for: now))
        XCTAssertEqual(reappliedTodayRecord.reapplyCount, 1)
        XCTAssertNotNil(reappliedTodayRecord.lastReappliedAt)
        XCTAssertTrue(harness.state.changeBatches.contains { $0.kind == .reapply })
    }

    func testAutomationNormalizesSPFAndNotesAcrossWriteActions() throws {
        let now = try makeDate(year: 2026, month: 7, day: 12, hour: 13)
        let harness = try makeHarness(clock: { now })
        harness.state.completeOnboarding()
        let longNote = String(repeating: "N", count: SunManualLogInput.noteCharacterLimit + 20)

        _ = try harness.state.performAutomationAction(
            .logToday(spfLevel: -4, notes: "  \(longNote)  "),
            invocation: .url
        )

        let todayRecord = try XCTUnwrap(harness.state.record(for: now))
        XCTAssertEqual(todayRecord.spfLevel, 1)
        XCTAssertEqual(todayRecord.notes?.count, SunManualLogInput.noteCharacterLimit)

        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: now))
        _ = try harness.state.performAutomationAction(
            .saveLog(day: yesterday, time: nil, spfLevel: 500, notes: "  Shortcut note  "),
            invocation: .shortcut
        )

        let yesterdayRecord = try XCTUnwrap(harness.state.record(for: yesterday))
        XCTAssertEqual(yesterdayRecord.spfLevel, 100)
        XCTAssertEqual(yesterdayRecord.notes, "Shortcut note")
    }

    func testStatusBackupReportAndStreakCardAutomationReturnExpectedValuesOrFiles() throws {
        let now = try makeDate(year: 2026, month: 7, day: 12, hour: 13)
        let harness = try makeHarness(clock: { now })
        harness.state.completeOnboarding()
        _ = try harness.state.performAutomationAction(.logToday(spfLevel: 50, notes: "File setup"), invocation: .shortcut)

        let status = try harness.state.performAutomationAction(.status, invocation: .shortcut)
        XCTAssertEqual(status.action, "status")
        XCTAssertEqual(status.status, "ok")
        XCTAssertEqual(status.todayLogged, true)
        XCTAssertEqual(status.currentStreak, 1)
        XCTAssertEqual(status.weeklyApplied, 1)
        XCTAssertEqual(status.minutesSinceLastApplication, 0)
        XCTAssertNotNil(status.lastAppliedAt)

        let backup = try harness.state.performAutomationAction(.exportBackup, invocation: .shortcut)
        try assertAutomationFile(backup, expectedAction: "export-backup", expectedType: SunclubBackupDocument.contentType.identifier)

        let report = try harness.state.performAutomationAction(
            .createSkinHealthReport(start: nil, end: nil),
            invocation: .shortcut
        )
        try assertAutomationFile(report, expectedAction: "create-skin-health-report", expectedType: UTType.pdf.identifier)

        let streakCard = try harness.state.performAutomationAction(.createStreakCard, invocation: .shortcut)
        try assertAutomationFile(streakCard, expectedAction: "create-streak-card", expectedType: UTType.png.identifier)
    }

    func testTimeSinceLastApplicationAutomationUsesMostRecentLogOrReapply() throws {
        let now = try makeDate(year: 2026, month: 7, day: 12, hour: 13)
        let harness = try makeHarness(clock: { now })
        harness.state.completeOnboarding()

        let empty = try harness.state.performAutomationAction(.timeSinceLastApplication, invocation: .shortcut)
        XCTAssertEqual(empty.action, "time-since-last-application")
        XCTAssertEqual(empty.status, "ok")
        XCTAssertEqual(empty.message, "No sunscreen application has been logged yet.")
        XCTAssertNil(empty.lastAppliedAt)
        XCTAssertNil(empty.minutesSinceLastApplication)

        _ = try harness.state.performAutomationAction(
            .saveLog(day: now, time: ReminderTime(hour: 10, minute: 15), spfLevel: 50, notes: "Morning"),
            invocation: .url
        )

        let afterLog = try harness.state.performAutomationAction(.timeSinceLastApplication, invocation: .shortcut)
        XCTAssertEqual(afterLog.minutesSinceLastApplication, 165)
        XCTAssertEqual(afterLog.message, "Last sunscreen application was 2 hours and 45 minutes ago.")
        XCTAssertNotNil(afterLog.lastAppliedAt)

        _ = try harness.state.performAutomationAction(.reapply, invocation: .url)
        let afterReapply = try harness.state.performAutomationAction(.timeSinceLastApplication, invocation: .shortcut)
        XCTAssertEqual(afterReapply.minutesSinceLastApplication, 0)
        XCTAssertEqual(afterReapply.message, "Last sunscreen application was 0 minutes ago.")
    }

    func testFriendEntityQueryImportInviteAndPokeAutomationUseSeededFriends() async throws {
        let friendID = try XCTUnwrap(UUID(uuidString: "C57B4D7A-BCB1-4A12-AF1E-069111E4D814"))
        let loggedFriendID = try XCTUnwrap(UUID(uuidString: "8E70869B-92D5-4AE4-A2B5-55AC64C01863"))
        let queryStore = MemoryGrowthFeatureStore(
            settings: SunclubGrowthSettings(
                friends: [
                    friendSnapshot(id: loggedFriendID, name: "Zoe", currentStreak: 8, hasLoggedToday: true),
                    friendSnapshot(id: friendID, name: "Maya", currentStreak: 2, hasLoggedToday: false)
                ]
            )
        )
        let query = SunclubFriendQuery(growthStore: queryStore)

        let suggested = try await query.suggestedEntities()
        XCTAssertEqual(suggested.map(\.name), ["Maya", "Zoe"])
        XCTAssertEqual(suggested.first?.status, "Not logged today, 2-day streak")
        let filtered = try await query.entities(for: [loggedFriendID])
        XCTAssertEqual(filtered.map(\.name), ["Zoe"])

        let now = try makeDate(year: 2026, month: 7, day: 12, hour: 13)
        let automationStore = MemoryGrowthFeatureStore(settings: SunclubGrowthSettings(preferredName: "Peyton"))
        let harness = try makeHarness(growthStore: automationStore, clock: { now })
        harness.state.completeOnboarding()
        let envelope = SunclubAccountabilityInviteEnvelope(
            profileID: try XCTUnwrap(UUID(uuidString: "1ED0032A-35D9-4B9A-A33F-A8C7A275D3D1")),
            displayName: "Maya",
            relationshipToken: "automation-friend-token",
            issuedAt: now,
            snapshot: friendSnapshot(id: friendID, name: "Maya", currentStreak: 2, hasLoggedToday: false)
        )
        let code = try SunclubAccountabilityCodec.backupCode(for: envelope)

        let importResult = try harness.state.performAutomationAction(.importFriend(code: code), invocation: .url)
        XCTAssertEqual(importResult.friend, "Maya")
        XCTAssertEqual(harness.state.friends.map(\.name), ["Maya"])
        XCTAssertFalse(harness.state.growthSettings.accountability.connections.first?.canDirectPoke ?? true)

        let pokeResult = try harness.state.performAutomationAction(.pokeFriend(id: friendID), invocation: .url)
        XCTAssertEqual(pokeResult.friend, "Maya")
        XCTAssertEqual(pokeResult.status, "needs-message")
        XCTAssertEqual(pokeResult.message, "Open Sunclub to message Maya.")
        let savedSettings = automationStore.load()
        XCTAssertTrue(savedSettings.accountability.pokeHistory.isEmpty)
        XCTAssertNil(savedSettings.accountability.connections.first?.lastPokeSentAt)
    }

    private func makeHarness(
        growthStore: SunclubGrowthFeatureStoring? = nil,
        clock: @escaping () -> Date = Date.init
    ) throws -> AutomationHarness {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))
        let widgetStore = SunclubWidgetSnapshotStore(userDefaults: userDefaults)
        let notificationManager = MockNotificationManager()
        let runtimeEnvironment = RuntimeEnvironmentSnapshot(
            isRunningTests: growthStore == nil,
            isPreviewing: growthStore != nil,
            hasAppGroupContainer: false,
            isPublicAccountabilityTransportEnabled: false
        )
        let historyService = SunclubHistoryService(context: context)
        let state = AppState(
            context: context,
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(),
            historyService: historyService,
            cloudSyncCoordinator: ProbeCloudSyncCoordinator(),
            widgetSnapshotStore: widgetStore,
            growthFeatureStore: growthStore ?? SunclubGrowthFeatureStore(userDefaults: userDefaults),
            runtimeEnvironment: runtimeEnvironment,
            clock: clock
        )
        return AutomationHarness(
            state: state,
            widgetStore: widgetStore,
            notificationManager: notificationManager
        )
    }

    private func assertAutomationFile(
        _ result: SunclubAutomationResult,
        expectedAction: String,
        expectedType: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertEqual(result.action, expectedAction, file: file, line: line)
        XCTAssertEqual(result.status, "ok", file: file, line: line)
        XCTAssertEqual(result.fileTypeIdentifier, expectedType, file: file, line: line)
        let fileURL = try XCTUnwrap(result.fileURL, file: file, line: line)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), file: file, line: line)
        XCTAssertGreaterThan((try Data(contentsOf: fileURL)).count, 0, file: file, line: line)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) throws -> Date {
        try XCTUnwrap(
            Calendar.current.date(
                from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
            )
        )
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    private func friendSnapshot(
        id: UUID,
        name: String,
        currentStreak: Int,
        hasLoggedToday: Bool
    ) -> SunclubFriendSnapshot {
        SunclubFriendSnapshot(
            id: id,
            name: name,
            currentStreak: currentStreak,
            longestStreak: max(currentStreak, 7),
            hasLoggedToday: hasLoggedToday,
            lastSharedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            seasonStyle: .summerGlow
        )
    }
}

@MainActor
private struct AutomationHarness {
    let state: AppState
    let widgetStore: SunclubWidgetSnapshotStore
    let notificationManager: MockNotificationManager
}

private final class MemoryGrowthFeatureStore: SunclubGrowthFeatureStoring {
    private var settings: SunclubGrowthSettings

    init(settings: SunclubGrowthSettings) {
        self.settings = settings
    }

    func load() -> SunclubGrowthSettings {
        settings
    }

    func save(_ settings: SunclubGrowthSettings) {
        self.settings = settings
    }
}
