import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class TodayQuietGlassPresentationTests: XCTestCase {
    func testLoggedStatusReportsSavedSPFAndAreasWithoutClaimingProtection() throws {
        let now = try date(hour: 10)
        let record = makeRecord(at: now, spf: 50, notes: "Areas: Neck, Face")
        let presentation = logPresentation(record: record, now: now)

        XCTAssertEqual(presentation.title, "Logged at \(now.formatted(date: .omitted, time: .shortened))")
        XCTAssertEqual(presentation.detail, "Face & Neck")
        XCTAssertEqual(presentation.spfLabel, "SPF 50")
        XCTAssertEqual(presentation.statusIdentifier, "home.todayStatus")
        XCTAssertFalse(presentation.title.lowercased().contains("protected"))
    }

    func testUnloggedStateDoesNotInventDefaultsOrReminderDeadline() throws {
        let presentation = logPresentation(record: nil, now: try date(hour: 10))

        XCTAssertEqual(presentation.title, "Not logged")
        XCTAssertEqual(presentation.statusIdentifier, "timeline.todayStatus")
        XCTAssertNil(presentation.reminderText)
        XCTAssertFalse(presentation.detail.contains("SPF 50"))
    }

    func testMissingDetailsAreNotFilledFromDefaults() throws {
        let now = try date(hour: 10)
        let presentation = logPresentation(record: makeRecord(at: now), now: now)

        XCTAssertTrue(presentation.detail.isEmpty, "Missing optional metadata should not fill Today with placeholders.")
    }

    func testDisabledRemindersDoNotClaimNoReapplyIsNeeded() throws {
        let now = try date(hour: 10)
        let presentation = logPresentation(record: makeRecord(at: now), now: now, enabled: false)

        XCTAssertNil(presentation.reminderText, "An inactive preference is not an action needed on Today.")
    }

    func testReminderStartsFromLatestReapplyAndUsesConfiguredInterval() throws {
        let appliedAt = try date(hour: 9)
        let reappliedAt = try date(hour: 11)
        let now = try date(hour: 11, minute: 30)
        let record = makeRecord(at: appliedAt)
        record.lastReappliedAt = reappliedAt
        record.reapplyCount = 1

        let presentation = logPresentation(record: record, now: now, interval: 90)
        let deadline = try date(hour: 12, minute: 30)

        XCTAssertEqual(presentation.reminderText, "Reapply around \(deadline.formatted(date: .omitted, time: .shortened))")
    }

    func testReminderBecomesDueWithoutChangingLoggedStatus() throws {
        let presentation = logPresentation(record: makeRecord(at: try date(hour: 9)), now: try date(hour: 12))

        XCTAssertTrue(presentation.title.hasPrefix("Logged at "))
        XCTAssertEqual(presentation.reminderText, "Reapply reminder")
    }

    func testAfterEstimatedCutoffCopyDoesNotClaimSunsetOrDenyPendingSnooze() throws {
        let now = try date(hour: 23)
        let snoozedPlan = ReapplyReminderPlan(snoozeMinutes: 15, now: now)
        let presentation = TodayQuietGlassLogPresentation(
            record: makeRecord(at: now), now: now,
            remindersEnabled: true, reapplyPlan: snoozedPlan
        )

        XCTAssertTrue(snoozedPlan.shouldScheduleNotification)
        XCTAssertNil(presentation.reminderText)
    }

    func testIntervalCrossingSunsetDoesNotClaimSunsetHasAlreadyPassed() throws {
        let sunset = ReminderPlanner.estimatedSunset(for: try date(hour: 10))
        let now = sunset.addingTimeInterval(-30 * 60)
        let presentation = logPresentation(record: makeRecord(at: now), now: now, interval: 120)

        XCTAssertNil(presentation.reminderText)
    }



    func testCurrentUVTakesPriorityOverForecastPeakAndKeepsSource() throws {
        let now = try date(hour: 10)
        let presentation = uvPresentation(
            reading: UVReading(index: 2, timestamp: now, source: .weatherKit),
            forecast: forecast(at: try date(hour: 13), index: 7),
            now: now
        )

        XCTAssertEqual(presentation.index, 2)
        XCTAssertEqual(presentation.level, .low)
        XCTAssertEqual(presentation.title, "UV index")
        XCTAssertTrue(presentation.sourceLabel?.contains("Apple Weather · Test Place · Updated") == true)
        XCTAssertEqual(presentation.gaugeFraction, 2.0 / 11, accuracy: 0.001)
    }

    func testForecastFallbackIsExplicitlyAPeakWithItsOwnSource() throws {
        let now = try date(hour: 10)
        let presentation = uvPresentation(
            forecast: forecast(at: try date(hour: 13), index: 7, source: .localEstimate),
            now: now
        )

        XCTAssertEqual(presentation.index, 7)
        XCTAssertEqual(presentation.title, "Peak UV today")
        XCTAssertTrue(presentation.sourceLabel?.hasPrefix("Local estimate") == true)
        XCTAssertTrue(presentation.accessibilityLabel.contains("Peak UV today 7, High"))
    }

    func testLocalAndCachedReadingsRemainClearlyLabeled() throws {
        let now = try date(hour: 10)
        for source: UVReadingSource in [.localEstimate, .cachedWeatherKit] {
            let presentation = uvPresentation(reading: UVReading(index: 3, timestamp: now, source: source), now: now)
            XCTAssertTrue(presentation.sourceLabel?.hasPrefix(source == .cachedWeatherKit ? "Apple Weather" : source.statusLabel) == true)
            XCTAssertFalse(presentation.sourceLabel?.contains("Cached") == true)
            if source == .cachedWeatherKit {
                XCTAssertTrue(presentation.sourceLabel?.contains("Near Test Place") == true)
                XCTAssertTrue(presentation.sourceLabel?.contains("Last available forecast") == true)
            }
        }
    }

    func testUnavailableOrStaleUVNeverBecomesZeroOrFallsBackToPeak() throws {
        let now = try date(hour: 10)
        let stale = SunclubUVStatus(
            availability: .available,
            source: .selectedPlace(displayName: "Test Place"),
            freshness: .stale,
            updatedAt: try date(hour: 8, day: 3)
        )
        for status in [SunclubUVStatus.unavailable, stale] {
            let presentation = uvPresentation(
                reading: UVReading(index: 2, timestamp: now),
                forecast: forecast(at: try date(hour: 13), index: 7),
                status: status,
                now: now
            )
            XCTAssertNil(presentation.index)
            XCTAssertEqual(presentation.level, .unknown)
            XCTAssertEqual(presentation.gaugeFraction, 0)
            XCTAssertTrue(presentation.accessibilityLabel.hasPrefix("UV unavailable"))
        }
    }

    func testUnverifiedOrWrongDayForecastCannotPopulateGauge() throws {
        let now = try date(hour: 10)
        let hour = SunclubUVHourForecast(date: now, index: 5, sourceLabel: "Legacy estimate")
        let unverified = SunclubUVForecast(
            generatedAt: now, sourceLabel: "Legacy estimate", hours: [hour], peakHour: hour, recommendation: ""
        )
        XCTAssertNil(uvPresentation(forecast: unverified, now: now).index)
        XCTAssertNil(uvPresentation(forecast: forecast(at: try date(hour: 13, day: 5), index: 7), now: now).index)
    }

    func testPastDayDoesNotDisplayTodaysCurrentUV() throws {
        let now = try date(hour: 10)
        let presentation = uvPresentation(
            reading: UVReading(index: 7, timestamp: now),
            selectedDay: try date(hour: 10, day: 3),
            now: now
        )
        XCTAssertNil(presentation.index)
    }

    func testZeroIsARealLowReadingAndExtremeUVDoesNotOverflowGauge() throws {
        let now = try date(hour: 10)
        let zero = uvPresentation(reading: UVReading(index: 0, timestamp: now), now: now)
        let extreme = uvPresentation(reading: UVReading(index: 14, timestamp: now), now: now)

        XCTAssertEqual(zero.index, 0)
        XCTAssertEqual(zero.level, .low)
        XCTAssertEqual(extreme.index, 14)
        XCTAssertEqual(extreme.level, .extreme)
        XCTAssertEqual(extreme.gaugeFraction, 1)
    }

    private func date(hour: Int, minute: Int = 0, day: Int = 4) throws -> Date {
        try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)))
    }

    private func makeRecord(at date: Date, spf: Int? = nil, notes: String? = nil) -> DailyRecord {
        DailyRecord(startOfDay: Calendar.current.startOfDay(for: date), verifiedAt: date, method: .manual, spfLevel: spf, notes: notes)
    }

    private func logPresentation(record: DailyRecord?, now: Date, enabled: Bool = true, interval: Int = 120) -> TodayQuietGlassLogPresentation {
        TodayQuietGlassLogPresentation(
            record: record, now: now, remindersEnabled: enabled,
            reapplyPlan: ReapplyReminderPlan(baseIntervalMinutes: interval, uvReading: UVReading(index: 7, timestamp: now), now: now)
        )
    }

    private func forecast(at date: Date, index: Int, source: UVReadingSource = .weatherKit) -> SunclubUVForecast {
        let hour = SunclubUVHourForecast(date: date, index: index, sourceLabel: source.hourlySourceLabel)
        return SunclubUVForecast(generatedAt: date, sourceLabel: source.forecastLabel, hours: [hour], peakHour: hour, recommendation: "")
    }

    private func uvPresentation(
        reading: UVReading? = nil,
        forecast: SunclubUVForecast? = nil,
        status: SunclubUVStatus? = nil,
        selectedDay: Date? = nil,
        now: Date
    ) -> TodayQuietGlassUVPresentation {
        TodayQuietGlassUVPresentation(
            reading: reading,
            forecast: forecast,
            status: status ?? SunclubUVStatus(
                availability: .available, source: .selectedPlace(displayName: "Test Place"), freshness: .fresh, updatedAt: now
            ),
            protectionWindow: nil,
            selectedDay: selectedDay ?? now,
            now: now
        )
    }
}
