import Foundation
import Observation
import os
import SwiftData
import WidgetKit

struct HomeTodayMetadataRow: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let symbolName: String

    var accessibilityLabel: String {
        "\(title): \(value)"
    }
}

struct HomeTodayCardPresentation: Equatable {
    let title: String
    let detail: String
    let logBadgeText: String?
    let streakRiskBadgeText: String?
    let uvHeadline: String?
    let uvSymbolName: String?
    let uvIsEstimated: Bool
    let metadataRows: [HomeTodayMetadataRow]

    var accessibilityValue: String {
        ([title, detail] + metadataRows.map(\.accessibilityLabel)).joined(separator: ". ")
    }
}

struct HomeRecoveryAction: Equatable, Identifiable {
    enum Kind: String {
        case logToday
        case backfillYesterday
    }

    let kind: Kind
    let title: String
    let detail: String
    let buttonTitle: String

    var id: Kind { kind }
}

enum HomeDailyPlanAction: String, Equatable {
    case logToday
    case backfillYesterday
    case logReapply
    case addDetails
    case viewProgress
    case reviewRecovery
    case repairReminders
    case openSettings
}

enum HomeDailyPlanTone: Equatable {
    case calm
    case action
    case warning
    case complete
}

struct HomeDailyPlanFact: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let symbolName: String

    var accessibilityLabel: String {
        "\(title): \(value)"
    }
}

struct HomeDailyPlanPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String
    let action: HomeDailyPlanAction
    let symbolName: String
    let tone: HomeDailyPlanTone
    let facts: [HomeDailyPlanFact]

    var accessibilityValue: String {
        ([title, detail] + facts.map(\.accessibilityLabel)).joined(separator: ". ")
    }
}

struct DailyReminderPreview: Equatable {
    let fireDate: Date
    let summary: String
}

struct ReapplyReminderPlan: Equatable {
    let baseIntervalMinutes: Int
    let intervalMinutes: Int
    let notificationTitle: String
    let notificationBody: String
    let confirmationText: String
    let confirmationSymbolName: String
    let fireDate: Date?
    let isElevated: Bool

    var intervalSummary: String {
        Self.formattedInterval(intervalMinutes)
    }

    var shouldScheduleNotification: Bool {
        fireDate != nil
    }

    init(
        baseIntervalMinutes: Int,
        uvReading: UVReading?,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) {
        let level = uvReading?.level ?? .unknown
        let adjustedInterval = max(30, baseIntervalMinutes - level.reapplyAdvanceMinutes)
        let isElevated = level.reapplyLabelPrefix != nil
        let scheduledFireDate = ReminderPlanner.reapplyFireDate(
            from: now,
            intervalMinutes: adjustedInterval,
            calendar: calendar
        )

        self.baseIntervalMinutes = baseIntervalMinutes
        self.intervalMinutes = adjustedInterval
        self.isElevated = isElevated
        self.notificationTitle = isElevated ? "Reapply sooner today" : "Time to reapply"
        self.fireDate = scheduledFireDate

        if let strongerMessage = level.strongerReapplyMessage {
            self.notificationBody = "\(strongerMessage) It's been \(adjustedInterval) minutes — reapply sunscreen for continued protection."
        } else {
            self.notificationBody = "It's been \(adjustedInterval) minutes — reapply sunscreen for continued protection."
        }

        if scheduledFireDate != nil {
            if let prefix = level.reapplyLabelPrefix {
                self.confirmationText = "\(prefix): reminder in \(Self.formattedInterval(adjustedInterval))"
            } else {
                self.confirmationText = "Reapply reminder in \(Self.formattedInterval(adjustedInterval))"
            }
            self.confirmationSymbolName = "timer"
        } else {
            self.confirmationText = "No reapply reminder today after sunset."
            self.confirmationSymbolName = "moon.stars"
        }
    }

    private static func formattedInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
    }
}

struct VerificationSuccessPresentation: Equatable {
    let streak: Int
    let isPersonalBest: Bool
    let canAddDetails: Bool
    let title: String

    init(streak: Int, isPersonalBest: Bool = false, canAddDetails: Bool = false, title: String = SunclubCopy.Success.defaultTitle) {
        self.streak = streak
        self.isPersonalBest = isPersonalBest
        self.canAddDetails = canAddDetails
        self.title = title
    }

    var detail: String {
        SunclubCopy.Success.streakDetail(streak)
    }
}

struct ReapplyCheckInPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String
}

enum LiveUVActionKind: Equatable {
    case requestPermission
    case openSettings
    case refresh
}

struct LiveUVStatusPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String?
    let actionKind: LiveUVActionKind?
}

enum LeaveHomeReminderActionKind: Equatable {
    case setHomeFromCurrentLocation
    case requestAlwaysAuthorization
    case openSettings
}

enum LeaveHomeReminderTone: Equatable {
    case neutral
    case success
    case warning
}

struct LeaveHomeReminderStatusPresentation: Equatable {
    let title: String
    let detail: String
    let symbol: String
    let tone: LeaveHomeReminderTone
    let actionTitle: String?
    let actionKind: LeaveHomeReminderActionKind?
}

struct CloudSyncStatusPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String?
    let pendingImportedBatchCount: Int
}

struct ManualLogPrefill: Equatable {
    let spfLevel: Int?
    let notes: String
}

enum HomeAccountabilityActionKind: Equatable {
    case invite
    case poke
    case view
}

struct HomeAccountabilityFriendPresentation: Equatable, Identifiable {
    let id: UUID
    let name: String
    let status: String
    let streak: String
    let hasLoggedToday: Bool
}

struct HomeAccountabilityPresentation: Equatable {
    let title: String
    let detail: String
    let openCountText: String
    let loggedCountText: String
    let primaryActionTitle: String
    let primaryActionKind: HomeAccountabilityActionKind
    let primaryFriendID: UUID?
    let latestPokeText: String?
    let friends: [HomeAccountabilityFriendPresentation]
}

struct FutureDayPreview: Equatable {
    let suggestedSPF: Int
    let suggestionText: String
}

struct TimelineDayLogSummary: Equatable {
    enum Category: Equatable {
        case past
        case today
        case future
    }

    let day: Date
    let category: Category
    let record: DailyRecord?
    let futurePreview: FutureDayPreview?
    let sunscreenStatusText: String
    let reapplyStatusText: String
    let notesStatusText: String?
    let factorsStatusText: String
}

@MainActor
@Observable
final class AppState {
    private typealias VerificationValues = (
        method: VerificationMethod,
        duration: Double?,
        spfLevel: Int?,
        notes: String?
    )

    private struct RecordUpsertRequest {
        let day: Date
        let verifiedAt: Date
        let verificationValues: VerificationValues
        let replaceOptionalFields: Bool
        let preserveExistingDuration: Bool
        let kind: SunclubChangeKind
        let summary: String
    }

    let modelContext: ModelContext
    var settings: Settings
    var verificationSuccessPresentation: VerificationSuccessPresentation?
    private let verificationStore: VerificationStore
    private let historyService: SunclubHistoryService
    private let cloudSyncCoordinator: CloudSyncControlling
    private let notificationManager: NotificationScheduling
    private let homeExitReminderMonitor: HomeExitReminderMonitoring
    private let uvIndexService: UVIndexService
    private let uvBriefingService: SunclubUVBriefingService
    private let healthKitService: SunclubHealthKitServing
    private let liveActivityCoordinator: SunclubLiveActivityCoordinating
    private let backupService: SunclubBackupService
    private let widgetSnapshotStore: SunclubWidgetSnapshotStore
    private let growthFeatureStore: SunclubGrowthFeatureStoring
    private let accountabilityService: SunclubAccountabilityServing
    private let currentDate: () -> Date
    private(set) var records: [DailyRecord] = []
    private(set) var changeBatches: [SunclubChangeBatch] = []
    private(set) var importSessions: [SunclubImportSession] = []
    private(set) var conflicts: [SunclubConflictItem] = []
    private(set) var syncPreference: CloudSyncPreference?
    private(set) var uvReading: UVReading?
    private(set) var uvForecast: SunclubUVForecast?
    private(set) var notificationHealthSnapshot: NotificationHealthSnapshot = .unknown
    private(set) var leaveHomeAuthorizationState: LeaveHomeAuthorizationState = .notDetermined
    private(set) var leaveHomeReminderErrorMessage: String?
    private(set) var growthSettings: SunclubGrowthSettings
    private(set) var achievementCelebration: SunclubAchievement?
    private(set) var friendImportMessage: String?
    var manualLogPrefill: ManualLogPrefill?
    var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    private(set) var lastRefreshError: String?

    private static let logger = Logger(subsystem: "com.sunclub", category: "AppState")
    private static let accountabilitySubscriptionInstallVersion = 2
    private let calendar = Calendar.current
    private var uvReadingOverride: UVReading?
    private var notificationHealthOverride: NotificationHealthSnapshot?
    private var leaveHomeAuthorizationOverride: LeaveHomeAuthorizationState?

    var referenceDate: Date {
        currentDate()
    }

    convenience init(context: ModelContext) {
        self.init(
            context: context,
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService(),
            uvBriefingService: SunclubUVBriefingService(),
            healthKitService: SunclubHealthKitService.shared,
            liveActivityCoordinator: SunclubLiveActivityCoordinator.shared
        )
    }

    convenience init(
        context: ModelContext,
        notificationManager: NotificationScheduling
    ) {
        self.init(
            context: context,
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(),
            uvBriefingService: SunclubUVBriefingService(),
            healthKitService: SunclubHealthKitService.shared,
            liveActivityCoordinator: SunclubLiveActivityCoordinator.shared
        )
    }

    convenience init(
        context: ModelContext,
        notificationManager: NotificationScheduling,
        homeExitReminderMonitor: HomeExitReminderMonitoring?
    ) {
        self.init(
            context: context,
            notificationManager: notificationManager,
            uvIndexService: UVIndexService(),
            uvBriefingService: SunclubUVBriefingService(),
            healthKitService: SunclubHealthKitService.shared,
            liveActivityCoordinator: SunclubLiveActivityCoordinator.shared,
            homeExitReminderMonitor: homeExitReminderMonitor
        )
    }

    init(
        context: ModelContext,
        notificationManager: NotificationScheduling,
        uvIndexService: UVIndexService,
        uvBriefingService: SunclubUVBriefingService? = nil,
        healthKitService: (any SunclubHealthKitServing)? = nil,
        liveActivityCoordinator: (any SunclubLiveActivityCoordinating)? = nil,
        backupService: SunclubBackupService = SunclubBackupService(),
        storeRecoveryService: SunclubStoreRecoveryService = SunclubStoreRecoveryService(),
        historyService: SunclubHistoryService? = nil,
        cloudSyncCoordinator: CloudSyncControlling? = nil,
        widgetSnapshotStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
        growthFeatureStore: SunclubGrowthFeatureStoring = SunclubGrowthFeatureStore.shared,
        accountabilityService: SunclubAccountabilityServing? = nil,
        runtimeEnvironment: RuntimeEnvironmentSnapshot = .current,
        homeExitReminderMonitor: HomeExitReminderMonitoring? = nil,
        clock: @escaping () -> Date = { RuntimeEnvironment.currentDateOverride ?? Date() }
    ) {
        modelContext = context
        verificationStore = VerificationStore(context: context)
        let resolvedHistoryService = historyService ?? SunclubHistoryService(context: context)
        self.historyService = resolvedHistoryService
        self.notificationManager = notificationManager
        let resolvedHomeExitReminderMonitor = homeExitReminderMonitor
            ?? (RuntimeEnvironment.isRunningTests ? NoopHomeExitReminderMonitor() : HomeExitReminderMonitor.shared)
        self.homeExitReminderMonitor = resolvedHomeExitReminderMonitor
        self.uvIndexService = uvIndexService
        self.uvBriefingService = uvBriefingService ?? SunclubUVBriefingService()
        self.healthKitService = healthKitService ?? SunclubHealthKitService.shared
        self.liveActivityCoordinator = liveActivityCoordinator ?? SunclubLiveActivityCoordinator.shared
        self.backupService = backupService
        let launchRecoveryResult = Self.recoverLegacyStoreIfNeeded(
            storeRecoveryService: storeRecoveryService,
            context: context,
            historyService: resolvedHistoryService,
            runtimeEnvironment: runtimeEnvironment
        )
        try? resolvedHistoryService.bootstrapIfNeeded()
        self.widgetSnapshotStore = widgetSnapshotStore
        self.growthFeatureStore = Self.defaultGrowthFeatureStore(
            growthFeatureStore,
            runtimeEnvironment: runtimeEnvironment
        )
        self.accountabilityService = Self.defaultAccountabilityService(
            accountabilityService,
            runtimeEnvironment: runtimeEnvironment
        )
        currentDate = clock
        settings = (try? resolvedHistoryService.settings()) ?? Self.loadOrCreateSettings(from: context)
        growthSettings = self.growthFeatureStore.load()
        self.cloudSyncCoordinator = Self.defaultCloudSyncCoordinator(
            cloudSyncCoordinator,
            historyService: resolvedHistoryService,
            runtimeEnvironment: runtimeEnvironment
        )
        self.homeExitReminderMonitor.setStateProvider { [weak self] in
            self
        }
        refresh()
        refreshUVReadingIfNeeded()
        refreshUVForecastIfNeeded()
        refreshNotificationHealth()
        refreshLeaveHomeReminderStatus()
        refreshHealthKitStatus()
        syncAchievementCelebration()
        Task {
            await self.liveActivityCoordinator.sync(using: self)
        }

        if runtimeEnvironment.shouldStartCloudSyncOnLaunch {
            Task {
                if let launchRecoveryResult,
                   self.syncPreference?.isICloudSyncEnabled ?? true {
                    _ = try? await self.cloudSyncCoordinator.publishImportedSession(
                        launchRecoveryResult.importSessionID
                    )
                }
                await self.cloudSyncCoordinator.start()
                self.refresh()
            }
        }
    }

