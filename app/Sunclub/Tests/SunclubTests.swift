import Foundation
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class MockNotificationManager: NotificationScheduling {
    private(set) var requestAuthorizationIfNeededCount = 0
    private(set) var scheduleRemindersCount = 0
    private(set) var scheduleReapplyReminderPlans: [ReapplyReminderPlan] = []
    private(set) var scheduleLeaveHomeReminderLevels: [UVLevel] = []
    private(set) var accountabilityPokeNotifications: [(friendName: String, message: String, route: AppRoute)] = []
    private(set) var refreshStreakRiskReminderCount = 0
    private(set) var scheduleReapplyReminderRoutes: [AppRoute] = []
    private(set) var scheduleLeaveHomeReminderRoutes: [AppRoute] = []
    private(set) var cancelDailyReminderDays: [Date] = []
    private(set) var cancelReapplyRemindersCount = 0
    private(set) var notificationHealthSnapshotCount = 0

    var requestAuthorizationResult = true
    var notificationHealthSnapshotResult: NotificationHealthSnapshot = .unknown

    func requestAuthorizationIfNeeded() async -> Bool {
        requestAuthorizationIfNeededCount += 1
        return requestAuthorizationResult
    }

    func scheduleReminders(using state: AppState) async {
        scheduleRemindersCount += 1
    }

    func scheduleReapplyReminder(plan: ReapplyReminderPlan, route: AppRoute) async {
        scheduleReapplyReminderPlans.append(plan)
        scheduleReapplyReminderRoutes.append(route)
    }

    func scheduleLeaveHomeReminder(level: UVLevel, route: AppRoute) async {
        scheduleLeaveHomeReminderLevels.append(level)
        scheduleLeaveHomeReminderRoutes.append(route)
    }

    func scheduleAccountabilityPokeNotification(friendName: String, message: String, route: AppRoute) async {
        accountabilityPokeNotifications.append((friendName, message, route))
    }

    func cancelDailyReminder(for day: Date, using state: AppState) async {
        cancelDailyReminderDays.append(day)
    }

    func refreshStreakRiskReminder(using state: AppState) async {
        refreshStreakRiskReminderCount += 1
    }

    func cancelReapplyReminders() async {
        cancelReapplyRemindersCount += 1
    }

    func notificationHealthSnapshot(using state: AppState) async -> NotificationHealthSnapshot {
        notificationHealthSnapshotCount += 1
        return notificationHealthSnapshotResult
    }
}

@MainActor
final class ProbeCloudSyncCoordinator: CloudSyncControlling {
    private(set) var startCallCount = 0

    func start() async {
        startCallCount += 1
    }

    func setEnabled(_ enabled: Bool) async throws {}

    func queueBatchIfNeeded(_ batchID: UUID) async {}

    func syncNow() async {}

    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult {
        CloudPublishResult(importSessionID: sessionID, publishedBatchCount: 0)
    }
}

@MainActor
final class FakeAccountabilityService: SunclubAccountabilityServing {
    private(set) var publishedProfiles: [SunclubAccountabilityProfile] = []
    private(set) var fetchedProfileRequests: [[UUID]] = []
    private(set) var sentInviteResponses: [SunclubAccountabilityInviteResponse] = []
    private(set) var sentPokes: [SunclubAccountabilityPokeEnvelope] = []
    private(set) var installedSubscriptionProfileIDs: [UUID] = []
    var profilesByID: [UUID: SunclubAccountabilityProfile] = [:]
    var remoteEvents = SunclubAccountabilityRemoteEvents(inviteResponses: [], pokes: [])
    var sendPokeError: Error?

    func publishProfile(_ profile: SunclubAccountabilityProfile) async throws {
        publishedProfiles.append(profile)
    }

    func fetchProfiles(profileIDs: [UUID]) async throws -> [SunclubAccountabilityProfile] {
        fetchedProfileRequests.append(profileIDs)
        return profileIDs.compactMap { profilesByID[$0] }
    }

    func sendInviteResponse(_ response: SunclubAccountabilityInviteResponse) async throws {
        sentInviteResponses.append(response)
    }

    func sendPoke(_ poke: SunclubAccountabilityPokeEnvelope) async throws {
        if let sendPokeError {
            throw sendPokeError
        }
        sentPokes.append(poke)
    }

    func fetchRemoteEvents(for profileID: UUID) async throws -> SunclubAccountabilityRemoteEvents {
        remoteEvents
    }

    func installSubscriptions(for profileID: UUID) async throws {
        installedSubscriptionProfileIDs.append(profileID)
    }
}

private enum FakeAccountabilityError: Error {
    case sendFailed
}

@MainActor
final class MockHomeExitReminderMonitor: HomeExitReminderMonitoring {
    private(set) var refreshMonitoringCalls: [(enabled: Bool, hasHome: Bool, allowPermissionPrompt: Bool)] = []
    private(set) var saveHomeFromCurrentLocationCount = 0
    private var stateProvider: (() -> AppState?)?

    var authorizationState: LeaveHomeAuthorizationState = .notDetermined
    var saveHomeResult: Result<HomeLocation, Error> = .success(
        HomeLocation(latitude: 34.116, longitude: -118.150)
    )
    var hasTriggeredReminderResult = false

    func setStateProvider(_ provider: @escaping () -> AppState?) {
        stateProvider = provider
    }

    func refreshMonitoring(using state: AppState, allowPermissionPrompt: Bool) async -> LeaveHomeAuthorizationState {
        refreshMonitoringCalls.append((
            enabled: state.settings.smartReminderSettings.leaveHomeReminder.isEnabled,
            hasHome: state.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil,
            allowPermissionPrompt: allowPermissionPrompt
        ))
        return authorizationState
    }

    func saveHomeFromCurrentLocation() async throws -> HomeLocation {
        saveHomeFromCurrentLocationCount += 1
        return try saveHomeResult.get()
    }

    func hasTriggeredReminder(on date: Date) -> Bool {
        hasTriggeredReminderResult
    }
}

final class SunclubTests: XCTestCase {
    @MainActor
    func testAppRouterGoBackRemovesCurrentRoute() {
        let router = AppRouter()

        router.open(.manualLog)
        XCTAssertEqual(router.path, [.manualLog])
        XCTAssertTrue(router.canGoBack)

        router.goBack()

        XCTAssertTrue(router.path.isEmpty)
        XCTAssertFalse(router.canGoBack)
    }

