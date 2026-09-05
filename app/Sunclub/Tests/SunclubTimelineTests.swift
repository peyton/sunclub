import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubTimelineTests: SunclubTestCase {
    @MainActor
    func testRecordVerificationSuccessUsesSelectedDayAfterMidnight() throws {
        let calendar = Calendar.current
        let afterMidnight = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 0, minute: 30))
        )
        let state = try makeAppState(clock: { afterMidnight })
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: afterMidnight))
        state.selectDay(yesterday)

        let didWrite = state.recordVerificationSuccess(
            method: .manual,
            context: AppLogContext(
                date: yesterday,
                dayPart: .night,
                source: .manualLog
            )
        )

        XCTAssertTrue(didWrite.succeeded)
        XCTAssertNotNil(state.record(for: yesterday))
        XCTAssertNil(state.record(for: afterMidnight))
    }


    @MainActor
    func testSelectedDayDefaultsToStartOfToday() throws {
        let appState = try makeAppState()
        let startOfToday = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(
            Calendar.current.startOfDay(for: appState.selectedDay),
            startOfToday
        )
    }

    @MainActor
    func testSelectDayNormalizesToStartOfDay() throws {
        let appState = try makeAppState()
        let noon = Calendar.current.date(bySettingHour: 13, minute: 30, second: 0, of: Date()) ?? Date()
        appState.selectDay(noon)
        let expected = Calendar.current.startOfDay(for: noon)
        XCTAssertEqual(appState.selectedDay, expected)
    }

    @MainActor
    func testFutureDayPreviewReturnsNilForTodayAndPast() throws {
        let appState = try makeAppState()
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        XCTAssertNil(appState.futureDayPreview(for: today))
        XCTAssertNil(appState.futureDayPreview(for: yesterday))
    }

    @MainActor
    func testFutureDayPreviewReturnsSuggestionForTomorrow() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: today
        ) ?? Date()
        let appState = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(generatedAt: today, daily: [
                    SunclubUVDayForecast(day: tomorrow, maxIndex: 7)
                ])
            )
        )

        let preview = appState.futureDayPreview(for: tomorrow)
        XCTAssertNotNil(preview)
        XCTAssertGreaterThanOrEqual(preview?.suggestedSPF ?? 0, 15)
        XCTAssertTrue(preview?.suggestionText.contains("SPF") ?? false)
    }

    @MainActor
    func testTimelineDayLogSummaryFutureCategoryForTomorrow() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: today
        ) ?? Date()
        let appState = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(generatedAt: today, daily: [
                    SunclubUVDayForecast(day: tomorrow, maxIndex: 7)
                ])
            )
        )

        let summary = appState.timelineDayLogSummary(for: tomorrow)
        XCTAssertEqual(summary.category, .future)
        XCTAssertNil(summary.record)
        XCTAssertNotNil(summary.futurePreview)
        XCTAssertTrue(summary.sunscreenStatusText.contains("Plan SPF"))
    }

    @MainActor
    func testTimelineBoundsEndsAtLastForecastDay() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let dailyForecastDay = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let hourlyForecastDay = calendar.date(byAdding: .day, value: 75, to: today) ?? today
        let gapFutureDay = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let hour = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: hourlyForecastDay) ?? hourlyForecastDay
        let afterForecast = calendar.date(byAdding: .day, value: 76, to: today) ?? today
        let expectedStartDay = calendar.date(byAdding: .day, value: -365, to: today) ?? today
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate,
                    hourly: [
                        SunclubUVHourForecast(
                            date: hour,
                            index: 8,
                            sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
                        )
                    ],
                    daily: [
                        SunclubUVDayForecast(day: dailyForecastDay, maxIndex: 6)
                    ]
                )
            ),
            clock: { referenceDate }
        )

        XCTAssertEqual(state.timelineBounds.startDay, expectedStartDay)
        XCTAssertEqual(state.timelineBounds.futureEndDay, hourlyForecastDay)
        XCTAssertEqual(state.timelineVisibleDays.last, hourlyForecastDay)
        XCTAssertFalse(state.timelineVisibleDays.contains(afterForecast))
        XCTAssertFalse(state.timelineVisibleDays.contains(gapFutureDay))
        XCTAssertTrue(state.timelineShowsFutureDays)
        XCTAssertFalse(state.canSelectTimelineDay(gapFutureDay))
        XCTAssertTrue(state.canSelectTimelineDay(dailyForecastDay))
        XCTAssertTrue(state.canSelectTimelineDay(hourlyForecastDay))
    }

    @MainActor
    func testTimelineBoundsClampKeepsRemainingSparseFutureForecast() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let invalidSelectedForecastDay = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let remainingForecastDay = calendar.date(byAdding: .day, value: 6, to: today) ?? today
        let earlierForecastDay = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let tiedInvalidForecastDay = calendar.date(byAdding: .day, value: 4, to: today) ?? today
        let bounds = TimelineBounds(
            today: referenceDate,
            forecastDays: [remainingForecastDay],
            calendar: calendar
        )
        let tiedBounds = TimelineBounds(
            today: referenceDate,
            forecastDays: [remainingForecastDay, earlierForecastDay],
            calendar: calendar
        )

        XCTAssertEqual(
            bounds.clamp(invalidSelectedForecastDay, calendar: calendar),
            remainingForecastDay
        )
        XCTAssertEqual(
            tiedBounds.clamp(tiedInvalidForecastDay, calendar: calendar),
            earlierForecastDay
        )
    }

    @MainActor
    func testNoFutureDaysSelectableWhenNoForecastDataBeyondToday() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate,
                    daily: [SunclubUVDayForecast(day: today, maxIndex: 6)]
                )
            ),
            clock: { referenceDate }
        )

        state.selectDay(tomorrow)

        XCTAssertEqual(state.timelineBounds.futureEndDay, today)
        XCTAssertFalse(state.timelineShowsFutureDays)
        XCTAssertEqual(state.selectedDay, today)
        XCTAssertNil(state.futureDayPreview(for: tomorrow))
    }

    @MainActor
    func testFutureLoggingRejectedEvenWhenForecastBrowsingAllowed() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate,
                    daily: [SunclubUVDayForecast(day: tomorrow, maxIndex: 7)]
                )
            ),
            clock: { referenceDate }
        )

        state.selectDay(tomorrow)
        let validatedDate = state.validatedLogDate(tomorrow)

        XCTAssertEqual(state.selectedDay, tomorrow)
        XCTAssertFalse(state.canLog(on: tomorrow))
        XCTAssertNil(validatedDate)
        XCTAssertEqual(state.logActionErrorMessage, "Cannot log future date.")
    }





    @MainActor
    func testTimelineForecastLevelLookupUsesRealForecastData() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let hourlyOnlyDay = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        let unforecastedFutureDay = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        let hourlyDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: hourlyOnlyDay) ?? hourlyOnlyDay
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate,
                    hourly: [
                        SunclubUVHourForecast(
                            date: hourlyDate,
                            index: 9,
                            sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
                        )
                    ],
                    daily: [
                        SunclubUVDayForecast(day: tomorrow, maxIndex: 8)
                    ]
                )
            ),
            clock: { referenceDate }
        )

        XCTAssertEqual(state.timelineForecastUVLevel(for: tomorrow), .veryHigh)
        XCTAssertEqual(state.timelineForecastUVLevel(for: hourlyOnlyDay), .veryHigh)
        XCTAssertNil(state.timelineForecastUVLevel(for: unforecastedFutureDay))
    }

    @MainActor
    func testTimelineUVForecastUsesFutureHourlyDataWhenAvailable() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let afternoon = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate,
                    hourly: [
                        SunclubUVHourForecast(
                            date: morning,
                            index: 4,
                            sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
                        ),
                        SunclubUVHourForecast(
                            date: afternoon,
                            index: 9,
                            sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
                        )
                    ],
                    daily: [
                        SunclubUVDayForecast(day: tomorrow, maxIndex: 6)
                    ]
                )
            ),
            clock: { referenceDate }
        )

        let forecast = try XCTUnwrap(state.timelineUVForecast(for: tomorrow))

        XCTAssertEqual(forecast.hours.map(\.date), [morning, afternoon])
        XCTAssertEqual(forecast.peakHour?.index, 9)
        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.cachedWeatherKit.forecastLabel)
    }

    @MainActor
    func testTimelineUVForecastFallsBackToDailyForecastPeak() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate,
                    daily: [
                        SunclubUVDayForecast(day: tomorrow, maxIndex: 8)
                    ]
                )
            ),
            clock: { referenceDate }
        )

        let forecast = try XCTUnwrap(state.timelineUVForecast(for: tomorrow))

        XCTAssertEqual(forecast.hours.count, 1)
        XCTAssertEqual(forecast.peakHour?.index, 8)
        XCTAssertEqual(forecast.peakHour?.sourceLabel, UVReadingSource.cachedWeatherKit.hourlySourceLabel)
        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.cachedWeatherKit.forecastLabel)
    }

    @MainActor
    func testTimelineUVForecastLabelsLastKnownWeatherAsCached() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate.addingTimeInterval(-9 * 60 * 60),
                    daily: [SunclubUVDayForecast(day: tomorrow, maxIndex: 8)]
                )
            ),
            clock: { referenceDate }
        )

        let forecast = try XCTUnwrap(state.timelineUVForecast(for: tomorrow))

        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.cachedWeatherKit.forecastLabel)
        XCTAssertEqual(forecast.peakHour?.sourceLabel, UVReadingSource.cachedWeatherKit.hourlySourceLabel)
    }

    @MainActor
    func testTimelineLabelsNineHourOldSameTimestampWeatherAsCached() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let bundleDate = referenceDate.addingTimeInterval(-9 * 60 * 60)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let bundle = makeUVForecastBundle(
            generatedAt: bundleDate,
            daily: [SunclubUVDayForecast(day: tomorrow, maxIndex: 8)]
        )
        let service = makeUVIndexService(bundle: bundle)
        let state = try makeAppState(
            uvIndexService: service,
            clock: { referenceDate }
        )
        state.setUVReadingForTesting(
            UVReading(index: 8, timestamp: bundleDate, source: .weatherKit)
        )

        let forecast = try XCTUnwrap(state.timelineUVForecast(for: tomorrow))

        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.cachedWeatherKit.forecastLabel)
        XCTAssertEqual(forecast.peakHour?.sourceLabel, UVReadingSource.cachedWeatherKit.hourlySourceLabel)
    }

    @MainActor
    func testTimelineUVForecastRejectsExpiredCachedBundle() throws {
        let calendar = Calendar.current
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let today = calendar.startOfDay(for: referenceDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let state = try makeAppState(
            uvIndexService: makeUVIndexService(
                bundle: makeUVForecastBundle(
                    generatedAt: referenceDate.addingTimeInterval(-25 * 60 * 60),
                    daily: [SunclubUVDayForecast(day: tomorrow, maxIndex: 8)]
                )
            ),
            clock: { referenceDate }
        )

        XCTAssertNil(state.timelineUVForecast(for: tomorrow))
        XCTAssertNil(state.timelineForecastUVLevel(for: tomorrow))
        XCTAssertFalse(state.timelineShowsFutureDays)
    }

    @MainActor
    func testTimelineDayLogSummaryTodayCategoryWhenUnlogged() throws {
        let appState = try makeAppState()
        let summary = appState.timelineDayLogSummary(for: Date())
        XCTAssertEqual(summary.category, .today)
        XCTAssertNil(summary.record)
        XCTAssertTrue(summary.sunscreenStatusText.contains("Not logged"))
    }

    @MainActor
    func testTimelineDayLogSummaryPastCategoryForBackfill() throws {
        let appState = try makeAppState()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) ?? Date()
        appState.saveManualRecord(for: yesterday, verifiedAt: yesterday, spfLevel: 30, notes: "Beach")
        let summary = appState.timelineDayLogSummary(for: yesterday)
        XCTAssertEqual(summary.category, .past)
        XCTAssertNotNil(summary.record)
        XCTAssertTrue(summary.sunscreenStatusText.contains("SPF 30"))
        XCTAssertEqual(summary.notesStatusText, "Beach")
    }

    @MainActor
    func testTimelineDayLogSummaryPreservesNightLogContext() throws {
        let appState = try makeAppState()
        let calendar = Calendar.current
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())))

        appState.saveManualRecord(for: yesterday, dayPart: .night, spfLevel: 30, notes: "Late application")

        let summary = appState.timelineDayLogSummary(for: yesterday)
        XCTAssertEqual(summary.record?.loggedDayPart(calendar: calendar), .night)
        XCTAssertEqual(summary.dayPart, .night)
        XCTAssertTrue(summary.partStatuses.contains { $0.dayPart == .night && $0.isCompleted })
    }



    @MainActor
    func testAdvanceSelectedDayIfStaleClampsFarFuture() throws {
        let appState = try makeAppState()
        let today = Calendar.current.startOfDay(for: Date())
        let farFuture = Calendar.current.date(byAdding: .day, value: 120, to: today) ?? today
        appState.selectedDay = farFuture
        appState.advanceSelectedDayIfStale()
        XCTAssertEqual(appState.selectedDay, today)
    }
}