    @MainActor
    private static func recoverLegacyStoreIfNeeded(
        storeRecoveryService: SunclubStoreRecoveryService,
        context: ModelContext,
        historyService: SunclubHistoryService,
        runtimeEnvironment: RuntimeEnvironmentSnapshot
    ) -> SunclubStoreRecoveryResult? {
        guard runtimeEnvironment.shouldRunLaunchStoreRecovery else {
            return nil
        }

        return try? storeRecoveryService.recoverLegacyApplicationSupportStoreIfNeeded(
            into: context,
            historyService: historyService
        )
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

    private static func defaultCloudSyncCoordinator(
        _ coordinator: CloudSyncControlling?,
        historyService: SunclubHistoryService,
        runtimeEnvironment: RuntimeEnvironmentSnapshot
    ) -> CloudSyncControlling {
        if let coordinator {
            return coordinator
        }

        return defaultCloudSyncCoordinator(
            historyService: historyService,
            runtimeEnvironment: runtimeEnvironment
        )
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

    private static func defaultAccountabilityService(
        _ service: SunclubAccountabilityServing?,
        runtimeEnvironment: RuntimeEnvironmentSnapshot
    ) -> SunclubAccountabilityServing {
        if let service {
            return service
        }
        if runtimeEnvironment.isRunningTests || runtimeEnvironment.isPreviewing {
            return NoopSunclubAccountabilityService()
        }
        if !runtimeEnvironment.isPublicAccountabilityTransportEnabled {
            return NoopSunclubAccountabilityService()
        }

        return SunclubAccountabilityService()
    }

    func refresh() {
        do {
            try historyService.refreshProjectedState()
            settings = try historyService.settings()
            records = try historyService.records()
            changeBatches = try historyService.changeBatches()
            importSessions = try historyService.importSessions()
            conflicts = try historyService.unresolvedConflicts()
            syncPreference = try historyService.syncPreference()
            lastRefreshError = nil
        } catch {
            Self.logger.error("Failed to refresh projected state: \(error)")
            lastRefreshError = "Unable to load your data. Please try again."
            if records.isEmpty {
                changeBatches = []
                importSessions = []
                conflicts = []
                syncPreference = nil
            }
        }

        syncLongestStreakIfNeeded()
        syncWidgetSnapshot()
    }

    private static func loadOrCreateSettings(from context: ModelContext) -> Settings {
        let descriptor = FetchDescriptor<Settings>()
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            return first
        }

        let created = Settings()
        context.insert(created)
        try? context.save()
        return created
    }

    func save() {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save model context: \(error)")
        }
    }

    func scheduleReminders() {
        Task {
            await notificationManager.scheduleReminders(using: self)
        }
    }

    private func refreshStreakRiskReminder() {
        Task {
            await notificationManager.refreshStreakRiskReminder(using: self)
        }
    }

    private func nextPhrase(
        catalog: [String],
        state: ReferenceWritableKeyPath<Settings, Data?>,
        changedField: SunclubTrackedField,
        summary: String
    ) -> String {
        nextPhrases(
            count: 1,
            catalog: catalog,
            state: state,
            changedField: changedField,
            summary: summary
        ).first ?? (catalog.first ?? "You're doing great.")
    }

    private func nextPhrases(
        count: Int,
        catalog: [String],
        state: ReferenceWritableKeyPath<Settings, Data?>,
        changedField: SunclubTrackedField,
        summary: String
    ) -> [String] {
        guard count > 0 else {
            return []
        }

        var phraseState = settings[keyPath: state]
        var phrases: [String] = []
        phrases.reserveCapacity(count)

        for _ in 0..<count {
            let next = PhraseRotation.nextPhrase(from: phraseState, catalog: catalog)
            phrases.append(next.0)
            phraseState = next.1
        }

        let batch = try? historyService.applySettingsChange(
            kind: .phraseRotation,
            summary: summary,
            changedFields: [changedField]
        ) { snapshot in
            switch changedField {
            case .dailyPhraseState:
                snapshot.dailyPhraseState = phraseState
            case .weeklyPhraseState:
                snapshot.weeklyPhraseState = phraseState
            default:
                break
            }
        }

        if let batch {
            Task {
                await cloudSyncCoordinator.queueBatchIfNeeded(batch.id)
            }
        }

        return phrases
    }

    var isUITesting: Bool {
        RuntimeEnvironment.isUITesting
    }

    var preferredCheckInRoute: AppRoute {
        .reapplyCheckIn
    }

    var pendingImportedBatchCount: Int {
        importSessions
            .filter { $0.publishedAt == nil }
            .flatMap(\.importedBatchIDs)
            .count
    }

