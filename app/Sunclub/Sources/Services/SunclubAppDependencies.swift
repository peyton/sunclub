import Foundation
import SwiftData

/// Concrete composition for the app. Tests supply protocol implementations and a deterministic clock.
@MainActor
struct SunclubAppDependencies {
    let context: ModelContext
    let notificationManager: NotificationScheduling
    let uvIndexService: UVIndexService
    let uvBriefingService: SunclubUVBriefingService
    let healthKitService: any SunclubHealthKitServing
    let liveActivityCoordinator: any SunclubLiveActivityCoordinating
    let backupService: SunclubBackupService
    let storeRecoveryService: SunclubStoreRecoveryService
    let historyService: SunclubHistoryService
    let cloudSyncCoordinator: CloudSyncControlling
    let widgetSnapshotStore: SunclubWidgetSnapshotStore
    let growthFeatureStore: SunclubGrowthFeatureStoring
    let runtimeEnvironment: RuntimeEnvironmentSnapshot
    let homeExitReminderMonitor: HomeExitReminderMonitoring
    let historicalUVStore: SunclubHistoricalUVStore
    let weatherKitKillSwitch: SunclubWeatherKitKillSwitch?
    let clock: () -> Date

    static func live(
        context: ModelContext,
        notificationManager: NotificationScheduling? = nil,
        uvIndexService: UVIndexService? = nil,
        uvBriefingService: SunclubUVBriefingService? = nil,
        healthKitService: (any SunclubHealthKitServing)? = nil,
        liveActivityCoordinator: (any SunclubLiveActivityCoordinating)? = nil,
        backupService: SunclubBackupService = SunclubBackupService(),
        storeRecoveryService: SunclubStoreRecoveryService = SunclubStoreRecoveryService(),
        historyService: SunclubHistoryService? = nil,
        cloudSyncCoordinator: CloudSyncControlling? = nil,
        widgetSnapshotStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
        growthFeatureStore: SunclubGrowthFeatureStoring = SunclubGrowthFeatureStore.shared,
        runtimeEnvironment: RuntimeEnvironmentSnapshot = .current,
        homeExitReminderMonitor: HomeExitReminderMonitoring? = nil,
        historicalUVStore: SunclubHistoricalUVStore? = nil,
        weatherKitKillSwitch: SunclubWeatherKitKillSwitch? = nil,
        clock: @escaping () -> Date = { RuntimeEnvironment.currentDateOverride ?? Date() }
    ) -> SunclubAppDependencies {
        let history = historyService ?? SunclubHistoryService(context: context)
        return SunclubAppDependencies(
            context: context, notificationManager: notificationManager ?? NotificationManager.shared,
            uvIndexService: uvIndexService ?? UVIndexService(),
            uvBriefingService: uvBriefingService ?? SunclubUVBriefingService(),
            healthKitService: healthKitService ?? SunclubHealthKitService.shared,
            liveActivityCoordinator: liveActivityCoordinator ?? SunclubLiveActivityCoordinator.shared,
            backupService: backupService, storeRecoveryService: storeRecoveryService, historyService: history,
            cloudSyncCoordinator: cloudSyncCoordinator ?? defaultCloudSyncCoordinator(
                historyService: history, runtimeEnvironment: runtimeEnvironment
            ),
            widgetSnapshotStore: widgetSnapshotStore,
            growthFeatureStore: defaultGrowthFeatureStore(growthFeatureStore, runtimeEnvironment: runtimeEnvironment),
            runtimeEnvironment: runtimeEnvironment,
            homeExitReminderMonitor: homeExitReminderMonitor
                ?? (runtimeEnvironment.isRunningTests ? NoopHomeExitReminderMonitor() : HomeExitReminderMonitor.shared),
            historicalUVStore: historicalUVStore ?? SunclubHistoricalUVStore(),
            weatherKitKillSwitch: weatherKitKillSwitch, clock: clock
        )
    }

    static func test(
        context: ModelContext,
        notificationManager: NotificationScheduling,
        uvIndexService: UVIndexService,
        clock: @escaping () -> Date
    ) -> SunclubAppDependencies {
        let suite = "sunclub-test-\(UUID().uuidString)"
        return live(context: context, notificationManager: notificationManager, uvIndexService: uvIndexService,
             widgetSnapshotStore: SunclubWidgetSnapshotStore(userDefaults: UserDefaults(suiteName: suite)),
             runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true, isPreviewing: false, hasAppGroupContainer: false
             ), historicalUVStore: SunclubHistoricalUVStore(appGroupID: suite), clock: clock)
    }

    static func defaultCloudSyncCoordinator(
        historyService: SunclubHistoryService,
        runtimeEnvironment: RuntimeEnvironmentSnapshot = .current
    ) -> CloudSyncControlling {
        if runtimeEnvironment.shouldUseNoopCloudSyncCoordinator {
            return NoopCloudSyncCoordinator(historyService: historyService)
        }

        return CloudSyncCoordinator(historyService: historyService)
    }

    private static func defaultGrowthFeatureStore(
        _ store: SunclubGrowthFeatureStoring,
        runtimeEnvironment: RuntimeEnvironmentSnapshot
    ) -> SunclubGrowthFeatureStoring {
        if runtimeEnvironment.isRunningTests {
            return SunclubGrowthFeatureStore(userDefaults: UserDefaults(suiteName: UUID().uuidString))
        }

        return store
    }

}
