import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class MockNotificationManager: NotificationScheduling {
    private(set) var requestAuthorizationIfNeededCount = 0
    private(set) var scheduleRemindersCount = 0
    private(set) var scheduledUVReadingSources: [UVReadingSource?] = []
    private(set) var scheduledUVPlaces: [SunclubSelectedUVPlace?] = []
    private(set) var scheduleReapplyReminderPlans: [ReapplyReminderPlan] = []
    private(set) var scheduleLeaveHomeReminderLevels: [UVLevel] = []
    private(set) var refreshStreakRiskReminderCount = 0
    private(set) var scheduleReapplyReminderRoutes: [AppRoute] = []
    private(set) var scheduleLeaveHomeReminderRoutes: [AppRoute] = []
    private(set) var cancelDailyReminderDays: [Date] = []
    private(set) var cancelReapplyRemindersCount = 0
    private(set) var notificationHealthSnapshotCount = 0

    var requestAuthorizationResult = true
    var scheduleRemindersResult: NotificationSchedulingReport = .empty
    var notificationOperationResult = NotificationOperationResult.success("Scheduled.")
    var notificationHealthSnapshotResult: NotificationHealthSnapshot = .unknown

    func requestAuthorizationIfNeeded() async -> Bool {
        requestAuthorizationIfNeededCount += 1
        return requestAuthorizationResult
    }

    @discardableResult
    func scheduleReminders(using state: any SunclubReminderState) async -> NotificationSchedulingReport {
        scheduleRemindersCount += 1
        scheduledUVReadingSources.append(state.uvReading?.source)
        scheduledUVPlaces.append(state.settings.selectedUVPlace)
        return scheduleRemindersResult
    }

    @discardableResult
    func scheduleReapplyReminder(
        plan: ReapplyReminderPlan,
        route: AppRoute
    ) async -> NotificationOperationResult {
        scheduleReapplyReminderPlans.append(plan)
        scheduleReapplyReminderRoutes.append(route)
        return notificationOperationResult
    }

    @discardableResult
    func scheduleLeaveHomeReminder(
        level: UVLevel,
        route: AppRoute
    ) async -> NotificationOperationResult {
        scheduleLeaveHomeReminderLevels.append(level)
        scheduleLeaveHomeReminderRoutes.append(route)
        return notificationOperationResult
    }

    func cancelDailyReminder(for day: Date, using state: any SunclubReminderState) async {
        cancelDailyReminderDays.append(day)
    }

    @discardableResult
    func refreshStreakRiskReminder(using state: any SunclubReminderState) async -> NotificationOperationResult {
        refreshStreakRiskReminderCount += 1
        return notificationOperationResult
    }

    func cancelReapplyReminders() async {
        cancelReapplyRemindersCount += 1
    }

    func notificationHealthSnapshot(using state: any SunclubReminderState) async -> NotificationHealthSnapshot {
        notificationHealthSnapshotCount += 1
        return notificationHealthSnapshotResult
    }
}

@MainActor
final class ProbeCloudSyncCoordinator: CloudSyncControlling {
    private(set) var startCallCount = 0
    private(set) var queuedBatchIDs: [UUID] = []
    var startResults: [CloudSyncStartResult] = [.noRemoteHistory]

    func start() async -> CloudSyncStartResult {
        startCallCount += 1
        if startResults.count > 1 {
            return startResults.removeFirst()
        }
        return startResults.first ?? .noRemoteHistory
    }

    func setEnabled(_ enabled: Bool) async throws {}

    func queueBatchIfNeeded(_ batchID: UUID) async {
        queuedBatchIDs.append(batchID)
    }

    func syncNow() async {}

    func publishImportedSession(_ sessionID: UUID) async throws -> CloudPublishResult {
        CloudPublishResult(importSessionID: sessionID, publishedBatchCount: 0)
    }
}

@MainActor
final class FakeCloudSyncEngineDriver: CloudSyncEngineDriving {
    enum Operation: Equatable {
        case saveZone
        case saveRecord(String)
        case send
        case fetch
        case cancel
    }

    private(set) var operations: [Operation] = []
    var fetchHandler: (() throws -> Void)?
    var sendError: Error?

    func addPendingDatabaseChanges(_ changes: [CKSyncEngine.PendingDatabaseChange]) {
        for change in changes {
            switch change {
            case .saveZone:
                operations.append(.saveZone)
            case .deleteZone:
                break
            @unknown default:
                break
            }
        }
    }

    func addPendingRecordZoneChanges(_ changes: [CKSyncEngine.PendingRecordZoneChange]) {
        for change in changes {
            switch change {
            case let .saveRecord(recordID):
                operations.append(.saveRecord(recordID.recordName))
            case .deleteRecord:
                break
            @unknown default:
                break
            }
        }
    }

    func sendAllChanges() async throws {
        operations.append(.send)
        if let sendError {
            throw sendError
        }
    }

    func fetchAllChanges() async throws {
        operations.append(.fetch)
        try fetchHandler?()
    }

    func cancelOperations() async {
        operations.append(.cancel)
    }
}