    var cloudSyncStatusPresentation: CloudSyncStatusPresentation {
        let pendingImportedBatchCount = pendingImportedBatchCount
        let status = syncPreference?.status ?? .idle

        switch status {
        case .paused:
            return CloudSyncStatusPresentation(
                title: "Saved only on this phone",
                detail: "Turn iCloud sync back on to keep your history in sync.",
                actionTitle: "Turn On iCloud Sync",
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        case .syncing:
            return CloudSyncStatusPresentation(
                title: "Syncing with iCloud",
                detail: "Sending recent changes and checking your other devices.",
                actionTitle: nil,
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        case .error:
            return CloudSyncStatusPresentation(
                title: "iCloud needs attention",
                detail: syncPreference?.lastSyncErrorDescription ?? "Sunclub couldn't finish the last sync.",
                actionTitle: "Try Again",
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        case .idle:
            let detail: String
            if let lastSyncAt = syncPreference?.lastSyncAt {
                detail = "Last synced \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))."
            } else {
                detail = "Your history is syncing with iCloud."
            }

            return CloudSyncStatusPresentation(
                title: "iCloud sync is on",
                detail: detail,
                actionTitle: "Sync Now",
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        }
    }

    var recentImportSession: SunclubImportSession? {
        importSessions.first
    }

    func completeOnboarding() {
        let batch = try? historyService.applySettingsChange(
            kind: .onboarding,
            summary: "Completed onboarding.",
            changedFields: [.hasCompletedOnboarding]
        ) { snapshot in
            snapshot.hasCompletedOnboarding = true
        }
        finishDurableChange(batch, reschedulesReminders: false)
    }

    @discardableResult
    func importPendingAccountabilityInvitesIfNeeded() -> Bool {
        guard settings.hasCompletedOnboarding,
              !growthSettings.accountability.pendingInvites.isEmpty else {
            return false
        }

        let pendingInvites = growthSettings.accountability.pendingInvites.sorted { $0.receivedAt < $1.receivedAt }
        growthSettings.accountability.pendingInvites.removeAll()
        persistGrowthSettings()

        for pendingInvite in pendingInvites {
            importAccountabilityInvite(pendingInvite.envelope)
        }

        return true
    }

    func updateDailyReminder(hour: Int, minute: Int) {
        var reminderSettings = settings.smartReminderSettings
        let reminderTime = ReminderTime(hour: hour, minute: minute)
        guard reminderSettings.weekdayTime != reminderTime || reminderSettings.weekendTime != reminderTime else {
            return
        }
        reminderSettings.weekdayTime = reminderTime
        reminderSettings.weekendTime = reminderTime
        applyReminderSettingsChange(
            reminderSettings,
            summary: "Updated the daily reminder schedule."
        )
    }

    func updateReminderTime(for kind: ReminderScheduleKind, hour: Int, minute: Int) {
        var reminderSettings = settings.smartReminderSettings
        let reminderTime = ReminderTime(hour: hour, minute: minute)
        guard reminderSettings.time(for: kind) != reminderTime else {
            return
        }

        switch kind {
        case .weekday:
            reminderSettings.weekdayTime = reminderTime
        case .weekend:
            reminderSettings.weekendTime = reminderTime
        }

        applyReminderSettingsChange(
            reminderSettings,
            summary: "Updated the \(kind.shortTitle.lowercased()) reminder."
        )
    }

    func updateTravelTimeZoneHandling(followsTravelTimeZone: Bool) {
        var reminderSettings = settings.smartReminderSettings
        guard reminderSettings.followsTravelTimeZone != followsTravelTimeZone else {
            return
        }
        reminderSettings.followsTravelTimeZone = followsTravelTimeZone
        if !followsTravelTimeZone {
            reminderSettings.anchoredTimeZoneIdentifier = TimeZone.autoupdatingCurrent.identifier
        }
        applyReminderSettingsChange(
            reminderSettings,
            summary: "Updated the travel reminder preference."
        )
    }

    func updateStreakRiskReminder(enabled: Bool) {
        var reminderSettings = settings.smartReminderSettings
        guard reminderSettings.streakRiskEnabled != enabled else {
            return
        }
        reminderSettings.streakRiskEnabled = enabled
        applyReminderSettingsChange(
            reminderSettings,
            summary: "Updated the streak-risk reminder."
        )
    }

    func updateLeaveHomeReminderEnabled(enabled: Bool, allowPermissionPrompt: Bool = true) {
        var reminderSettings = settings.smartReminderSettings
        guard reminderSettings.leaveHomeReminder.isEnabled != enabled else {
            if enabled {
                refreshLeaveHomeReminderStatus(allowPermissionPrompt: false)
            }
            return
        }
        reminderSettings.leaveHomeReminder.isEnabled = enabled
        leaveHomeReminderErrorMessage = nil
        applyReminderSettingsChange(
            reminderSettings,
            summary: enabled
                ? "Enabled leave-home reminders."
                : "Disabled leave-home reminders."
        )

        if enabled {
            refreshLeaveHomeReminderStatus(allowPermissionPrompt: allowPermissionPrompt)
        }
    }

    func saveCurrentLocationAsHome() {
        leaveHomeReminderErrorMessage = nil

        Task {
            do {
                let homeLocation = try await homeExitReminderMonitor.saveHomeFromCurrentLocation()
                var reminderSettings = settings.smartReminderSettings
                reminderSettings.leaveHomeReminder.homeLocation = homeLocation
                applyReminderSettingsChange(
                    reminderSettings,
                    summary: "Saved Home for leave-home reminders."
                )
                leaveHomeReminderErrorMessage = nil
                refreshLeaveHomeReminderStatus(
                    allowPermissionPrompt: reminderSettings.leaveHomeReminder.isEnabled
                )
            } catch {
                leaveHomeReminderErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                leaveHomeAuthorizationState = homeExitReminderMonitor.authorizationState
            }
        }
    }

    func clearSavedHomeLocation() {
        var reminderSettings = settings.smartReminderSettings
        reminderSettings.leaveHomeReminder.homeLocation = nil
        leaveHomeReminderErrorMessage = nil
        applyReminderSettingsChange(
            reminderSettings,
            summary: "Cleared Home for leave-home reminders."
        )
    }

    func requestLeaveHomeMonitoringPermission() {
        leaveHomeReminderErrorMessage = nil
        refreshLeaveHomeReminderStatus(allowPermissionPrompt: true)
    }

    func updateWeeklyReminder(hour: Int, weekday: Int) {
        let batch = try? historyService.applySettingsChange(
            kind: .weeklyReminder,
            summary: "Updated the weekly summary reminder.",
            changedFields: [.weeklyHour, .weeklyWeekday]
        ) { snapshot in
            snapshot.weeklyHour = hour
            snapshot.weeklyWeekday = max(1, min(7, weekday))
        }
        finishDurableChange(batch, reschedulesReminders: true)
    }

    func updateCloudSyncEnabled(_ enabled: Bool) {
        Task {
            try? await cloudSyncCoordinator.setEnabled(enabled)
            refresh()
        }
    }

    func syncCloudNow() {
        Task {
            await cloudSyncCoordinator.syncNow()
            refresh()
        }
    }

    func publishImportedChanges(for sessionID: UUID) {
        Task {
            _ = try? await cloudSyncCoordinator.publishImportedSession(sessionID)
            refresh()
        }
    }

    func restoreImportedChanges(for sessionID: UUID) {
        let batch = try? historyService.restoreImportSession(sessionID)
        finishDurableChange(batch, reschedulesReminders: true)
    }

    func undoChange(_ batchID: UUID) {
        let batch = try? historyService.undo(batchID: batchID)
        finishDurableChange(batch, reschedulesReminders: true)
    }

    func redoChange(_ batchID: UUID) {
        let batch = try? historyService.redo(batchID: batchID)
        finishDurableChange(batch, reschedulesReminders: true)
    }

    func resolveConflict(_ conflictID: UUID) {
        try? historyService.resolveConflict(conflictID)
        refresh()
    }

    func conflict(for day: Date) -> SunclubConflictItem? {
        try? historyService.conflict(for: day)
    }

    func conflictChangedFieldNames(for conflict: SunclubConflictItem) -> [String] {
        let batchID = conflict.mergedBatchID
        let recordPredicate = #Predicate<DailyRecordRevision> { revision in
            revision.batchID == batchID
        }
        let settingsPredicate = #Predicate<SettingsRevision> { revision in
            revision.batchID == batchID
        }
        let recordFields = (try? modelContext.fetch(FetchDescriptor<DailyRecordRevision>(predicate: recordPredicate)))?
            .flatMap(\.changedFields) ?? []
        let settingsFields = (try? modelContext.fetch(FetchDescriptor<SettingsRevision>(predicate: settingsPredicate)))?
            .flatMap(\.changedFields) ?? []
        let uniqueTitles = Set((recordFields + settingsFields).map(\.displayTitle))

        return uniqueTitles.sorted()
    }

    var reminderDate: Date {
        reminderDate(for: ReminderPlanner.scheduleKind(for: currentDate(), calendar: calendar))
    }

    func reminderDate(for kind: ReminderScheduleKind) -> Date {
        let reminderTime = settings.smartReminderSettings.time(for: kind)
        let today = calendar.startOfDay(for: currentDate())
        return calendar.date(
            bySettingHour: reminderTime.hour,
            minute: reminderTime.minute,
            second: 0,
            of: today
        ) ?? today
    }

    var nextDailyReminderPreview: DailyReminderPreview? {
        nextDailyReminderPreview(now: currentDate())
    }

    private func nextDailyReminderPreview(now: Date) -> DailyReminderPreview? {
        let reminderSettings = settings.smartReminderSettings
        let timeZone = reminderSettings.notificationTimeZone(currentTimeZone: calendar.timeZone)
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone
        let today = scheduleCalendar.startOfDay(for: now)

        for dayOffset in 0..<14 {
            guard let day = scheduleCalendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            let kind = ReminderPlanner.scheduleKind(for: day, calendar: scheduleCalendar)
            let time = reminderSettings.time(for: kind)
            guard let fireDate = ReminderPlanner.scheduledDate(
                for: day,
                time: time,
                timeZone: timeZone,
                calendar: scheduleCalendar
            ),
                fireDate > now else {
                continue
            }

            let summary = "Next reminder: \(fireDate.formatted(.dateTime.weekday(.wide).hour().minute()))."
            return DailyReminderPreview(fireDate: fireDate, summary: summary)
        }

        return nil
    }

    var todayCardPresentation: HomeTodayCardPresentation {
        let now = currentDate()
        let todayRecord = record(for: now)
        let hasLoggedToday = todayRecord != nil
        let title = hasLoggedToday ? "Today's log is in" : "Ready for today's log"
        let defaultDetail = hasLoggedToday
            ? "Update today's SPF or note any time."
            : "One quick check-in keeps the streak steady."
        let logBadgeText = todayRecord.map { Self.logBadgeText(for: $0) }
        let streakRiskBadgeText = streakRiskBadgeText(now: now, hasLoggedToday: hasLoggedToday)
        let metadataRows = todayCardMetadataRows(now: now, todayRecord: todayRecord)

        guard let level = uvReading?.level,
              let uvHeadline = level.homeHeadline else {
            return HomeTodayCardPresentation(
                title: title,
                detail: defaultDetail,
                logBadgeText: logBadgeText,
                streakRiskBadgeText: streakRiskBadgeText,
                uvHeadline: nil,
                uvSymbolName: nil,
                uvIsEstimated: false,
                metadataRows: metadataRows
            )
        }

        let detail: String
        if reapplyReminderPlan.isElevated {
            detail = hasLoggedToday
                ? "You've logged today. Reapply sooner if you're spending time outside."
                : "Log now and plan to reapply sooner while UV stays high."
        } else {
            detail = defaultDetail
        }

        return HomeTodayCardPresentation(
            title: title,
            detail: detail,
            logBadgeText: logBadgeText,
            streakRiskBadgeText: streakRiskBadgeText,
            uvHeadline: uvHeadline,
            uvSymbolName: level.symbolName,
            uvIsEstimated: uvReading?.source == .heuristic,
            metadataRows: metadataRows
        )
    }

    var homeDailyPlanPresentation: HomeDailyPlanPresentation {
        let now = currentDate()
        let todayRecord = record(for: now)
        let facts = dailyPlanFacts(now: now, todayRecord: todayRecord)

        guard let todayRecord else {
            let activeStreak = CalendarAnalytics.currentStreak(
                records: recordedDays,
                now: now,
                calendar: calendar
            )
            let hour = calendar.component(.hour, from: now)
            let title: String
            let detail: String

            if hour >= 18, activeStreak > 0 {
                title = "Log before midnight"
                detail = "Today is still open. One quick log keeps your \(activeStreak)-day streak intact."
            } else if reapplyReminderPlan.isElevated {
                title = "Log before outdoor time"
                detail = "UV is elevated today. Save the first log now, then reapply sooner if you stay outside."
            } else if uvReading?.level == .low {
                title = "Keep the routine steady"
                detail = "UV is low, but logging now keeps the habit simple and consistent."
            } else {
                title = "Log sunscreen today"
                detail = "One quick check-in is enough to keep the day on track."
            }

            return HomeDailyPlanPresentation(
                title: title,
                detail: detail,
                actionTitle: "Log Today",
                action: .logToday,
                symbolName: "sun.max.fill",
                tone: .action,
                facts: facts
            )
        }

        if appStateNeedsRecoveryReview {
            return HomeDailyPlanPresentation(
                title: syncRecoveryTitle,
                detail: syncRecoveryDetail,
                actionTitle: "Review Changes",
                action: .reviewRecovery,
                symbolName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                tone: .warning,
                facts: facts
            )
        }

        if let notificationHealthPresentation {
            let action: HomeDailyPlanAction = notificationHealthPresentation.state == .stale ? .repairReminders : .openSettings
            return HomeDailyPlanPresentation(
                title: notificationHealthPresentation.title,
                detail: "\(notificationHealthPresentation.detail) Manual logging still works.",
                actionTitle: notificationHealthPresentation.actionTitle,
                action: action,
                symbolName: "bell.badge.fill",
                tone: .warning,
                facts: facts
            )
        }

        if let backfillAction = homeRecoveryActions.first(where: { $0.kind == .backfillYesterday }) {
            return HomeDailyPlanPresentation(
                title: backfillAction.title,
                detail: backfillAction.detail,
                actionTitle: backfillAction.buttonTitle,
                action: .backfillYesterday,
                symbolName: "calendar.badge.exclamationmark",
                tone: .warning,
                facts: facts
            )
        }

        if settings.reapplyReminderEnabled, reapplyReminderPlan.shouldScheduleNotification {
            let title = todayRecord.reapplyCount > 0 ? "Reapply again if you're outside" : "Plan the next reapply"
            let detail: String
            if let fireDate = reapplyReminderPlan.fireDate {
                detail = "Sunclub can remind you around \(fireDate.formatted(date: .omitted, time: .shortened)). Log a reapply whenever you put more on."
            } else {
                detail = "Log a reapply whenever you put more on so today's history stays accurate."
            }

            return HomeDailyPlanPresentation(
                title: title,
                detail: detail,
                actionTitle: todayRecord.reapplyCount > 0 ? "Log Another Reapply" : "Log Reapply",
                action: .logReapply,
                symbolName: "timer",
                tone: .action,
                facts: facts
            )
        }

        if todayRecord.spfLevel == nil, todayRecord.trimmedNotes == nil {
            return HomeDailyPlanPresentation(
                title: "Add details if useful",
                detail: "Today's streak is saved. Add SPF or a note only if it helps future you understand the day.",
                actionTitle: "Add SPF or Note",
                action: .addDetails,
                symbolName: "note.text",
                tone: .calm,
                facts: facts
            )
        }

        if !settings.reapplyReminderEnabled {
            return HomeDailyPlanPresentation(
                title: "You're set for today",
                detail: "Today's log is saved. Reapply reminders are off, so Sunclub will stay quiet unless you open it.",
                actionTitle: "View Progress",
                action: .viewProgress,
                symbolName: "checkmark.circle.fill",
                tone: .complete,
                facts: facts
            )
        }

        return HomeDailyPlanPresentation(
            title: "You're set for today",
            detail: "Today's log is saved. Check your week if you want a quick progress read.",
            actionTitle: "View Progress",
            action: .viewProgress,
            symbolName: "checkmark.circle.fill",
            tone: .complete,
            facts: facts
        )
    }

    private var appStateNeedsRecoveryReview: Bool {
        pendingImportedBatchCount > 0 || !conflicts.isEmpty
    }

    var syncRecoveryTitle: String {
        if !conflicts.isEmpty {
            return "Review changes"
        }

        return "Saved only on this phone"
    }

    var syncRecoveryDetail: String {
        var parts: [String] = []

        if pendingImportedBatchCount > 0 {
            parts.append(SunclubCopy.Sync.readyToSendToICloud(pendingImportedBatchCount))
        }

        if !conflicts.isEmpty {
            parts.append(SunclubCopy.Sync.mergedChangesNeedReview(conflicts.count))
        }

        return parts.joined(separator: " ")
    }

    private func dailyPlanFacts(now: Date, todayRecord: DailyRecord?) -> [HomeDailyPlanFact] {
        var facts = [
            todayDailyPlanFact(now: now, record: todayRecord),
            streakDailyPlanFact(now: now)
        ]

        if let uvFact = uvDailyPlanFact() {
            facts.append(uvFact)
        }

        if let detailsFact = detailsDailyPlanFact(for: todayRecord) {
            facts.append(detailsFact)
        }

        return Array(facts.prefix(4))
    }

    private func todayDailyPlanFact(now: Date, record: DailyRecord?) -> HomeDailyPlanFact {
        if let record {
            return HomeDailyPlanFact(
                id: "today",
                title: "Today",
                value: "Logged \(record.verifiedAt.formatted(date: .omitted, time: .shortened))",
                symbolName: "checkmark.circle.fill"
            )
        }

        return HomeDailyPlanFact(
            id: "reminder",
            title: "Reminder",
            value: nextReminderSummary(now: now),
            symbolName: "bell.fill"
        )
    }

    private func streakDailyPlanFact(now: Date) -> HomeDailyPlanFact {
        let streak = CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar)
        return HomeDailyPlanFact(
            id: "streak",
            title: "Streak",
            value: streak == 1 ? "1 day" : "\(streak) days",
            symbolName: "flame.fill"
        )
    }

    private func uvDailyPlanFact() -> HomeDailyPlanFact? {
        if let uvForecast, let peakHour = uvForecast.peakHour {
            return HomeDailyPlanFact(
                id: "uv",
                title: "Peak UV",
                value: "\(peakHour.index) at \(peakHour.date.formatted(date: .omitted, time: .shortened))",
                symbolName: peakHour.level.symbolName
            )
        }

        guard let uvReading else {
            return nil
        }

        return HomeDailyPlanFact(
            id: "uv",
            title: "UV Now",
            value: "\(uvReading.index), \(uvReading.level.displayName)",
            symbolName: uvReading.level.symbolName
        )
    }

    private func detailsDailyPlanFact(for record: DailyRecord?) -> HomeDailyPlanFact? {
        guard let record, record.spfLevel != nil || record.trimmedNotes != nil else {
            return nil
        }

        return HomeDailyPlanFact(
            id: "details",
            title: "Details",
            value: dailyPlanDetailsValue(for: record),
            symbolName: "note.text"
        )
    }

    private func dailyPlanDetailsValue(for record: DailyRecord) -> String {
        switch (record.spfLevel, record.trimmedNotes) {
        case let (.some(spfLevel), .some(_)):
            return "SPF \(spfLevel), note saved"
        case let (.some(spfLevel), .none):
            return "SPF \(spfLevel)"
        case (.none, .some(_)):
            return "Note saved"
        case (.none, .none):
            return "Optional"
        }
    }

    private func todayCardMetadataRows(now: Date, todayRecord: DailyRecord?) -> [HomeTodayMetadataRow] {
        var rows: [HomeTodayMetadataRow] = []

        if let todayRecord {
            rows.append(
                HomeTodayMetadataRow(
                    id: "logged",
                    title: "Last Saved",
                    value: todayRecord.verifiedAt.formatted(date: .omitted, time: .shortened),
                    symbolName: "checkmark.circle.fill"
                )
            )

            rows.append(
                HomeTodayMetadataRow(
                    id: "spf",
                    title: "SPF",
                    value: todayRecord.spfLevel.map { "SPF \($0)" } ?? "Not saved",
                    symbolName: "sun.max.fill"
                )
            )

            if todayRecord.trimmedNotes != nil {
                rows.append(
                    HomeTodayMetadataRow(
                        id: "notes",
                        title: "Notes",
                        value: "Saved",
                        symbolName: "note.text"
                    )
                )
            }

            if settings.reapplyReminderEnabled {
                rows.append(
                    HomeTodayMetadataRow(
                        id: "reapply",
                        title: "Reapply",
                        value: reapplyWindowSummary,
                        symbolName: "timer"
                    )
                )
            }
        } else {
            rows.append(
                HomeTodayMetadataRow(
                    id: "reminder",
                    title: "Reminder",
                    value: nextReminderSummary(now: now),
                    symbolName: "bell.fill"
                )
            )

            let activeStreak = CalendarAnalytics.currentStreak(
                records: recordedDays,
                now: now,
                calendar: calendar
            )
            if activeStreak > 0 {
                rows.append(
                    HomeTodayMetadataRow(
                        id: "streak",
                        title: "Streak",
                        value: "\(activeStreak) \(activeStreak == 1 ? "day" : "days") open",
                        symbolName: "flame.fill"
                    )
                )
            }

            if settings.reapplyReminderEnabled {
                rows.append(
                    HomeTodayMetadataRow(
                        id: "reapply",
                        title: "Reapply",
                        value: "After today's log",
                        symbolName: "timer"
                    )
                )
            }
        }

        rows.append(contentsOf: uvMetadataRows())
        return Array(rows.prefix(6))
    }

    private var reapplyWindowSummary: String {
        let plan = reapplyReminderPlan
        guard plan.shouldScheduleNotification else {
            return "No reminder after sunset"
        }

        if plan.isElevated {
            return "\(plan.intervalSummary), UV-adjusted"
        }

        return "Every \(plan.intervalSummary)"
    }

    private func nextReminderSummary(now: Date) -> String {
        let kind = ReminderPlanner.scheduleKind(for: now, calendar: calendar)
        let time = settings.smartReminderSettings.time(for: kind)
        let day = calendar.startOfDay(for: now)
        let reminderDate = calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: day
        ) ?? day
        return "\(kind.shortTitle) \(reminderDate.formatted(date: .omitted, time: .shortened))"
    }

