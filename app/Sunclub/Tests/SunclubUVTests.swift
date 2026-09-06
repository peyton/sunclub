import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubUVTests: SunclubTestCase {
    @MainActor
    func testRoutineProgressUsesEligibleWindowAndRealHighUVDays() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let eligibilityStart = calendar.date(byAdding: .day, value: -3, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let morning = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: yesterday)!
        let laterMorning = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: twoDaysAgo)!

        let insights = CalendarAnalytics.routineProgress(
            recordDays: [yesterday, twoDaysAgo],
            verifiedAtDates: [morning, laterMorning],
            highUVDays: [yesterday, today],
            now: today,
            eligibleFrom: eligibilityStart,
            calendar: calendar
        )

        XCTAssertEqual(insights.eligibleDayCount, 4)
        XCTAssertEqual(insights.loggedCount, 2)
        XCTAssertEqual(insights.consistencyPercent, 50)
        XCTAssertEqual(insights.typicalApplicationMinute, 600)
        XCTAssertEqual(insights.highUVLoggedCount, 1)
        XCTAssertEqual(insights.highUVEligibleDayCount, 2)
        XCTAssertEqual(insights.highUVRateText, "50%")
        XCTAssertEqual(insights.nextStep, "Today is open if you wore sunscreen.")
    }

    @MainActor
    func testReapplyReminderPlanKeepsLabelBackedIntervalOnHighUV() throws {
        let daytime = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(clock: { daytime })
        state.updateReapplySettings(enabled: true, intervalMinutes: 120)
        state.setUVReadingForTesting(UVReading(index: 7))

        let plan = state.reapplyReminderPlan

        XCTAssertTrue(plan.isElevated)
        XCTAssertEqual(plan.baseIntervalMinutes, 120)
        XCTAssertEqual(plan.intervalMinutes, 120)
        XCTAssertEqual(plan.notificationTitle, "Time to check your sunscreen")
        XCTAssertTrue(plan.notificationBody.contains("Follow your sunscreen label"))
        XCTAssertEqual(plan.confirmationText, "High UV today: label check in 2h")
    }

    @MainActor
    func testScheduleReapplyReminderDoesNotInventUVAwareInterval() async throws {
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
        await state.scheduleReapplyReminder().value

        XCTAssertGreaterThan(notificationManager.scheduleRemindersCount, 0)
        XCTAssertEqual(state.reapplyReminderPlan.intervalMinutes, 120)
        XCTAssertTrue(state.reapplyReminderPlan.notificationBody.contains("UV is elevated"))
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
    func testUVLevelHighUsesAdvisoryReapplyLabel() {
        XCTAssertEqual(UVLevel.high.homeHeadline, "UV is high today")
        XCTAssertEqual(UVLevel.high.reapplyLabelPrefix, "High UV today")
    }

    @MainActor
    func testWeatherKitPolicyDecodesHostedSnakeCaseConfig() throws {
        let payload = """
        {
          "$schema": "https://sunclub.peyton.app/schemas/weatherkit-config.v1.json",
          "version": 1,
          "weatherkit_enabled": true,
          "min_fetch_interval_seconds": 28800,
          "max_daily_fetches_per_device": 2,
          "max_monthly_fetches_per_device": 60,
          "reason": ""
        }
        """

        let policy = try JSONDecoder().decode(
            SunclubWeatherKitBudgetPolicy.self,
            from: Data(payload.utf8)
        )

        XCTAssertTrue(policy.weatherKitEnabled)
        XCTAssertEqual(policy.minFetchIntervalSeconds, 28_800)
        XCTAssertEqual(policy.maxDailyFetchesPerDevice, 2)
        XCTAssertEqual(policy.maxMonthlyFetchesPerDevice, 60)
        XCTAssertEqual(policy.reason, "")
        XCTAssertEqual(SunclubWeatherKitBudgetPolicy.builtInDefault, policy)
    }

    @MainActor
    func testWidgetSnapshotPublishesFreshVerifiedWeatherKitUV() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let peakHour = SunclubUVHourForecast(
            date: now.addingTimeInterval(3_600),
            index: 10,
            sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
        )
        let forecast = SunclubUVForecast(
            generatedAt: now,
            sourceLabel: UVReadingSource.weatherKit.forecastLabel,
            hours: [peakHour],
            peakHour: peakHour,
            recommendation: "Very high UV today."
        )

        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: Settings(),
            records: [],
            uvReading: UVReading(index: 9, timestamp: now, source: .weatherKit),
            uvForecast: forecast,
            now: now
        )

        XCTAssertEqual(snapshot.currentUVIndex, 9)
        XCTAssertEqual(snapshot.peakUVIndex, 10)
        XCTAssertEqual(snapshot.peakUVHour, peakHour.date)
        XCTAssertEqual(snapshot.uvValidUntil, now.addingTimeInterval(8 * 60 * 60))
        XCTAssertNil(snapshot.currentUVIndex(at: now.addingTimeInterval(8 * 60 * 60 + 1)))
        XCTAssertNil(snapshot.peakUVIndex(at: now.addingTimeInterval(8 * 60 * 60 + 1)))
    }

    @MainActor
    func testWidgetSnapshotRejectsUnverifiedUVForecast() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let peakHour = SunclubUVHourForecast(
            date: now.addingTimeInterval(3_600),
            index: 7,
            sourceLabel: "Legacy estimate"
        )
        let forecast = SunclubUVForecast(
            generatedAt: now,
            sourceLabel: "Legacy estimate",
            hours: [peakHour],
            peakHour: peakHour,
            recommendation: "High UV today."
        )

        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: Settings(),
            records: [],
            uvReading: nil,
            uvForecast: forecast,
            now: now
        )

        XCTAssertNil(snapshot.currentUVIndex)
        XCTAssertNil(snapshot.peakUVIndex)
        XCTAssertNil(snapshot.peakUVHour)
    }

    @MainActor
    func testLiveActivityPayloadPublishesFreshVerifiedWeatherKitUV() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let peakHour = SunclubUVHourForecast(
            date: now.addingTimeInterval(3_600),
            index: 10,
            sourceLabel: UVReadingSource.weatherKit.hourlySourceLabel
        )
        let forecast = SunclubUVForecast(
            generatedAt: now,
            sourceLabel: UVReadingSource.weatherKit.forecastLabel,
            hours: [peakHour],
            peakHour: peakHour,
            recommendation: "Very high UV today."
        )

        let payload = SunclubLiveActivityCoordinator.compactSurfaceUVPayload(
            reading: UVReading(index: 9, timestamp: now, source: .weatherKit),
            forecast: forecast,
            now: now
        )

        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.currentUVIndex, 9)
        XCTAssertEqual(payload?.peakUVIndex, 10)
    }

    @MainActor
    func testUVForecastDataQualityPresentationClearlyDistinguishesSources() {
        let live = UVForecastDetailView.dataQualityPresentation(for: .weatherKit)
        let cached = UVForecastDetailView.dataQualityPresentation(for: .cachedWeatherKit)
        let estimated = UVForecastDetailView.dataQualityPresentation(for: .localEstimate)

        XCTAssertEqual(live.title, "Apple Weather")
        XCTAssertEqual(cached.title, "Apple Weather")
        XCTAssertEqual(estimated.title, "Local UV estimate")
        XCTAssertNotEqual(live.symbol, estimated.symbol)
        XCTAssertTrue(UVReadingSource.cachedWeatherKit.shouldDisplayAttribution)
        XCTAssertFalse(UVReadingSource.localEstimate.shouldDisplayAttribution)
    }

    @MainActor
    func testCachedUVLocationPresentationUsesNearWithoutChangingExactSources() {
        let savedPlace = SunclubUVLocationSource.selectedPlace(displayName: "Pasadena")

        XCTAssertEqual(savedPlace.displayName(for: .cachedWeatherKit), "Near Pasadena")
        XCTAssertEqual(
            SunclubUVLocationSource.liveLocation.displayName(for: .cachedWeatherKit),
            "Near Current Location"
        )
        XCTAssertEqual(savedPlace.displayName(for: .weatherKit), "Pasadena")
        XCTAssertEqual(savedPlace.displayName(for: .localEstimate), "Pasadena")
    }

    @MainActor
    func testLiveUVStatusPresentationDefaultsToUnavailableWhenDisabled() throws {
        let state = try makeAppState()

        XCTAssertEqual(state.liveUVStatusPresentation.title, "UV unavailable")
        XCTAssertNil(state.liveUVStatusPresentation.actionKind)
        XCTAssertTrue(
            state.liveUVStatusPresentation.detail.contains("choose a city")
        )
    }

    @MainActor
    func testUVIndexServiceReturnsLiveReadingWhenPreferenceEnabled() async throws {
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .authorizedWhenInUse,
            location: CLLocation(latitude: 34.116, longitude: -118.150)
        )
        let service = UVIndexService(
            locationService: locationService,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 8, peakIndex: 10),
            cache: SunclubUVForecastCache(
                appGroupID: "group.test.\(UUID().uuidString)",
                key: "test-\(UUID().uuidString)"
            ),
            budget: SunclubWeatherKitBudget(
                appGroupID: "group.test.\(UUID().uuidString)",
                policyKey: "test-policy-\(UUID().uuidString)",
                counterKey: "test-counter-\(UUID().uuidString)"
            ),
            networkPathProvider: { nil }
        )

        await service.fetchUVIndex(prefersLiveData: true)

        XCTAssertEqual(service.currentReading?.source, .weatherKit)
        XCTAssertEqual(service.currentReading?.index, 8)
        XCTAssertEqual(service.liveUVAccessState, .live)
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.lastBundle?.daily.isEmpty ?? true)
    }

    @MainActor
    func testUVIndexServiceReportsNeedsPermissionWhenNotDeterminedAndPromptDisallowed() async throws {
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .notDetermined,
            location: CLLocation(latitude: 34.116, longitude: -118.150)
        )
        let service = UVIndexService(
            locationService: locationService,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 8, peakIndex: 10),
            cache: SunclubUVForecastCache(
                appGroupID: "group.test.\(UUID().uuidString)",
                key: "test-\(UUID().uuidString)"
            )
        )

        await service.fetchUVIndex(prefersLiveData: true, allowPermissionPrompt: false)

        XCTAssertEqual(service.currentReading?.source, .localEstimate)
        XCTAssertEqual(service.status.freshness, .estimated)
        XCTAssertEqual(service.liveUVAccessState, .needsPermission)
    }

    @MainActor
    func testUVIndexServiceReportsUnavailableWhenProviderFails() async throws {
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .authorizedWhenInUse,
            location: CLLocation(latitude: -33.8688, longitude: 151.2093)
        )
        let service = UVIndexService(
            locationService: locationService,
            weatherProvider: UITestLiveUVWeatherProvider(
                currentIndex: 8,
                peakIndex: 10,
                shouldFail: true
            ),
            cache: SunclubUVForecastCache(
                appGroupID: "group.test.\(UUID().uuidString)",
                key: "test-\(UUID().uuidString)"
            )
        )

        await service.fetchUVIndex(prefersLiveData: true)

        XCTAssertEqual(service.currentReading?.source, .localEstimate)
        XCTAssertEqual(service.status.freshness, .estimated)
        XCTAssertEqual(service.liveUVAccessState, .unavailable)
        XCTAssertNotNil(service.errorMessage)
    }

    @MainActor
    func testUVBriefingServiceReturnsLocalEstimateWithoutVerifiedForecast() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .authorizedWhenInUse,
            location: CLLocation(latitude: 34.116, longitude: -118.150)
        )
        let service = SunclubUVBriefingService(
            locationService: locationService,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 8, peakIndex: 10)
        )

        let forecast = await service.forecast(
            prefersLiveData: true,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.localEstimate.forecastLabel)
        XCTAssertFalse(forecast.hours.isEmpty)
        XCTAssertTrue(forecast.isAvailable)
    }

    @MainActor
    func testUVBriefingServiceFallsBackWhenLiveForecastIsEmpty() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .authorizedWhenInUse,
            location: CLLocation(latitude: 34.116, longitude: -118.150)
        )
        let service = SunclubUVBriefingService(
            locationService: locationService,
            weatherProvider: UITestLiveUVWeatherProvider(
                currentIndex: 8,
                peakIndex: 10,
                shouldReturnEmptyForecast: true
            )
        )

        let forecast = await service.forecast(
            prefersLiveData: true,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.localEstimate.forecastLabel)
        XCTAssertFalse(forecast.hours.isEmpty)
    }

    @MainActor
    func testAppStateLiveUVIntegrationRefreshesReadingAndForecast() async throws {
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .authorizedWhenInUse,
            location: CLLocation(latitude: 34.116, longitude: -118.150)
        )
        let weatherProvider = UITestLiveUVWeatherProvider(currentIndex: 8, peakIndex: 11)
        let state = try makeAppState(
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(
                locationService: locationService,
                weatherProvider: weatherProvider,
                cache: SunclubUVForecastCache(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    key: "test-\(UUID().uuidString)"
                ),
                budget: SunclubWeatherKitBudget(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    policyKey: "test-policy-\(UUID().uuidString)",
                    counterKey: "test-counter-\(UUID().uuidString)"
                ),
                networkPathProvider: { nil }
            ),
            uvBriefingService: SunclubUVBriefingService(
                locationService: locationService,
                weatherProvider: weatherProvider
            ),
            clock: { referenceDate }
        )

        state.updateLiveUVPreference(enabled: true, allowPermissionPrompt: false)
        try await waitForLiveUVForecast(on: state)

        XCTAssertTrue(state.settings.usesLiveUV)
        XCTAssertEqual(state.uvReading?.source, .weatherKit)
        XCTAssertEqual(state.uvForecast?.sourceLabel, UVReadingSource.weatherKit.forecastLabel)
        XCTAssertEqual(state.weatherAttribution?.serviceName, UVReadingSource.weatherKit.forecastLabel)
        XCTAssertEqual(state.liveUVStatusPresentation.title, "UV available")
    }

    @MainActor
    func testChangingUVSourceReschedulesRemindersAfterRefresh() async throws {
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let notificationManager = MockNotificationManager()
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .authorizedWhenInUse,
            location: CLLocation(latitude: 34.116, longitude: -118.150)
        )
        let weatherProvider = UITestLiveUVWeatherProvider(currentIndex: 8, peakIndex: 11)
        let state = try makeAppState(
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(
                locationService: locationService,
                weatherProvider: weatherProvider,
                cache: SunclubUVForecastCache(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    key: "test-\(UUID().uuidString)"
                ),
                budget: SunclubWeatherKitBudget(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    policyKey: "test-policy-\(UUID().uuidString)",
                    counterKey: "test-counter-\(UUID().uuidString)"
                ),
                networkPathProvider: { nil }
            ),
            clock: { referenceDate }
        )

        state.updateLiveUVPreference(enabled: true, allowPermissionPrompt: false)
        try await waitForReminderSchedules(2, on: notificationManager)

        XCTAssertEqual(notificationManager.scheduledUVReadingSources.last, .weatherKit)

        state.updateLiveUVPreference(enabled: false, allowPermissionPrompt: false)
        try await waitForReminderSchedules(4, on: notificationManager)

        XCTAssertEqual(notificationManager.scheduleRemindersCount, 4)
        XCTAssertEqual(notificationManager.scheduledUVReadingSources.last, .localEstimate)
    }

    @MainActor
    func testChangingSelectedUVPlaceReschedulesRemindersForNewPlace() async throws {
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let notificationManager = MockNotificationManager()
        let weatherProvider = UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 10)
        let state = try makeAppState(
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(
                weatherProvider: weatherProvider,
                cache: SunclubUVForecastCache(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    key: "test-\(UUID().uuidString)"
                ),
                budget: SunclubWeatherKitBudget(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    policyKey: "test-policy-\(UUID().uuidString)",
                    counterKey: "test-counter-\(UUID().uuidString)"
                ),
                networkPathProvider: { nil }
            ),
            clock: { referenceDate }
        )
        let place = SunclubSelectedUVPlace(
            displayName: "Pasadena",
            latitude: 34.1478,
            longitude: -118.1445
        )

        state.updateSelectedUVPlace(place)
        try await waitForReminderSchedules(2, on: notificationManager)

        XCTAssertEqual(notificationManager.scheduleRemindersCount, 2)
        XCTAssertEqual(notificationManager.scheduledUVReadingSources.last, .weatherKit)
        XCTAssertEqual(notificationManager.scheduledUVPlaces, [place, place])
    }

    @MainActor
    func testWeatherKitBudgetAllowsInitialFetchAndBlocksWithinInterval() throws {
        let budget = SunclubWeatherKitBudget(
            appGroupID: "group.test.\(UUID().uuidString)",
            policyKey: "policy-\(UUID().uuidString)",
            counterKey: "counter-\(UUID().uuidString)"
        )
        budget.storePolicy(SunclubWeatherKitBudgetPolicy(
            weatherKitEnabled: true,
            minFetchIntervalSeconds: 60,
            maxDailyFetchesPerDevice: 3,
            maxMonthlyFetchesPerDevice: 20,
            reason: ""
        ))

        let start = Date()
        XCTAssertEqual(budget.check(now: start), .allow)
        budget.recordFetch(at: start)

        if case .deny = budget.check(now: start.addingTimeInterval(5)) {
            // expected — rate limited
        } else {
            XCTFail("Expected rate-limit deny within min fetch interval")
        }

        XCTAssertEqual(budget.check(now: start.addingTimeInterval(8 * 60 * 60 + 1)), .allow)
    }

    @MainActor
    func testWeatherKitBudgetClampsRemotePolicyToTheBuiltInSafetyCeiling() throws {
        let budget = SunclubWeatherKitBudget(
            appGroupID: "group.test.\(UUID().uuidString)",
            policyKey: "policy-\(UUID().uuidString)",
            counterKey: "counter-\(UUID().uuidString)"
        )
        budget.storePolicy(SunclubWeatherKitBudgetPolicy(
            weatherKitEnabled: true,
            minFetchIntervalSeconds: 1,
            maxDailyFetchesPerDevice: 100,
            maxMonthlyFetchesPerDevice: 1_000,
            reason: ""
        ))

        XCTAssertEqual(budget.currentPolicy.minFetchIntervalSeconds, 8 * 60 * 60)
        XCTAssertEqual(budget.currentPolicy.maxDailyFetchesPerDevice, 2)
        XCTAssertEqual(budget.currentPolicy.maxMonthlyFetchesPerDevice, 60)
    }

    @MainActor
    func testWeatherKitBudgetRespectsDisabledKillSwitch() throws {
        let budget = SunclubWeatherKitBudget(
            appGroupID: "group.test.\(UUID().uuidString)",
            policyKey: "policy-\(UUID().uuidString)",
            counterKey: "counter-\(UUID().uuidString)"
        )
        budget.storePolicy(SunclubWeatherKitBudgetPolicy(
            weatherKitEnabled: false,
            minFetchIntervalSeconds: 0,
            maxDailyFetchesPerDevice: 100,
            maxMonthlyFetchesPerDevice: 1000,
            reason: "Server-side disabled for overage protection"
        ))

        if case .deny(let reason) = budget.check() {
            XCTAssertTrue(reason.contains("overage") || reason.contains("Apple Weather"))
        } else {
            XCTFail("Expected deny when kill switch disables WeatherKit")
        }
    }

    @MainActor
    func testWeatherKitBudgetEnforcesDailyCap() throws {
        let budget = SunclubWeatherKitBudget(
            appGroupID: "group.test.\(UUID().uuidString)",
            policyKey: "policy-\(UUID().uuidString)",
            counterKey: "counter-\(UUID().uuidString)"
        )
        defer { budget.resetForTesting() }
        budget.storePolicy(SunclubWeatherKitBudgetPolicy(
            weatherKitEnabled: true,
            minFetchIntervalSeconds: 1,
            maxDailyFetchesPerDevice: 2,
            maxMonthlyFetchesPerDevice: 50,
            reason: ""
        ))

        let calendar = Calendar(identifier: .gregorian)
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 5,
            hour: 12
        )))
        budget.recordFetch(at: anchor)
        budget.recordFetch(at: anchor.addingTimeInterval(120))

        if case .deny(let reason) = budget.check(now: anchor.addingTimeInterval(9 * 60 * 60)) {
            XCTAssertTrue(reason.contains("Daily"))
        } else {
            XCTFail("Expected deny when daily cap reached")
        }
    }

    @MainActor
    func testHistoricalUVStoreRoundTripsLogs() throws {
        let store = SunclubHistoricalUVStore(
            appGroupID: "group.test.\(UUID().uuidString)",
            key: "uv-\(UUID().uuidString)"
        )
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        store.record(uvIndex: 8, for: today)
        store.record(uvIndex: 5, for: yesterday)
        XCTAssertEqual(store.uvIndex(for: today), 8)
        XCTAssertEqual(store.uvIndex(for: yesterday), 5)
        XCTAssertEqual(store.allEntries().count, 2)

        store.record(uvIndex: 10, for: today)
        XCTAssertEqual(store.uvIndex(for: today), 10)
    }

    @MainActor
    func testUVForecastCacheReturnsFreshBundleWithinRadius() throws {
        let key = "test-\(UUID().uuidString)"
        let group = "group.test.\(UUID().uuidString)"
        let cache = SunclubUVForecastCache(
            appGroupID: group,
            key: key,
            policy: SunclubUVForecastCachePolicy(maxAge: 3600, locationRadiusMeters: 5000)
        )
        let now = Date()
        let location = CLLocation(latitude: 34.05, longitude: -118.25)
        let bundle = SunclubUVForecastBundle(
            generatedAt: now,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            currentIndex: 6,
            hourly: [],
            daily: []
        )
        cache.store(bundle)

        let nearby = CLLocation(latitude: 34.06, longitude: -118.25)
        XCTAssertNotNil(cache.freshBundle(for: nearby, now: now))

        let far = CLLocation(latitude: 34.50, longitude: -118.25)
        XCTAssertNil(cache.freshBundle(for: far, now: now))

        let later = now.addingTimeInterval(7200)
        XCTAssertNil(cache.freshBundle(for: nearby, now: later))
    }

    @MainActor
    func testUVForecastBundleElevatedDaysPropagateToAppState() async throws {
        let referenceDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let calendar = Calendar.current
        let locationService = UITestLiveUVLocationService(
            authorizationStatus: .authorizedWhenInUse,
            location: CLLocation(latitude: 34.116, longitude: -118.150)
        )
        let weatherProvider = UITestLiveUVWeatherProvider(currentIndex: 9, peakIndex: 10)
        let state = try makeAppState(
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(
                locationService: locationService,
                weatherProvider: weatherProvider,
                cache: SunclubUVForecastCache(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    key: "test-\(UUID().uuidString)"
                ),
                budget: SunclubWeatherKitBudget(
                    appGroupID: "group.test.\(UUID().uuidString)",
                    policyKey: "test-policy-\(UUID().uuidString)",
                    counterKey: "test-counter-\(UUID().uuidString)"
                ),
                networkPathProvider: { nil }
            ),
            uvBriefingService: SunclubUVBriefingService(),
            clock: { referenceDate }
        )

        state.updateLiveUVPreference(enabled: true, allowPermissionPrompt: false)
        try await waitForLiveUVForecast(on: state)

        let today = calendar.startOfDay(for: referenceDate)
        XCTAssertTrue(state.elevatedUVDays.contains(today))
        XCTAssertFalse(state.dailyUVForecast.isEmpty)
    }
}