    @MainActor
    func testDayStatusAppliesToFutureTodayAndPast() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let set: Set<Date> = [today]
        XCTAssertEqual(CalendarAnalytics.status(for: today, with: set, now: today, calendar: calendar), .applied)
        XCTAssertEqual(CalendarAnalytics.status(for: tomorrow, with: set, now: today, calendar: calendar), .future)
        XCTAssertEqual(CalendarAnalytics.status(for: yesterday, with: set, now: today, calendar: calendar), .missed)
        XCTAssertEqual(CalendarAnalytics.status(for: today, with: [], now: today, calendar: calendar), .todayPending)
    }

    @MainActor
    func testStreakIsContiguousFromMostRecentAppliedDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records = [
            today,
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!,
            calendar.date(byAdding: .day, value: -4, to: today)!
        ]

        XCTAssertEqual(CalendarAnalytics.currentStreak(records: records, now: today, calendar: calendar), 3)
    }

    @MainActor
    func testPhraseShuffleBagDoesNotRepeatUntilExhaustion() {
        let phrases = ["a", "b", "c", "d"]
        var state = Data()
        var seen: [String] = []

        for _ in phrases {
            let next = PhraseRotation.nextPhrase(from: state, catalog: phrases)
            seen.append(next.0)
            state = next.1
        }

        XCTAssertEqual(Set(seen).count, 4)
    }

    @MainActor
    func testNextDailyPhrasesPersistRotationOncePerSchedulePass() throws {
        let state = try makeAppState()
        let initialBatchCount = try state.modelContext.fetch(FetchDescriptor<SunclubChangeBatch>()).count
        let initialSettingsRevisionCount = try state.modelContext.fetch(FetchDescriptor<SettingsRevision>()).count

        let phrases = state.nextDailyPhrases(count: 60)

        XCTAssertEqual(phrases.count, 60)
        XCTAssertEqual(try state.modelContext.fetch(FetchDescriptor<SunclubChangeBatch>()).count, initialBatchCount + 1)
        XCTAssertEqual(
            try state.modelContext.fetch(FetchDescriptor<SettingsRevision>()).count,
            initialSettingsRevisionCount + 1
        )
    }

    @MainActor
    func testVerificationSuccessPresentationUsesUpdatedStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual,
            verificationDuration: 1.0
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 2)
        XCTAssertEqual(state.verificationSuccessPresentation?.detail, "2 days in a row.")
    }

    @MainActor
    func testWeeklySummaryFormattingUsesSpacedFraction() {
        let report = WeeklyReport(
            startDate: Date(),
            endDate: Date(),
            appliedCount: 7,
            totalDays: 7,
            missedDays: [],
            streak: 7
        )

        XCTAssertEqual(report.appliedSummaryText, "7 / 7")
    }

    @MainActor
    func testUpdateDailyReminderPersistsToSettings() throws {
        let state = try makeAppState()

        state.updateDailyReminder(hour: 9, minute: 45)

        XCTAssertEqual(state.settings.reminderHour, 9)
        XCTAssertEqual(state.settings.reminderMinute, 45)
        XCTAssertEqual(state.settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 9, minute: 45))
        XCTAssertEqual(state.settings.smartReminderSettings.weekendTime, ReminderTime(hour: 9, minute: 45))
    }

    @MainActor
    func testUpdateReminderTimePersistsSeparateWeekdayAndWeekendSchedules() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.updateReminderTime(for: .weekday, hour: 7, minute: 30)
        state.updateReminderTime(for: .weekend, hour: 9, minute: 15)

        await Task.yield()
        XCTAssertEqual(state.settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 30))
        XCTAssertEqual(state.settings.smartReminderSettings.weekendTime, ReminderTime(hour: 9, minute: 15))
        XCTAssertEqual(state.settings.reminderHour, 7)
        XCTAssertEqual(state.settings.reminderMinute, 30)
        XCTAssertEqual(notificationManager.scheduleRemindersCount, 2)
    }

    @MainActor
    func testUpdateTravelTimeZoneHandlingAnchorsCurrentZoneWhenDisabled() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.updateTravelTimeZoneHandling(followsTravelTimeZone: false)

        await Task.yield()
        XCTAssertFalse(state.settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertEqual(state.settings.smartReminderSettings.anchoredTimeZoneIdentifier, TimeZone.autoupdatingCurrent.identifier)
        XCTAssertEqual(notificationManager.scheduleRemindersCount, 1)
    }

    @MainActor
    func testUpdateStreakRiskReminderPersistsAndReschedules() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.updateStreakRiskReminder(enabled: false)

        await Task.yield()
        XCTAssertFalse(state.settings.smartReminderSettings.streakRiskEnabled)
        XCTAssertEqual(notificationManager.scheduleRemindersCount, 1)
    }

    @MainActor
    func testUpdateLeaveHomeReminderEnabledPersistsAndRefreshesMonitor() async throws {
        let notificationManager = MockNotificationManager()
        let homeExitReminderMonitor = MockHomeExitReminderMonitor()
        let state = try makeAppState(
            notificationManager: notificationManager,
            homeExitReminderMonitor: homeExitReminderMonitor
        )

        state.updateLeaveHomeReminderEnabled(enabled: true, allowPermissionPrompt: false)

        await Task.yield()
        XCTAssertTrue(state.settings.smartReminderSettings.leaveHomeReminder.isEnabled)
        XCTAssertEqual(notificationManager.scheduleRemindersCount, 1)
        XCTAssertGreaterThanOrEqual(homeExitReminderMonitor.refreshMonitoringCalls.count, 2)
        XCTAssertFalse(homeExitReminderMonitor.refreshMonitoringCalls.last?.hasHome ?? true)
        XCTAssertFalse(homeExitReminderMonitor.refreshMonitoringCalls.last?.allowPermissionPrompt ?? true)
    }

    @MainActor
    func testSaveCurrentLocationAsHomePersistsHomeCoordinate() async throws {
        let homeExitReminderMonitor = MockHomeExitReminderMonitor()
        let state = try makeAppState(homeExitReminderMonitor: homeExitReminderMonitor)

        state.saveCurrentLocationAsHome()

        await Task.yield()
        await Task.yield()
        XCTAssertEqual(homeExitReminderMonitor.saveHomeFromCurrentLocationCount, 1)
        XCTAssertEqual(
            state.settings.smartReminderSettings.leaveHomeReminder.homeLocation,
            HomeLocation(latitude: 34.116, longitude: -118.150)
        )
        XCTAssertNil(state.leaveHomeReminderErrorMessage)
    }

    @MainActor
    func testLeaveHomeReminderPresentationRequestsHomeWhenEnabledWithoutSavedHome() async throws {
        let state = try makeAppState()

        state.updateLeaveHomeReminderEnabled(enabled: true, allowPermissionPrompt: false)
        state.setLeaveHomeAuthorizationStateForTesting(.notDetermined)

        await Task.yield()
        let presentation = state.leaveHomeReminderStatusPresentation
        XCTAssertEqual(presentation.title, "Home isn't set")
        XCTAssertEqual(presentation.actionKind, .setHomeFromCurrentLocation)
    }

    @MainActor
    func testLeaveHomeReminderPresentationRequestsAlwaysAccessWhenHomeIsSaved() throws {
        let state = try makeAppState()

        var reminderSettings = state.settings.smartReminderSettings
        reminderSettings.leaveHomeReminder = LeaveHomeReminderSettings(
            isEnabled: true,
            homeLocation: HomeLocation(latitude: 34.0, longitude: -118.0)
        )
        state.settings.smartReminderSettings = reminderSettings
        state.save()
        state.setLeaveHomeAuthorizationStateForTesting(.whenInUse)

        let presentation = state.leaveHomeReminderStatusPresentation
        XCTAssertEqual(presentation.title, "Background location needed")
        XCTAssertEqual(presentation.actionKind, .requestAlwaysAuthorization)
    }

    @MainActor
    func testMarkAppliedTodayUpdatesExistingRecordInsteadOfDuplicating() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, verificationDuration: 1.2)
        state.markAppliedToday(method: .manual, verificationDuration: 2.4)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.verificationDuration, 2.4)
    }

    @MainActor
    func testManualVerificationMethodProperties() {
        let manual = VerificationMethod.manual
        XCTAssertEqual(manual.title, "manual")
        XCTAssertEqual(manual.displayName, "Manual Log")
        XCTAssertEqual(manual.symbolName, "hand.tap")
        XCTAssertEqual(manual.rawValue, 1)
    }

    @MainActor
    func testVerificationMethodCaseIterable() {
        let allCases = VerificationMethod.allCases
        XCTAssertEqual(allCases, [.manual])
    }

    @MainActor
    func testVerificationMethodRoundTripsThroughRawValue() {
        XCTAssertEqual(VerificationMethod(rawValue: VerificationMethod.manual.rawValue), .manual)
    }

    @MainActor
    func testMarkAppliedTodayWithManualMethod() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.method, .manual)
        XCTAssertNil(state.records.first?.verificationDuration)
    }

    @MainActor
    func testMarkAppliedTodayWithSPFAndNotes() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, spfLevel: 50, notes: "Before morning run")

        XCTAssertEqual(state.records.first?.spfLevel, 50)
        XCTAssertEqual(state.records.first?.notes, "Before morning run")
    }

    @MainActor
    func testSaveManualRecordBackfillsPastDay() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        state.saveManualRecord(for: yesterday, spfLevel: 70, notes: "After lunch")

        let record = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertEqual(record.spfLevel, 70)
        XCTAssertEqual(record.notes, "After lunch")
        XCTAssertTrue(calendar.isDate(record.startOfDay, inSameDayAs: yesterday))
        XCTAssertTrue(calendar.isDate(record.verifiedAt, inSameDayAs: yesterday))
        XCTAssertEqual(state.dayStatus(for: yesterday), .applied)
    }

    @MainActor
    func testUpdateExistingRecordPreservesSPF() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, spfLevel: 50)
        state.markAppliedToday(method: .manual, verificationDuration: 1.0)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.spfLevel, 50)
    }

    @MainActor
    func testSaveManualRecordCanClearOptionalFieldsAndPreserveDuration() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let existingVerifiedAt = calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday
        let existing = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: existingVerifiedAt,
            method: .manual,
            verificationDuration: 1.5,
            spfLevel: 50,
            notes: "Before run"
        )
        state.modelContext.insert(existing)
        state.refresh()

        state.saveManualRecord(for: yesterday, spfLevel: nil, notes: "")

        let updated = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertNil(updated.spfLevel)
        XCTAssertNil(updated.notes)
        XCTAssertEqual(updated.verificationDuration, 1.5)
        XCTAssertEqual(updated.verifiedAt, existingVerifiedAt)
    }

    @MainActor
    func testManualLogSuggestionStatePrefillsLastSPFAndRecentNoteSnippets() {
        let records = [
            makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: 50, notes: "Morning beach walk"),
            makeDailyRecord(dayOffset: 2, hour: 8, spfLevel: 30, notes: "Before lunch"),
            makeDailyRecord(dayOffset: 3, hour: 7, spfLevel: 50, notes: "Morning beach walk")
        ]

        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: Date(),
            calendar: Calendar.current
        )

        XCTAssertEqual(suggestions.defaultSPF, 50)
        XCTAssertEqual(suggestions.sameAsLastTime?.spfLevel, 50)
        XCTAssertEqual(suggestions.sameAsLastTime?.note, "Morning beach walk")
        XCTAssertEqual(suggestions.noteSnippets, ["Before lunch"])
    }

    @MainActor
    func testManualLogSuggestionStatePrefillsMostRecentSPFEvenAfterNoteOnlyLog() {
        let records = [
            makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: nil, notes: "Hat day"),
            makeDailyRecord(dayOffset: 2, hour: 8, spfLevel: 45, notes: nil)
        ]

        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: Date(),
            calendar: Calendar.current
        )

        XCTAssertEqual(suggestions.defaultSPF, 45)
        XCTAssertNil(suggestions.sameAsLastTime?.spfLevel)
        XCTAssertEqual(suggestions.sameAsLastTime?.note, "Hat day")
    }

    @MainActor
    func testManualLogSuggestionStateIncludesScannedSPFLevels() {
        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: [],
            scannedSPFLevels: [45, 80, 45]
        )

        XCTAssertEqual(suggestions.scannedSPFLevels, [45, 80])
    }

    @MainActor
    func testRememberScannedSPFStoresMostRecentLevels() throws {
        let state = try makeAppState()

        state.rememberScannedSPF(45)
        state.rememberScannedSPF(80)
        state.rememberScannedSPF(45)

        XCTAssertEqual(state.growthSettings.scannedSPFLevels, [45, 80])
        XCTAssertEqual(state.manualLogSuggestionState(for: Date()).scannedSPFLevels, [45, 80])
    }

    func testGrowthSettingsDecodesOlderPayloadWithoutScannedSPFLevels() throws {
        let data = Data("""
        {
            "preferredName": "Peyton",
            "healthKit": {
                "isEnabled": false,
                "importedSampleCount": 0
            },
            "uvBriefing": {
                "dailyBriefingEnabled": true,
                "extremeAlertEnabled": false,
                "morningHour": 8,
                "morningMinute": 0
            },
            "friends": [
                {
                    "id": "9C9E0C71-0C6B-46C2-8AC0-32E3AC1EE0E5",
                    "name": "Maya",
                    "currentStreak": 4,
                    "longestStreak": 9,
                    "hasLoggedToday": true,
                    "lastSharedAt": 800000000,
                    "seasonStyleRawValue": "summerGlow"
                }
            ],
            "presentedAchievementIDs": []
        }
        """.utf8)

        let settings = try JSONDecoder().decode(SunclubGrowthSettings.self, from: data)

        XCTAssertEqual(settings.preferredName, "Peyton")
        XCTAssertEqual(settings.friends.first?.name, "Maya")
        XCTAssertEqual(settings.friends.first?.currentStreak, 4)
        XCTAssertEqual(settings.scannedSPFLevels, [])
        XCTAssertFalse(settings.accountability.isActive)
        XCTAssertTrue(settings.accountability.connections.isEmpty)
    }

    func testGrowthSettingsDecodesPartialAccountabilityPayloadWithDefaults() throws {
        let data = Data("""
        {
            "preferredName": "Peyton",
            "accountability": {
                "displayName": " Peyton ",
                "activatedAt": 800000000
            }
        }
        """.utf8)

        let settings = try JSONDecoder().decode(SunclubGrowthSettings.self, from: data)

        XCTAssertEqual(settings.preferredName, "Peyton")
        XCTAssertEqual(settings.accountability.displayName, "Peyton")
        XCTAssertTrue(settings.accountability.isActive)
        XCTAssertTrue(settings.accountability.inviteTokens.isEmpty)
        XCTAssertTrue(settings.accountability.pendingInvites.isEmpty)
        XCTAssertTrue(settings.accountability.connections.isEmpty)
        XCTAssertTrue(settings.accountability.pokeHistory.isEmpty)
    }

    func testHomeGreetingFormatterUsesPreferredDisplayNameWhenPresent() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        func date(hour: Int) throws -> Date {
            try XCTUnwrap(
                calendar.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: hour))
            )
        }

        XCTAssertEqual(
            HomeGreetingFormatter.greeting(for: try date(hour: 8), preferredDisplayName: "", calendar: calendar),
            "Good morning"
        )
        XCTAssertEqual(
            HomeGreetingFormatter.greeting(for: try date(hour: 8), preferredDisplayName: "   ", calendar: calendar),
            "Good morning"
        )
        XCTAssertEqual(
            HomeGreetingFormatter.greeting(for: try date(hour: 8), preferredDisplayName: "Peyton", calendar: calendar),
            "Good morning, Peyton"
        )
        XCTAssertEqual(
            HomeGreetingFormatter.greeting(
                for: try date(hour: 13),
                preferredDisplayName: "Peyton Appleseed",
                calendar: calendar
            ),
            "Good afternoon, Peyton Appleseed"
        )
        XCTAssertEqual(
            HomeGreetingFormatter.greeting(for: try date(hour: 20), preferredDisplayName: "Peyton", calendar: calendar),
            "Good evening, Peyton"
        )
    }

    @MainActor
    func testPreferredDisplayNameStoresTrimmedShareProfileName() throws {
        let state = try makeAppState()

        state.updatePreferredDisplayName("  Peyton Appleseed  ")

        XCTAssertEqual(state.preferredDisplayName, "Peyton Appleseed")
        XCTAssertEqual(state.growthSettings.preferredName, "Peyton Appleseed")
    }

    @MainActor
    func testFriendShareCodeUsesPreferredDisplayName() throws {
        let state = try makeAppState()
        state.updatePreferredDisplayName("Peyton Appleseed")

        let shareCode = try state.friendShareCode()
        let snapshot = try SunclubFriendCodeCodec.decode(shareCode)

        XCTAssertEqual(snapshot.name, "Peyton Appleseed")
    }

    @MainActor
    func testAccountabilityInviteCodeRoundTripsAndDeepLinkParses() throws {
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        let code = try SunclubAccountabilityCodec.backupCode(for: envelope)
        let decoded = try SunclubAccountabilityCodec.envelope(from: code)
        let inviteURL = try SunclubAccountabilityCodec.inviteURL(for: envelope)

        XCTAssertEqual(decoded, envelope)
        guard case let .accountabilityInvite(parsedCode) = SunclubDeepLink(url: inviteURL) else {
            return XCTFail("Expected accountability invite deep link.")
        }
        XCTAssertEqual(try SunclubAccountabilityCodec.envelope(from: parsedCode), envelope)
        XCTAssertThrowsError(try SunclubAccountabilityCodec.envelope(from: "not-a-sunclub-code"))
    }

    @MainActor
    func testQueuedAccountabilityInviteImportsAfterOnboarding() throws {
        let state = try makeAppState()
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        let code = try SunclubAccountabilityCodec.backupCode(for: envelope)

        try state.queuePendingAccountabilityInviteCode(code)

        XCTAssertFalse(state.growthSettings.accountability.isActive)
        XCTAssertTrue(state.friends.isEmpty)

        state.completeOnboarding()
        XCTAssertTrue(state.importPendingAccountabilityInvitesIfNeeded())

        XCTAssertTrue(state.growthSettings.accountability.isActive)
        XCTAssertEqual(state.friends.map(\.name), ["Maya"])
        XCTAssertTrue(state.growthSettings.accountability.pendingInvites.isEmpty)
    }

    @MainActor
    func testAddingByInviteStoresFriendSendsResponseAndUpdatesByProfileID() async throws {
        let service = FakeAccountabilityService()
        let state = try makeAppState(accountabilityService: service)
        let profileID = UUID(uuidString: "391D15FD-475F-4EE5-9A85-E68E27980EA8") ?? UUID()
        let initialEnvelope = makeAccountabilityInviteEnvelope(
            profileID: profileID,
            snapshotID: UUID(uuidString: "9C9E0C71-0C6B-46C2-8AC0-32E3AC1EE0E5") ?? UUID(),
            displayName: "Maya",
            currentStreak: 1
        )

        state.importAccountabilityInvite(initialEnvelope)
        await waitForMainActorTasks()

        XCTAssertEqual(state.friends.count, 1)
        XCTAssertEqual(state.friends.first?.name, "Maya")
        XCTAssertEqual(state.growthSettings.accountability.connections.first?.friendProfileID, profileID)
        XCTAssertEqual(service.sentInviteResponses.count, 1)
        XCTAssertEqual(service.sentInviteResponses.first?.recipientProfileID, profileID)

        let existingFriendID = try XCTUnwrap(state.friends.first?.id)
        let updatedEnvelope = makeAccountabilityInviteEnvelope(
            profileID: profileID,
            snapshotID: UUID(uuidString: "1EDBD356-6014-4B58-B2B4-ED4F6258E2F7") ?? UUID(),
            displayName: "Maya",
            currentStreak: 4
        )

        state.importAccountabilityInvite(updatedEnvelope, sendsResponse: false)

        XCTAssertEqual(state.friends.count, 1)
        XCTAssertEqual(state.friends.first?.id, existingFriendID)
        XCTAssertEqual(state.friends.first?.currentStreak, 4)
    }

    @MainActor
    func testDirectPokeUsesServiceAndFailureLeavesShareFallback() async throws {
        let service = FakeAccountabilityService()
        let state = try makeAppState(accountabilityService: service)
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        state.importAccountabilityInvite(envelope, sendsResponse: false)
        let friendID = try XCTUnwrap(state.friends.first?.id)

        state.sendDirectPoke(to: friendID)
        await waitForMainActorTasks()

        XCTAssertEqual(service.sentPokes.count, 1)
        XCTAssertEqual(service.sentPokes.first?.receiverProfileID, envelope.profileID)
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.status, .sent)

        service.sendPokeError = FakeAccountabilityError.sendFailed
        state.sendDirectPoke(to: friendID)
        await waitForMainActorTasks()

        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.status, .failed)
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.channel, .direct)
        XCTAssertEqual(state.friendImportMessage, "Direct poke did not send. Use Share Poke instead.")
        XCTAssertTrue(state.sharePokeText(for: try XCTUnwrap(state.friends.first)).contains("sunscreen check"))
    }

    @MainActor
    func testIncomingPokeValidatesRelationshipBeforeNotifying() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        state.importAccountabilityInvite(envelope, sendsResponse: false)

        let validPoke = SunclubAccountabilityPokeEnvelope(
            senderProfileID: envelope.profileID,
            senderName: "Maya",
            receiverProfileID: state.growthSettings.accountability.localProfileID,
            relationshipToken: envelope.relationshipToken,
            message: "Sunscreen check?",
            createdAt: Date()
        )
        state.handleIncomingPoke(validPoke)
        await waitForMainActorTasks()

        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.count, 1)
        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.first?.friendName, "Maya")
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.status, .received)

        let invalidPoke = SunclubAccountabilityPokeEnvelope(
            senderProfileID: envelope.profileID,
            senderName: "Maya",
            receiverProfileID: state.growthSettings.accountability.localProfileID,
            relationshipToken: "wrong-token",
            message: "Sunscreen check?",
            createdAt: Date()
        )
        state.handleIncomingPoke(invalidPoke)
        await waitForMainActorTasks()

        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.count, 1)
    }

    @MainActor
    func testSunscreenUsageInsightsReturnsMostUsedSPF() {
        let records = [
            makeDailyRecord(dayOffset: 0, spfLevel: 50),
            makeDailyRecord(dayOffset: 1, spfLevel: 30),
            makeDailyRecord(dayOffset: 2, spfLevel: 50),
            makeDailyRecord(dayOffset: 3, spfLevel: nil)
        ]

        let insights = SunscreenUsageAnalytics.insights(from: records)

        XCTAssertEqual(insights.mostUsedSPF?.level, 50)
        XCTAssertEqual(insights.mostUsedSPF?.count, 2)
        XCTAssertEqual(insights.mostUsedSPF?.totalLoggedCount, 3)
    }

    @MainActor
    func testSunscreenUsageInsightsBreaksSPFTiesByRecency() {
        let records = [
            makeDailyRecord(dayOffset: 4, spfLevel: 30),
            makeDailyRecord(dayOffset: 1, spfLevel: 30),
            makeDailyRecord(dayOffset: 2, spfLevel: 50),
            makeDailyRecord(dayOffset: 0, spfLevel: 50)
        ]

        let insights = SunscreenUsageAnalytics.insights(from: records)

        XCTAssertEqual(insights.mostUsedSPF?.level, 50)
    }

    @MainActor
    func testSunscreenUsageInsightsReturnsRecentTrimmedNotesNewestFirst() {
        let records = [
            makeDailyRecord(dayOffset: 0, notes: "  Before beach walk  "),
            makeDailyRecord(dayOffset: 1, notes: "Applied before morning run"),
            makeDailyRecord(dayOffset: 2, notes: "   "),
            makeDailyRecord(dayOffset: 3, notes: nil)
        ]

        let insights = SunscreenUsageAnalytics.insights(from: records, recentNotesLimit: 2)

        XCTAssertEqual(insights.recentNotes.map(\.text), [
            "Before beach walk",
            "Applied before morning run"
        ])
    }

    @MainActor
    func testLongestStreakUpdatesOnNewRecord() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.longestStreak, 1)
    }

    @MainActor
    func testLongestStreakTracksMaximum() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in stride(from: -2, through: 0, by: 1) {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let record = DailyRecord(
                startOfDay: day,
                verifiedAt: calendar.date(byAdding: .hour, value: 8, to: day) ?? day,
                method: .manual
            )
            state.modelContext.insert(record)
        }
        state.refresh()
        state.markAppliedToday(method: .manual)

        XCTAssertGreaterThanOrEqual(state.longestStreak, 3)
    }

    @MainActor
    func testLongestStreakRecomputesFromProjectedHistoryInsteadOfUsingStaleCache() throws {
        let state = try makeAppState()
        state.settings.longestStreak = 10
        state.save()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.longestStreak, 1)
        XCTAssertEqual(state.settings.longestStreak, 1)
    }

    @MainActor
    func testRefreshNormalizesLegacyCameraMethodToManual() throws {
        let state = try makeAppState()
        let today = Calendar.current.startOfDay(for: Date())

        let record = DailyRecord(startOfDay: today, verifiedAt: today, method: .manual)
        record.methodRawValue = 0
        state.modelContext.insert(record)

        state.refresh()

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.method, .manual)
        XCTAssertEqual(state.records.first?.methodRawValue, VerificationMethod.manual.rawValue)
    }

    @MainActor
    func testDeleteTodayRecordCancelsReapplyReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.markAppliedToday(method: .manual)
        state.deleteRecord(for: Date())

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
        XCTAssertEqual(notificationManager.refreshStreakRiskReminderCount, 2)
    }

    @MainActor
    func testDeleteNonTodayRecordDoesNotCancelReapplyReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        state.markAppliedToday(method: .manual)
        state.deleteRecord(for: yesterday)

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 0)
        XCTAssertEqual(notificationManager.refreshStreakRiskReminderCount, 2)
    }

    @MainActor
    func testRecordVerificationSuccessSetsPresentation() throws {
        let state = try makeAppState()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 1)
        XCTAssertTrue(state.verificationSuccessPresentation?.isPersonalBest ?? false)
    }

    @MainActor
    func testRecordVerificationSuccessStoresSPFAndTrimmedNotes() throws {
        let state = try makeAppState()

        state.recordVerificationSuccess(
            method: .manual,
            verificationDuration: 0.8,
            spfLevel: 30,
            notes: "  Pool day  "
        )

        let record = try XCTUnwrap(state.record(for: Date()))
        XCTAssertEqual(record.spfLevel, 30)
        XCTAssertEqual(record.notes, "Pool day")
    }

    @MainActor
    func testUpdateReapplySettingsPersistsAndClamps() throws {
        let state = try makeAppState()

        state.updateReapplySettings(enabled: true, intervalMinutes: 10)
        XCTAssertTrue(state.settings.reapplyReminderEnabled)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 30)

        state.updateReapplySettings(enabled: true, intervalMinutes: 600)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 480)
    }

    @MainActor
    func testDisablingReapplyCancelsPendingReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.updateReapplySettings(enabled: true, intervalMinutes: 90)
        state.updateReapplySettings(enabled: false, intervalMinutes: 90)

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
    }

    @MainActor
    func testScheduleReapplyReminderUsesPreferredCheckInRoute() async throws {
        let notificationManager = MockNotificationManager()
        let daytime = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(
            notificationManager: notificationManager,
            clock: { daytime }
        )

        state.updateReapplySettings(enabled: true, intervalMinutes: 90)
        state.scheduleReapplyReminder()

        await Task.yield()
        XCTAssertEqual(notificationManager.scheduleReapplyReminderPlans.map(\.intervalMinutes), [90])
        XCTAssertEqual(notificationManager.scheduleReapplyReminderRoutes, [.reapplyCheckIn])
    }

    @MainActor
    func testScheduleReapplyReminderSkipsPastSunset() async throws {
        let notificationManager = MockNotificationManager()
        let afterSunset = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 17, minute: 15))
        )
        let state = try makeAppState(
            notificationManager: notificationManager,
            clock: { afterSunset }
        )

        state.updateReapplySettings(enabled: true, intervalMinutes: 60)

        let plan = state.reapplyReminderPlan
        XCTAssertFalse(plan.shouldScheduleNotification)
        XCTAssertNil(plan.fireDate)
        XCTAssertEqual(plan.confirmationText, "No reapply reminder today after sunset.")

        state.scheduleReapplyReminder()

        await Task.yield()
        XCTAssertTrue(notificationManager.scheduleReapplyReminderPlans.isEmpty)
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
    }

    @MainActor
    func testTodayCardPresentationShowsHighUVMessaging() throws {
        let state = try makeAppState()

        state.setUVReadingForTesting(UVReading(index: 7))

        let presentation = state.todayCardPresentation
        XCTAssertEqual(presentation.title, "Ready for today's log")
        XCTAssertEqual(presentation.uvHeadline, "UV is high today")
        XCTAssertEqual(presentation.uvSymbolName, UVLevel.high.symbolName)
        XCTAssertTrue(presentation.detail.contains("reapply sooner"))
    }

    @MainActor
    func testTodayCardPresentationKeepsDefaultDetailForModerateUV() throws {
        let state = try makeAppState()

        state.setUVReadingForTesting(UVReading(index: 4))

        let presentation = state.todayCardPresentation
        XCTAssertEqual(presentation.uvHeadline, "UV is moderate today")
        XCTAssertEqual(presentation.detail, "One quick check-in keeps the streak steady.")
    }

    @MainActor
    func testReapplyReminderPlanShortensIntervalOnHighUV() throws {
        let daytime = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(clock: { daytime })
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        state.setUVReadingForTesting(UVReading(index: 7))

        let plan = state.reapplyReminderPlan

        XCTAssertTrue(plan.isElevated)
        XCTAssertEqual(plan.baseIntervalMinutes, 120)
        XCTAssertEqual(plan.intervalMinutes, 90)
        XCTAssertEqual(plan.notificationTitle, "Reapply sooner today")
        XCTAssertTrue(plan.notificationBody.contains("UV is high today"))
        XCTAssertEqual(plan.confirmationText, "High UV today: reminder in 1h 30m")
    }

    @MainActor
    func testScheduleReapplyReminderUsesUVAwarePlan() async throws {
        let notificationManager = MockNotificationManager()
        let daytime = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(
            notificationManager: notificationManager,
            clock: { daytime }
        )

        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        state.setUVReadingForTesting(UVReading(index: 9))
        state.scheduleReapplyReminder()

        await Task.yield()
        XCTAssertEqual(notificationManager.scheduleReapplyReminderPlans.map(\.intervalMinutes), [60])
        XCTAssertTrue(notificationManager.scheduleReapplyReminderPlans.first?.notificationBody.contains("very high today") ?? false)
    }

    @MainActor
    func testUVLevelFromIndex() {
        XCTAssertEqual(UVLevel.from(index: 0), .low)
        XCTAssertEqual(UVLevel.from(index: 3), .moderate)
        XCTAssertEqual(UVLevel.from(index: 6), .high)
        XCTAssertEqual(UVLevel.from(index: 8), .veryHigh)
        XCTAssertEqual(UVLevel.from(index: 11), .extreme)
    }

    @MainActor
    func testUVLevelShouldShowBanner() {
        XCTAssertFalse(UVLevel.low.shouldShowBanner)
        XCTAssertTrue(UVLevel.moderate.shouldShowBanner)
        XCTAssertTrue(UVLevel.high.shouldShowBanner)
        XCTAssertTrue(UVLevel.veryHigh.shouldShowBanner)
        XCTAssertTrue(UVLevel.extreme.shouldShowBanner)
        XCTAssertFalse(UVLevel.unknown.shouldShowBanner)
    }

    @MainActor
    func testUVLevelHighTriggersStrongerReapplyRules() {
        XCTAssertEqual(UVLevel.high.homeHeadline, "UV is high today")
        XCTAssertEqual(UVLevel.high.reapplyAdvanceMinutes, 30)
        XCTAssertEqual(UVLevel.high.reapplyLabelPrefix, "High UV today")
        XCTAssertNotNil(UVLevel.high.strongerReapplyMessage)
    }

    @MainActor
    func testSettingsDefaultValues() {
        let settings = Settings()
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 8)
        XCTAssertEqual(settings.reminderMinute, 0)
        XCTAssertEqual(settings.weeklyHour, 18)
        XCTAssertEqual(settings.weeklyWeekday, 1)
        XCTAssertNil(settings.dailyPhraseState)
        XCTAssertNil(settings.weeklyPhraseState)
        XCTAssertNil(settings.smartReminderSettingsData)
        XCTAssertEqual(settings.longestStreak, 0)
        XCTAssertFalse(settings.reapplyReminderEnabled)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 120)
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)
        XCTAssertEqual(settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 8, minute: 0))
        XCTAssertEqual(settings.smartReminderSettings.weekendTime, ReminderTime(hour: 8, minute: 0))
        XCTAssertTrue(settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertTrue(settings.smartReminderSettings.streakRiskEnabled)
    }

    @MainActor
    func testCloudSyncDefaultsToEnabled() throws {
        let state = try makeAppState()

        XCTAssertTrue(state.syncPreference?.isICloudSyncEnabled ?? false)
        XCTAssertEqual(state.cloudSyncStatusPresentation.title, "iCloud sync is on")
    }

    @MainActor
    func testCloudSyncToggleUpdatesPresentation() async throws {
        let state = try makeAppState()

        state.updateCloudSyncEnabled(false)
        await Task.yield()

        XCTAssertFalse(state.syncPreference?.isICloudSyncEnabled ?? true)
        XCTAssertEqual(state.cloudSyncStatusPresentation.title, "Saved only on this phone")

        state.updateCloudSyncEnabled(true)
        await Task.yield()

        XCTAssertTrue(state.syncPreference?.isICloudSyncEnabled ?? false)
        XCTAssertEqual(state.cloudSyncStatusPresentation.title, "iCloud sync is on")
    }

    @MainActor
    func testDefaultCloudSyncCoordinatorUsesLiveSyncWhenAppGroupContainerIsUnavailableInProductionRuntime() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))
        let runtimeEnvironment = RuntimeEnvironmentSnapshot(
            isRunningTests: false,
            isPreviewing: false,
            hasAppGroupContainer: false
        )

        let coordinator = AppState.defaultCloudSyncCoordinator(
            historyService: historyService,
            runtimeEnvironment: runtimeEnvironment
        )

        XCTAssertTrue(coordinator is CloudSyncCoordinator)
    }

    @MainActor
    func testDefaultCloudSyncCoordinatorUsesNoopSyncForTestsAndPreviews() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let historyService = SunclubHistoryService(context: ModelContext(container))

        let testCoordinator = AppState.defaultCloudSyncCoordinator(
            historyService: historyService,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false
            )
        )
        let previewCoordinator = AppState.defaultCloudSyncCoordinator(
            historyService: historyService,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: true,
                hasAppGroupContainer: false
            )
        )

        XCTAssertTrue(testCoordinator is NoopCloudSyncCoordinator)
        XCTAssertTrue(previewCoordinator is NoopCloudSyncCoordinator)
    }

    @MainActor
    func testAppStateStartsInjectedCloudSyncCoordinatorWhenProductionRuntimeLacksAppGroupContainer() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let coordinator = ProbeCloudSyncCoordinator()

        let state = AppState(
            context: ModelContext(container),
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            cloudSyncCoordinator: coordinator,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: false,
                hasAppGroupContainer: false
            ),
            homeExitReminderMonitor: nil
        )

        await Task.yield()
        await Task.yield()

        XCTAssertEqual(coordinator.startCallCount, 1)
        XCTAssertTrue(state.syncPreference?.isICloudSyncEnabled ?? false)
    }

    @MainActor
    func testDailyRecordMethodRoundTrips() {
        let now = Date()
        let record = DailyRecord(startOfDay: now, verifiedAt: now, method: .manual)
        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.methodRawValue, 1)
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
        XCTAssertFalse(record.hasReapplied)

        record.methodRawValue = 999
        XCTAssertEqual(record.method, .manual)
    }

    @MainActor
    func testAppRouteCasesExist() {
        XCTAssertEqual(AppRoute.history.rawValue, "history")
        XCTAssertEqual(AppRoute.manualLog.rawValue, "manualLog")
        XCTAssertEqual(AppRoute.reapplyCheckIn.rawValue, "reapplyCheckIn")
        XCTAssertEqual(AppRoute.backfillYesterday.rawValue, "backfillYesterday")
        XCTAssertEqual(AppRoute.weeklySummary.rawValue, "weeklySummary")
        XCTAssertEqual(AppRoute.recovery.rawValue, "recovery")
    }

    @MainActor
    func testPreferredCheckInRouteIsReapplyCheckIn() throws {
        let state = try makeAppState()
        XCTAssertEqual(state.preferredCheckInRoute, .reapplyCheckIn)
    }

    @MainActor
    func testPersonalBestBannerOnlyShowsOnImprovement() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual
        )
        let todayRecord = DailyRecord(
            startOfDay: today,
            verifiedAt: calendar.date(byAdding: .hour, value: 9, to: today) ?? today,
            method: .manual
        )
        state.modelContext.insert(yesterdayRecord)
        state.modelContext.insert(todayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertFalse(state.verificationSuccessPresentation?.isPersonalBest ?? true)
    }

    @MainActor
    func testManualLogUpdatesStreakAndLongestStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertGreaterThanOrEqual(state.longestStreak, 2)
        XCTAssertEqual(state.record(for: today)?.method, .manual)
    }

    @MainActor
    func testRecordVerificationSuccessRefreshesStreakRiskReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        await Task.yield()
        XCTAssertEqual(notificationManager.refreshStreakRiskReminderCount, 1)
    }

    @MainActor
    func testSunclubDeepLinkParsesWidgetLogTodayURL() throws {
        let url = try XCTUnwrap(
            URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://widget/log-today")
        )

        XCTAssertEqual(SunclubDeepLink(url: url), .widgetLogToday)
        XCTAssertEqual(SunclubDeepLink.widgetLogToday.url, url)
    }

    @MainActor
    func testWidgetLogTodayDeepLinkRecordsTodayAndRoutesToSuccess() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.record(for: Date())?.method, .manual)
        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 1)
        XCTAssertEqual(state.verificationSuccessPresentation?.canAddDetails, true)
        XCTAssertEqual(router.path, [.verifySuccess])
    }

    @MainActor
    func testWidgetLogTodayDeepLinkSchedulesReapplyReminderWhenEnabled() async throws {
        let notificationManager = MockNotificationManager()
        let daytime = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(
            notificationManager: notificationManager,
            clock: { daytime }
        )
        let router = AppRouter()
        state.completeOnboarding()
        state.updateReapplySettings(enabled: true, intervalMinutes: 90)

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        await Task.yield()
        XCTAssertTrue(handled)
        XCTAssertEqual(notificationManager.scheduleReapplyReminderPlans.map(\.intervalMinutes), [90])
        XCTAssertEqual(notificationManager.scheduleReapplyReminderRoutes, [.reapplyCheckIn])
    }

    @MainActor
    func testRecordReapplicationUpdatesTodayRecordAndCancelsReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        state.markAppliedToday(method: .manual, spfLevel: 50)

        state.recordReapplication()

        await Task.yield()
        let record = try XCTUnwrap(state.record(for: Date()))
        XCTAssertEqual(record.reapplyCount, 1)
        XCTAssertNotNil(record.lastReappliedAt)
        XCTAssertTrue(record.hasReapplied)
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
        XCTAssertEqual(state.reapplyCheckInPresentation?.actionTitle, "Log Another Reapply")
    }

    @MainActor
    func testUndoingDeleteRestoresProjectedRecord() throws {
        let state = try makeAppState()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))

        state.saveManualRecord(for: yesterday, spfLevel: 50, notes: "Beach day")
        state.deleteRecord(for: yesterday)

        let deletedBatch = try XCTUnwrap(state.changeBatches.first(where: { $0.kind == .deleteRecord }))
        XCTAssertNil(state.record(for: yesterday))

        state.undoChange(deletedBatch.id)

        let restored = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertEqual(restored.spfLevel, 50)
        XCTAssertEqual(restored.notes, "Beach day")
    }

    @MainActor
    func testRemoteDayConflictAutoMergesAndCreatesReviewItem() throws {
        let state = try makeAppState()
        let today = Calendar.current.startOfDay(for: Date())
        let verifiedAt = Calendar.current.date(byAdding: .hour, value: 9, to: today) ?? today

        state.saveManualRecord(for: today, verifiedAt: verifiedAt, spfLevel: 30, notes: "Local entry")

        let remoteCreatedAt = Date().addingTimeInterval(60)
        let remoteBatch = SunclubChangeBatch(
            createdAt: remoteCreatedAt,
            kind: .historyEdit,
            scope: .day,
            scopeIdentifier: today.formatted(.iso8601.year().month().day()),
            authorDeviceID: "remote-device",
            summary: "Remote history edit",
            isLocalOnly: false,
            isPublishedToCloud: true,
            cloudPublishedAt: remoteCreatedAt
        )
        state.modelContext.insert(remoteBatch)
        state.modelContext.insert(
            DailyRecordRevision(
                batch: remoteBatch,
                snapshot: DailyRecordProjectionSnapshot(
                    startOfDay: today,
                    verifiedAt: verifiedAt,
                    methodRawValue: VerificationMethod.manual.rawValue,
                    verificationDuration: nil,
                    spfLevel: 50,
                    notes: "Remote entry",
                    reapplyCount: 1,
                    lastReappliedAt: remoteCreatedAt
                ),
                changedFields: [.spfLevel, .notes, .reapplyCount, .lastReappliedAt]
            )
        )
        state.save()

        state.refresh()

        let mergedRecord = try XCTUnwrap(state.record(for: today))
        XCTAssertEqual(mergedRecord.spfLevel, 50)
        XCTAssertEqual(mergedRecord.notes, "Remote entry")
        XCTAssertEqual(mergedRecord.reapplyCount, 1)
        XCTAssertEqual(state.conflicts.count, 1)
        XCTAssertEqual(state.conflicts.first?.scope, .day)
    }

    @MainActor
    func testHomeRecoveryActionsStayQuietForNewUsers() throws {
        let state = try makeAppState()

        XCTAssertTrue(state.homeRecoveryActions.isEmpty)
    }

    @MainActor
    func testHomeRecoveryActionsOfferYesterdayBackfillAfterHabitExists() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in [2, 3, 4] {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: today))
            state.saveManualRecord(for: day, spfLevel: 50, notes: nil)
        }

        XCTAssertEqual(state.homeRecoveryActions.map(\.kind), [.backfillYesterday])
    }

    @MainActor
    func testHomeRecoveryActionsDisappearWhenTodayAndYesterdayAreLogged() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))

        state.saveManualRecord(for: today, spfLevel: 50, notes: nil)
        state.saveManualRecord(for: yesterday, spfLevel: 30, notes: nil)

        XCTAssertTrue(state.homeRecoveryActions.isEmpty)
    }

    @MainActor
    func testReminderCoachingEngineSuggestsWeekdayAndWeekendTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }

        let now = date(year: 2026, month: 4, day: 20, hour: 12, minute: 0)
        let records = [
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 6, hour: 0, minute: 0), verifiedAt: date(year: 2026, month: 4, day: 6, hour: 9, minute: 15), method: .manual),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 13, hour: 0, minute: 0), verifiedAt: date(year: 2026, month: 4, day: 13, hour: 9, minute: 0), method: .manual),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 20, hour: 0, minute: 0), verifiedAt: date(year: 2026, month: 4, day: 20, hour: 9, minute: 30), method: .manual),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 4, hour: 0, minute: 0), verifiedAt: date(year: 2026, month: 4, day: 4, hour: 11, minute: 0), method: .manual),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 5, hour: 0, minute: 0), verifiedAt: date(year: 2026, month: 4, day: 5, hour: 10, minute: 45), method: .manual),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 11, hour: 0, minute: 0), verifiedAt: date(year: 2026, month: 4, day: 11, hour: 11, minute: 15), method: .manual)
        ]
        let settings = SmartReminderSettings(
            weekdayTime: ReminderTime(hour: 8, minute: 0),
            weekendTime: ReminderTime(hour: 8, minute: 0),
            followsTravelTimeZone: true,
            anchoredTimeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier,
            streakRiskEnabled: true
        )

        let suggestions = ReminderCoachingEngine.suggestions(
            from: records,
            settings: settings,
            now: now,
            calendar: calendar
        )

        let weekday = try XCTUnwrap(suggestions.first { $0.kind == .weekday })
        XCTAssertEqual(weekday.typicalLogTime, ReminderTime(hour: 9, minute: 15))
        XCTAssertEqual(weekday.suggestedTime, ReminderTime(hour: 8, minute: 45))

        let weekend = try XCTUnwrap(suggestions.first { $0.kind == .weekend })
        XCTAssertEqual(weekend.typicalLogTime, ReminderTime(hour: 11, minute: 0))
        XCTAssertEqual(weekend.suggestedTime, ReminderTime(hour: 10, minute: 30))
    }

    @MainActor
    func testMonthlyReviewInsightsHighlightBestHardestWeekdayAndMostCommonSPF() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))

        func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }

        let records = [
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 1), verifiedAt: date(year: 2026, month: 4, day: 1, hour: 9), method: .manual, spfLevel: 50),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 3), verifiedAt: date(year: 2026, month: 4, day: 3, hour: 9), method: .manual, spfLevel: 50),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 5), verifiedAt: date(year: 2026, month: 4, day: 5, hour: 10), method: .manual, spfLevel: 30),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 7), verifiedAt: date(year: 2026, month: 4, day: 7, hour: 9), method: .manual, spfLevel: 50),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 8), verifiedAt: date(year: 2026, month: 4, day: 8, hour: 9), method: .manual, spfLevel: 30),
            DailyRecord(startOfDay: date(year: 2026, month: 4, day: 10), verifiedAt: date(year: 2026, month: 4, day: 10, hour: 9), method: .manual, spfLevel: 50)
        ]

        let insights = MonthlyReviewAnalytics.insights(
            from: records,
            month: date(year: 2026, month: 4, day: 15),
            now: date(year: 2026, month: 4, day: 10, hour: 12),
            calendar: calendar
        )

        XCTAssertEqual(insights.bestWeekday?.weekday, 4)
        XCTAssertEqual(insights.hardestWeekday?.weekday, 5)
        XCTAssertEqual(insights.mostCommonSPF?.level, 50)
        XCTAssertEqual(insights.mostCommonSPF?.count, 4)
    }

    @MainActor
    func testNotificationHealthEvaluatorReturnsDeniedAndStalePresentations() {
        let denied = NotificationHealthEvaluator.presentation(
            from: NotificationHealthSnapshot(
                authorizationState: .denied,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            ),
            onboardingComplete: true
        )
        XCTAssertEqual(denied?.state, .denied)
        XCTAssertEqual(denied?.actionTitle, "Open Settings")

        let stale = NotificationHealthEvaluator.presentation(
            from: NotificationHealthSnapshot(
                authorizationState: .authorized,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            ),
            onboardingComplete: true
        )
        XCTAssertEqual(stale?.state, .stale)
        XCTAssertEqual(stale?.actionTitle, "Refresh Reminders")
    }

    @MainActor
    func testRepairReminderScheduleRequestsAuthorizationReschedulesAndRefreshesSnapshot() async throws {
        let notificationManager = MockNotificationManager()
        notificationManager.notificationHealthSnapshotResult = NotificationHealthSnapshot(
            authorizationState: .authorized,
            pendingDailyReminderCount: 2,
            pendingStreakRiskReminderCount: 1,
            pendingReapplyReminderCount: 0,
            lastScheduledAt: Date()
        )
        let state = try makeAppState(notificationManager: notificationManager)

        state.repairReminderSchedule()

        await Task.yield()
        await Task.yield()
        XCTAssertEqual(notificationManager.requestAuthorizationIfNeededCount, 1)
        XCTAssertEqual(notificationManager.scheduleRemindersCount, 1)
        XCTAssertEqual(notificationManager.notificationHealthSnapshotCount, 2)
        XCTAssertEqual(state.notificationHealthSnapshot, notificationManager.notificationHealthSnapshotResult)
    }

    @MainActor
    func testLiveUVStatusPresentationDefaultsToEstimatedUVWhenDisabled() throws {
        let state = try makeAppState()

        XCTAssertEqual(state.liveUVStatusPresentation.title, "Estimated UV")
        XCTAssertNil(state.liveUVStatusPresentation.actionKind)
    }

    @MainActor
    func testWidgetLogTodayDeepLinkDoesNotLogBeforeOnboarding() throws {
        let state = try makeAppState()
        let router = AppRouter()

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertTrue(state.records.isEmpty)
        XCTAssertNil(state.verificationSuccessPresentation)
        XCTAssertTrue(router.path.isEmpty)
    }

    @MainActor
    private func makeAppState(
        notificationManager: NotificationScheduling? = nil,
        homeExitReminderMonitor: HomeExitReminderMonitoring? = nil,
        accountabilityService: SunclubAccountabilityServing? = nil,
        clock: @escaping () -> Date = Date.init
    ) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager ?? NotificationManager.shared,
            uvIndexService: UVIndexService(),
            accountabilityService: accountabilityService,
            homeExitReminderMonitor: homeExitReminderMonitor,
            clock: clock
        )
    }

    private func waitForMainActorTasks() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }

    private func makeAccountabilityInviteEnvelope(
        profileID: UUID = UUID(uuidString: "391D15FD-475F-4EE5-9A85-E68E27980EA8") ?? UUID(),
        snapshotID: UUID = UUID(uuidString: "9C9E0C71-0C6B-46C2-8AC0-32E3AC1EE0E5") ?? UUID(),
        displayName: String,
        currentStreak: Int = 2,
        hasLoggedToday: Bool = false
    ) -> SunclubAccountabilityInviteEnvelope {
        SunclubAccountabilityInviteEnvelope(
            profileID: profileID,
            displayName: displayName,
            relationshipToken: "test-relationship-token",
            issuedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            snapshot: SunclubFriendSnapshot(
                id: snapshotID,
                name: displayName,
                currentStreak: currentStreak,
                longestStreak: 7,
                hasLoggedToday: hasLoggedToday,
                lastSharedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
                seasonStyle: .summerGlow
            )
        )
    }

    @MainActor
    private func makeDailyRecord(
        dayOffset: Int,
        hour: Int = 9,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) -> DailyRecord {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
        let verifiedAt = calendar.date(byAdding: .hour, value: hour, to: day) ?? day

        return DailyRecord(
            startOfDay: day,
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: spfLevel,
            notes: notes
        )
    }
}
