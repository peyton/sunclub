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

    func testUnavailableUVNeverCreatesAHeuristicCurrentReading() async throws {
        let now = Date()
        let service = makeService(
            locationStatus: .authorizedWhenInUse,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9, shouldFail: true)
        )

        await service.fetchUVIndex(prefersLiveData: true, now: now)

        XCTAssertNil(service.currentReading)
        XCTAssertNil(service.lastBundle)
        XCTAssertEqual(service.status.availability, .unavailable)
        XCTAssertEqual(service.liveUVAccessState, .unavailable)
        XCTAssertNotNil(service.errorMessage)
    }

    func testDisablingEveryUVSourceClearsCachedWeather() async throws {
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

        XCTAssertNil(service.currentReading)
        XCTAssertNil(service.lastBundle)
        XCTAssertNil(cache.lastBundle())
        XCTAssertEqual(service.status, .unavailable)
    }

    func testCachedWeatherOlderThanTwoHoursIsUnavailable() async throws {
        let cache = makeCache(maxAge: 12 * 60 * 60)
        let fetchedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        cache.store(makeBundle(generatedAt: fetchedAt, place: place))
        let service = makeService(
            locationStatus: .denied,
            weatherProvider: UITestLiveUVWeatherProvider(currentIndex: 7, peakIndex: 9, shouldFail: true),
            cache: cache
        )

        await service.fetchUVIndex(
            prefersLiveData: false,
            selectedPlace: place,
            now: fetchedAt.addingTimeInterval(UVIndexService.verifiedDataMaxAge + 1)
        )

        XCTAssertNil(service.currentReading)
        XCTAssertNil(service.lastBundle)
        XCTAssertEqual(service.status.freshness, .stale)
        XCTAssertEqual(service.status.updatedAt, fetchedAt)
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

    func testBriefingReturnsUnavailableForMissingOrStaleWeather() async throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let place = SunclubSelectedUVPlace(displayName: "Pasadena", latitude: 34.1478, longitude: -118.1445)
        let staleBundle = makeBundle(
            generatedAt: now.addingTimeInterval(-UVIndexService.verifiedDataMaxAge - 1),
            place: place
        )
        let service = SunclubUVBriefingService(cache: makeCache())

        let missing = await service.forecast(prefersLiveData: true, referenceDate: now)
        let stale = await service.forecast(
            prefersLiveData: true,
            liveBundle: staleBundle,
            referenceDate: now
        )

        XCTAssertFalse(missing.isAvailable)
        XCTAssertEqual(missing.sourceLabel, UVReadingSource.unavailableSourceLabel)
        XCTAssertTrue(missing.hours.isEmpty)
        XCTAssertFalse(stale.isAvailable)
        XCTAssertTrue(stale.hours.isEmpty)
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
        cache: SunclubUVForecastCache? = nil
    ) -> UVIndexService {
        UVIndexService(
            locationService: UITestLiveUVLocationService(
                authorizationStatus: locationStatus,
                location: CLLocation(latitude: 34.1478, longitude: -118.1445)
            ),
            weatherProvider: weatherProvider,
            cache: cache ?? makeCache(),
            budget: SunclubWeatherKitBudget(
                appGroupID: "group.test.\(UUID().uuidString)",
                policyKey: "test-policy-\(UUID().uuidString)",
                counterKey: "test-counter-\(UUID().uuidString)"
            ),
            networkPathProvider: { nil }
        )
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
        place: SunclubSelectedUVPlace
    ) -> SunclubUVForecastBundle {
        let calendar = Calendar.current
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