    private func uvMetadataRows() -> [HomeTodayMetadataRow] {
        if let uvForecast, let peakHour = uvForecast.peakHour {
            return [
                HomeTodayMetadataRow(
                    id: "uvPeak",
                    title: "Peak UV",
                    value: "\(peakHour.index) at \(peakHour.date.formatted(date: .omitted, time: .shortened))",
                    symbolName: peakHour.level.symbolName
                ),
                HomeTodayMetadataRow(
                    id: "uvSource",
                    title: "Source",
                    value: uvForecast.sourceLabel,
                    symbolName: "location.fill"
                )
            ]
        }

        if let uvReading {
            return [
                HomeTodayMetadataRow(
                    id: "uvNow",
                    title: "UV Now",
                    value: "\(uvReading.index), \(uvReading.source.statusLabel)",
                    symbolName: uvReading.level.symbolName
                )
            ]
        }

        return []
    }

    private static func logBadgeText(for record: DailyRecord) -> String {
        guard record.reapplyCount > 0 else {
            return "Logged"
        }

        let noun = record.reapplyCount == 1 ? "reapply" : "reapplies"
        return "Applied + \(record.reapplyCount) \(noun)"
    }

    private func streakRiskBadgeText(now: Date, hasLoggedToday: Bool) -> String? {
        guard !hasLoggedToday else {
            return nil
        }

        let hour = calendar.component(.hour, from: now)
        guard hour >= 18 else {
            return nil
        }

        let activeStreak = CalendarAnalytics.currentStreak(
            records: recordedDays,
            now: now,
            calendar: calendar
        )
        guard activeStreak > 0 else {
            return nil
        }

        return "\(activeStreak)-day streak at risk"
    }

    var reapplyReminderPlan: ReapplyReminderPlan {
        ReapplyReminderPlan(
            baseIntervalMinutes: settings.reapplyIntervalMinutes,
            uvReading: uvReading,
            now: currentDate(),
            calendar: calendar
        )
    }

    var homeRecoveryActions: [HomeRecoveryAction] {
        var actions: [HomeRecoveryAction] = []

        let now = currentDate()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        if records.count >= 3, record(for: yesterday) == nil {
            actions.append(
                HomeRecoveryAction(
                    kind: .backfillYesterday,
                    title: "Yesterday is missing",
                    detail: "Add it now without opening your full history.",
                    buttonTitle: "Backfill Yesterday"
                )
            )
        }

        return actions
    }

    var reapplyCheckInPresentation: ReapplyCheckInPresentation? {
        guard settings.reapplyReminderEnabled,
              let todayRecord = record(for: currentDate()) else {
            return nil
        }

        if todayRecord.reapplyCount > 0 {
            let detail: String
            if let lastReappliedAt = todayRecord.lastReappliedAt {
                detail = "Checked in \(todayRecord.reapplyCount) \(todayRecord.reapplyCount == 1 ? "time" : "times") today. Last one at \(lastReappliedAt.formatted(date: .omitted, time: .shortened)). If there is enough daylight left, Sunclub will set up the next reminder."
            } else {
                detail = "Checked in \(todayRecord.reapplyCount) \(todayRecord.reapplyCount == 1 ? "time" : "times") today. If there is enough daylight left, Sunclub will set up the next reminder."
            }

            return ReapplyCheckInPresentation(
                title: "Reapply",
                detail: detail,
                actionTitle: "Log Another Reapply"
            )
        }

        return ReapplyCheckInPresentation(
            title: "Reapply",
            detail: "Use this whenever you reapply. If there is enough daylight left, Sunclub will set up the next interval reminder.",
            actionTitle: "Log Reapply"
        )
    }

    var reminderCoachingSuggestions: [ReminderCoachingSuggestion] {
        ReminderCoachingEngine.suggestions(
            from: records,
            settings: settings.smartReminderSettings,
            now: currentDate(),
            calendar: calendar
        )
    }

    var notificationHealthPresentation: NotificationHealthPresentation? {
        NotificationHealthEvaluator.presentation(
            from: notificationHealthSnapshot,
            onboardingComplete: settings.hasCompletedOnboarding
        )
    }

    var notificationHealthStatusPresentation: NotificationHealthStatusPresentation? {
        NotificationHealthEvaluator.statusPresentation(
            from: notificationHealthSnapshot,
            onboardingComplete: settings.hasCompletedOnboarding
        )
    }

    var leaveHomeReminderStatusPresentation: LeaveHomeReminderStatusPresentation {
        let leaveHomeReminder = settings.smartReminderSettings.leaveHomeReminder

        if leaveHomeReminder.homeLocation == nil {
            switch leaveHomeAuthorizationState {
            case .denied, .restricted:
                return LeaveHomeReminderStatusPresentation(
                    title: "Location access is off",
                    detail: "Open Settings so Sunclub can save your current location as Home.",
                    symbol: "location.slash",
                    tone: .warning,
                    actionTitle: "Open Settings",
                    actionKind: .openSettings
                )
            default:
                return LeaveHomeReminderStatusPresentation(
                    title: "Home isn't set",
                    detail: leaveHomeReminderErrorMessage
                        ?? "Save your current location and Sunclub can remind you when you head out.",
                    symbol: "house",
                    tone: .neutral,
                    actionTitle: "Use Current Location as Home",
                    actionKind: .setHomeFromCurrentLocation
                )
            }
        }

        guard leaveHomeReminder.isEnabled else {
            return LeaveHomeReminderStatusPresentation(
                title: "Home is saved",
                detail: "Turn this on to use your first trip out as the morning reminder.",
                symbol: "house.fill",
                tone: .neutral,
                actionTitle: nil,
                actionKind: nil
            )
        }

        switch leaveHomeAuthorizationState {
        case .always:
            return LeaveHomeReminderStatusPresentation(
                title: "First exit reminder is ready",
                detail: "Sunclub will watch Home with a \(Int(leaveHomeReminder.radiusMeters)) m radius and send one reminder before your usual weekday or weekend time if today is still open.",
                symbol: "figure.walk.departure",
                tone: .success,
                actionTitle: nil,
                actionKind: nil
            )
        case .notDetermined, .whenInUse, .unknown:
            return LeaveHomeReminderStatusPresentation(
                title: "Background location needed",
                detail: "Allow Always location so Sunclub can catch your first exit even when the app isn't open.",
                symbol: "location.fill",
                tone: .warning,
                actionTitle: "Allow Background Access",
                actionKind: .requestAlwaysAuthorization
            )
        case .denied, .restricted:
            return LeaveHomeReminderStatusPresentation(
                title: "Location access is off",
                detail: "Open Settings to re-enable Always location access for this reminder.",
                symbol: "location.slash",
                tone: .warning,
                actionTitle: "Open Settings",
                actionKind: .openSettings
            )
        }
    }

    var liveUVStatusPresentation: LiveUVStatusPresentation {
        LiveUVStatusPresentation(
            title: "Estimated UV",
            detail: "Using Sunclub's built-in UV estimate in this release.",
            actionTitle: nil,
            actionKind: nil
        )
    }

    var achievements: [SunclubAchievement] {
        SunclubGrowthAnalytics.achievements(
            records: records,
            changeBatches: changeBatches,
            settings: settings,
            growthSettings: growthSettings,
            now: currentDate(),
            calendar: calendar
        )
    }

    var seasonalChallenges: [SunclubSeasonalChallenge] {
        SunclubGrowthAnalytics.challenges(
            records: records,
            now: currentDate(),
            calendar: calendar
        )
    }

    var friends: [SunclubFriendSnapshot] {
        growthSettings.friends.sorted { lhs, rhs in
            if lhs.hasLoggedToday != rhs.hasLoggedToday {
                return !lhs.hasLoggedToday && rhs.hasLoggedToday
            }
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            return lhs.lastSharedAt > rhs.lastSharedAt
        }
    }

    var localFriendSnapshot: SunclubFriendSnapshot {
        SunclubGrowthAnalytics.localFriendSnapshot(
            preferredName: growthSettings.preferredName,
            records: records,
            now: currentDate(),
            calendar: calendar
        )
    }

    var supportsDirectAccountabilityTransport: Bool {
        accountabilityService.supportsDirectDelivery
    }

    var accountabilitySummary: SunclubAccountabilitySummary {
        SunclubWidgetSnapshotBuilder.make(
            settings: settings,
            records: records,
            growthSettings: growthSettings,
            uvReading: uvReading,
            uvForecast: uvForecast,
            now: currentDate(),
            calendar: calendar
        ).accountabilitySummary
    }

