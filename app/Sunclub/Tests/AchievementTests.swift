import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class AchievementTests: XCTestCase {
    private let newAchievementIDs: [SunclubAchievementID] = [
        .morningGlow,
        .weekendCanopy,
        .spfSampler,
        .noteTaker,
        .reapplyRelay,
        .highUVHero,
        .homeBase,
        .liveSignal,
        .bottleDetective,
        .socialSpark
    ]

    func testAllAchievementsIncludeNewSetAndMetadata() throws {
        let achievements = SunclubGrowthAnalytics.achievements(
            records: [],
            changeBatches: [],
            now: date(year: 2026, month: 7, day: 1),
            calendar: calendar
        )

        XCTAssertEqual(SunclubAchievementID.allCases.count, 18)
        XCTAssertEqual(achievements.count, 18)

        for id in newAchievementIDs {
            let achievement = try XCTUnwrap(achievements.first(where: { $0.id == id }))
            XCTAssertFalse(id.title.isEmpty)
            XCTAssertFalse(id.symbolName.isEmpty)
            XCTAssertGreaterThan(id.targetValue, 0)
            XCTAssertEqual(achievement.title, id.title)
            XCTAssertEqual(achievement.symbolName, id.symbolName)
            XCTAssertTrue(achievement.shareBlurb.contains(id.title))
            XCTAssertTrue(achievement.shareBlurb.contains("Sunclub"))
        }
    }

    func testNewAchievementsUnlockFromMinimalFixtures() throws {
        XCTAssertTrue(try achievement(.morningGlow, records: records(count: 5, hour: 8)).isUnlocked)
        XCTAssertTrue(try achievement(.weekendCanopy, records: weekendRecords(pairCount: 4)).isUnlocked)
        XCTAssertTrue(try achievement(.spfSampler, records: spfRecords([15, 30, 45, 50, 70])).isUnlocked)
        XCTAssertTrue(try achievement(.noteTaker, records: records(count: 10, notes: { "Log \($0)" })).isUnlocked)
        XCTAssertTrue(try achievement(.reapplyRelay, records: [record(day: date(year: 2026, month: 4, day: 1), reapplyCount: 3)]).isUnlocked)
        XCTAssertTrue(try achievement(.highUVHero, records: records(count: 10, startingAt: date(year: 2026, month: 7, day: 1))).isUnlocked)
        XCTAssertTrue(try achievement(.homeBase, settings: makeSettings(homeBase: true)).isUnlocked)
        XCTAssertTrue(try achievement(.liveSignal, growthSettings: makeGrowthSettings(dailyUVBriefingEnabled: true)).isUnlocked)
        XCTAssertTrue(try achievement(.bottleDetective, growthSettings: SunclubGrowthSettings(telemetry: SunclubGrowthTelemetry(productScanUseCount: 1))).isUnlocked)
        XCTAssertTrue(try achievement(.socialSpark, growthSettings: SunclubGrowthSettings(telemetry: SunclubGrowthTelemetry(shareActionCount: 1))).isUnlocked)
    }

    func testNewAchievementsStayLockedBelowTarget() throws {
        XCTAssertFalse(try achievement(.morningGlow, records: records(count: 4, hour: 8)).isUnlocked)
        XCTAssertFalse(try achievement(.weekendCanopy, records: weekendRecords(pairCount: 3)).isUnlocked)
        XCTAssertFalse(try achievement(.spfSampler, records: spfRecords([15, 30, 45, 50])).isUnlocked)
        XCTAssertFalse(try achievement(.noteTaker, records: records(count: 9, notes: { "Log \($0)" })).isUnlocked)
        XCTAssertFalse(try achievement(.reapplyRelay, records: [record(day: date(year: 2026, month: 4, day: 1), reapplyCount: 2)]).isUnlocked)
        XCTAssertFalse(try achievement(.highUVHero, records: records(count: 9, startingAt: date(year: 2026, month: 7, day: 1))).isUnlocked)
        XCTAssertFalse(try achievement(.homeBase, settings: makeSettings(homeBase: false)).isUnlocked)
        XCTAssertFalse(try achievement(.liveSignal, growthSettings: makeGrowthSettings(dailyUVBriefingEnabled: false)).isUnlocked)
        XCTAssertFalse(try achievement(.bottleDetective, growthSettings: SunclubGrowthSettings()).isUnlocked)
        XCTAssertFalse(try achievement(.socialSpark, growthSettings: SunclubGrowthSettings()).isUnlocked)
    }

    func testLegacyGrowthSettingsDecodeWithoutTelemetry() throws {
        let json = """
        {
          "preferredName": "Mina",
          "healthKit": {
            "isEnabled": true,
            "importedSampleCount": 3
          },
          "uvBriefing": {
            "dailyBriefingEnabled": false,
            "extremeAlertEnabled": true,
            "morningHour": 7,
            "morningMinute": 30
          },
          "friends": [],
          "presentedAchievementIDs": ["streak7"]
        }
        """

        let decoded = try JSONDecoder().decode(SunclubGrowthSettings.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.preferredName, "Mina")
        XCTAssertTrue(decoded.healthKit.isEnabled)
        XCTAssertEqual(decoded.healthKit.importedSampleCount, 3)
        XCTAssertFalse(decoded.uvBriefing.dailyBriefingEnabled)
        XCTAssertTrue(decoded.uvBriefing.extremeAlertEnabled)
        XCTAssertEqual(decoded.presentedAchievementIDs, ["streak7"])
        XCTAssertEqual(decoded.telemetry, SunclubGrowthTelemetry())
    }

    func testTelemetryMethodsPersistAndAffectAchievements() throws {
        let store = CapturingGrowthFeatureStore(settings: SunclubGrowthSettings())
        let state = try makeAppState(growthFeatureStore: store)

        XCTAssertFalse(try state.achievement(.socialSpark).isUnlocked)
        XCTAssertFalse(try state.achievement(.bottleDetective).isUnlocked)

        state.recordShareActionStarted()
        XCTAssertEqual(store.settings.telemetry.shareActionCount, 1)
        XCTAssertNotNil(store.settings.telemetry.lastSharedAt)
        XCTAssertTrue(try state.achievement(.socialSpark).isUnlocked)

        state.recordProductScanUsedForLog(spfLevel: nil)
        XCTAssertEqual(store.settings.telemetry.productScanUseCount, 0)

        state.recordProductScanUsedForLog(spfLevel: 50)
        XCTAssertEqual(store.settings.telemetry.productScanUseCount, 1)
        XCTAssertNotNil(store.settings.telemetry.lastProductScanUsedAt)
        XCTAssertTrue(try state.achievement(.bottleDetective).isUnlocked)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func achievement(
        _ id: SunclubAchievementID,
        records: [DailyRecord] = [],
        settings: Settings? = nil,
        growthSettings: SunclubGrowthSettings = SunclubGrowthSettings()
    ) throws -> SunclubAchievement {
        try XCTUnwrap(
            SunclubGrowthAnalytics.achievements(
                records: records,
                changeBatches: [],
                settings: settings,
                growthSettings: growthSettings,
                now: date(year: 2026, month: 7, day: 15),
                calendar: calendar
            )
            .first(where: { $0.id == id })
        )
    }

    private func makeAppState(growthFeatureStore: SunclubGrowthFeatureStoring) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            healthKitService: AchievementTestHealthKitService(),
            liveActivityCoordinator: AchievementTestLiveActivityCoordinator(),
            cloudSyncCoordinator: AchievementTestCloudSyncCoordinator(),
            growthFeatureStore: growthFeatureStore,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false,
                isPreviewing: true,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )
    }

    private func makeSettings(homeBase: Bool = false) -> Settings {
        let settings = Settings()

        if homeBase {
            var smartReminderSettings = settings.smartReminderSettings
            smartReminderSettings.leaveHomeReminder = LeaveHomeReminderSettings(
                isEnabled: true,
                homeLocation: HomeLocation(latitude: 34.116, longitude: -118.150)
            )
            settings.smartReminderSettings = smartReminderSettings
        }

        return settings
    }

    private func makeGrowthSettings(
        dailyUVBriefingEnabled: Bool
    ) -> SunclubGrowthSettings {
        var settings = SunclubGrowthSettings()
        settings.uvBriefing.dailyBriefingEnabled = dailyUVBriefingEnabled
        return settings
    }

    private func records(
        count: Int,
        startingAt start: Date? = nil,
        hour: Int = 9,
        notes: (Int) -> String? = { _ in nil }
    ) -> [DailyRecord] {
        let start = start ?? date(year: 2026, month: 4, day: 1)
        return (0..<count).compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: start) else {
                return nil
            }
            return record(day: day, hour: hour, notes: notes(index))
        }
    }

    private func spfRecords(_ spfLevels: [Int]) -> [DailyRecord] {
        spfLevels.enumerated().compactMap { index, spfLevel in
            guard let day = calendar.date(byAdding: .day, value: index, to: date(year: 2026, month: 4, day: 1)) else {
                return nil
            }
            return record(day: day, spfLevel: spfLevel)
        }
    }

    private func weekendRecords(pairCount: Int) -> [DailyRecord] {
        let firstSaturday = date(year: 2026, month: 1, day: 3)
        return (0..<pairCount).flatMap { index -> [DailyRecord] in
            guard let saturday = calendar.date(byAdding: .day, value: index * 7, to: firstSaturday),
                  let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) else {
                return []
            }
            return [
                record(day: saturday),
                record(day: sunday)
            ]
        }
    }

    private func record(
        day: Date,
        hour: Int = 9,
        spfLevel: Int? = nil,
        notes: String? = nil,
        reapplyCount: Int = 0
    ) -> DailyRecord {
        let startOfDay = calendar.startOfDay(for: day)
        let verifiedAt = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
        let lastReappliedAt = reapplyCount > 0
            ? calendar.date(bySettingHour: hour + 2, minute: 0, second: 0, of: startOfDay)
            : nil

        return DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: spfLevel,
            notes: notes,
            reapplyCount: reapplyCount,
            lastReappliedAt: lastReappliedAt
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

private extension AppState {
    func achievement(_ id: SunclubAchievementID) throws -> SunclubAchievement {
        try XCTUnwrap(achievements.first(where: { $0.id == id }))
    }
}

private final class CapturingGrowthFeatureStore: SunclubGrowthFeatureStoring {
    var settings: SunclubGrowthSettings

    init(settings: SunclubGrowthSettings) {
        self.settings = settings
    }

    func load() -> SunclubGrowthSettings {
        settings
    }

    func save(_ settings: SunclubGrowthSettings) {
        self.settings = settings
    }
}

@MainActor
private final class AchievementTestCloudSyncCoordinator: CloudSyncControlling {
    func start() async {}
    func setEnabled(_ enabled: Bool) async throws {}
    func queueBatchIfNeeded(_ batchID: UUID) async {}
    func syncNow() async {}
    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult {
        CloudPublishResult(importSessionID: sessionID, publishedBatchCount: 0)
    }
}

@MainActor
private final class AchievementTestHealthKitService: SunclubHealthKitServing {
    var isAvailable: Bool { false }
    func requestAuthorizationIfNeeded() async -> Bool { false }
    func exportLog(recordDate: Date, uvIndex: Int?, externalID: UUID?, spfLevel: Int?) async {}
    func recentUVSampleCount(since startDate: Date) async -> Int { 0 }
}

@MainActor
private final class AchievementTestLiveActivityCoordinator: SunclubLiveActivityCoordinating {
    func sync(using state: AppState) async {}
    func endAll() async {}
}
