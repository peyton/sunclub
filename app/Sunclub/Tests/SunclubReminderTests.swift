import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubReminderTests: SunclubTestCase {
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

        state.saveManualRecord(for: yesterday, spfLevel: 30, notes: nil)
        state.markAppliedToday(method: .manual)
        await Task.yield()
        let refreshCountBeforeDelete = notificationManager.refreshStreakRiskReminderCount
        state.deleteRecord(for: yesterday)

        await Task.yield()
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 0)
        XCTAssertEqual(
            notificationManager.refreshStreakRiskReminderCount,
            refreshCountBeforeDelete + 1
        )
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
    func testSnoozeReapplyReminderPropagatesSchedulingFailure() async throws {
        let notificationManager = MockNotificationManager()
        notificationManager.notificationOperationResult = .failure("Notifications are off.")
        let daytime = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13))
        )
        let state = try makeAppState(
            notificationManager: notificationManager,
            clock: { daytime }
        )
        state.updateReapplySettings(enabled: true, intervalMinutes: 90)

        let result = await state.snoozeReapplyReminder(minutes: 15)

        XCTAssertFalse(result.isSuccessful)
        XCTAssertEqual(result.message, "Notifications are off.")
        XCTAssertEqual(notificationManager.scheduleReapplyReminderPlans.map(\.intervalMinutes), [15])
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
    func testRecordVerificationSuccessRefreshesStreakRiskReminder() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(notificationManager: notificationManager)

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        await Task.yield()
        XCTAssertEqual(notificationManager.refreshStreakRiskReminderCount, 1)
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
    func testRecordReapplicationUpdatesTodayRecordAndSchedulesNextReminderBeforeSunset() async throws {
        let notificationManager = MockNotificationManager()
        let midday = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(
            notificationManager: notificationManager,
            clock: { midday }
        )
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        state.markAppliedToday(method: .manual, spfLevel: 50)

        state.recordReapplication()

        await Task.yield()
        let record = try XCTUnwrap(state.record(for: midday))
        XCTAssertEqual(record.reapplyCount, 1)
        XCTAssertNotNil(record.lastReappliedAt)
        XCTAssertTrue(record.hasReapplied)
        XCTAssertEqual(notificationManager.scheduleReapplyReminderPlans.map(\.intervalMinutes), [120])
        XCTAssertEqual(notificationManager.scheduleReapplyReminderRoutes, [.reapplyCheckIn])
        XCTAssertEqual(state.reapplyCheckInPresentation?.actionTitle, "Log Another Reapply")
    }

    @MainActor
    func testRecordReapplicationAfterSunsetCancelsReminder() async throws {
        let notificationManager = MockNotificationManager()
        let afterSunset = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 17, minute: 15))
        )
        let state = try makeAppState(
            notificationManager: notificationManager,
            clock: { afterSunset }
        )
        state.updateReapplySettings(enabled: true, intervalMinutes: 60)
        state.markAppliedToday(method: .manual, spfLevel: 50)

        state.recordReapplication()

        await Task.yield()
        let record = try XCTUnwrap(state.record(for: afterSunset))
        XCTAssertEqual(record.reapplyCount, 1)
        XCTAssertTrue(notificationManager.scheduleReapplyReminderPlans.isEmpty)
        XCTAssertEqual(notificationManager.cancelReapplyRemindersCount, 1)
    }

    @MainActor
    func testNextDailyReminderPreviewUsesActualNextFireDate() throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 9, minute: 0))
        )
        let state = try makeAppState(clock: { now })
        state.updateReminderTime(for: .weekday, hour: 8, minute: 30)
        state.updateReminderTime(for: .weekend, hour: 10, minute: 15)

        let preview = try XCTUnwrap(state.nextDailyReminderPreview)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: preview.fireDate)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 30)
        XCTAssertTrue(preview.summary.hasPrefix("Next reminder:"))
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

        let provisional = NotificationHealthEvaluator.presentation(
            from: NotificationHealthSnapshot(
                authorizationState: .provisional,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            ),
            onboardingComplete: true
        )
        XCTAssertEqual(provisional?.state, .stale)
        XCTAssertEqual(provisional?.title, "Quiet reminders need attention")
    }

    @MainActor
    func testNotificationHealthStatusPresentationIncludesHealthyAndQuietStates() {
        let scheduledAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let healthy = NotificationHealthEvaluator.statusPresentation(
            from: NotificationHealthSnapshot(
                authorizationState: .authorized,
                pendingDailyReminderCount: 1,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: scheduledAt
            ),
            onboardingComplete: true
        )
        XCTAssertEqual(healthy?.title, "Notifications are ready")
        XCTAssertEqual(healthy?.needsAttention, false)

        let quiet = NotificationHealthEvaluator.statusPresentation(
            from: NotificationHealthSnapshot(
                authorizationState: .provisional,
                pendingDailyReminderCount: 1,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: scheduledAt
            ),
            onboardingComplete: true
        )
        XCTAssertEqual(quiet?.title, "Quiet reminders are ready")
        XCTAssertEqual(quiet?.needsAttention, false)

        let denied = NotificationHealthEvaluator.statusPresentation(
            from: NotificationHealthSnapshot(
                authorizationState: .denied,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            ),
            onboardingComplete: true
        )
        XCTAssertEqual(denied?.title, "Notifications are off")
        XCTAssertEqual(denied?.needsAttention, true)

        let notDetermined = NotificationHealthEvaluator.statusPresentation(
            from: NotificationHealthSnapshot(
                authorizationState: .notDetermined,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            ),
            onboardingComplete: true
        )
        XCTAssertEqual(notDetermined?.title, "Allow notifications?")
        XCTAssertEqual(notDetermined?.actionTitle, "Allow Notifications")
        XCTAssertEqual(notDetermined?.actionKind, .requestPermission)
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
}