    var homeAccountabilityPresentation: HomeAccountabilityPresentation? {
        guard settings.hasCompletedOnboarding,
              growthSettings.accountability.isActive else {
            return nil
        }

        let prioritizedFriends = friends
        let openCount = prioritizedFriends.filter { !$0.hasLoggedToday }.count
        let loggedCount = prioritizedFriends.filter(\.hasLoggedToday).count
        let latestPokeText = SunclubAccountabilityMessaging.latestPokeText(
            growthSettings.accountability.pokeHistory.sorted { $0.createdAt > $1.createdAt }.first
        )

        guard !prioritizedFriends.isEmpty else {
            return HomeAccountabilityPresentation(
                title: "Bring in backup",
                detail: "Accountability is on. Add one sunscreen buddy to keep check-ins visible.",
                openCountText: "0 open",
                loggedCountText: "0 logged",
                primaryActionTitle: "Add Friend",
                primaryActionKind: .invite,
                primaryFriendID: nil,
                latestPokeText: latestPokeText,
                friends: []
            )
        }

        let topOpenFriend = prioritizedFriends.first { !$0.hasLoggedToday }
        let title: String
        let detail: String
        let actionTitle: String
        let actionKind: HomeAccountabilityActionKind
        let actionFriendID: UUID?

        if let topOpenFriend {
            if supportsDirectAccountabilityTransport {
                title = "Poke \(topOpenFriend.name)"
                detail = "\(topOpenFriend.name) still has an open sunscreen day. One tap sends a quick nudge."
                actionTitle = "Poke"
                actionKind = .poke
                actionFriendID = topOpenFriend.id
            } else {
                title = "Message \(topOpenFriend.name)"
                detail = "\(topOpenFriend.name) still has an open sunscreen day. Send a note through Messages when you want to nudge."
                actionTitle = "Open Friends"
                actionKind = .view
                actionFriendID = nil
            }
        } else {
            title = "Everyone logged"
            detail = "Everyone in your circle logged today. Nice work from the whole crew."
            actionTitle = "View Friends"
            actionKind = .view
            actionFriendID = nil
        }

        return HomeAccountabilityPresentation(
            title: title,
            detail: detail,
            openCountText: "\(openCount) open",
            loggedCountText: "\(loggedCount) logged",
            primaryActionTitle: actionTitle,
            primaryActionKind: actionKind,
            primaryFriendID: actionFriendID,
            latestPokeText: latestPokeText,
            friends: prioritizedFriends.prefix(4).map { friend in
                HomeAccountabilityFriendPresentation(
                    id: friend.id,
                    name: friend.name,
                    status: friend.hasLoggedToday ? "Logged" : "Needs SPF",
                    streak: "\(friend.currentStreak)d",
                    hasLoggedToday: friend.hasLoggedToday
                )
            }
        )
    }

    var shouldShowAccountabilityNudge: Bool {
        settings.hasCompletedOnboarding
            && recordedDays.count >= 3
            && !growthSettings.accountability.isActive
            && growthSettings.accountability.dismissedAt == nil
    }

    var accountabilityInviteEnvelope: SunclubAccountabilityInviteEnvelope? {
        guard let token = growthSettings.accountability.activeInviteToken else {
            return nil
        }

        let displayName = resolvedAccountabilityDisplayName
        return SunclubAccountabilityInviteEnvelope(
            profileID: growthSettings.accountability.localProfileID,
            displayName: displayName,
            relationshipToken: token.token,
            issuedAt: token.createdAt,
            snapshot: localFriendSnapshot
        )
    }

    var accountabilityInviteCode: String {
        guard let envelope = accountabilityInviteEnvelope else {
            return ""
        }

        return (try? SunclubAccountabilityCodec.backupCode(for: envelope)) ?? ""
    }

    var accountabilityInviteURL: URL? {
        guard let envelope = accountabilityInviteEnvelope else {
            return nil
        }

        return try? SunclubAccountabilityCodec.inviteURL(for: envelope)
    }

    var accountabilityInviteShareText: String {
        guard let envelope = accountabilityInviteEnvelope else {
            return "Add me on Sunclub for sunscreen accountability."
        }

        return (try? SunclubAccountabilityCodec.inviteShareText(envelope: envelope))
            ?? "Add me on Sunclub for sunscreen accountability."
    }

    var healthKitAvailable: Bool {
        healthKitService.isAvailable
    }

