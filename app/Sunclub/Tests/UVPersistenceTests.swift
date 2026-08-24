import CoreLocation
import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class UVPersistenceTests: XCTestCase {
    func testSelectedPlaceAndSunscreenProfileNormalizeAndRoundTrip() throws {
        let place = SunclubSelectedUVPlace(
            displayName: "  Pasadena, CA  ",
            latitude: 34.1478,
            longitude: -118.1445
        )
        let profile = SunclubSunscreenProfile(
            name: "  Beach lotion  ",
            spf: 150,
            waterResistance: .eightyMinutes
        )

        XCTAssertEqual(place.displayName, "Pasadena, CA")
        XCTAssertEqual(profile.name, "Beach lotion")
        XCTAssertEqual(profile.spf, 100)
        XCTAssertEqual(profile.waterResistance.durationMinutes, 80)

        let placeRoundTrip = try JSONDecoder().decode(
            SunclubSelectedUVPlace.self,
            from: JSONEncoder().encode(place)
        )
        let profileRoundTrip = try JSONDecoder().decode(
            SunclubSunscreenProfile.self,
            from: JSONEncoder().encode(profile)
        )
        XCTAssertEqual(placeRoundTrip, place)
        XCTAssertEqual(profileRoundTrip, profile)
    }

    func testSettingsRevisionSnapshotRoundTripsNewPreferencesAndDecodesOldPayload() throws {
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        let profile = SunclubSunscreenProfile(name: "Daily SPF", spf: 50, waterResistance: .fortyMinutes)
        let snapshot = makeSettingsSnapshot(selectedUVPlace: place, sunscreenProfile: profile)
        let batch = SunclubChangeBatch(
            kind: .liveUVSettings,
            scope: .settings,
            scopeIdentifier: "settings",
            authorDeviceID: "test-device",
            summary: "Updated UV place and sunscreen profile."
        )
        let revision = SettingsRevision(
            batch: batch,
            snapshot: snapshot,
            changedFields: [.selectedUVPlace, .sunscreenProfile]
        )

        XCTAssertEqual(revision.snapshot, snapshot)
        XCTAssertEqual(revision.changedFields, [.selectedUVPlace, .sunscreenProfile])

        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "selectedUVPlace")
        legacyObject.removeValue(forKey: "sunscreenProfile")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacySnapshot = try JSONDecoder().decode(SettingsProjectionSnapshot.self, from: legacyData)
        XCTAssertNil(legacySnapshot.selectedUVPlace)
        XCTAssertNil(legacySnapshot.sunscreenProfile)
    }

    func testBackupRoundTripsSelectedPlaceAndSunscreenProfile() throws {
        let sourceContainer = try SunclubModelContainerFactory.makeInMemoryContainer()
        let sourceContext = ModelContext(sourceContainer)
        let history = SunclubHistoryService(context: sourceContext)
        try history.bootstrapIfNeeded()

        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        let profile = SunclubSunscreenProfile(name: "Daily SPF", spf: 50, waterResistance: .eightyMinutes)
        try history.applySettingsChange(
            kind: .liveUVSettings,
            summary: "Saved UV place and sunscreen profile.",
            changedFields: [.selectedUVPlace, .sunscreenProfile]
        ) { snapshot in
            snapshot.selectedUVPlace = place
            snapshot.sunscreenProfile = profile
        }

        let service = SunclubBackupService()
        let document = try service.exportDocument(from: sourceContext)
        let targetContainer = try SunclubModelContainerFactory.makeInMemoryContainer()
        let targetContext = ModelContext(targetContainer)
        _ = try service.importBackupDocument(document, into: targetContext)

        let restored = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertEqual(restored.selectedUVPlace, place)
        XCTAssertEqual(restored.sunscreenProfile, profile)
    }

    func testSelectedPlaceProvidesVerifiedUVWithoutLocationPermission() async throws {
        let service = makeService(
            locationStatus: .denied,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9)
        )
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        let now = Date()

        await service.fetchUVIndex(prefersLiveData: false, selectedPlace: place, now: now)

        XCTAssertEqual(service.currentReading?.index, 7)
        XCTAssertEqual(service.currentReading?.source, .weatherKit)
        XCTAssertEqual(service.status.availability, .available)
        XCTAssertEqual(service.status.source, .selectedPlace(displayName: "Pasadena"))
        XCTAssertEqual(service.status.freshness, .fresh)
        XCTAssertEqual(service.status.updatedAt, now)
        XCTAssertNotNil(service.protectionWindow)
    }

    func testWeatherProviderFailureCreatesALocationBasedEstimate() async throws {
        let now = Date()
        let service = makeService(
            locationStatus: .authorizedWhenInUse,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9, shouldFail: true)
        )

        await service.fetchUVIndex(prefersLiveData: true, now: now)

        XCTAssertNotNil(service.currentReading)
        XCTAssertEqual(service.currentReading?.source, .localEstimate)
        XCTAssertEqual(service.currentReading?.timestamp, now)
        XCTAssertNil(service.lastBundle)
        XCTAssertEqual(service.status.availability, .available)
        XCTAssertEqual(service.status.freshness, .estimated)
        XCTAssertEqual(service.liveUVAccessState, .unavailable)
        XCTAssertNotNil(service.errorMessage)
    }

    func testFarAwayCachedWeatherIsNotRetainedOrUsedByLocalFallbackBriefing() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 10,
            hour: 16
        )))
        let farAwayPlace = SunclubSelectedUVPlace(
            displayName: "New York",
            latitude: 40.7128,
            longitude: -74.0060
        )
        let cache = makeCache(maxAge: 24 * 60 * 60)
        cache.store(makeBundle(generatedAt: now, place: farAwayPlace, calendar: calendar))
        let service = makeService(
            locationStatus: .authorizedWhenInUse,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9, shouldFail: true),
            cache: cache
        )

        await service.fetchUVIndex(prefersLiveData: true, now: now)

        XCTAssertEqual(service.currentReading?.source, .localEstimate)
        XCTAssertNil(service.lastBundle)

        let briefing = SunclubUVBriefingService(cache: cache)
        let forecast = await briefing.forecast(
            prefersLiveData: true,
            liveBundle: service.lastBundle,
            readingSource: service.currentReading?.source,
            fallbackLatitude: service.fallbackLatitude,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.localEstimate.forecastLabel)
    }

    func testBriefingUsesLocalEstimateWhenTheReadingIsLocal() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 10,
            hour: 16
        )))
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        let bundle = makeBundle(generatedAt: now, place: place, calendar: calendar)
        let briefing = SunclubUVBriefingService(cache: makeCache())

        let forecast = await briefing.forecast(
            prefersLiveData: true,
            liveBundle: bundle,
            readingSource: .localEstimate,
            fallbackLatitude: place.latitude,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.localEstimate.forecastLabel)
    }

    func testDisablingEveryUVSourceUsesEstimateAndPreservesCache() async throws {
        let cache = makeCache()
        let now = Date()
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        cache.store(makeBundle(generatedAt: now, place: place))
        let service = makeService(
            locationStatus: .denied,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9),
            cache: cache
        )

        await service.fetchUVIndex(prefersLiveData: false, now: now)

        XCTAssertEqual(service.currentReading?.source, .localEstimate)
        XCTAssertEqual(service.status.availability, .available)
        XCTAssertEqual(service.status.freshness, .estimated)
        XCTAssertNil(service.status.source)
        XCTAssertNil(service.lastBundle)
        XCTAssertNotNil(cache.lastBundle())
    }

    func testDeniedCurrentLocationDoesNotRelabelSavedPlaceCache() async throws {
        let cache = makeCache(maxAge: 24 * 60 * 60)
        let now = Date()
        let savedPlace = SunclubSelectedUVPlace(
            displayName: "New York",
            latitude: 40.7128,
            longitude: -74.0060
        )
        cache.store(makeBundle(generatedAt: now, place: savedPlace))
        let service = makeService(
            locationStatus: .denied,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9),
            cache: cache
        )

        await service.fetchUVIndex(prefersLiveData: true, now: now)

        XCTAssertEqual(service.currentReading?.source, .localEstimate)
        XCTAssertNil(service.lastBundle)
        XCTAssertNil(service.status.source)
        XCTAssertEqual(service.status.freshness, .estimated)
        XCTAssertNotNil(cache.lastBundle())
    }

    func testCachedWeatherBridgesTheFormerTwoToThreeHourBudgetGap() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let cache = makeCache(maxAge: 8 * 60 * 60)
        let fetchedAt = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 10,
            hour: 10
        )))
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        cache.store(makeBundle(generatedAt: fetchedAt, place: place, calendar: calendar))
        let service = makeService(
            locationStatus: .denied,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9, shouldFail: true),
            cache: cache
        )

        await service.fetchUVIndex(
            prefersLiveData: false,
            selectedPlace: place,
            now: fetchedAt.addingTimeInterval(2 * 60 * 60 + 1)
        )

        XCTAssertEqual(service.currentReading?.source, .cachedWeatherKit)
        XCTAssertNotNil(service.lastBundle)
        XCTAssertEqual(service.status.availability, .available)
        XCTAssertEqual(service.status.freshness, .fresh)
        XCTAssertEqual(service.status.updatedAt, fetchedAt)
    }

    func testLastKnownWeatherIsUsedForUpToTwentyFourHoursAfterRefreshFailure() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let fetchedAt = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 10,
            hour: 6
        )))
        let now = fetchedAt.addingTimeInterval(9 * 60 * 60)
        let cache = makeCache(maxAge: 24 * 60 * 60)
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        cache.store(makeBundle(generatedAt: fetchedAt, place: place, calendar: calendar))
        let service = makeService(
            locationStatus: .denied,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9, shouldFail: true),
            cache: cache
        )

        await service.fetchUVIndex(prefersLiveData: false, selectedPlace: place, now: now)

        XCTAssertEqual(service.currentReading?.source, .cachedWeatherKit)
        XCTAssertEqual(service.currentReading?.index, 3)
        XCTAssertEqual(service.status.availability, .available)
        XCTAssertEqual(service.status.freshness, .stale)
        XCTAssertEqual(service.status.updatedAt, fetchedAt)
    }

    func testFailedWeatherRequestCountsAgainstTheRequestInterval() async throws {
        let provider = CountingUVWeatherProvider(shouldFail: true)
        let budget = makeBudget(minFetchInterval: 8 * 60 * 60)
        let service = makeService(
            locationStatus: .authorizedWhenInUse,
            weatherProvider: provider,
            budget: budget
        )
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

        await service.fetchUVIndex(prefersLiveData: true, now: now)
        await service.fetchUVIndex(prefersLiveData: true, now: now.addingTimeInterval(60))

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(service.currentReading?.source, .localEstimate)
    }

    func testConcurrentRefreshWaitsForTheSharedWeatherRequest() async throws {
        let provider = CountingUVWeatherProvider(delay: .milliseconds(100))
        let service = makeService(
            locationStatus: .authorizedWhenInUse,
            weatherProvider: provider
        )
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let firstRefresh = Task {
            await service.fetchUVIndex(prefersLiveData: true, now: now)
        }

        for _ in 0..<100 {
            if provider.requestCount > 0 {
                break
            }
            await Task.yield()
        }
        XCTAssertEqual(provider.requestCount, 1)
        await service.fetchUVIndex(prefersLiveData: true, now: now)

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(service.currentReading?.source, .weatherKit)
        await firstRefresh.value
    }

    func testLocalEstimatorUsesHemisphereSeasonAndAlwaysReturnsAGenericValue() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let januaryNoon = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 1,
            day: 15,
            hour: 12
        )))
        let julyNoon = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 15,
            hour: 12
        )))

        XCTAssertGreaterThan(
            SunclubUVEstimator.estimatedIndex(at: januaryNoon, calendar: calendar, latitude: -34),
            SunclubUVEstimator.estimatedIndex(at: januaryNoon, calendar: calendar, latitude: 34)
        )
        XCTAssertGreaterThan(
            SunclubUVEstimator.estimatedIndex(at: julyNoon, calendar: calendar, latitude: 34),
            SunclubUVEstimator.estimatedIndex(at: julyNoon, calendar: calendar, latitude: -34)
        )
        XCTAssertGreaterThan(
            SunclubUVEstimator.estimatedIndex(at: januaryNoon, calendar: calendar, latitude: nil),
            0
        )
    }

    func testProtectionWindowUsesOnlyElevatedHoursOnRequestedDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let hours = [
            (8, 2),
            (9, 3),
            (12, 7),
            (13, 2)
        ].compactMap { hour, index -> SunclubUVHourForecast? in
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { return nil }
            return SunclubUVHourForecast(date: date, index: index, sourceLabel: UVReadingSource.weatherKitSourceLabel)
        }
        let bundle = SunclubUVForecastBundle(
            generatedAt: day,
            latitude: 34,
            longitude: -118,
            currentIndex: 3,
            hourly: hours,
            daily: []
        )

        let window = try XCTUnwrap(bundle.protectionWindow(for: day, calendar: calendar))
        XCTAssertEqual(calendar.component(.hour, from: window.start), 9)
        XCTAssertEqual(calendar.component(.hour, from: window.end), 13)
    }

    func testBriefingFallsBackForMissingOrStaleWeather() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 10,
            hour: 16
        )))
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        let staleBundle = makeBundle(
            generatedAt: now.addingTimeInterval(-9 * 60 * 60),
            place: place,
            calendar: calendar
        )
        let service = SunclubUVBriefingService(cache: makeCache())

        let missing = await service.forecast(
            prefersLiveData: true,
            fallbackLatitude: place.latitude,
            referenceDate: now,
            calendar: calendar
        )
        let stale = await service.forecast(
            prefersLiveData: true,
            liveBundle: staleBundle,
            readingSource: .cachedWeatherKit,
            fallbackLatitude: place.latitude,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertTrue(missing.isAvailable)
        XCTAssertEqual(missing.sourceLabel, UVReadingSource.localEstimate.forecastLabel)
        XCTAssertFalse(missing.hours.isEmpty)
        XCTAssertTrue(stale.isAvailable)
        XCTAssertEqual(stale.sourceLabel, UVReadingSource.cachedWeatherKit.forecastLabel)
        XCTAssertFalse(stale.hours.isEmpty)
    }

    func testNotificationForecastRejectsNineHourLastKnownWeather() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 10,
            hour: 16
        )))
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        let cache = makeCache(maxAge: 24 * 60 * 60)
        cache.store(makeBundle(
            generatedAt: now.addingTimeInterval(-9 * 60 * 60),
            place: place,
            calendar: calendar
        ))
        let service = SunclubUVBriefingService(cache: cache)

        let forecast = service.notificationForecast(
            referenceDate: now,
            readingSource: .cachedWeatherKit,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(forecast.isAvailable)
        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.unavailableSourceLabel)
    }

    func testNotificationForecastRejectsPersistentWeatherAfterLocalFallback() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 10,
            hour: 16
        )))
        let place = SunclubSelectedUVPlace(displayName: "New York", latitude: 40.7128, longitude: -74.0060)
        let cache = makeCache(maxAge: 24 * 60 * 60)
        cache.store(makeBundle(generatedAt: now, place: place, calendar: calendar))
        let service = SunclubUVBriefingService(cache: cache)

        let forecast = service.notificationForecast(
            referenceDate: now,
            readingSource: .localEstimate,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(forecast.isAvailable)
        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.unavailableSourceLabel)
    }

    func testNotificationForecastRejectsCacheWithoutResolvedProvenance() throws {
        let now = Date()
        let place = SunclubSelectedUVPlace(
            displayName: "New York",
            latitude: 40.7128,
            longitude: -74.0060
        )
        let cache = makeCache(maxAge: 24 * 60 * 60)
        cache.store(makeBundle(generatedAt: now, place: place))
        let service = SunclubUVBriefingService(cache: cache)

        let forecast = service.notificationForecast(
            referenceDate: now,
            readingSource: nil,
            now: now
        )

        XCTAssertFalse(forecast.isAvailable)
        XCTAssertEqual(forecast.sourceLabel, UVReadingSource.unavailableSourceLabel)
    }

    private func makeSettingsSnapshot(
        selectedUVPlace: SunclubSelectedUVPlace?,
        sunscreenProfile: SunclubSunscreenProfile?
    ) -> SettingsProjectionSnapshot {
        SettingsProjectionSnapshot(
            hasCompletedOnboarding: true,
            reminderHour: 8,
            reminderMinute: 0,
            weeklyHour: 18,
            weeklyWeekday: 1,
            dailyPhraseState: nil,
            weeklyPhraseState: nil,
            smartReminderSettingsData: nil,
            reapplyReminderEnabled: false,
            reapplyIntervalMinutes: 120,
            usesLiveUV: false,
            selectedUVPlace: selectedUVPlace,
            sunscreenProfile: sunscreenProfile
        )
    }

    private func makeService(
        locationStatus: CLAuthorizationStatus,
        weatherProvider: any LiveUVWeatherProviding,
        cache: SunclubUVForecastCache? = nil,
        budget: SunclubWeatherKitBudget? = nil
    ) -> UVIndexService {
        UVIndexService(
            locationService: UITestLiveUVLocationService(
                authorizationStatus: locationStatus,
                location: CLLocation(latitude: 34.1478, longitude: -118.1445)
            ),
            weatherProvider: weatherProvider,
            cache: cache ?? makeCache(),
            budget: budget ?? SunclubWeatherKitBudget(
                appGroupID: "group.test.\(UUID().uuidString)",
                policyKey: "test-policy-\(UUID().uuidString)",
                counterKey: "test-counter-\(UUID().uuidString)"
            ),
            networkPathProvider: { nil }
        )
    }

    private func makeBudget(minFetchInterval: TimeInterval) -> SunclubWeatherKitBudget {
        let budget = SunclubWeatherKitBudget(
            appGroupID: "group.test.\(UUID().uuidString)",
            policyKey: "test-policy-\(UUID().uuidString)",
            counterKey: "test-counter-\(UUID().uuidString)"
        )
        budget.storePolicy(SunclubWeatherKitBudgetPolicy(
            weatherKitEnabled: true,
            minFetchIntervalSeconds: minFetchInterval,
            maxDailyFetchesPerDevice: 2,
            maxMonthlyFetchesPerDevice: 60,
            reason: ""
        ))
        return budget
    }

    private func makeCache(maxAge: TimeInterval = UVIndexService.verifiedDataMaxAge) -> SunclubUVForecastCache {
        SunclubUVForecastCache(
            appGroupID: "group.test.\(UUID().uuidString)",
            key: "test-\(UUID().uuidString)",
            policy: SunclubUVForecastCachePolicy(maxAge: maxAge, locationRadiusMeters: 5_000)
        )
    }

    private func makeBundle(
        generatedAt: Date,
        place: SunclubSelectedUVPlace,
        calendar: Calendar = .current
    ) -> SunclubUVForecastBundle {
        let dayStart = calendar.startOfDay(for: generatedAt)
        let hourly = [9, 12, 15].compactMap { hour -> SunclubUVHourForecast? in
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart) else { return nil }
            return SunclubUVHourForecast(date: date, index: hour == 12 ? 7 : 3, sourceLabel: UVReadingSource.weatherKitSourceLabel)
        }
        return SunclubUVForecastBundle(
            generatedAt: generatedAt,
            latitude: place.latitude,
            longitude: place.longitude,
            currentIndex: 5,
            hourly: hourly,
            daily: []
        )
    }
}

@MainActor
private final class CountingUVWeatherProvider: LiveUVWeatherProviding {
    private(set) var requestCount = 0
    private let shouldFail: Bool
    private let delay: Duration?

    init(shouldFail: Bool = false, delay: Duration? = nil) {
        self.shouldFail = shouldFail
        self.delay = delay
    }

    func uvBundle(for location: CLLocation, referenceDate: Date) async throws -> SunclubUVForecastBundle {
        requestCount += 1
        if let delay {
            try await Task.sleep(for: delay)
        }
        if shouldFail {
            throw CountingUVWeatherProviderError.unavailable
        }
        return try await UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9)
            .uvBundle(for: location, referenceDate: referenceDate)
    }

    func attributionMarkup() async throws -> SunclubWeatherAttribution {
        try await UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9).attributionMarkup()
    }
}

private enum CountingUVWeatherProviderError: Error {
    case unavailable
}
