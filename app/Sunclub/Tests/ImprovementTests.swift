import Foundation
import ImageIO
import SwiftData
import UIKit
import XCTest
@testable import Sunclub

@MainActor
final class ImprovementTests: XCTestCase {

    // MARK: - Fix 1: Duplicate widgetSnapshotStore parameter removed

    func testAppStateInitAcceptsSingleWidgetSnapshotStore() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService(),
            widgetSnapshotStore: SunclubWidgetSnapshotStore()
        )
        XCTAssertNotNil(state)
    }

    // MARK: - Fix 2: SunclubSchemaV3 frozen model definitions

    func testSchemaV3DefinesFrozenDailyRecord() {
        let models = SunclubSchemaV3.models
        XCTAssertTrue(models.contains(where: { $0 == SunclubSchemaV3.DailyRecord.self }))
    }

    func testSchemaV3DefinesFrozenSettings() {
        let models = SunclubSchemaV3.models
        XCTAssertTrue(models.contains(where: { $0 == SunclubSchemaV3.Settings.self }))
    }

    func testMigrationV2ToV3UsesFrozenTypes() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        _ = try LegacyStoreFixture.seedCurrentV2Store(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyRecord>()).first)
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
    }

    func testProductionSourcesCreateSwiftDataContainersOnlyThroughFactory() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let sunclubRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = sunclubRoot.appendingPathComponent("Sources", isDirectory: true)
        let allowedFactoryFile = sourcesRoot
            .appendingPathComponent("Models/SunclubSchema.swift")
            .standardizedFileURL
            .path
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourcesRoot,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        )
        var offenders: [String] = []

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let standardizedPath = fileURL.standardizedFileURL.path
            guard standardizedPath != allowedFactoryFile else {
                continue
            }

            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            if contents.contains("ModelContainer(") {
                offenders.append(fileURL.path.replacingOccurrences(of: "\(sunclubRoot.path)/", with: ""))
            }
        }

        XCTAssertEqual(offenders, [])
    }

    func testMigrationV3ToV4PreservesData() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        let seededDates = try LegacyStoreFixture.seedCurrentV3Store(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertTrue(settings.reapplyReminderEnabled)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyRecord>()).first)
        XCTAssertEqual(record.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(record.reapplyCount, 1)
    }

    func testFullMigrationV1ThroughV4() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        _ = try LegacyStoreFixture.seedCommit22ffStore(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertNotNil(settings.smartReminderSettingsData)
        XCTAssertNil(settings.lastReminderScheduleAt)
        XCTAssertFalse(settings.usesLiveUV)

        let record = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyRecord>()).first)
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
        XCTAssertEqual(record.method, .manual)

        XCTAssertFalse(try context.fetch(FetchDescriptor<SunclubChangeBatch>()).isEmpty)
        XCTAssertFalse(try context.fetch(FetchDescriptor<SettingsRevision>()).isEmpty)
    }

    // MARK: - Fix 6: UV heuristic hemisphere support

    func testEstimatedUVNorthernHemisphereSummerIsHigh() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // July noon, Northern Hemisphere
        let julyNoon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let uvNorth = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: 40.0)
        XCTAssertGreaterThanOrEqual(uvNorth, 6, "Northern Hemisphere summer noon should have high UV")
    }

    func testEstimatedUVSouthernHemisphereSummerIsHigh() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // January noon, Southern Hemisphere (their summer)
        let janNoon = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let uvSouth = UVIndexService.estimatedUVIndex(at: janNoon, calendar: calendar, latitude: -33.0)
        XCTAssertGreaterThanOrEqual(uvSouth, 6, "Southern Hemisphere January noon should have high UV")
    }

    func testEstimatedUVSouthernHemisphereWinterIsLow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // July noon, Southern Hemisphere (their winter)
        let julyNoon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let uvSouth = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: -33.0)
        XCTAssertLessThanOrEqual(uvSouth, 3, "Southern Hemisphere July noon should have low UV")
    }

    func testEstimatedUVNilLatitudeDefaultsToNorthernHemisphere() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let julyNoon = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let uvDefault = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: nil)
        let uvNorth = UVIndexService.estimatedUVIndex(at: julyNoon, calendar: calendar, latitude: 40.0)
        XCTAssertEqual(uvDefault, uvNorth, "nil latitude should behave like Northern Hemisphere")
    }

    func testEstimatedUVNighttimeIsZero() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let midnight = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 2))!
        XCTAssertEqual(UVIndexService.estimatedUVIndex(at: midnight, calendar: calendar, latitude: 40.0), 0)
        XCTAssertEqual(UVIndexService.estimatedUVIndex(at: midnight, calendar: calendar, latitude: -33.0), 0)
    }

    // MARK: - Fix 7 & 8: AppState error logging

    func testAppStateHasLastRefreshErrorProperty() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService()
        )
        XCTAssertNil(state.lastRefreshError, "lastRefreshError should be nil after successful init")
    }

    func testRefreshClearsLastRefreshErrorOnSuccess() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService()
        )
        state.refresh()
        XCTAssertNil(state.lastRefreshError)
    }

    // MARK: - App Store readiness: scanner parsing and efficiency

    func testProductScannerAnalyzerParsesCommonSPFVariants() {
        let cases: [(line: String, spfLevel: Int)] = [
            ("Broad Spectrum SPF-50+", 50),
            ("SPF: 30 water resistant", 30),
            ("sun protection factor 45", 45),
            ("50 SPF lotion", 50),
            ("Sunscreen 100", 100),
            ("SPF 150", 100)
        ]

        for testCase in cases {
            let result = SunclubProductScannerService.analyze(recognizedText: [testCase.line])
            XCTAssertEqual(result.spfLevel, testCase.spfLevel, "Failed to parse \(testCase.line)")
        }
    }

    func testProductScannerAnalyzerPreservesUsefulExpirationText() {
        let cases: [(line: String, expiration: String)] = [
            ("EXP 05/2027", "05/2027"),
            ("Expires 05/27", "05/27"),
            ("EXP 2027-05", "2027-05"),
            ("EXP JAN 2027", "JAN 2027"),
            ("Best by 2028/6", "2028/6")
        ]

        for testCase in cases {
            let result = SunclubProductScannerService.analyze(recognizedText: [testCase.line])
            XCTAssertEqual(result.expirationText, testCase.expiration, "Failed to parse \(testCase.line)")
        }
    }

    func testProductScannerResultAsksUserToConfirmDetectedSPF() {
        let result = SunclubProductScanResult(
            spfLevel: 50,
            expirationText: nil,
            recognizedText: ["SPF 50"]
        )
        let noResult = SunclubProductScanResult(
            spfLevel: nil,
            expirationText: nil,
            recognizedText: ["WATER RESISTANT"]
        )

        XCTAssertTrue(result.confirmationDetail.contains("Check this against the label"))
        XCTAssertTrue(noResult.confirmationDetail.contains("enter SPF manually"))
    }

    func testProductScannerAnalyzerNormalizesAndCapsRecognizedText() {
        let longLine = String(repeating: "A", count: 140)
        let input = ["  SPF    50  ", "spf 50"] + (0..<20).map { "Line \($0) \(longLine)" }

        let result = SunclubProductScannerService.analyze(recognizedText: input)

        XCTAssertEqual(result.spfLevel, 50)
        XCTAssertEqual(result.recognizedText.first, "SPF 50")
        XCTAssertEqual(result.recognizedText.count, 12)
        XCTAssertFalse(result.recognizedText.contains("spf 50"))
        XCTAssertTrue(result.recognizedText.last?.hasSuffix("...") == true)
    }

    func testProductScannerMapsUIImageOrientationForVision() {
        let cases: [(UIImage.Orientation, CGImagePropertyOrientation)] = [
            (.up, .up),
            (.upMirrored, .upMirrored),
            (.down, .down),
            (.downMirrored, .downMirrored),
            (.left, .leftMirrored),
            (.leftMirrored, .left),
            (.right, .rightMirrored),
            (.rightMirrored, .right)
        ]

        for (imageOrientation, expectedVisionOrientation) in cases {
            XCTAssertEqual(
                SunclubProductScannerService.visionOrientation(for: imageOrientation),
                expectedVisionOrientation
            )
        }
    }

    // MARK: - App Store readiness: manual log suggestions

    func testManualLogSuggestionsExposeUsualSPFAfterNoteOnlyLog() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 14)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        let twoDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: today))

        let noteOnlyRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: try XCTUnwrap(calendar.date(byAdding: .hour, value: 8, to: yesterday)),
            method: .manual,
            notes: "Cloudy commute"
        )
        let spfRecord = DailyRecord(
            startOfDay: twoDaysAgo,
            verifiedAt: try XCTUnwrap(calendar.date(byAdding: .hour, value: 9, to: twoDaysAgo)),
            method: .manual,
            spfLevel: 45,
            notes: nil
        )

        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: [noteOnlyRecord, spfRecord],
            excluding: today,
            calendar: calendar
        )

        XCTAssertEqual(suggestions.sameAsLastTime?.note, "Cloudy commute")
        XCTAssertNil(suggestions.sameAsLastTime?.spfLevel)
        XCTAssertEqual(suggestions.defaultSPF, 45)
    }

    // MARK: - App Store readiness: injected clock consistency

    func testAppStateUsesInjectedClockForTodayLogReportsAndWidgetSnapshot() throws {
        let calendar = Calendar.current
        let fixedNow = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 10, minute: 30)))
        let suiteName = "sunclub-improvement-tests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let widgetStore = SunclubWidgetSnapshotStore(userDefaults: userDefaults)
        let state = AppState(
            context: ModelContext(container),
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService(),
            widgetSnapshotStore: widgetStore,
            clock: { fixedNow }
        )

        state.completeOnboarding()
        state.recordVerificationSuccess(method: .manual, spfLevel: 50, notes: "Release test")

        let record = try XCTUnwrap(state.record(for: fixedNow))
        XCTAssertTrue(calendar.isDate(record.startOfDay, inSameDayAs: fixedNow))
        XCTAssertEqual(record.verifiedAt, fixedNow)
        XCTAssertEqual(state.currentStreak, 1)

        let report = state.last7DaysReport()
        XCTAssertEqual(report.endDate, calendar.startOfDay(for: fixedNow))
        XCTAssertEqual(report.appliedCount, 1)

        let snapshot = widgetStore.load()
        XCTAssertEqual(snapshot.currentStreak, 1)
        XCTAssertEqual(snapshot.weeklyAppliedCount, 1)
        XCTAssertTrue(calendar.isDate(try XCTUnwrap(snapshot.lastLoggedDay), inSameDayAs: fixedNow))
    }

    func testAppStateReferenceDateUsesInjectedClock() throws {
        let calendar = Calendar.current
        let fixedNow = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 16)))
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            clock: { fixedNow }
        )

        XCTAssertEqual(state.referenceDate, fixedNow)
    }

    func testNoopSettingsUpdatesDoNotCreateDurableHistoryBatches() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let state = AppState(
            context: ModelContext(container),
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService()
        )
        let initialBatchCount = state.changeBatches.count
        let reminderSettings = state.settings.smartReminderSettings

        state.updateDailyReminder(
            hour: reminderSettings.weekdayTime.hour,
            minute: reminderSettings.weekdayTime.minute
        )
        state.updateReminderTime(
            for: .weekend,
            hour: reminderSettings.weekendTime.hour,
            minute: reminderSettings.weekendTime.minute
        )
        state.updateTravelTimeZoneHandling(followsTravelTimeZone: reminderSettings.followsTravelTimeZone)
        state.updateStreakRiskReminder(enabled: reminderSettings.streakRiskEnabled)
        state.updateLeaveHomeReminderEnabled(
            enabled: reminderSettings.leaveHomeReminder.isEnabled,
            allowPermissionPrompt: false
        )
        state.updateReapplySettings(
            enabled: state.settings.reapplyReminderEnabled,
            intervalMinutes: state.settings.reapplyIntervalMinutes
        )
        state.updateLiveUVPreference(enabled: state.settings.usesLiveUV, allowPermissionPrompt: false)

        XCTAssertEqual(state.changeBatches.count, initialBatchCount)
    }
}