struct StaticCloudKitEntitlementProvider: SunclubCloudKitEntitlementProviding {
    var entitlements: [String: Any]

    func entitlementValue(for key: String) -> Any? {
        entitlements[key]
    }
}

@MainActor
final class MockHomeExitReminderMonitor: HomeExitReminderMonitoring {
    private(set) var refreshMonitoringCalls: [(enabled: Bool, hasHome: Bool, allowPermissionPrompt: Bool)] = []
    private(set) var saveHomeFromCurrentLocationCount = 0
    private var stateProvider: (() -> (any SunclubReminderState)?)?

    var authorizationState: LeaveHomeAuthorizationState = .notDetermined
    var saveHomeResult: Result<HomeLocation, Error> = .success(
        HomeLocation(latitude: 34.116, longitude: -118.150)
    )
    var hasTriggeredReminderResult = false

    func setStateProvider(_ provider: @escaping () -> (any SunclubReminderState)?) {
        stateProvider = provider
    }

    func refreshMonitoring(using state: any SunclubReminderState, allowPermissionPrompt: Bool) async -> LeaveHomeAuthorizationState {
        refreshMonitoringCalls.append((
            enabled: state.settings.smartReminderSettings.leaveHomeReminder.isEnabled,
            hasHome: state.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil,
            allowPermissionPrompt: allowPermissionPrompt
        ))
        return authorizationState
    }

    func saveHomeFromCurrentLocation() async throws -> HomeLocation {
        saveHomeFromCurrentLocationCount += 1
        return try saveHomeResult.get()
    }

    func hasTriggeredReminder(on date: Date) -> Bool {
        hasTriggeredReminderResult
    }
}

@MainActor
class SunclubTestCase: XCTestCase {
    static func cloudKitEntitlements(containerIdentifier: String) -> [String: Any] {
        [
            "com.apple.developer.icloud-container-identifiers": [containerIdentifier],
            "com.apple.developer.icloud-services": ["CloudKit"]
        ]
    }

    @MainActor
    func makeAppState(
        notificationManager: NotificationScheduling? = nil,
        homeExitReminderMonitor: HomeExitReminderMonitoring? = nil,
        uvIndexService: UVIndexService? = nil,
        uvBriefingService: SunclubUVBriefingService? = nil,
        cloudSyncCoordinator: CloudSyncControlling? = nil,
        growthFeatureStore: SunclubGrowthFeatureStoring? = nil,
        runtimeEnvironment: RuntimeEnvironmentSnapshot = .current,
        widgetSnapshotStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
        clock: @escaping () -> Date = Date.init
    ) throws -> AppState {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        return AppState(
            context: ModelContext(container),
            notificationManager: notificationManager ?? NotificationManager.shared,
            uvIndexService: uvIndexService ?? UVIndexService(),
            uvBriefingService: uvBriefingService,
            cloudSyncCoordinator: cloudSyncCoordinator,
            widgetSnapshotStore: widgetSnapshotStore,
            growthFeatureStore: growthFeatureStore ?? SunclubGrowthFeatureStore.shared,
            runtimeEnvironment: runtimeEnvironment,
            homeExitReminderMonitor: homeExitReminderMonitor,
            clock: clock
        )
    }

    func waitForMainActorTasks() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }

    @MainActor
    func makeUVIndexService(bundle: SunclubUVForecastBundle) -> UVIndexService {
        let cache = SunclubUVForecastCache(
            appGroupID: "group.test.\(UUID().uuidString)",
            key: "test-\(UUID().uuidString)"
        )
        cache.store(bundle)
        return UVIndexService(cache: cache)
    }

    func makeUVForecastBundle(
        generatedAt: Date,
        hourly: [SunclubUVHourForecast] = [],
        daily: [SunclubUVDayForecast] = []
    ) -> SunclubUVForecastBundle {
        SunclubUVForecastBundle(
            generatedAt: generatedAt,
            latitude: 34.116,
            longitude: -118.150,
            currentIndex: nil,
            hourly: hourly,
            daily: daily
        )
    }

    @MainActor
    func waitForLiveUVForecast(
        on state: AppState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0..<20 {
            if state.uvReading?.source == .weatherKit,
               state.uvForecast?.sourceLabel == UVReadingSource.weatherKit.forecastLabel {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
            await waitForMainActorTasks()
        }

        XCTFail("Timed out waiting for Live UV forecast", file: file, line: line)
    }

    @MainActor
    func waitForReminderSchedules(
        _ expectedCount: Int,
        on notificationManager: MockNotificationManager,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0..<20 {
            if notificationManager.scheduleRemindersCount >= expectedCount {
                return
            }
            try await Task.sleep(for: .milliseconds(25))
            await waitForMainActorTasks()
        }

        XCTFail("Timed out waiting for reminder reschedule", file: file, line: line)
    }

    @MainActor
    func makeDailyRecord(
        dayOffset: Int,
        hour: Int = 9,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) -> DailyRecord {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
        let verifiedAt = calendar.date(byAdding: .hour, value: hour, to: day) ?? day

        return DailyRecord(
            startOfDay: day,
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: spfLevel,
            notes: notes
        )
    }
}
