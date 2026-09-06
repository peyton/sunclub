import Foundation
import SwiftData
import UIKit
import XCTest
@testable import Sunclub

@MainActor
final class SunclubWidgetTests: XCTestCase {
    func testUnloggedWidgetOffersFirstApplicationAndTodayDestination() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(dayOffsets: [1], longestStreak: 1, now: now, calendar: calendar)
        let status = snapshot.applicationStatus(now: now, calendar: calendar)
        XCTAssertFalse(status.hasLoggedToday)
        XCTAssertEqual(status.actionTitle, "Log sunscreen")
        XCTAssertNil(status.lastAppliedAt)
        XCTAssertNil(status.reapplyDeadline)
        XCTAssertEqual(SunclubWidgetRoute.today.appRoute, .home)
        XCTAssertEqual(SunclubWidgetRoute.updateToday.appRoute, .manualLog)
    }

    func testLoggedWidgetOffersEarlyReapplicationWithRemindersOnOrOff() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 10)
        for enabled in [false, true] {
            let snapshot = makeWidgetSnapshot(dayOffsets: [0], longestStreak: 1, now: now, calendar: calendar,
                                              reapplyReminderEnabled: enabled)
            let status = snapshot.applicationStatus(now: now, calendar: calendar)
            XCTAssertEqual(status.actionTitle, "Log reapplication")
            XCTAssertEqual(status.lastAppliedAt, try fixedDate(calendar: calendar, hour: 9))
            XCTAssertFalse(status.isReapplyDue)
            XCTAssertEqual(status.reapplyDeadline != nil, enabled)
        }
    }

    func testWidgetUsesLatestCurrentDayApplicationAndDueState() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 12)
        let reapplied = try fixedDate(calendar: calendar, hour: 10)
        let snapshot = makeWidgetSnapshot(dayOffsets: [0], longestStreak: 1, now: now, calendar: calendar,
                                          lastReappliedAt: reapplied, reapplyReminderEnabled: true,
                                          reapplyIntervalMinutes: 90)
        let status = snapshot.applicationStatus(now: now, calendar: calendar)
        XCTAssertEqual(status.lastAppliedAt, reapplied)
        XCTAssertTrue(status.isReapplyDue)
        XCTAssertEqual(status.title, "Reapply due")
        XCTAssertEqual(status.actionTitle, "Log reapplication")
    }

    func testStaleReapplyDoesNotHideTodaysFirstApplication() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 10)
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let snapshot = makeWidgetSnapshot(dayOffsets: [0], longestStreak: 1, now: now, calendar: calendar,
                                          lastReappliedAt: yesterday, reapplyReminderEnabled: true)
        XCTAssertEqual(snapshot.applicationStatus(now: now, calendar: calendar).lastAppliedAt,
                       try fixedDate(calendar: calendar, hour: 9))
        XCTAssertEqual(snapshot.reapplyDeadline(now: now, calendar: calendar),
                       try fixedDate(calendar: calendar, hour: 11))
    }

    func testMidnightDropsPreviousDayApplicationAndTimer() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 23)
        let midnight = try XCTUnwrap(calendar.dateInterval(of: .day, for: now)?.end)
        let snapshot = makeWidgetSnapshot(dayOffsets: [0], longestStreak: 1, now: now, calendar: calendar,
                                          lastReappliedAt: now, reapplyReminderEnabled: true)
        XCTAssertEqual(snapshot.nextTimelineRefreshDate(after: now, calendar: calendar), midnight)
        let status = snapshot.applicationStatus(now: midnight, calendar: calendar)
        XCTAssertFalse(status.hasLoggedToday)
        XCTAssertNil(status.lastAppliedAt)
        XCTAssertNil(status.reapplyDeadline)
        XCTAssertEqual(status.actionTitle, "Log sunscreen")
    }

    func testIncompleteSetupOffersForegroundEntryWithoutLoggingClaim() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(dayOffsets: [], longestStreak: 0, now: now, calendar: calendar,
                                          isOnboardingComplete: false)
        let status = snapshot.applicationStatus(now: now, calendar: calendar)
        XCTAssertFalse(status.isSetupComplete)
        XCTAssertEqual(status.actionTitle, "Open Sunclub")
    }

    func testReapplyDeadlineIgnoresExpiredTimerFromYesterday() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 12)
        let yesterdayReapply = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            lastReappliedAt: yesterdayReapply,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )

        XCTAssertNil(snapshot.reapplyDeadline(now: now, calendar: calendar))

        XCTAssertFalse(snapshot.applicationStatus(now: now, calendar: calendar).hasLoggedToday)
    }

    func testSnapshotShowsTodayOpenWhenLatestRecordIsYesterday() {
        let snapshot = makeSnapshot(dayOffsets: [1, 2, 3], longestStreak: 7)

        XCTAssertFalse(snapshot.hasLoggedToday())
        XCTAssertEqual(snapshot.streakValue(), 3)
        XCTAssertEqual(snapshot.weeklyValue(), 3)
    }

    func testSnapshotShowsLoggedTodayAndRetainsStreak() {
        let snapshot = makeSnapshot(dayOffsets: [0, 1, 2, 3], longestStreak: 8)

        XCTAssertTrue(snapshot.hasLoggedToday())
        XCTAssertEqual(snapshot.streakValue(), 4)
    }

    func testSnapshotResetsStreakAfterMissedYesterday() {
        let snapshot = makeSnapshot(dayOffsets: [2, 3, 4], longestStreak: 9)

        XCTAssertFalse(snapshot.hasLoggedToday())
        XCTAssertEqual(snapshot.streakValue(), 0)
    }

    func testSnapshotCalculatesMonthlyCountsFromRecordedDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentMonthRecord = makeRecord(day: today, spfLevel: 50)
        let olderRecord = makeRecord(day: calendar.date(byAdding: .month, value: -1, to: today) ?? today, spfLevel: 30)

        let settings = Settings()
        settings.hasCompletedOnboarding = true
        let snapshot = SunclubWidgetSnapshotBuilder.make(settings: settings, records: [currentMonthRecord, olderRecord])

        XCTAssertEqual(snapshot.monthlyAppliedValue(now: today, calendar: calendar), 1)
        XCTAssertGreaterThanOrEqual(snapshot.monthlyDayValue(now: today, calendar: calendar), 1)
        XCTAssertEqual(snapshot.todaySPFLevel, 50)
        XCTAssertEqual(snapshot.mostUsedSPF, 50)
    }

    func testSnapshotNextTimelineRefreshUsesReapplyDeadlineBeforeMidnight() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 11)
        let lastReappliedAt = try fixedDate(calendar: calendar, hour: 10)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2],
            longestStreak: 6,
            now: now,
            calendar: calendar,
            lastReappliedAt: lastReappliedAt,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )

        let refreshDate = snapshot.nextTimelineRefreshDate(after: now, calendar: calendar)

        XCTAssertEqual(refreshDate, try fixedDate(calendar: calendar, hour: 11, minute: 30))
    }

    func testSnapshotUVExpiresAfterEightHoursAndRequestsARefresh() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 11)
        let validUntil = now.addingTimeInterval(8 * 60 * 60)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0],
            longestStreak: 1,
            now: now,
            calendar: calendar,
            currentUVIndex: 7,
            peakUVIndex: 9,
            uvValidUntil: validUntil
        )

        XCTAssertEqual(snapshot.currentUVIndex(at: now), 7)
        XCTAssertEqual(snapshot.peakUVIndex(at: now), 9)
        XCTAssertNil(snapshot.currentUVIndex(at: validUntil.addingTimeInterval(1)))
        XCTAssertNil(snapshot.peakUVIndex(at: validUntil.addingTimeInterval(1)))
        XCTAssertEqual(
            snapshot.nextTimelineRefreshDate(after: now, calendar: calendar),
            validUntil.addingTimeInterval(1)
        )
    }

    func testWidgetSnapshotDecodesLegacyPayload() throws {
        let data = Data("""
        {
            "isOnboardingComplete": true,
            "lastLoggedDay": null,
            "lastVerifiedAt": null,
            "lastReappliedAt": null,
            "recordedDays": [],
            "currentStreak": 0,
            "longestStreak": 3,
            "weeklyAppliedCount": 0,
            "monthlyAppliedCount": 0,
            "monthlyDayCount": 0,
            "mostUsedSPF": null,
            "currentUVIndex": null,
            "peakUVIndex": null,
            "peakUVHour": null,
            "reapplyReminderEnabled": false,
            "reapplyIntervalMinutes": 120
        }
        """.utf8)

        let snapshot = try JSONDecoder().decode(SunclubWidgetSnapshot.self, from: data)

        XCTAssertEqual(snapshot.longestStreak, 3)
        XCTAssertNil(snapshot.todaySPFLevel)
    }

    func testWidgetSnapshotDecodesMinimalLegacyPayloadWithDefaults() throws {
        let data = Data("""
        {
            "isOnboardingComplete": true
        }
        """.utf8)

        let snapshot = try JSONDecoder().decode(SunclubWidgetSnapshot.self, from: data)

        XCTAssertTrue(snapshot.isOnboardingComplete)
        XCTAssertTrue(snapshot.recordedDays.isEmpty)
        XCTAssertEqual(snapshot.currentStreak, 0)
        XCTAssertEqual(snapshot.longestStreak, 0)
        XCTAssertEqual(snapshot.weeklyAppliedCount, 0)
        XCTAssertEqual(snapshot.monthlyAppliedCount, 0)
        XCTAssertEqual(snapshot.monthlyDayCount, 0)
        XCTAssertFalse(snapshot.reapplyReminderEnabled)
        XCTAssertEqual(snapshot.reapplyIntervalMinutes, 120)
    }

    func testWidgetSnapshotIgnoresRetiredPayloadFields() throws {
        let data = Data("""
        {
            "isOnboardingComplete": true,
            "lastLoggedDay": null,
            "lastVerifiedAt": null,
            "lastReappliedAt": null,
            "recordedDays": [],
            "currentStreak": 0,
            "longestStreak": 3,
            "weeklyAppliedCount": 0,
            "monthlyAppliedCount": 0,
            "monthlyDayCount": 0,
            "mostUsedSPF": null,
            "currentUVIndex": null,
            "peakUVIndex": null,
            "peakUVHour": null,
            "reapplyReminderEnabled": false,
            "reapplyIntervalMinutes": 120,
            "accountabilitySummary": {
                "isActive": true,
                "friendCount": 2
            }
        }
        """.utf8)

        let snapshot = try JSONDecoder().decode(SunclubWidgetSnapshot.self, from: data)

        XCTAssertTrue(snapshot.isOnboardingComplete)
        XCTAssertEqual(snapshot.longestStreak, 3)
        XCTAssertEqual(snapshot.reapplyIntervalMinutes, 120)
        let encoded = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(object["accountabilitySummary"])
    }

    func testSnapshotDayStatusUsesStoredCalendarHistory() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let snapshot = makeSnapshot(dayOffsets: [1], longestStreak: 4)

        XCTAssertEqual(snapshot.dayStatus(for: today, now: today, calendar: calendar), .todayPending)
        XCTAssertEqual(snapshot.dayStatus(for: yesterday, now: today, calendar: calendar), .applied)
        XCTAssertEqual(snapshot.dayStatus(for: tomorrow, now: today, calendar: calendar), .future)
    }

    func testCurrentWeekAppliedValueMatchesWeekStripDays() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2, 3, 7],
            longestStreak: 6,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.currentWeekAppliedValue(now: now, calendar: calendar), 4)
    }

    func testSunclubDeepLinkParsesWidgetRoutes() throws {
        let scheme = SunclubRuntimeConfiguration.urlScheme
        let summaryURL = try XCTUnwrap(URL(string: "\(scheme)://widget/open/summary"))
        let historyURL = try XCTUnwrap(URL(string: "\(scheme)://widget/open/history"))
        let updateURL = try XCTUnwrap(URL(string: "\(scheme)://widget/open/updateToday"))

        XCTAssertEqual(SunclubDeepLink(url: summaryURL), .widgetRoute(.summary))
        XCTAssertEqual(SunclubDeepLink(url: historyURL), .widgetRoute(.history))
        XCTAssertEqual(SunclubDeepLink(url: updateURL), .widgetRoute(.updateToday))
    }

    func testWatchSyncPayloadRoundTripsSnapshotContext() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2],
            longestStreak: 5,
            now: now,
            calendar: calendar,
            currentUVIndex: 8,
            peakUVIndex: 10
        )

        let context = try XCTUnwrap(SunclubWatchSyncPayload.context(snapshot: snapshot, message: "Status updated."))
        let decodedSnapshot = try XCTUnwrap(SunclubWatchSyncPayload.decodeSnapshot(from: context))

        XCTAssertEqual(decodedSnapshot, snapshot)
        XCTAssertEqual(context[SunclubWatchSyncPayload.successKey] as? Bool, true)
        XCTAssertEqual(context[SunclubWatchSyncPayload.messageKey] as? String, "Status updated.")
    }

    func testWatchSyncPayloadRejectsMalformedSnapshotData() {
        let payload: [String: Any] = [
            SunclubWatchSyncPayload.snapshotKey: Data("not-json".utf8)
        ]

        XCTAssertNil(SunclubWatchSyncPayload.decodeSnapshot(from: payload))
    }

    func testWatchSyncRepliesCarrySuccessAndFailureState() throws {
        let snapshot = makeSnapshot(dayOffsets: [1], longestStreak: 4)
        let successReply = SunclubWatchSyncPayload.successReply(
            snapshot: snapshot,
            message: "Logged from your wrist."
        )
        let errorReply = SunclubWatchSyncPayload.errorReply("Open Sunclub once to finish setup.")

        XCTAssertEqual(successReply[SunclubWatchSyncPayload.successKey] as? Bool, true)
        XCTAssertEqual(successReply[SunclubWatchSyncPayload.messageKey] as? String, "Logged from your wrist.")
        XCTAssertEqual(try XCTUnwrap(SunclubWatchSyncPayload.decodeSnapshot(from: successReply)), snapshot)
        XCTAssertEqual(errorReply[SunclubWatchSyncPayload.successKey] as? Bool, false)
        XCTAssertEqual(errorReply[SunclubWatchSyncPayload.messageKey] as? String, "Open Sunclub once to finish setup.")
        XCTAssertNil(SunclubWatchSyncPayload.decodeSnapshot(from: errorReply))
    }

    func testLiveActivityCountdownUsesActiveReapplyCopy() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 12)
        let deadline = try fixedDate(calendar: calendar, hour: 13, minute: 20)

        XCTAssertEqual(
            SunclubLiveActivityCoordinator.reapplyCountdownLabel(deadline: deadline, now: now),
            "in 1h 20m"
        )
        XCTAssertEqual(
            SunclubLiveActivityCoordinator.reapplyCountdownLabel(deadline: now, now: now),
            "due"
        )
    }

    func testLiveActivityContentStateCarriesReapplyDatesAndUVPillCopy() throws {
        let calendar = fixedCalendar()
        let verifiedAt = try fixedDate(calendar: calendar, hour: 9)
        let reappliedAt = try fixedDate(calendar: calendar, hour: 11, minute: 15)
        let deadline = try fixedDate(calendar: calendar, hour: 13, minute: 15)
        let record = DailyRecord(
            startOfDay: try fixedDate(calendar: calendar, hour: 0),
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: 50,
            lastReappliedAt: reappliedAt
        )
        let payload = SunclubLiveActivityUVPayload(currentUVIndex: 6, peakUVIndex: 8, level: .high)

        let state = SunclubLiveActivityCoordinator.contentState(
            record: record,
            uvPayload: payload,
            reapplyStartDate: reappliedAt,
            reapplyDeadline: deadline,
            now: try fixedDate(calendar: calendar, hour: 12)
        )

        XCTAssertEqual(state.reapplyStartDate, reappliedAt)
        XCTAssertEqual(state.reapplyDeadline, deadline)
        XCTAssertEqual(state.reapplyInterval?.lowerBound, reappliedAt)
        XCTAssertEqual(state.reapplyInterval?.upperBound, deadline)
        XCTAssertEqual(state.uvPillLabel, "UV 6 High")
        XCTAssertEqual(state.appliedLabel, "Applied \(state.lastAppliedLabel)")
        XCTAssertEqual(state.statusTitle(now: try fixedDate(calendar: calendar, hour: 12)), "Reapply in")
        XCTAssertTrue(try XCTUnwrap(state.nextReapplyLabel(now: try fixedDate(calendar: calendar, hour: 12))).hasPrefix("Next "))
    }

    func testLiveActivityDueStateOmitsNextReapplyLabel() throws {
        let calendar = fixedCalendar()
        let verifiedAt = try fixedDate(calendar: calendar, hour: 9)
        let deadline = try fixedDate(calendar: calendar, hour: 11)
        let record = DailyRecord(
            startOfDay: try fixedDate(calendar: calendar, hour: 0),
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: 50
        )
        let payload = SunclubLiveActivityUVPayload(currentUVIndex: 7, peakUVIndex: 8, level: .high)

        let state = SunclubLiveActivityCoordinator.contentState(
            record: record,
            uvPayload: payload,
            reapplyStartDate: verifiedAt,
            reapplyDeadline: deadline,
            now: deadline
        )

        XCTAssertEqual(state.countdownLabel, "due")
        XCTAssertTrue(state.isReapplyDue(now: deadline))
        XCTAssertEqual(state.statusTitle(now: deadline), "Reapply due")
        XCTAssertEqual(state.fallbackTimerText(now: deadline), "Due")
        XCTAssertNil(state.nextReapplyLabel(now: deadline))
        XCTAssertEqual(state.accessibilitySummary(now: deadline), "Reapply due. UV 7 High. \(state.appliedLabel).")
    }

    func testLiveActivityFallsBackToCountdownWhenDatesAreMissing() {
        let state = SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: 6,
            peakUVIndex: 6,
            countdownLabel: "in 1h 29m",
            lastAppliedLabel: "11:59 AM",
            lastLogDetail: "SPF 50",
            reapplyStartDate: nil,
            reapplyDeadline: nil,
            uvValidUntil: .distantFuture
        )

        XCTAssertNil(state.reapplyInterval)
        XCTAssertFalse(state.isReapplyDue())
        XCTAssertEqual(state.statusTitle(), "Reapply in")
        XCTAssertEqual(state.fallbackTimerText(), "1h 29m")
        XCTAssertEqual(state.uvPillLabel, "UV 6 High")
    }

    func testLiveActivitySnoozeMovesCountdownWithoutChangingUVOrLogDetails() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 12)
        let deadline = try XCTUnwrap(calendar.date(byAdding: .minute, value: 30, to: now))
        let original = SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: 7,
            peakUVIndex: 9,
            countdownLabel: "due",
            lastAppliedLabel: "10:00 AM",
            lastLogDetail: "SPF 50",
            reapplyStartDate: now.addingTimeInterval(-7_200),
            reapplyDeadline: now,
            uvValidUntil: now.addingTimeInterval(60 * 60)
        )

        let snoozed = SunclubLiveActivityCoordinator.snoozedContentState(
            original,
            until: deadline,
            now: now
        )

        XCTAssertEqual(snoozed.countdownLabel, "in 30m")
        XCTAssertEqual(snoozed.reapplyStartDate, original.reapplyStartDate)
        XCTAssertEqual(snoozed.reapplyDeadline, deadline)
        XCTAssertEqual(snoozed.currentUVIndex, original.currentUVIndex)
        XCTAssertEqual(snoozed.lastLogDetail, original.lastLogDetail)
        XCTAssertEqual(snoozed.uvValidUntil, original.uvValidUntil)
    }

    func testLiveActivityUVBecomesUnavailableAfterVerifiedWindow() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 12)
        let state = SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: 7,
            peakUVIndex: 9,
            countdownLabel: "in 1h",
            lastAppliedLabel: "11:00 AM",
            lastLogDetail: "SPF 50",
            reapplyStartDate: now,
            reapplyDeadline: now.addingTimeInterval(60 * 60),
            uvValidUntil: now.addingTimeInterval(2 * 60 * 60)
        )

        XCTAssertEqual(state.uvPillLabel(now: now), "UV 7 High")
        XCTAssertEqual(
            state.uvPillLabel(now: now.addingTimeInterval(2 * 60 * 60 + 1)),
            "UV unavailable"
        )
    }

    func testLiveActivityLastLogDetailUsesSPFWithoutStreak() throws {
        let calendar = fixedCalendar()
        let record = DailyRecord(
            startOfDay: try fixedDate(calendar: calendar, hour: 0),
            verifiedAt: try fixedDate(calendar: calendar, hour: 8, minute: 20),
            method: .manual,
            spfLevel: 50
        )

        XCTAssertEqual(SunclubLiveActivityCoordinator.lastLogDetail(for: record), "SPF 50")
    }

    func testWidgetSummaryRouteOpensWeeklySummary() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetRoute(.summary), appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.selectedTab, .history)
        XCTAssertEqual(router.path, [.weeklySummary])
    }

    func testWidgetHistoryRouteOpensHistory() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetRoute(.history), appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.selectedTab, .history)
        XCTAssertTrue(router.path.isEmpty)
    }

    func testWidgetUpdateRouteOpensManualLog() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetRoute(.updateToday), appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(router.path, [.manualLog])
    }

    func testPendingRouteStoreRoundTripsAppRoutes() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SunclubWidgetSnapshotStore(userDefaults: defaults)

        store.setPendingRoute(.manualLog)

        XCTAssertEqual(store.takePendingRoute(), .manualLog)
        XCTAssertNil(store.takePendingRoute())
    }

    func testPendingRouteStoreReadsLegacyWidgetRouteValues() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SunclubWidgetSnapshotStore(userDefaults: defaults)
        defaults.set(SunclubWidgetRoute.updateToday.rawValue, forKey: SunclubWidgetDefaults.pendingRouteKey)

        XCTAssertEqual(store.takePendingRoute(), .manualLog)
    }

    func testHomeScreenQuickActionOpensTodayWithoutWriting() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let shortcutItem = UIApplicationShortcutItem(
            type: SunclubHomeScreenQuickAction.logToday.rawValue,
            localizedTitle: "Log sunscreen"
        )

        XCTAssertTrue(SunclubHomeScreenQuickAction.handleShortcutItem(shortcutItem, routeStore: store))
        XCTAssertEqual(store.takePendingRoute(), .home)
    }

    private func makeSnapshot(dayOffsets: [Int], longestStreak: Int) -> SunclubWidgetSnapshot {
        let settings = Settings()
        settings.hasCompletedOnboarding = true
        settings.longestStreak = longestStreak

        let records = dayOffsets.map { offset in
            makeRecord(day: Calendar.current.date(byAdding: .day, value: -offset, to: Calendar.current.startOfDay(for: Date())) ?? Date())
        }

        return SunclubWidgetSnapshotBuilder.make(settings: settings, records: records)
    }

    private func makeRecord(day: Date, spfLevel: Int? = 50) -> DailyRecord {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay

        return DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: spfLevel
        )
    }

    private func makeWidgetSnapshot(
        dayOffsets: [Int],
        longestStreak: Int,
        now: Date,
        calendar: Calendar,
        isOnboardingComplete: Bool = true,
        currentUVIndex: Int? = nil,
        peakUVIndex: Int? = nil,
        uvValidUntil: Date? = nil,
        todaySPFLevel: Int? = nil,
        mostUsedSPF: Int? = nil,
        lastReappliedAt: Date? = nil,
        reapplyReminderEnabled: Bool = false,
        reapplyIntervalMinutes: Int = 120
    ) -> SunclubWidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        let recordedDays = dayOffsets.compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.sorted()
        let lastLoggedDay = recordedDays.last

        return SunclubWidgetSnapshot(
            isOnboardingComplete: isOnboardingComplete,
            lastLoggedDay: lastLoggedDay,
            lastVerifiedAt: lastLoggedDay.flatMap {
                calendar.date(byAdding: .hour, value: 9, to: $0)
            },
            lastReappliedAt: lastReappliedAt,
            recordedDays: recordedDays,
            currentStreak: 0,
            longestStreak: longestStreak,
            weeklyAppliedCount: 0,
            monthlyAppliedCount: 0,
            monthlyDayCount: 0,
            todaySPFLevel: todaySPFLevel,
            mostUsedSPF: mostUsedSPF,
            currentUVIndex: currentUVIndex,
            peakUVIndex: peakUVIndex,
            peakUVHour: peakUVIndex == nil ? nil : calendar.date(byAdding: .hour, value: 13, to: today),
            uvValidUntil: uvValidUntil,
            reapplyReminderEnabled: reapplyReminderEnabled,
            reapplyIntervalMinutes: reapplyIntervalMinutes
        )
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 1
        return calendar
    }

    private func fixedDate(calendar: Calendar, hour: Int = 12) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: hour))
        )
    }

    private func fixedDate(calendar: Calendar, hour: Int, minute: Int) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: hour, minute: minute))
        )
    }

    private func makeAppState(
        notificationManager: NotificationScheduling? = nil
    ) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager ?? NotificationManager.shared
        )
    }
}
