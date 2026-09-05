import Foundation
import SwiftData
import UIKit
import XCTest
@testable import Sunclub

@MainActor
final class SunclubWidgetTests: XCTestCase {
    func testLogTodayPresentationSupportsEveryWidgetFamily() {
        XCTAssertEqual(
            SunclubLogTodayWidgetFamily.allCases.map(\.rawValue),
            [
                "systemSmall",
                "systemMedium",
                "systemLarge",
                "systemExtraLarge",
                "accessoryCircular",
                "accessoryRectangular"
            ]
        )
    }

    func testAccountabilityPresentationSupportsEveryWidgetFamily() throws {
        XCTAssertEqual(
            SunclubAccountabilityWidgetFamily.allCases.map(\.rawValue),
            [
                "systemSmall",
                "systemMedium",
                "systemLarge",
                "systemExtraLarge",
                "accessoryInline",
                "accessoryCircular",
                "accessoryRectangular"
            ]
        )

        for family in SunclubAccountabilityWidgetFamily.allCases {
            let presentation = SunclubAccountabilityWidgetPresentation.make(
                summary: makeAccountabilitySummary(),
                family: family
            )

            XCTAssertEqual(presentation.family, family)
            XCTAssertFalse(presentation.title.isEmpty)
            XCTAssertFalse(presentation.actionText.isEmpty)
            XCTAssertFalse(presentation.detail.isEmpty)
            XCTAssertNotNil(presentation.primaryPokeFriendID)
            XCTAssertEqual(presentation.actionURL, SunclubDeepLink.accountabilityPoke(try XCTUnwrap(presentation.primaryPokeFriendID)).url)
        }
    }

    func testAccountabilityPresentationDoesNotClaimDirectPokeWhenUnavailable() {
        let summary = makeAccountabilitySummary(includePrimaryPokeFriend: false)

        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: summary,
            family: .systemMedium
        )

