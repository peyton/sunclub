import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubHomePresentationTests: SunclubTestCase {
    @MainActor
    func testTodayCardPresentationShowsHighUVMessaging() throws {
        let state = try makeAppState()

        state.setUVReadingForTesting(UVReading(index: 7))

        let presentation = state.todayCardPresentation
        XCTAssertEqual(presentation.title, "Ready for today's log")
        XCTAssertEqual(presentation.uvHeadline, "UV is high today")
        XCTAssertEqual(presentation.uvSymbolName, UVLevel.high.symbolName)
        XCTAssertTrue(presentation.detail.contains("product label"))
    }

    @MainActor
    func testTodayCardPresentationKeepsDefaultDetailForModerateUV() throws {
        let state = try makeAppState()

        state.setUVReadingForTesting(UVReading(index: 4))

        let presentation = state.todayCardPresentation
        XCTAssertEqual(presentation.uvHeadline, "UV is moderate today")
        XCTAssertEqual(presentation.detail, "Add a log to start your reminder.")
    }

    @MainActor
    func testTodayCardPresentationShowsLoggedMetadataRows() throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 10, minute: 0))
        )
        let peakDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 13, minute: 0))
        )
        let peakHour = SunclubUVHourForecast(
            date: peakDate,
            index: 7,
            sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
        )
        let state = try makeAppState(clock: { now })
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        state.setUVReadingForTesting(UVReading(index: 7, timestamp: now, source: .weatherKit))
        state.setUVForecastForTesting(
            SunclubUVForecast(
                generatedAt: now,
                sourceLabel: UVReadingSource.weatherKit.forecastLabel,
                hours: [peakHour],
                peakHour: peakHour,
                recommendation: "High UV today."
            )
        )
        state.modelContext.insert(
            DailyRecord(
                startOfDay: calendar.startOfDay(for: now),
                verifiedAt: now,
                method: .manual,
                spfLevel: 50,
                notes: "Beach bag"
            )
        )
        state.refresh()

        let presentation = state.todayCardPresentation
        let rows = Dictionary(uniqueKeysWithValues: presentation.metadataRows.map { ($0.id, $0) })

        XCTAssertEqual(presentation.metadataRows.map(\.id), ["logged", "spf", "notes", "reapply", "uvPeak", "uvSource"])
        XCTAssertEqual(rows["logged"]?.title, "Last Saved")
        XCTAssertEqual(rows["spf"]?.value, "SPF 50")
        XCTAssertEqual(rows["notes"]?.value, "Saved")
        XCTAssertEqual(rows["reapply"]?.value, "Label check in 2h")
        XCTAssertEqual(rows["uvSource"]?.value, UVReadingSource.weatherKit.forecastLabel)
        XCTAssertTrue(presentation.accessibilityValue.contains("SPF: SPF 50"))
    }

    @MainActor
    func testTodayCardPresentationRejectsUnverifiedForecastRows() throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 9, minute: 0))
        )
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)))
        let peakDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 12, minute: 0))
        )
        let peakHour = SunclubUVHourForecast(date: peakDate, index: 5, sourceLabel: "Legacy estimate")
        let state = try makeAppState(clock: { now })
        state.updateReminderTime(for: .weekday, hour: 8, minute: 30)
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        state.setUVForecastForTesting(
            SunclubUVForecast(
                generatedAt: now,
                sourceLabel: "Legacy estimate",
                hours: [peakHour],
                peakHour: peakHour,
                recommendation: "Moderate UV today."
            )
        )
        state.modelContext.insert(
            DailyRecord(
                startOfDay: yesterday,
                verifiedAt: yesterday,
                method: .manual
            )
        )
        state.refresh()

        let presentation = state.todayCardPresentation
        let rows = Dictionary(uniqueKeysWithValues: presentation.metadataRows.map { ($0.id, $0) })

        XCTAssertEqual(presentation.metadataRows.map(\.id), ["reminder", "reapply"])
        XCTAssertTrue(rows["reminder"]?.value.contains("Weekdays") == true)
        XCTAssertEqual(rows["reapply"]?.value, "After today's log")
        XCTAssertNil(rows["uvSource"])
    }

    @MainActor
    func testTodayCardPresentationShowsReapplyCountBadge() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oneReapplyState = try makeAppState()
        oneReapplyState.modelContext.insert(
            DailyRecord(
                startOfDay: today,
                verifiedAt: today,
                method: .manual,
                reapplyCount: 1
            )
        )
        oneReapplyState.refresh()

        XCTAssertEqual(oneReapplyState.todayCardPresentation.logBadgeText, "Logged + 1 reapply")

        let multipleReapplyState = try makeAppState()
        multipleReapplyState.modelContext.insert(
            DailyRecord(
                startOfDay: today,
                verifiedAt: today,
                method: .manual,
                reapplyCount: 3
            )
        )
        multipleReapplyState.refresh()

        XCTAssertEqual(multipleReapplyState.todayCardPresentation.logBadgeText, "Logged + 3 reapplies")
    }

    @MainActor
    func testTodayCardPresentationShowsStreakRiskOnlyAfterSixWhenUnlogged() throws {
        let calendar = Calendar.current
        let evening = try XCTUnwrap(
            calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date())
        )
        let beforeRiskWindow = try XCTUnwrap(
            calendar.date(bySettingHour: 17, minute: 59, second: 0, of: Date())
        )
        let yesterday = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: evening))
        )

        let atRiskState = try makeAppState(clock: { evening })
        atRiskState.modelContext.insert(
            DailyRecord(
                startOfDay: yesterday,
                verifiedAt: yesterday,
                method: .manual
            )
        )
        atRiskState.refresh()

        XCTAssertEqual(atRiskState.todayCardPresentation.streakRiskBadgeText, "Today still open")

        let earlyState = try makeAppState(clock: { beforeRiskWindow })
        earlyState.modelContext.insert(
            DailyRecord(
                startOfDay: yesterday,
                verifiedAt: yesterday,
                method: .manual
            )
        )
        earlyState.refresh()

        XCTAssertNil(earlyState.todayCardPresentation.streakRiskBadgeText)

        let loggedState = try makeAppState(clock: { evening })
        loggedState.modelContext.insert(
            DailyRecord(
                startOfDay: calendar.startOfDay(for: evening),
                verifiedAt: evening,
                method: .manual
            )
        )
        loggedState.refresh()

        XCTAssertNil(loggedState.todayCardPresentation.streakRiskBadgeText)
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
    func testHomeDailyPlanStartsWithLogToday() throws {
        let morning = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 9, minute: 0))
        )
        let state = try makeAppState(clock: { morning })

        let presentation = state.homeDailyPlanPresentation

        XCTAssertEqual(presentation.action, .logToday)
        XCTAssertEqual(presentation.actionTitle, "Log Today")
        XCTAssertEqual(presentation.tone, .action)
        XCTAssertTrue(presentation.facts.contains(where: { $0.id == "reminder" }))
    }

    @MainActor
    func testHomeDailyPlanOffersDetailsAfterBareLog() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual)

        let presentation = state.homeDailyPlanPresentation
        XCTAssertEqual(presentation.action, .addDetails)
        XCTAssertEqual(presentation.actionTitle, "Add SPF or Note")
        XCTAssertEqual(presentation.tone, .calm)
    }

    @MainActor
    func testHomeDailyPlanPrioritizesYesterdayBackfillAfterTodayIsLogged() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        state.saveManualRecord(for: today, spfLevel: 50, notes: "Today")
        for offset in [2, 3, 4] {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: today))
            state.saveManualRecord(for: day, spfLevel: 50, notes: nil)
        }

        let presentation = state.homeDailyPlanPresentation
        XCTAssertEqual(presentation.action, .backfillYesterday)
        XCTAssertEqual(presentation.actionTitle, "Backfill Yesterday")
        XCTAssertEqual(presentation.tone, .warning)
    }

    @MainActor
    func testHomeDailyPlanShowsReapplyWhenEnabledBeforeSunset() throws {
        let midday = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(clock: { midday })

        state.updateReapplySettings(enabled: true, intervalMinutes: 90)
        state.markAppliedToday(method: .manual, spfLevel: 50)

        let presentation = state.homeDailyPlanPresentation
        XCTAssertEqual(presentation.action, .logReapply)
        XCTAssertEqual(presentation.actionTitle, "Log Reapply")
        XCTAssertEqual(presentation.tone, .action)
    }

    @MainActor
    func testHomeDailyPlanExplainsReapplyRemindersOffAfterTodayIsLogged() throws {
        let state = try makeAppState()

        state.updateReapplySettings(enabled: false, intervalMinutes: 90)
        state.markAppliedToday(method: .manual, spfLevel: 50, notes: "Morning")

        let presentation = state.homeDailyPlanPresentation
        XCTAssertEqual(presentation.action, .viewProgress)
        XCTAssertTrue(presentation.detail.contains("Reapply reminders are off"))
    }

    @MainActor
    func testHomeDailyPlanFallsBackToProgressWhenTodayIsComplete() throws {
        let afterSunset = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 18, minute: 0))
        )
        let state = try makeAppState(clock: { afterSunset })

        state.updateReapplySettings(enabled: true, intervalMinutes: 90)
        state.markAppliedToday(method: .manual, spfLevel: 50, notes: "Commute")

        let presentation = state.homeDailyPlanPresentation
        XCTAssertEqual(presentation.action, .viewProgress)
        XCTAssertEqual(presentation.actionTitle, "View Progress")
        XCTAssertEqual(presentation.tone, .complete)
    }

    @MainActor
    func testHomeDailyPlanNotificationDeniedKeepsManualLoggingAvailable() throws {
        let state = try makeAppState()
        state.completeOnboarding()
        state.markAppliedToday(method: .manual, spfLevel: 50, notes: "Morning")
        state.setNotificationHealthSnapshotForTesting(
            NotificationHealthSnapshot(
                authorizationState: .denied,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            )
        )

        let presentation = state.homeDailyPlanPresentation
        XCTAssertEqual(presentation.action, .openSettings)
        XCTAssertEqual(presentation.actionTitle, "Open Settings")
        XCTAssertTrue(presentation.detail.contains("Manual logging still works"))
    }

    @MainActor
    func testHomeDailyPlanStaleNotificationsOfferRepair() throws {
        let state = try makeAppState()
        state.completeOnboarding()
        state.markAppliedToday(method: .manual, spfLevel: 50, notes: "Morning")
        state.setNotificationHealthSnapshotForTesting(
            NotificationHealthSnapshot(
                authorizationState: .authorized,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            )
        )

        let presentation = state.homeDailyPlanPresentation
        XCTAssertEqual(presentation.action, .repairReminders)
        XCTAssertEqual(presentation.actionTitle, "Refresh Reminders")
        XCTAssertTrue(presentation.detail.contains("Manual logging still works"))
    }
}
