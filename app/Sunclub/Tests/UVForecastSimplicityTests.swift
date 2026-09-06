import Foundation
import XCTest
@testable import Sunclub

@MainActor
final class UVForecastSimplicityTests: SunclubTestCase {
    func testStaleForecastHidesCurrentHeroButRetainsRequiredAttributionForHours() {
        let status = SunclubUVStatus(
            availability: .available, source: .liveLocation, freshness: .stale, updatedAt: Date()
        )
        XCTAssertFalse(UVForecastDetailView.canShowCurrentUV(status: status))
        let hours = [SunclubUVHourForecast(date: Date(), index: 7, sourceLabel: UVReadingSource.cachedWeatherKit.hourlySourceLabel)]
        let source = UVForecastDetailView.displayedSource(heroSource: nil, forecastSource: .cachedWeatherKit, hours: hours)
        XCTAssertEqual(source, .cachedWeatherKit)
        XCTAssertEqual(source?.shouldDisplayAttribution, true)
        XCTAssertEqual(
            UVForecastDetailView.freshnessDetail(for: .cachedWeatherKit, updatedAt: nil, isStale: true),
            "Last available forecast is out of date."
        )
        XCTAssertNil(UVForecastDetailView.displayedSource(heroSource: nil, forecastSource: .cachedWeatherKit, hours: []))
    }

    func testHeroEligibilityDistinguishesFreshSavedAndEstimatedFromUnavailableData() {
        for freshness in [SunclubUVFreshness.fresh, .estimated] {
            XCTAssertTrue(UVForecastDetailView.canShowCurrentUV(status: SunclubUVStatus(
                availability: .available, source: .liveLocation, freshness: freshness, updatedAt: Date()
            )))
        }
        XCTAssertFalse(UVForecastDetailView.canShowCurrentUV(status: .unavailable))
        XCTAssertFalse(UVForecastDetailView.canShowCurrentUV(status: SunclubUVStatus(
            availability: .available, source: .liveLocation, freshness: .unavailable, updatedAt: nil
        )))
        let hours = [SunclubUVHourForecast(date: Date(), index: 7, sourceLabel: UVReadingSource.localEstimate.hourlySourceLabel)]
        XCTAssertEqual(
            UVForecastDetailView.displayedSource(heroSource: nil, forecastSource: .localEstimate, hours: hours)?.shouldDisplayAttribution,
            false
        )
    }

    func testHourlyForecastIncludesEntireDayInChronologicalOrder() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 6)))
        let hours = (-1...24).reversed().map { offset in
            SunclubUVHourForecast(
                date: day.addingTimeInterval(Double(offset) * 3600),
                index: max(0, offset), sourceLabel: UVReadingSource.cachedWeatherKit.forecastLabel
            )
        }

        let displayed = UVForecastDetailView.hoursForDay(hours, day: day, calendar: calendar)

        XCTAssertEqual(displayed.count, 24)
        XCTAssertEqual(displayed.map { calendar.component(.hour, from: $0.date) }, Array(0...23))
        XCTAssertTrue(displayed.allSatisfy { $0.sourceLabel == UVReadingSource.cachedWeatherKit.forecastLabel })
    }

    func testCurrentHourMarkerMovesAtHourBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let hour = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 23)))

        XCTAssertTrue(UVForecastDetailView.isCurrentHour(hour, now: hour.addingTimeInterval(3599), calendar: calendar))
        XCTAssertFalse(UVForecastDetailView.isCurrentHour(hour, now: hour.addingTimeInterval(3600), calendar: calendar))
        XCTAssertFalse(UVForecastDetailView.isCurrentHour(hour, now: hour.addingTimeInterval(-1), calendar: calendar))
    }

    func testFreshnessExplainsFallbackWithoutExposingCacheTerminology() {
        let live = UVForecastDetailView.freshnessDetail(for: .weatherKit, updatedAt: nil)
        let saved = UVForecastDetailView.freshnessDetail(for: .cachedWeatherKit, updatedAt: nil)
        let estimated = UVForecastDetailView.freshnessDetail(for: .localEstimate, updatedAt: nil)
        XCTAssertEqual(live, "Latest available forecast.")
        XCTAssertEqual(saved, "Last available forecast.")
        XCTAssertEqual(estimated, "Based on season and time of day.")
        for source in [UVReadingSource.weatherKit, .cachedWeatherKit, .localEstimate] {
            XCTAssertFalse(UVForecastDetailView.dataQualityPresentation(for: source).title.localizedCaseInsensitiveContains("cached"))
        }
        let timestamp = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(UVForecastDetailView.freshnessDetail(for: .cachedWeatherKit, updatedAt: timestamp).contains(
            timestamp.formatted(date: .omitted, time: .shortened)
        ))
    }

    // Catches reusing AppState's launch-day selection after the local clock crosses midnight.
    func testForecastDayFollowsMidnightWithoutChangingLegacyDaySelection() throws {
        let calendar = Calendar.current
        let initialDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 4)))
        let nextDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 5)))
        var now = try XCTUnwrap(calendar.date(bySettingHour: 23, minute: 59, second: 0, of: initialDay))
        let suite = "UVForecastSimplicityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let state = try makeAppState(
            notificationManager: MockNotificationManager(),
            homeExitReminderMonitor: MockHomeExitReminderMonitor(),
            cloudSyncCoordinator: ProbeCloudSyncCoordinator(),
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: defaults),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true, isPreviewing: false, hasAppGroupContainer: false
            ),
            clock: { now }
        )
        XCTAssertEqual(UVForecastDetailView.referenceDay(in: state), initialDay)
        XCTAssertEqual(state.selectedDay, initialDay)

        now = now.addingTimeInterval(2 * 60)

        XCTAssertEqual(
            UVForecastDetailView.referenceDay(in: state), nextDay,
            "Forecast must advance with the actual local day without relying on a navigation selection."
        )
        XCTAssertEqual(state.selectedDay, initialDay, "Reading today's forecast must not mutate another date selection.")
    }
}