        XCTAssertEqual(presentation.actionText, "Open")
        XCTAssertTrue(presentation.title.hasPrefix("Message"))
        XCTAssertEqual(presentation.actionURL, SunclubWidgetRoute.accountability.url)
        XCTAssertNil(presentation.primaryPokeFriendID)
    }

    func testAccountabilityInactivePresentationUsesSharingEmptyState() {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: .empty,
            family: .systemSmall
        )

        XCTAssertEqual(presentation.title, "Set up sharing")
        XCTAssertEqual(presentation.detail, "Share whether today is logged.")
        XCTAssertEqual(presentation.actionText, "Set up in app")
        XCTAssertEqual(presentation.iconName, "person.badge.plus.fill")
        XCTAssertFalse(presentation.showsFriendStats)
        XCTAssertEqual(presentation.circularText, "+")
    }

    func testAccountabilityActiveEmptyPresentationDoesNotShowZeroMetricGrid() {
        let summary = SunclubAccountabilitySummary(
            isActive: true,
            friendCount: 0,
            loggedCount: 0,
            openCount: 0,
            topFriends: [],
            latestPoke: nil,
            primaryPokeFriendID: nil,
            latestPokeText: ""
        )

        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: summary,
            family: .systemMedium
        )

        XCTAssertEqual(presentation.title, "Set up sharing")
        XCTAssertEqual(presentation.detail, "Share whether today is logged.")
        XCTAssertEqual(presentation.actionText, "Set up in app")
        XCTAssertFalse(presentation.showsFriendStats)
    }

    func testAccountabilityActiveFriendPresentationShowsPrivateStatus() {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: makeAccountabilitySummary(),
            family: .systemMedium
        )

        XCTAssertEqual(presentation.title, "Remind Maya")
        XCTAssertEqual(presentation.subtitle, "1 friend not logged")
        XCTAssertEqual(presentation.iconName, "person.2.fill")
        XCTAssertTrue(presentation.showsFriendStats)
        XCTAssertEqual(presentation.friends.first?.status, "Not logged")
    }

    func testLogTodayOpenPresentationIsSingleLogSunscreenButton() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            currentUVIndex: 7,
            peakUVIndex: 9
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemSmall,
            calendar: calendar
        )

        XCTAssertEqual(presentation.state, .open)
        XCTAssertEqual(presentation.iconName, "sun.max.fill")
        XCTAssertEqual(presentation.title, "Log Sunscreen")
        XCTAssertEqual(presentation.subtitle, "")
        XCTAssertEqual(presentation.detail, "")
        XCTAssertEqual(presentation.actionText, "Log Sunscreen")
        XCTAssertEqual(presentation.inlineText, "Log Sunscreen")
        XCTAssertEqual(presentation.circularText, "Log")
        XCTAssertEqual(presentation.metrics, [])
        XCTAssertEqual(presentation.accessibilityLabel, "Log Sunscreen")
        XCTAssertEqual(presentation.tapAction, .logTodayInPlace)
        XCTAssertEqual(presentation.homeAction, .logToday)
    }

    func testLogTodayPresentationDoesNotExposeHabitMetadata() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            currentUVIndex: 7,
            peakUVIndex: 9,
            mostUsedSPF: 50
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemMedium,
            calendar: calendar
        )

        XCTAssertEqual(presentation.title, "Log Sunscreen")
        XCTAssertEqual(presentation.actionText, "Log Sunscreen")
        XCTAssertEqual(presentation.metrics, [])
        XCTAssertEqual(presentation.accessibilityLabel, "Log Sunscreen")
    }

    func testLogTodayLoggedPresentationOpensProgress() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 11)
        let lastReappliedAt = try fixedDate(calendar: calendar, hour: 10)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            lastReappliedAt: lastReappliedAt,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemLarge,
            calendar: calendar
        )

        XCTAssertEqual(presentation.state, .logged)
        XCTAssertEqual(presentation.iconName, "checkmark")
        XCTAssertEqual(presentation.title, "")
        XCTAssertEqual(presentation.actionText, "")
        XCTAssertEqual(presentation.detail, "")
        XCTAssertEqual(presentation.metrics, [])
        XCTAssertEqual(presentation.accessibilityLabel, "Sunscreen logged")
        XCTAssertEqual(presentation.tapAction, .open(.summary))
        XCTAssertEqual(presentation.homeAction, .viewProgress)
    }

    func testLogTodayLoggedPresentationIgnoresSPFMetadata() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 11)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            todaySPFLevel: 50,
            mostUsedSPF: 30
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemSmall,
            calendar: calendar
        )

        XCTAssertEqual(presentation.state, .logged)
        XCTAssertEqual(presentation.title, "")
        XCTAssertEqual(presentation.subtitle, "")
        XCTAssertEqual(presentation.metrics, [])
    }

    func testLogTodayPresentationExposesReapplyActionAfterDeadline() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar, hour: 12)
        let lastReappliedAt = try fixedDate(calendar: calendar, hour: 10)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2, 3],
            longestStreak: 9,
            now: now,
            calendar: calendar,
            lastReappliedAt: lastReappliedAt,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemMedium,
            calendar: calendar
        )

        XCTAssertEqual(presentation.state, .open)
        XCTAssertEqual(presentation.iconName, "timer")
        XCTAssertEqual(presentation.actionText, "Reapply now")
        XCTAssertEqual(presentation.accessibilityLabel, "Reapply sunscreen now")
        XCTAssertEqual(presentation.tapAction, .logReapplyInPlace)
        XCTAssertEqual(presentation.homeAction, .logReapply)
    }

    func testLogTodaySetupPresentationStaysNonOpeningLogButton() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [],
            longestStreak: 0,
            now: now,
            calendar: calendar,
            isOnboardingComplete: false
        )

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemSmall,
            calendar: calendar
        )

        XCTAssertEqual(presentation.state, .open)
        XCTAssertEqual(presentation.actionText, "Open Sunclub")
        XCTAssertEqual(presentation.tapAction, .open(.updateToday))
        XCTAssertEqual(presentation.homeAction, .openSettings)
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

        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemMedium,
            calendar: calendar
        )
        XCTAssertEqual(presentation.state, .open)
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

    func testWidgetSnapshotDecodesLegacyPayloadWithoutAccountabilitySummary() throws {
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
        XCTAssertEqual(snapshot.accountabilitySummary, .empty)
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
        XCTAssertEqual(snapshot.accountabilitySummary, .empty)
    }

    func testWidgetSnapshotDecodesPartialAccountabilitySummaryWithDefaults() throws {
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

        XCTAssertTrue(snapshot.accountabilitySummary.isActive)
        XCTAssertEqual(snapshot.accountabilitySummary.friendCount, 2)
        XCTAssertEqual(snapshot.accountabilitySummary.loggedCount, 0)
        XCTAssertTrue(snapshot.accountabilitySummary.topFriends.isEmpty)
        XCTAssertNil(snapshot.accountabilitySummary.latestPoke)
        XCTAssertNil(snapshot.accountabilitySummary.primaryPokeFriendID)
        XCTAssertTrue(snapshot.accountabilitySummary.latestPokeText.isEmpty)
    }

    func testWidgetSnapshotBuilderIncludesAccountabilitySummary() {
        let settings = Settings()
        settings.hasCompletedOnboarding = true
        let growthSettings = makeAccountabilityGrowthSettings()

        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: settings,
            records: [],
            growthSettings: growthSettings
        )

        XCTAssertTrue(snapshot.accountabilitySummary.isActive)
        XCTAssertEqual(snapshot.accountabilitySummary.friendCount, 2)
        XCTAssertEqual(snapshot.accountabilitySummary.loggedCount, 1)
        XCTAssertEqual(snapshot.accountabilitySummary.openCount, 1)
        XCTAssertEqual(snapshot.accountabilitySummary.topFriends.first?.name, "Maya")
        XCTAssertNil(snapshot.accountabilitySummary.primaryPokeFriendID)
        XCTAssertEqual(snapshot.accountabilitySummary.latestPokeText, "You reminded Maya.")
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

    func testHistoryPresentationSummarizesMonthAndCurrentWeek() throws {
        let calendar = fixedCalendar()
        let now = try fixedDate(calendar: calendar)
        let snapshot = makeWidgetSnapshot(
            dayOffsets: [0, 1, 2, 3, 7],
            longestStreak: 6,
            now: now,
            calendar: calendar
        )

        let presentation = SunclubHistoryWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(presentation.title, "July")
        XCTAssertEqual(presentation.compactTitle, "July")
        XCTAssertEqual(presentation.weekSummary, "4/7")
        XCTAssertEqual(presentation.streakSummary, "4d")
        XCTAssertEqual(presentation.monthSummary, "33%")
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
        XCTAssertEqual(snoozed.reapplyStartDate, now)
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

    func testHomeScreenQuickActionStoresManualLogRoute() throws {
        let suiteName = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let shortcutItem = UIApplicationShortcutItem(
            type: SunclubHomeScreenQuickAction.logToday.rawValue,
            localizedTitle: "Log Today"
        )

        XCTAssertTrue(SunclubHomeScreenQuickAction.handleShortcutItem(shortcutItem, routeStore: store))
        XCTAssertEqual(store.takePendingRoute(), .manualLog)
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

    private func makeAccountabilitySummary(includePrimaryPokeFriend: Bool = true) -> SunclubAccountabilitySummary {
        let friendID = UUID(uuidString: "33A0D8B2-3E8E-4C4C-A2BB-B06AE2756A47") ?? UUID()
        return SunclubAccountabilitySummary(
            isActive: true,
            friendCount: 1,
            loggedCount: 0,
            openCount: 1,
            topFriends: [
                SunclubFriendSnapshot(
                    id: friendID,
                    name: "Maya",
                    currentStreak: 2,
                    longestStreak: 5,
                    hasLoggedToday: false,
                    lastSharedAt: Date(),
                    seasonStyle: .summerGlow
                )
            ],
            latestPoke: nil,
            primaryPokeFriendID: includePrimaryPokeFriend ? friendID : nil,
            latestPokeText: "You reminded Maya."
        )
    }

    private func makeAccountabilityGrowthSettings() -> SunclubGrowthSettings {
        let openFriendID = UUID(uuidString: "33A0D8B2-3E8E-4C4C-A2BB-B06AE2756A47") ?? UUID()
        let profileID = UUID(uuidString: "07F5E424-2D67-44FB-8F46-EAC9F4D6A63D") ?? UUID()
        let openFriend = makeFriendSnapshot(id: openFriendID, name: "Maya", streak: 2, hasLoggedToday: false)
        let loggedFriend = makeFriendSnapshot(name: "Rae", streak: 4, hasLoggedToday: true)

        return SunclubGrowthSettings(
            friends: [loggedFriend, openFriend],
            accountability: SunclubAccountabilitySettings(
                activatedAt: Date(),
                connections: [
                    SunclubFriendConnection(
                        friendProfileID: profileID,
                        friendSnapshotID: openFriend.id,
                        friendDisplayName: "Maya",
                        relationshipToken: "widget-token",
                        acceptedAt: Date()
                    )
                ],
                pokeHistory: [
                    SunclubAccountabilityPoke(
                        friendProfileID: profileID,
                        friendName: "Maya",
                        direction: .sent,
                        channel: .direct,
                        status: .sent,
                        message: "Widget poke",
                        createdAt: Date()
                    )
                ]
            )
        )
    }

    private func makeFriendSnapshot(
        id: UUID = UUID(),
        name: String,
        streak: Int,
        hasLoggedToday: Bool
    ) -> SunclubFriendSnapshot {
        SunclubFriendSnapshot(
            id: id,
            name: name,
            currentStreak: streak,
            longestStreak: streak + 3,
            hasLoggedToday: hasLoggedToday,
            lastSharedAt: Date(),
            seasonStyle: .summerGlow
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