    var preferredDisplayName: String {
        growthSettings.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var unseenAchievementCount: Int {
        achievements
            .filter(\.isUnlocked)
            .filter { !growthSettings.presentedAchievementIDs.contains($0.id.rawValue) }
            .count
    }

    func updatePreferredDisplayName(_ name: String) {
        growthSettings.preferredName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !growthSettings.accountability.displayName.isEmpty {
            growthSettings.accountability.displayName = growthSettings.preferredName
        }
        persistGrowthSettings()
    }

    func activateAccountability(displayName: String? = nil) {
        let now = currentDate()
        let resolvedName = (displayName ?? preferredDisplayName).trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedName.isEmpty {
            growthSettings.preferredName = resolvedName
            growthSettings.accountability.displayName = resolvedName
        } else if growthSettings.accountability.displayName.isEmpty {
            growthSettings.accountability.displayName = "Sunclub Friend"
        }
        growthSettings.accountability.activatedAt = growthSettings.accountability.activatedAt ?? now
        _ = growthSettings.accountability.ensureInviteToken(now: now)
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
        publishAccountabilityProfileIfNeeded()
    }

    func dismissAccountabilityNudge() {
        growthSettings.accountability.dismissedAt = currentDate()
        persistGrowthSettings()
    }

    func prepareAccountabilityInvite() {
        _ = growthSettings.accountability.ensureInviteToken(now: currentDate())
        persistGrowthSettings()
    }

    func preparedAccountabilityInviteEnvelope() -> SunclubAccountabilityInviteEnvelope {
        let now = currentDate()
        let token = growthSettings.accountability.ensureInviteToken(now: now)
        persistGrowthSettings()
        let displayName = resolvedAccountabilityDisplayName
        return SunclubAccountabilityInviteEnvelope(
            profileID: growthSettings.accountability.localProfileID,
            displayName: displayName,
            relationshipToken: token.token,
            issuedAt: token.createdAt,
            snapshot: localFriendSnapshot
        )
    }

    func recordShareActionStarted() {
        growthSettings.telemetry.recordShare(at: currentDate())
        persistGrowthSettings()
        syncAchievementCelebration()
    }

    func recordProductScanUsedForLog(spfLevel: Int?) {
        guard spfLevel != nil else { return }
        growthSettings.telemetry.recordProductScanUse(at: currentDate())
        persistGrowthSettings()
        syncAchievementCelebration()
    }

    func updateHealthKitEnabled(_ enabled: Bool) {
        if !enabled {
            guard growthSettings.healthKit.isEnabled else {
                return
            }
            growthSettings.healthKit.isEnabled = false
            persistGrowthSettings()
            return
        }

        Task {
            let granted = await healthKitService.requestAuthorizationIfNeeded()
            growthSettings.healthKit.isEnabled = granted
            if granted {
                growthSettings.healthKit.importedSampleCount = await healthKitService.recentUVSampleCount(
                    since: calendar.date(byAdding: .year, value: -1, to: currentDate()) ?? currentDate()
                )
            }
            persistGrowthSettings()
        }
    }

    func refreshHealthKitStatus() {
        guard growthSettings.healthKit.isEnabled else { return }

        Task {
            growthSettings.healthKit.importedSampleCount = await healthKitService.recentUVSampleCount(
                since: calendar.date(byAdding: .year, value: -1, to: currentDate()) ?? currentDate()
            )
            persistGrowthSettings()
        }
    }

    func updateUVBriefingPreferences(
        dailyBriefingEnabled: Bool? = nil,
        extremeAlertEnabled: Bool? = nil
    ) {
        let newDailyBriefingEnabled = dailyBriefingEnabled ?? growthSettings.uvBriefing.dailyBriefingEnabled
        let newExtremeAlertEnabled = extremeAlertEnabled ?? growthSettings.uvBriefing.extremeAlertEnabled

        guard growthSettings.uvBriefing.dailyBriefingEnabled != newDailyBriefingEnabled
                || growthSettings.uvBriefing.extremeAlertEnabled != newExtremeAlertEnabled else {
            return
        }

        growthSettings.uvBriefing.dailyBriefingEnabled = newDailyBriefingEnabled
        growthSettings.uvBriefing.extremeAlertEnabled = newExtremeAlertEnabled
        persistGrowthSettings()
        scheduleReminders()
    }

    var automationPreferences: SunclubAutomationPreferences {
        growthSettings.automation
    }

    func updateAutomationPreferences(_ preferences: SunclubAutomationPreferences) {
        guard growthSettings.automation != preferences else {
            return
        }
        growthSettings.automation = preferences
        persistGrowthSettings()
    }

    @discardableResult
    func performAutomationAction(
        _ action: SunclubAutomationAction,
        invocation: SunclubAutomationInvocation
    ) throws -> SunclubAutomationResult {
        let result = try SunclubAutomationRuntime.perform(
            action,
            invocation: invocation,
            context: modelContext,
            growthStore: growthFeatureStore,
            widgetStore: widgetSnapshotStore,
            now: currentDate(),
            supportsDirectAccountabilityTransport: supportsDirectAccountabilityTransport
        )
        growthSettings = growthFeatureStore.load()
        refresh()
        if action.logsCurrentDay, settings.reapplyReminderEnabled {
            scheduleReapplyReminder()
        }
        if case .setReminder = action {
            scheduleReminders()
        }
        if case .setReapply = action {
            scheduleReminders()
        }
        if case let .setToggle(toggle, _) = action,
           toggle == .dailyUVBriefing || toggle == .extremeUVAlert || toggle == .travelTimeZone || toggle == .streakRisk {
            scheduleReminders()
        }
        return result
    }

    func refreshUVForecastIfNeeded(allowPermissionPrompt: Bool = false) {
        Task {
            uvForecast = await uvBriefingService.forecast(
                prefersLiveData: settings.usesLiveUV,
                allowPermissionPrompt: allowPermissionPrompt,
                referenceDate: currentDate(),
                calendar: calendar
            )
            syncWidgetSnapshot()
            reloadWidgetTimelines()
            await liveActivityCoordinator.sync(using: self)
        }
    }

    func clearFriendImportMessage() {
        friendImportMessage = nil
    }

    func resetAccountabilityForTesting() {
        growthSettings.friends = []
        growthSettings.accountability = SunclubAccountabilitySettings()
        friendImportMessage = nil
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
    }

    func setManualLogPrefill(spfLevel: Int?, notes: String) {
        manualLogPrefill = ManualLogPrefill(spfLevel: spfLevel, notes: notes)
    }

    func rememberScannedSPF(_ spfLevel: Int?) {
        guard let spfLevel else {
            return
        }

        let normalizedLevel = SunclubGrowthSettings.normalizedSPFLevels([spfLevel]).first ?? spfLevel
        var scannedLevels = growthSettings.scannedSPFLevels.filter { $0 != normalizedLevel }
        scannedLevels.insert(normalizedLevel, at: 0)
        growthSettings.scannedSPFLevels = Array(scannedLevels.prefix(6))
        persistGrowthSettings()
    }

    func clearManualLogPrefill() {
        manualLogPrefill = nil
    }

    func friendShareCode() throws -> String {
        try SunclubFriendCodeCodec.encode(localFriendSnapshot)
    }

    func importFriendCode(_ code: String) throws {
        if let envelope = try? SunclubAccountabilityCodec.envelope(from: code) {
            importAccountabilityInvite(envelope)
            return
        }

        importLegacyFriendSnapshot(try SunclubFriendCodeCodec.decode(code))
    }

    func removeFriend(_ id: UUID) {
        growthSettings.friends.removeAll { $0.id == id }
        growthSettings.accountability.connections.removeAll { $0.friendSnapshotID == id }
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
    }

    func importAccountabilityInviteCode(_ code: String) throws {
        let envelope = try SunclubAccountabilityCodec.envelope(from: code)
        importAccountabilityInvite(envelope)
    }

    func queuePendingAccountabilityInviteCode(_ code: String) throws {
        let envelope = try SunclubAccountabilityCodec.envelope(from: code)
        guard envelope.profileID != growthSettings.accountability.localProfileID else {
            friendImportMessage = "That invite is yours. Share it with a friend instead."
            return
        }

        growthSettings.accountability.pendingInvites.removeAll { pendingInvite in
            pendingInvite.envelope.profileID == envelope.profileID
        }
        growthSettings.accountability.pendingInvites.append(
            SunclubAccountabilityPendingInvite(
                envelope: envelope,
                receivedAt: currentDate()
            )
        )
        persistGrowthSettings()
    }

    func importAccountabilityInvite(_ envelope: SunclubAccountabilityInviteEnvelope, sendsResponse: Bool = true) {
        guard envelope.profileID != growthSettings.accountability.localProfileID else {
            friendImportMessage = "That invite is yours. Share it with a friend instead."
            return
        }

        if !growthSettings.accountability.isActive {
            activateAccountability(displayName: preferredDisplayName)
        }

        var importedSnapshot = envelope.snapshot
        importedSnapshot.name = envelope.displayName.isEmpty ? importedSnapshot.name : envelope.displayName
        if let existingConnection = growthSettings.accountability.connections.first(where: { $0.friendProfileID == envelope.profileID }) {
            importedSnapshot.id = existingConnection.friendSnapshotID
        }

        upsertFriendSnapshot(importedSnapshot)
        upsertConnection(
            SunclubFriendConnection(
                friendProfileID: envelope.profileID,
                friendSnapshotID: importedSnapshot.id,
                friendDisplayName: importedSnapshot.name,
                relationshipToken: envelope.relationshipToken,
                acceptedAt: currentDate(),
                canDirectPoke: supportsDirectAccountabilityTransport
            )
        )
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
        if !supportsDirectAccountabilityTransport {
            friendImportMessage = "Added \(importedSnapshot.name). Use Message when you want to send a nudge."
        } else if importedSnapshot.hasLoggedToday && record(for: currentDate()) == nil {
            friendImportMessage = "\(importedSnapshot.name) logged today. Have you?"
        } else {
            friendImportMessage = "Added \(importedSnapshot.name)."
        }

        if sendsResponse, supportsDirectAccountabilityTransport {
            let response = SunclubAccountabilityInviteResponse(
                recipientProfileID: envelope.profileID,
                envelope: preparedAccountabilityInviteEnvelope()
            )
            Task {
                try? await accountabilityService.sendInviteResponse(response)
                publishAccountabilityProfileIfNeeded()
            }
        }
    }

    func refreshAccountabilityFriends() {
        guard growthSettings.accountability.isActive else {
            return
        }
        guard supportsDirectAccountabilityTransport else {
            return
        }

        publishAccountabilityProfileIfNeeded()
        Task {
            do {
                let profileIDs = growthSettings.accountability.connections.map(\.friendProfileID)
                let profiles = try await accountabilityService.fetchProfiles(profileIDs: profileIDs)
                for profile in profiles {
                    applyAccountabilityProfile(profile)
                }
                persistGrowthSettings()
                syncWidgetSnapshot()
                reloadWidgetTimelines()
            } catch {
                friendImportMessage = "Accountability updates did not sync yet. You can still use Message."
            }
        }
    }

    func sendDirectPoke(to friendID: UUID) {
        guard let friend = friends.first(where: { $0.id == friendID }) else {
            return
        }

        guard supportsDirectAccountabilityTransport else {
            friendImportMessage = SunclubAccountabilityMessaging.directPokeUnavailableMessage(friendName: friend.name)
            return
        }

        guard let connection = growthSettings.accountability.connections.first(where: { $0.friendSnapshotID == friendID }),
              connection.canDirectPoke else {
            friendImportMessage = SunclubAccountabilityMessaging.directPokeUnavailableMessage(friendName: friend.name)
            return
        }

        let now = currentDate()
        let message = SunclubAccountabilityMessaging.outgoingPokeMessage(
            for: friend,
            friendProfileID: connection.friendProfileID,
            recentPokes: growthSettings.accountability.pokeHistory,
            now: now,
            calendar: calendar
        )
        let senderToken = growthSettings.accountability.ensureInviteToken(now: now)
        persistGrowthSettings()

        let envelope = SunclubAccountabilityPokeEnvelope(
            senderProfileID: growthSettings.accountability.localProfileID,
            senderName: resolvedAccountabilityDisplayName,
            receiverProfileID: connection.friendProfileID,
            relationshipToken: senderToken.token,
            message: message,
            createdAt: now
        )

        Task {
            do {
                try await accountabilityService.sendPoke(envelope)
                recordPoke(
                    SunclubAccountabilityPoke(
                        friendProfileID: connection.friendProfileID,
                        friendName: friend.name,
                        direction: .sent,
                        channel: .direct,
                        status: .sent,
                        message: message,
                        createdAt: now
                    )
                )
                friendImportMessage = SunclubAccountabilityMessaging.directPokeSuccessMessage(
                    friendName: friend.name,
                    hasLoggedToday: friend.hasLoggedToday
                )
            } catch {
                recordPoke(
                    SunclubAccountabilityPoke(
                        friendProfileID: connection.friendProfileID,
                        friendName: friend.name,
                        direction: .sent,
                        channel: .direct,
                        status: .failed,
                        message: message,
                        createdAt: now
                    )
                )
                friendImportMessage = SunclubAccountabilityMessaging.directPokeFailureMessage(friendName: friend.name)
            }
        }
    }

    func sharePokeText(for friend: SunclubFriendSnapshot) -> String {
        SunclubAccountabilityCodec.pokeShareText(
            from: resolvedAccountabilityDisplayName,
            to: friend.name,
            hasLoggedToday: friend.hasLoggedToday
        )
    }

    func processRemoteAccountabilityEventsNow() async -> Bool {
        guard growthSettings.accountability.isActive else { return false }
        guard supportsDirectAccountabilityTransport else { return false }

        do {
            let events = try await accountabilityService.fetchRemoteEvents(for: growthSettings.accountability.localProfileID)
            var didProcessEvent = false
            for response in events.inviteResponses {
                importAccountabilityInvite(response.envelope, sendsResponse: false)
                didProcessEvent = true
            }
            var notificationTasks: [Task<Void, Never>] = []
            for poke in events.pokes {
                if let notificationTask = handleIncomingPoke(poke) {
                    notificationTasks.append(notificationTask)
                    didProcessEvent = true
                }
            }
            for notificationTask in notificationTasks {
                await notificationTask.value
            }
            return didProcessEvent
        } catch {
            friendImportMessage = "Accountability updates did not sync yet."
            return false
        }
    }

    @discardableResult
    func processRemoteAccountabilityEvents() -> Task<Void, Never>? {
        guard growthSettings.accountability.isActive else { return nil }
        guard supportsDirectAccountabilityTransport else { return nil }

        return Task {
            _ = await processRemoteAccountabilityEventsNow()
        }
    }

    @discardableResult
    func refreshAccountabilityForForeground() -> Task<Void, Never>? {
        guard growthSettings.accountability.isActive else { return nil }
        guard supportsDirectAccountabilityTransport else { return nil }

        let remoteRefreshTask = processRemoteAccountabilityEvents()
        refreshAccountabilityFriends()
        return remoteRefreshTask
    }

    @discardableResult
    func handleIncomingPoke(_ envelope: SunclubAccountabilityPokeEnvelope) -> Task<Void, Never>? {
        guard supportsDirectAccountabilityTransport else { return nil }

        guard envelope.receiverProfileID == growthSettings.accountability.localProfileID,
              let connection = growthSettings.accountability.connections.first(where: {
                $0.friendProfileID == envelope.senderProfileID
              }) else {
            return nil
        }
        guard isValidRelationshipToken(envelope.relationshipToken, for: connection) else {
            return nil
        }

        recordPoke(
            SunclubAccountabilityPoke(
                friendProfileID: envelope.senderProfileID,
                friendName: envelope.senderName,
                direction: .received,
                channel: .direct,
                status: .received,
                message: envelope.message,
                createdAt: envelope.createdAt
            )
        )
        updateConnection(connection.friendProfileID) { connection in
            connection.lastPokeReceivedAt = envelope.createdAt
        }
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()

        let notificationMessage = SunclubAccountabilityMessaging.incomingNotificationBody(
            from: envelope.senderName,
            recipientHasLoggedToday: record(for: currentDate()) != nil,
            recentPokes: growthSettings.accountability.pokeHistory,
            now: currentDate(),
            calendar: calendar
        )

        return Task {
            await notificationManager.scheduleAccountabilityPokeNotification(
                friendName: envelope.senderName,
                message: notificationMessage,
                route: .friends
            )
        }
    }

    func markAchievementCelebrationSeen() {
        guard let achievementCelebration else { return }
        if !growthSettings.presentedAchievementIDs.contains(achievementCelebration.id.rawValue) {
            growthSettings.presentedAchievementIDs.append(achievementCelebration.id.rawValue)
            persistGrowthSettings()
        }
        self.achievementCelebration = nil
    }

    func streakCardArtifact() throws -> SunclubShareArtifact {
        try SunclubShareArtifactService.makeStreakCard(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            recordedDays: recordedDays,
            seasonStyle: SunclubGrowthAnalytics.seasonalStyle(for: currentDate(), calendar: calendar),
            now: currentDate(),
            calendar: calendar
        )
    }

    func achievementArtifact(for achievement: SunclubAchievement) throws -> SunclubShareArtifact {
        try SunclubShareArtifactService.makeAchievementCard(
            achievement: achievement,
            seasonStyle: SunclubGrowthAnalytics.seasonalStyle(for: currentDate(), calendar: calendar)
        )
    }

    func challengeArtifact(for challenge: SunclubSeasonalChallenge) throws -> SunclubShareArtifact {
        try SunclubShareArtifactService.makeChallengeCard(
            challenge: challenge,
            seasonStyle: SunclubGrowthAnalytics.seasonalStyle(for: currentDate(), calendar: calendar)
        )
    }

    func skinHealthReportArtifact(for interval: DateInterval) throws -> SunclubShareArtifact {
        try SunclubShareArtifactService.makeSkinHealthReport(
            summary: SunclubGrowthAnalytics.reportSummary(
                records: records,
                interval: interval,
                calendar: calendar
            ),
            preferredName: preferredDisplayName
        )
    }

    func skinHealthReportSummary(for interval: DateInterval) -> SunclubSkinHealthReportSummary {
        SunclubGrowthAnalytics.reportSummary(records: records, interval: interval, calendar: calendar)
    }

    var yearInReviewSummary: SunclubSkinHealthReportSummary? {
        let loggedDays = Set(records.map { calendar.startOfDay(for: $0.startOfDay) })
        guard loggedDays.count >= 30 else { return nil }

        let now = currentDate()
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        let interval = DateInterval(start: yearStart, end: now)
        return SunclubGrowthAnalytics.reportSummary(records: records, interval: interval, calendar: calendar)
    }

    func nextDailyPhrase() -> String {
        nextPhrase(
            catalog: PhraseBank.dailyPhrases,
            state: \.dailyPhraseState,
            changedField: .dailyPhraseState,
            summary: "Updated the daily phrase rotation."
        )
    }

    func nextDailyPhrases(count: Int) -> [String] {
        nextPhrases(
            count: count,
            catalog: PhraseBank.dailyPhrases,
            state: \.dailyPhraseState,
            changedField: .dailyPhraseState,
            summary: "Updated the daily phrase rotation."
        )
    }

    func nextWeeklyPhrase() -> String {
        nextPhrase(
            catalog: PhraseBank.weeklyPhrases,
            state: \.weeklyPhraseState,
            changedField: .weeklyPhraseState,
            summary: "Updated the weekly phrase rotation."
        )
    }

    func markAppliedToday(
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) {
        let now = currentDate()
        upsertRecord(
            RecordUpsertRequest(
                day: now,
                verifiedAt: now,
                verificationValues: (method, verificationDuration, SunManualLogInput.normalizedSPF(spfLevel), notes),
                replaceOptionalFields: false,
                preserveExistingDuration: false,
                kind: .manualLog,
                summary: "Logged sunscreen for today."
            )
        )
    }

    func saveManualRecord(
        for day: Date,
        verifiedAt: Date? = nil,
        spfLevel: Int?,
        notes: String?
    ) {
        let existingTimestamp = record(for: day)?.verifiedAt
        let timestamp = verifiedAt ?? existingTimestamp ?? defaultVerifiedAt(for: day)
        let kind: SunclubChangeKind = record(for: day) == nil ? .historyBackfill : .historyEdit
        let summary = kind == .historyBackfill
            ? "Backfilled \(calendar.startOfDay(for: day).formatted(.dateTime.month().day()))."
            : "Edited \(calendar.startOfDay(for: day).formatted(.dateTime.month().day()))."
        upsertRecord(
            RecordUpsertRequest(
                day: day,
                verifiedAt: timestamp,
                verificationValues: (.manual, nil, SunManualLogInput.normalizedSPF(spfLevel), notes),
                replaceOptionalFields: true,
                preserveExistingDuration: true,
                kind: kind,
                summary: summary
            )
        )
    }

    func recordVerificationSuccess(
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) {
        let previousLongestStreak = settings.longestStreak
        markAppliedToday(
            method: method,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes
        )
        var growthSettings = growthFeatureStore.load()
        let (successTitle, updatedSuccessState) = PhraseRotation.nextPhrase(
            from: growthSettings.successPhraseState,
            catalog: PhraseBank.successPhrases
        )
        growthSettings.successPhraseState = updatedSuccessState
        growthFeatureStore.save(growthSettings)
        verificationSuccessPresentation = VerificationSuccessPresentation(
            streak: currentStreak,
            isPersonalBest: currentStreak > previousLongestStreak,
            canAddDetails: spfLevel == nil && Self.normalizedNotes(notes) == nil,
            title: successTitle
        )
    }

    func recordWatchSunscreenLog() throws -> SunclubWidgetSnapshot {
        guard settings.hasCompletedOnboarding else {
            throw SunclubQuickLogError.onboardingRequired
        }

        markAppliedToday(method: .quickLog)
        if settings.reapplyReminderEnabled {
            scheduleReapplyReminder()
        }
        return widgetSnapshotStore.load()
    }

    func clearVerificationSuccessPresentation() {
        verificationSuccessPresentation = nil
    }

    func deleteRecord(for day: Date) {
        let batch = try? historyService.applyDayChange(
            for: day,
            kind: .deleteRecord,
            summary: "Deleted \(calendar.startOfDay(for: day).formatted(.dateTime.month().day())).",
            changedFields: [.isDeleted]
        ) { existingSnapshot in
            guard existingSnapshot != nil else {
                return existingSnapshot
            }
            return nil
        }

        finishDurableChange(batch, reschedulesReminders: false)

        let target = calendar.startOfDay(for: day)
        if calendar.isDate(target, inSameDayAs: currentDate()), record(for: target) == nil {
            cancelReapplyRemindersIfNeeded()
        }
    }

    var longestStreak: Int {
        settings.longestStreak
    }

    func scheduleReapplyReminder() {
        guard settings.reapplyReminderEnabled else { return }
        let plan = reapplyReminderPlan

        guard plan.shouldScheduleNotification else {
            cancelReapplyRemindersIfNeeded()
            return
        }

        Task {
            await notificationManager.scheduleReapplyReminder(
                plan: plan,
                route: preferredCheckInRoute
            )
        }
    }

    func updateReapplySettings(enabled: Bool, intervalMinutes: Int) {
        let clampedIntervalMinutes = max(30, min(480, intervalMinutes))
        guard settings.reapplyReminderEnabled != enabled
                || settings.reapplyIntervalMinutes != clampedIntervalMinutes else {
            return
        }

        let batch = try? historyService.applySettingsChange(
            kind: .reapplySettings,
            summary: "Updated the reapply reminder.",
            changedFields: [.reapplyReminderEnabled, .reapplyIntervalMinutes]
        ) { snapshot in
            snapshot.reapplyReminderEnabled = enabled
            snapshot.reapplyIntervalMinutes = clampedIntervalMinutes
        }
        finishDurableChange(batch, reschedulesReminders: false)

        if !enabled {
            cancelReapplyRemindersIfNeeded()
        }
    }

    func recordReapplication(for day: Date? = nil, performedAt: Date? = nil) {
        let now = performedAt ?? currentDate()
        let targetDay = day ?? now
        let batch = try? historyService.applyDayChange(
            for: targetDay,
            kind: .reapply,
            summary: "Logged a reapply check-in.",
            changedFields: [.reapplyCount, .lastReappliedAt]
        ) { existingSnapshot in
            guard var snapshot = existingSnapshot else {
                return nil
            }

            snapshot.reapplyCount += 1
            snapshot.lastReappliedAt = now
            return snapshot
        }
        finishDurableChange(batch, reschedulesReminders: false)

        if calendar.isDate(targetDay, inSameDayAs: currentDate()) {
            if settings.reapplyReminderEnabled {
                scheduleReapplyReminder()
            } else {
                cancelReapplyRemindersIfNeeded()
            }
        }
    }

    func updateLiveUVPreference(enabled: Bool, allowPermissionPrompt: Bool = true) {
        guard settings.usesLiveUV != enabled else {
            return
        }

        let batch = try? historyService.applySettingsChange(
            kind: .liveUVSettings,
            summary: "Updated the live UV preference.",
            changedFields: [.usesLiveUV]
        ) { snapshot in
            snapshot.usesLiveUV = enabled
        }
        finishDurableChange(batch, reschedulesReminders: false)
        refreshUVReadingIfNeeded(allowPermissionPrompt: allowPermissionPrompt)
        refreshUVForecastIfNeeded(allowPermissionPrompt: allowPermissionPrompt)
    }

    func performLiveUVAction(_ action: LiveUVActionKind) {
        switch action {
        case .requestPermission:
            refreshUVReadingIfNeeded(allowPermissionPrompt: true)
            refreshUVForecastIfNeeded(allowPermissionPrompt: true)
        case .openSettings:
            break
        case .refresh:
            refreshUVReadingIfNeeded()
            refreshUVForecastIfNeeded()
        }
    }

    func applyReminderCoachingSuggestion(_ suggestion: ReminderCoachingSuggestion) {
        updateReminderTime(
            for: suggestion.kind,
            hour: suggestion.suggestedTime.hour,
            minute: suggestion.suggestedTime.minute
        )
    }

    func exportBackupDocument() throws -> SunclubBackupDocument {
        try backupService.exportDocument(from: modelContext)
    }

    @discardableResult
    func exportBackup(to url: URL) throws -> SunclubBackupDocument {
        try backupService.exportBackup(from: modelContext, to: url)
    }

    @discardableResult
    func importBackupDocument(_ document: SunclubBackupDocument) throws -> SunclubBackupImportSummary {
        let summary = try backupService.importBackupDocument(document, into: modelContext)
        finalizeImportedBackup(importedBatchCount: summary.importedBatchCount)
        return summary
    }

    @discardableResult
    func importBackup(from url: URL) throws -> SunclubBackupImportSummary {
        let summary = try backupService.importBackup(from: url, into: modelContext)
        finalizeImportedBackup(importedBatchCount: summary.importedBatchCount)
        return summary
    }

    func record(for day: Date) -> DailyRecord? {
        let target = calendar.startOfDay(for: day)
        if let projectedRecord = records.first(where: { calendar.isDate($0.startOfDay, inSameDayAs: target) }) {
            return projectedRecord
        }

        return (try? verificationStore.record(for: target)).flatMap { $0 }
    }

    func advanceSelectedDayIfStale() {
        let today = calendar.startOfDay(for: referenceDate)
        let normalized = calendar.startOfDay(for: selectedDay)
        if normalized != selectedDay {
            selectedDay = normalized
        }
        if selectedDay > calendar.date(byAdding: .day, value: 60, to: today) ?? today {
            selectedDay = today
        }
    }

    func selectDay(_ day: Date) {
        selectedDay = calendar.startOfDay(for: day)
    }

    func futureDayPreview(for day: Date) -> FutureDayPreview? {
        let dayStart = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: referenceDate)
        guard dayStart > today else {
            return nil
        }

        let suggestion = ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: dayStart,
            calendar: calendar,
            scannedSPFLevels: growthSettings.scannedSPFLevels
        )
        let spf = suggestion.defaultSPF ?? 30
        let interval = settings.reapplyIntervalMinutes
        let intervalText = interval >= 60
            ? "every \(interval / 60)h" + (interval % 60 == 0 ? "" : " \(interval % 60)m")
            : "every \(interval) min"
        let text = "Plan SPF \(spf)+. Reapply \(intervalText) if you're outside."
        return FutureDayPreview(suggestedSPF: spf, suggestionText: text)
    }

    func timelineDayLogSummary(for day: Date) -> TimelineDayLogSummary {
        let dayStart = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: referenceDate)
        let record = record(for: dayStart)

        if dayStart > today {
            let preview = futureDayPreview(for: dayStart)
            let spf = preview?.suggestedSPF ?? 30
            return TimelineDayLogSummary(
                day: dayStart,
                category: .future,
                record: nil,
                futurePreview: preview,
                sunscreenStatusText: "Plan SPF \(spf)+",
                reapplyStatusText: "Forecast ahead",
                notesStatusText: nil,
                factorsStatusText: "View only"
            )
        }

        let isToday = calendar.isDate(dayStart, inSameDayAs: today)
        let category: TimelineDayLogSummary.Category = isToday ? .today : .past

        if let record {
            let sunscreenText: String
            if let spfLevel = record.spfLevel {
                sunscreenText = "Applied · SPF \(spfLevel)"
            } else {
                sunscreenText = "Applied"
            }

            let reapplyText: String
            switch record.reapplyCount {
            case 0:
                reapplyText = "None"
            case 1:
                reapplyText = "1 check-in"
            default:
                reapplyText = "\(record.reapplyCount) check-ins"
            }

            let factorsText: String
            if isToday, let level = uvReading?.level {
                factorsText = "UV \(level.displayName)"
            } else {
                factorsText = record.method.displayName
            }

            return TimelineDayLogSummary(
                day: dayStart,
                category: category,
                record: record,
                futurePreview: nil,
                sunscreenStatusText: sunscreenText,
                reapplyStatusText: reapplyText,
                notesStatusText: record.trimmedNotes,
                factorsStatusText: factorsText
            )
        }

        let sunscreenText = isToday ? "Not logged — tap to log" : "Not logged — tap to backfill"
        let factorsText: String
        if isToday, let level = uvReading?.level {
            factorsText = "UV \(level.displayName)"
        } else {
            factorsText = "—"
        }

        return TimelineDayLogSummary(
            day: dayStart,
            category: category,
            record: nil,
            futurePreview: nil,
            sunscreenStatusText: sunscreenText,
            reapplyStatusText: "None",
            notesStatusText: nil,
            factorsStatusText: factorsText
        )
    }

    func refreshUVReadingIfNeeded(allowPermissionPrompt: Bool = false) {
        if let uvReadingOverride {
            uvReading = uvReadingOverride
            return
        }

        Task {
            await uvIndexService.fetchUVIndex(
                prefersLiveData: settings.usesLiveUV,
                allowPermissionPrompt: allowPermissionPrompt
            )
            guard uvReadingOverride == nil else {
                return
            }
            uvReading = uvIndexService.currentReading
            syncWidgetSnapshot()
            reloadWidgetTimelines()
            await liveActivityCoordinator.sync(using: self)
        }
    }

    func setUVReadingForTesting(_ reading: UVReading?) {
        uvReadingOverride = reading
        uvReading = reading
    }

    func setUVForecastForTesting(_ forecast: SunclubUVForecast?) {
        uvForecast = forecast
    }

    func refreshNotificationHealth() {
        if let notificationHealthOverride {
            notificationHealthSnapshot = notificationHealthOverride
            return
        }

        Task {
            let snapshot = await notificationManager.notificationHealthSnapshot(using: self)
            guard notificationHealthOverride == nil else {
                return
            }
            notificationHealthSnapshot = snapshot
        }
    }

    func setNotificationHealthSnapshotForTesting(_ snapshot: NotificationHealthSnapshot?) {
        notificationHealthOverride = snapshot
        notificationHealthSnapshot = snapshot ?? .unknown
    }

    func refreshLeaveHomeReminderStatus(allowPermissionPrompt: Bool = false) {
        if let leaveHomeAuthorizationOverride {
            leaveHomeAuthorizationState = leaveHomeAuthorizationOverride
            return
        }

        Task {
            let state = await homeExitReminderMonitor.refreshMonitoring(
                using: self,
                allowPermissionPrompt: allowPermissionPrompt
            )
            guard leaveHomeAuthorizationOverride == nil else {
                return
            }
            leaveHomeAuthorizationState = state
        }
    }

    func setLeaveHomeAuthorizationStateForTesting(_ state: LeaveHomeAuthorizationState?) {
        leaveHomeAuthorizationOverride = state
        leaveHomeAuthorizationState = state ?? .notDetermined
    }

    func repairReminderSchedule() {
        Task {
            _ = await notificationManager.requestAuthorizationIfNeeded()
            await notificationManager.scheduleReminders(using: self)
            notificationHealthSnapshot = await notificationManager.notificationHealthSnapshot(using: self)
        }
    }

    func dayStatus(for date: Date, now: Date? = nil) -> DayStatus {
        let set = Set(records.map { calendar.startOfDay(for: $0.startOfDay) })
        return CalendarAnalytics.status(for: date, with: set, now: now ?? currentDate(), calendar: calendar)
    }

    func monthGrid(for month: Date) -> [Date] {
        CalendarAnalytics.monthGridDays(for: month, calendar: calendar)
    }

    func isCurrentMonth(_ date: Date, month: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    var currentStreak: Int {
        CalendarAnalytics.currentStreak(records: recordedDays, now: currentDate(), calendar: calendar)
    }

    var currentStreakDays: [Date] {
        CalendarAnalytics.currentStreakDays(records: recordedDays, now: currentDate(), calendar: calendar)
    }

    func last7DaysReport() -> WeeklyReport {
        CalendarAnalytics.weeklyReport(records: records.map(\.startOfDay), now: currentDate(), calendar: calendar)
    }

    func sunscreenUsageInsights(recentNotesLimit: Int = 3) -> SunscreenUsageInsights {
        SunscreenUsageAnalytics.insights(from: records, recentNotesLimit: recentNotesLimit)
    }

    func manualLogSuggestionState(for day: Date) -> ManualLogSuggestionState {
        ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: day,
            calendar: calendar,
            scannedSPFLevels: growthSettings.scannedSPFLevels
        )
    }

    func monthlyReviewInsights(for month: Date) -> MonthlyReviewInsights {
        MonthlyReviewAnalytics.insights(
            from: records,
            month: month,
            now: currentDate(),
            calendar: calendar
        )
    }

    func recordStartsForTesting() -> [Date] {
        recordedDays
    }

    var recordedDays: [Date] {
        records.map { calendar.startOfDay(for: $0.startOfDay) }
    }

    func shouldSuppressDailyReminder(on day: Date) -> Bool {
        homeExitReminderMonitor.hasTriggeredReminder(on: day)
    }

    private func applyReminderSettingsChange(
        _ reminderSettings: SmartReminderSettings,
        summary: String
    ) {
        let encodedSettings = try? JSONEncoder().encode(
            reminderSettings.normalized(
                fallbackHour: reminderSettings.weekdayTime.hour,
                fallbackMinute: reminderSettings.weekdayTime.minute
            )
        )

        let batch = try? historyService.applySettingsChange(
            kind: .reminderSettings,
            summary: summary,
            changedFields: [.reminderHour, .reminderMinute, .smartReminderSettingsData]
        ) { snapshot in
            snapshot.reminderHour = reminderSettings.weekdayTime.hour
            snapshot.reminderMinute = reminderSettings.weekdayTime.minute
            snapshot.smartReminderSettingsData = encodedSettings
        }
        finishDurableChange(batch, reschedulesReminders: true)
        refreshLeaveHomeReminderStatus()
    }

    private func upsertRecord(_ request: RecordUpsertRequest) {
        let batch = try? historyService.applyDayChange(
            for: request.day,
            kind: request.kind,
            summary: request.summary,
            changedFields: [.verifiedAt, .methodRawValue, .verificationDuration, .spfLevel, .notes]
        ) { existingSnapshot in
            let normalizedSPF = SunManualLogInput.normalizedSPF(request.verificationValues.spfLevel)
            let normalizedNotes = Self.normalizedNotes(request.verificationValues.notes)
            if var snapshot = existingSnapshot {
                snapshot.verifiedAt = request.verifiedAt
                snapshot.methodRawValue = request.verificationValues.method.rawValue
                snapshot.verificationDuration = request.preserveExistingDuration
                    ? (request.verificationValues.duration ?? snapshot.verificationDuration)
                    : request.verificationValues.duration

                if request.replaceOptionalFields {
                    snapshot.spfLevel = normalizedSPF
                    snapshot.notes = normalizedNotes
                } else {
                    if let spfLevel = normalizedSPF {
                        snapshot.spfLevel = spfLevel
                    }
                    if let normalizedNotes {
                        snapshot.notes = normalizedNotes
                    }
                }
                return snapshot
            }

            return DailyRecordProjectionSnapshot(
                startOfDay: self.calendar.startOfDay(for: request.day),
                verifiedAt: request.verifiedAt,
                methodRawValue: request.verificationValues.method.rawValue,
                verificationDuration: request.verificationValues.duration,
                spfLevel: normalizedSPF,
                notes: normalizedNotes,
                reapplyCount: 0,
                lastReappliedAt: nil
            )
        }
        finishDurableChange(batch, reschedulesReminders: false)
        exportHealthKitLogIfNeeded(for: request.day)
    }

    private func defaultVerifiedAt(for day: Date) -> Date {
        let targetDay = calendar.startOfDay(for: day)
        let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: currentDate())
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)

        return calendar.date(
            from: DateComponents(
                year: dayComponents.year,
                month: dayComponents.month,
                day: dayComponents.day,
                hour: nowComponents.hour,
                minute: nowComponents.minute,
                second: nowComponents.second
            )
        ) ?? targetDay
    }

    private func finishDurableChange(
        _ batch: SunclubChangeBatch?,
        reschedulesReminders: Bool
    ) {
        refresh()
        syncAchievementCelebration()
        refreshUVForecastIfNeeded()
        publishAccountabilityProfileIfNeeded()
        Task {
            await liveActivityCoordinator.sync(using: self)
        }

        if reschedulesReminders {
            scheduleReminders()
        }

        refreshStreakRiskReminder()

        guard let batch else {
            return
        }

        reloadWidgetTimelines()

        Task {
            await cloudSyncCoordinator.queueBatchIfNeeded(batch.id)
        }
    }

    private func persistGrowthSettings() {
        growthFeatureStore.save(growthSettings)
    }

    private var resolvedAccountabilityDisplayName: String {
        let accountabilityName = growthSettings.accountability.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !accountabilityName.isEmpty {
            return accountabilityName
        }

        let preferredName = preferredDisplayName
        return preferredName.isEmpty ? "Sunclub Friend" : preferredName
    }

    private func importLegacyFriendSnapshot(_ importedSnapshot: SunclubFriendSnapshot) {
        upsertFriendSnapshot(importedSnapshot)
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
        friendImportMessage = importedSnapshot.hasLoggedToday && record(for: currentDate()) == nil
            ? "\(importedSnapshot.name) logged today. Have you?"
            : "Imported \(importedSnapshot.name)."
    }

    private func upsertFriendSnapshot(_ snapshot: SunclubFriendSnapshot) {
        if let existingIndex = growthSettings.friends.firstIndex(where: { $0.id == snapshot.id || $0.name == snapshot.name }) {
            growthSettings.friends[existingIndex] = snapshot
        } else {
            growthSettings.friends.append(snapshot)
        }
    }

    private func upsertConnection(_ connection: SunclubFriendConnection) {
        if let existingIndex = growthSettings.accountability.connections.firstIndex(where: { $0.friendProfileID == connection.friendProfileID }) {
            var existing = growthSettings.accountability.connections[existingIndex]
            existing.friendSnapshotID = connection.friendSnapshotID
            existing.friendDisplayName = connection.friendDisplayName
            existing.relationshipToken = connection.relationshipToken
            existing.canDirectPoke = connection.canDirectPoke
            growthSettings.accountability.connections[existingIndex] = existing
        } else {
            growthSettings.accountability.connections.append(connection)
        }
    }

    private func updateConnection(
        _ friendProfileID: UUID,
        update: (inout SunclubFriendConnection) -> Void
    ) {
        guard let index = growthSettings.accountability.connections.firstIndex(where: { $0.friendProfileID == friendProfileID }) else {
            return
        }
        update(&growthSettings.accountability.connections[index])
    }

    private func isValidRelationshipToken(_ token: String, for connection: SunclubFriendConnection) -> Bool {
        connection.relationshipToken == token || growthSettings.accountability.inviteTokens.contains { inviteToken in
            inviteToken.token == token
        }
    }

    private func applyAccountabilityProfile(_ profile: SunclubAccountabilityProfile) {
        guard let connection = growthSettings.accountability.connections.first(where: { $0.friendProfileID == profile.profileID }) else {
            return
        }
        var snapshot = profile.snapshot
        snapshot.id = connection.friendSnapshotID
        snapshot.name = profile.displayName
        upsertFriendSnapshot(snapshot)
        updateConnection(profile.profileID) { connection in
            connection.friendDisplayName = profile.displayName
            connection.lastStatusRefreshAt = profile.updatedAt
        }
    }

    private func recordPoke(_ poke: SunclubAccountabilityPoke) {
        growthSettings.accountability.pokeHistory.insert(poke, at: 0)
        growthSettings.accountability.pokeHistory = Array(growthSettings.accountability.pokeHistory.prefix(50))
        if poke.direction == .sent {
            updateConnection(poke.friendProfileID) { connection in
                connection.lastPokeSentAt = poke.createdAt
            }
        }
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
    }

    private func publishAccountabilityProfileIfNeeded() {
        guard growthSettings.accountability.isActive else {
            return
        }
        guard supportsDirectAccountabilityTransport else {
            return
        }

        let now = currentDate()
        let profile = SunclubAccountabilityProfile(
            profileID: growthSettings.accountability.localProfileID,
            displayName: resolvedAccountabilityDisplayName,
            snapshot: localFriendSnapshot,
            updatedAt: now
        )
        growthSettings.accountability.lastPublishedAt = now
        persistGrowthSettings()

        Task {
            try? await accountabilityService.publishProfile(profile)
            if growthSettings.accountability.subscriptionInstallVersion < Self.accountabilitySubscriptionInstallVersion {
                do {
                    try await accountabilityService.installSubscriptions(for: growthSettings.accountability.localProfileID)
                    growthSettings.accountability.subscriptionsInstalledAt = currentDate()
                    growthSettings.accountability.subscriptionInstallVersion = Self.accountabilitySubscriptionInstallVersion
                    persistGrowthSettings()
                } catch {
                    growthSettings.accountability.subscriptionsInstalledAt = nil
                    persistGrowthSettings()
                }
            }
        }
    }

    private func syncAchievementCelebration() {
        guard achievementCelebration == nil else {
            return
        }

        achievementCelebration = achievements.first(where: { achievement in
            achievement.isUnlocked && !growthSettings.presentedAchievementIDs.contains(achievement.id.rawValue)
        })
    }

    private func exportHealthKitLogIfNeeded(for day: Date) {
        guard growthSettings.healthKit.isEnabled,
              let record = record(for: day) else {
            return
        }

        Task {
            await healthKitService.exportLog(
                recordDate: record.verifiedAt,
                uvIndex: uvForecast?.peakHour?.index ?? uvReading?.index,
                externalID: record.id,
                spfLevel: record.spfLevel
            )
            growthSettings.healthKit.lastExportAt = currentDate()
            persistGrowthSettings()
        }
    }

    private func syncLongestStreakIfNeeded() {
        let computed = CalendarAnalytics.longestStreak(records: recordedDays, calendar: calendar)
        if computed != settings.longestStreak {
            settings.longestStreak = computed
            save()
        }
    }

    private func cancelReapplyRemindersIfNeeded() {
        Task {
            await notificationManager.cancelReapplyReminders()
        }
    }

    private static func normalizedNotes(_ notes: String?) -> String? {
        SunManualLogInput.normalizedNotes(notes)
    }

    private func finalizeImportedBackup(importedBatchCount: Int) {
        clearVerificationSuccessPresentation()
        refresh()
        syncAchievementCelebration()
        cancelReapplyRemindersIfNeeded()
        scheduleReminders()
        refreshStreakRiskReminder()
        refreshNotificationHealth()
        refreshLeaveHomeReminderStatus()
        refreshUVReadingIfNeeded()
        refreshUVForecastIfNeeded()
        _ = importedBatchCount
        reloadWidgetTimelines()
    }

    private func syncWidgetSnapshot() {
        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: settings,
            records: records,
            growthSettings: growthSettings,
            uvReading: uvReading,
            uvForecast: uvForecast,
            now: currentDate(),
            calendar: calendar
        )
        widgetSnapshotStore.save(snapshot)
        SunclubWatchSyncCoordinator.shared.push(snapshot: snapshot)
    }

    private func reloadWidgetTimelines() {
        guard !RuntimeEnvironment.isRunningTests else {
            return
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
