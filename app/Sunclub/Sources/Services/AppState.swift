import Foundation
import Observation
import os
import SwiftData
import WidgetKit

@MainActor
@Observable
final class AppState: SunclubReminderState {
    let modelContext: ModelContext
    var settings: Settings
    var verificationSuccessPresentation: VerificationSuccessPresentation?
    private let verificationStore: VerificationStore
    private let historicalUVStore: SunclubHistoricalUVStore
    private let weatherKitKillSwitch: SunclubWeatherKitKillSwitch?
    private let historyService: SunclubHistoryService
    private let mutationService: SunclubMutationService
    private let cloudSyncCoordinator: CloudSyncControlling
    private let reminderCoordinator: SunclubReminderCoordinator
    private let notificationManager: NotificationScheduling
    private let homeExitReminderMonitor: HomeExitReminderMonitoring
    private let uvIndexService: UVIndexService
    private let uvCoordinator: SunclubUVCoordinator
    private let healthKitService: SunclubHealthKitServing
    private let liveActivityCoordinator: SunclubLiveActivityCoordinating
    private let recoveryCoordinator: SunclubRecoveryCoordinator
    private let widgetSnapshotStore: SunclubWidgetSnapshotStore
    private let growthFeatureStore: SunclubGrowthFeatureStoring
    private let accountabilityCoordinator: SunclubAccountabilityCoordinator
    private let currentDate: () -> Date
    private(set) var records: [DailyRecord] = []
    private(set) var changeBatches: [SunclubChangeBatch] = []
    private(set) var importSessions: [SunclubImportSession] = []
    private(set) var conflicts: [SunclubConflictItem] = []
    private(set) var syncPreference: CloudSyncPreference?
    var initialICloudRestoreState: InitialICloudRestoreState { recoveryCoordinator.initialRestoreState }
    var uvReading: UVReading? { uvCoordinator.reading }
    var uvForecast: SunclubUVForecast? { uvCoordinator.forecast }
    var uvStatus: SunclubUVStatus { uvCoordinator.status }
    var uvProtectionWindow: SunclubUVProtectionWindow? { uvCoordinator.protectionWindow }
    var notificationHealthSnapshot: NotificationHealthSnapshot { reminderCoordinator.health }
    var leaveHomeAuthorizationState: LeaveHomeAuthorizationState { reminderCoordinator.homeAuthorization }
    private(set) var leaveHomeReminderErrorMessage: String?
    private(set) var growthSettings: SunclubGrowthSettings
    private(set) var achievementCelebration: SunclubAchievement?
    private(set) var friendImportMessage: String?
    var manualLogPrefill: ManualLogPrefill?
    var selectedDay: Date = Calendar.current.startOfDay(for: Date()) {
        didSet {
            normalizeSelectedDayIfNeeded()
        }
    }
    private(set) var pendingManualLogContext: AppLogContext?
    private(set) var lastLogContext: AppLogContext?
    private(set) var logActionErrorMessage: String?

    private(set) var lastRefreshError: String?

    private static let logger = Logger(subsystem: "com.sunclub", category: "AppState")
    private static let accountabilitySubscriptionInstallVersion = 2
    private let calendar = Calendar.current
    private var isNormalizingSelectedDay = false
    private var lastAppliedRestorablePreferences: SunclubRestorablePreferences?
    private var healthKitAuthorizationRequestID: UUID?

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

    convenience init(
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
        historicalUVStore: SunclubHistoricalUVStore? = nil,
        weatherKitKillSwitch: SunclubWeatherKitKillSwitch? = nil,
        clock: @escaping () -> Date = { RuntimeEnvironment.currentDateOverride ?? Date() }
    ) {
        self.init(dependencies: .live(
            context: context,
            notificationManager: notificationManager,
            uvIndexService: uvIndexService,
            uvBriefingService: uvBriefingService,
            healthKitService: healthKitService,
            liveActivityCoordinator: liveActivityCoordinator,
            backupService: backupService,
            storeRecoveryService: storeRecoveryService,
            historyService: historyService,
            cloudSyncCoordinator: cloudSyncCoordinator,
            widgetSnapshotStore: widgetSnapshotStore,
            growthFeatureStore: growthFeatureStore,
            accountabilityService: accountabilityService,
            runtimeEnvironment: runtimeEnvironment,
            homeExitReminderMonitor: homeExitReminderMonitor,
            historicalUVStore: historicalUVStore,
            weatherKitKillSwitch: weatherKitKillSwitch,
            clock: clock
        ))
    }

    init(dependencies: SunclubAppDependencies) {
        let context = dependencies.context
        let notificationManager = dependencies.notificationManager
        let uvIndexService = dependencies.uvIndexService
        let uvBriefingService = dependencies.uvBriefingService
        let healthKitService = dependencies.healthKitService
        let liveActivityCoordinator = dependencies.liveActivityCoordinator
        let backupService = dependencies.backupService
        let storeRecoveryService = dependencies.storeRecoveryService
        let historyService = dependencies.historyService
        let cloudSyncCoordinator = dependencies.cloudSyncCoordinator
        let widgetSnapshotStore = dependencies.widgetSnapshotStore
        let growthFeatureStore = dependencies.growthFeatureStore
        let accountabilityService = dependencies.accountabilityService
        let runtimeEnvironment = dependencies.runtimeEnvironment
        let homeExitReminderMonitor = dependencies.homeExitReminderMonitor
        let historicalUVStore = dependencies.historicalUVStore
        let weatherKitKillSwitch = dependencies.weatherKitKillSwitch
        let clock = dependencies.clock

        modelContext = context
        verificationStore = VerificationStore(context: context)
        self.historicalUVStore = historicalUVStore
        self.weatherKitKillSwitch = weatherKitKillSwitch
        let resolvedHistoryService = historyService
        self.historyService = resolvedHistoryService
        mutationService = SunclubMutationService(history: resolvedHistoryService)
        self.notificationManager = notificationManager
        let resolvedHomeExitReminderMonitor = homeExitReminderMonitor
        self.homeExitReminderMonitor = resolvedHomeExitReminderMonitor
        reminderCoordinator = SunclubReminderCoordinator(notifications: notificationManager, homeMonitor: resolvedHomeExitReminderMonitor)
        self.uvIndexService = uvIndexService
        uvCoordinator = SunclubUVCoordinator(
            indexService: uvIndexService, briefingService: uvBriefingService, clock: clock
        )
        self.healthKitService = healthKitService
        self.liveActivityCoordinator = liveActivityCoordinator
        recoveryCoordinator = SunclubRecoveryCoordinator(history: resolvedHistoryService, cloud: cloudSyncCoordinator, backups: backupService)
        let launchRecoveryResult = SunclubRecoveryCoordinator.recoverLegacyStoreIfNeeded(
            storeRecoveryService: storeRecoveryService,
            context: context,
            historyService: resolvedHistoryService,
            runtimeEnvironment: runtimeEnvironment
        )
        try? resolvedHistoryService.bootstrapIfNeeded()
        self.widgetSnapshotStore = widgetSnapshotStore
        self.growthFeatureStore = growthFeatureStore
        accountabilityCoordinator = SunclubAccountabilityCoordinator(service: accountabilityService, clock: clock)
        currentDate = clock
        selectedDay = calendar.startOfDay(for: currentDate())
        settings = (try? resolvedHistoryService.settings()) ?? Self.loadOrCreateSettings(from: context)
        growthSettings = self.growthFeatureStore.load()
        self.cloudSyncCoordinator = cloudSyncCoordinator
        recoveryCoordinator.initialRestoreState = SunclubRecoveryCoordinator.initialICloudRestoreState(
            historyService: resolvedHistoryService,
            runtimeEnvironment: runtimeEnvironment
        )
        self.homeExitReminderMonitor.setStateProvider { [weak self] in
            self
        }
        refresh()
        refreshWeatherKitKillSwitchIfNeeded()
        refreshUVForecastIfNeeded()
        refreshNotificationHealth()
        refreshLeaveHomeReminderStatus()
        refreshHealthKitStatus()
        syncAchievementCelebration()
        syncRestorablePreferencesRevisionIfNeeded()
        Task {
            await self.liveActivityCoordinator.sync(using: self)
        }

        if runtimeEnvironment.shouldStartCloudSyncOnLaunch {
            Task {
                await self.recoveryCoordinator.start(
                    launchRecovery: launchRecoveryResult, syncEnabled: self.syncPreference?.isICloudSyncEnabled ?? true
                )
                self.refresh()
            }
        }
    }

    static func defaultCloudSyncCoordinator(
        historyService: SunclubHistoryService,
        runtimeEnvironment: RuntimeEnvironmentSnapshot = .current
    ) -> CloudSyncControlling {
        SunclubAppDependencies.defaultCloudSyncCoordinator(historyService: historyService, runtimeEnvironment: runtimeEnvironment)
    }

    var shouldShowInitialICloudRestoreGate: Bool {
        switch initialICloudRestoreState {
        case .checking, .failed:
            return !settings.hasCompletedOnboarding
        case .notNeeded, .restored, .noRemoteHistory, .continuedLocally:
            return false
        }
    }

    func refresh() {
        do {
            try historyService.refreshProjectedState()
            settings = try historyService.settings()
            applyRestorablePreferencesFromSettingsIfNeeded()
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
            await reminderCoordinator.schedule(using: self)
        }
    }

    private func scheduleReminders(after uvRefreshTask: Task<Void, Never>) {
        Task {
            await uvRefreshTask.value
            await reminderCoordinator.schedule(using: self)
        }
    }

    private func refreshStreakRiskReminder() {
        Task {
            await reminderCoordinator.refreshStreakRisk(using: self)
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

    private var timelinePresentation: SunclubTimelinePresentation {
        SunclubTimelinePresentation(
            referenceDate: referenceDate, calendar: calendar, selectedDay: selectedDay,
            records: records, scannedSPFLevels: growthSettings.scannedSPFLevels,
            reapplyIntervalMinutes: settings.reapplyIntervalMinutes,
            uvReading: uvReading, uvForecast: uvForecast, forecastBundle: uvIndexService.lastBundle
        )
    }

    var timelineShowsFutureDays: Bool { timelinePresentation.timelineShowsFutureDays }
    var timelineAllowsFutureSelection: Bool { timelinePresentation.timelineAllowsFutureSelection }
    var timelineBounds: TimelineBounds { timelinePresentation.timelineBounds }
    var timelineVisibleDays: [Date] { timelinePresentation.timelineVisibleDays }
    var timelineForecastUVLevels: [Date: UVLevel] { timelinePresentation.timelineForecastUVLevels }
    func timelineForecastUVLevel(for day: Date) -> UVLevel? { timelinePresentation.timelineForecastUVLevel(for: day) }
    func canSelectTimelineDay(_ day: Date) -> Bool { timelinePresentation.canSelectTimelineDay(day) }
    func timelineClampedDay(_ day: Date) -> Date { timelinePresentation.timelineClampedDay(day) }
    func timelineUVForecast(for day: Date) -> SunclubUVForecast? { timelinePresentation.timelineUVForecast(for: day) }

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
        SunclubStatusPresentation.cloudSyncStatusPresentation(
            pendingImportedBatchCount: pendingImportedBatchCount, status: syncPreference?.status ?? .idle,
            lastSyncAt: syncPreference?.lastSyncAt, lastSyncError: syncPreference?.lastSyncErrorDescription
        )
    }

    var recentImportSession: SunclubImportSession? {
        importSessions.first
    }

    @discardableResult
    func completeOnboarding() -> SunclubHistoryMutationResult {
        let today = startOfLocalDay(currentDate())
        do {
            let batch = try historyService.applySettingsChange(
                kind: .onboarding,
                summary: "Completed onboarding.",
                changedFields: [.hasCompletedOnboarding]
            ) { snapshot in
                snapshot.hasCompletedOnboarding = true
            }
            finishDurableChange(batch, reschedulesReminders: false)
            logActionErrorMessage = nil
            return .success(
                SunclubHistoryMutationReceipt(
                    batchID: batch?.id,
                    day: today,
                    verifiedAt: nil,
                    kind: .onboarding,
                    didChange: batch != nil
                )
            )
        } catch {
            return historyMutationFailure(error)
        }
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
            summary: "Updated the evening log reminder."
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
        let didChange = applyReminderSettingsChange(
            reminderSettings,
            summary: enabled
                ? "Enabled leave-home reminders."
                : "Disabled leave-home reminders."
        )

        if didChange, enabled {
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
                guard applyReminderSettingsChange(
                    reminderSettings,
                    summary: "Saved Home for leave-home reminders."
                ) else { return }
                leaveHomeReminderErrorMessage = nil
                refreshLeaveHomeReminderStatus(
                    allowPermissionPrompt: reminderSettings.leaveHomeReminder.isEnabled
                )
            } catch {
                leaveHomeReminderErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                reminderCoordinator.updateHomeAuthorization(homeExitReminderMonitor.authorizationState)
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

    func retryInitialICloudRestore() {
        recoveryCoordinator.initialRestoreState = .checking
        Task {
            await recoveryCoordinator.retry()
            refresh()
        }
    }

    func continueWithoutInitialICloudRestore() {
        recoveryCoordinator.initialRestoreState = .continuedLocally
    }

    @discardableResult
    func publishImportedChanges(
        for sessionID: UUID
    ) -> Task<Result<CloudPublishResult, SunclubHistoryMutationError>, Never> {
        Task {
            do {
                let result = try await recoveryCoordinator.publishImport(sessionID)
                refresh()
                logActionErrorMessage = nil
                return .success(result)
            } catch {
                refresh()
                let failure = error as? SunclubHistoryMutationError ?? .recoveryFailure(error.localizedDescription)
                _ = historyMutationFailure(failure)
                return .failure(failure)
            }
        }
    }

    @discardableResult
    func restoreImportedChanges(for sessionID: UUID) -> Result<SunclubChangeBatch, SunclubHistoryMutationError> {
        recoveryMutation {
            let current = growthFeatureStore.load()
            return try recoveryCoordinator.restoreImport(
                sessionID, currentPreferences: SunclubRestorablePreferences(growthSettings: current)
            )
        }
    }

    private func applyRestoredPreferences(_ preferences: SunclubRestorablePreferences?, to current: SunclubGrowthSettings) {
        let restored = preferences ?? SunclubRestorablePreferences(growthSettings: SunclubGrowthSettings(
            accountability: SunclubAccountabilitySettings(localProfileID: current.accountability.localProfileID)
        ))
        growthSettings = restored.replacingRestorableFields(in: current)
        growthFeatureStore.save(growthSettings)
        lastAppliedRestorablePreferences = preferences
    }

    @discardableResult
    func undoChange(_ batchID: UUID) -> Result<SunclubChangeBatch, SunclubHistoryMutationError> {
        if let sessionID = try? historyService.importSessionForUndo(batchID: batchID) {
            return restoreImportedChanges(for: sessionID)
        }
        return recoveryMutation {
            try recoveryCoordinator.undo(
                batchID, currentPreferences: SunclubRestorablePreferences(growthSettings: growthFeatureStore.load())
            )
        }
    }

    @discardableResult
    func redoChange(_ batchID: UUID) -> Result<SunclubChangeBatch, SunclubHistoryMutationError> {
        recoveryMutation {
            try recoveryCoordinator.redo(
                batchID, currentPreferences: SunclubRestorablePreferences(growthSettings: growthFeatureStore.load())
            )
        }
    }

    @discardableResult
    func undoChangeIfCurrent(batchID: UUID) -> Result<SunclubChangeBatch, SunclubHistoryMutationError> {
        recoveryMutation { try recoveryCoordinator.undoIfCurrent(batchID) }
    }

    func canUndoChangeIfCurrent(batchID: UUID) -> Bool {
        (try? recoveryCoordinator.canUndoIfCurrent(batchID)) == true
    }

    @discardableResult
    func undoConflict(_ conflictID: UUID) -> Result<SunclubChangeBatch, SunclubHistoryMutationError> {
        recoveryMutation { try recoveryCoordinator.undoConflict(conflictID) }
    }

    private func recoveryMutation(
        _ operation: () throws -> SunclubChangeBatch
    ) -> Result<SunclubChangeBatch, SunclubHistoryMutationError> {
        do {
            let previousPreferences = try historyService.settings().restorablePreferences
            let batch = try operation()
            if batch.scope == .timeline || batch.scope == .settings,
               try historyService.settingsRevision(forBatchID: batch.id) != nil {
                let preferences = try historyService.settings().restorablePreferences
                let restoresKnownPreferences = batch.scope == .settings && previousPreferences != nil
                    && preferences != nil && preferences != previousPreferences
                if batch.importSessionID != nil || restoresKnownPreferences {
                    // Apply known recovery snapshots before refresh can merge the undone value back.
                    // Import provenance alone does not make a history-only batch own preferences.
                    // Ordinary nil/pre-ledger recovery cannot establish ownership of local preferences.
                    applyRestoredPreferences(preferences, to: growthFeatureStore.load())
                }
            }
            finishDurableChange(batch, reschedulesReminders: true)
            logActionErrorMessage = nil
            return .success(batch)
        } catch {
            let failure: SunclubHistoryMutationError
            if let mutationError = error as? SunclubHistoryMutationError {
                failure = mutationError
            } else if let historyError = error as? HistoryServiceError {
                switch historyError {
                case .staleChange: failure = .staleChange
                default: failure = .recoveryFailure(historyError.localizedDescription)
                }
            } else {
                failure = .persistenceFailure
            }
            _ = historyMutationFailure(failure)
            return .failure(failure)
        }
    }

    @discardableResult
    func resolveConflict(_ conflictID: UUID) -> Result<Void, SunclubHistoryMutationError> {
        do {
            try recoveryCoordinator.resolveConflict(conflictID)
            refresh()
            logActionErrorMessage = nil
            return .success(())
        } catch {
            let failure = error as? SunclubHistoryMutationError ?? .persistenceFailure
            _ = historyMutationFailure(failure)
            return .failure(failure)
        }
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

    private var reminderPresentation: SunclubReminderPresentation {
        SunclubReminderPresentation(
            now: currentDate(), calendar: calendar, reminderSettings: settings.smartReminderSettings,
            reapplyReminderEnabled: settings.reapplyReminderEnabled,
            recordedDays: recordedDays, todayRecord: record(for: currentDate())?.projectionSnapshot
        )
    }

    var reminderDate: Date { reminderPresentation.reminderDate }
    func reminderDate(for kind: ReminderScheduleKind) -> Date { reminderPresentation.reminderDate(for: kind) }
    var nextDailyReminderPreview: DailyReminderPreview? { reminderPresentation.nextDailyReminderPreview }

    private var homePresentation: SunclubHomePresentation {
        SunclubHomePresentation(
            now: currentDate(), calendar: calendar,
            records: records.map { .init(startOfDay: $0.startOfDay, verifiedAt: $0.verifiedAt,
                                        spfLevel: $0.spfLevel, trimmedNotes: $0.trimmedNotes,
                                        reapplyCount: $0.reapplyCount) },
            reapplyReminderEnabled: settings.reapplyReminderEnabled,
            smartReminderSettings: settings.smartReminderSettings, reapplyReminderPlan: reapplyReminderPlan,
            uvReading: uvReading, uvForecast: uvForecast, pendingImportedBatchCount: pendingImportedBatchCount,
            conflictCount: conflicts.count, notificationHealthPresentation: notificationHealthPresentation,
            homeRecoveryActions: homeRecoveryActions
        )
    }

    var todayCardPresentation: HomeTodayCardPresentation { homePresentation.todayCardPresentation }
    var homeDailyPlanPresentation: HomeDailyPlanPresentation { homePresentation.homeDailyPlanPresentation }
    var syncRecoveryTitle: String { homePresentation.syncRecoveryTitle }
    var syncRecoveryDetail: String { homePresentation.syncRecoveryDetail }

    var reapplyReminderPlan: ReapplyReminderPlan {
        ReapplyReminderPlan(
            baseIntervalMinutes: settings.reapplyIntervalMinutes,
            uvReading: uvReading,
            now: currentDate(),
            calendar: calendar
        )
    }

    var homeRecoveryActions: [HomeRecoveryAction] { reminderPresentation.homeRecoveryActions }
    var reapplyCheckInPresentation: ReapplyCheckInPresentation? { reminderPresentation.reapplyCheckInPresentation }

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
        SunclubStatusPresentation.leaveHomeReminderStatusPresentation(
            reminderSettings: settings.smartReminderSettings, leaveHomeAuthorizationState: leaveHomeAuthorizationState,
            leaveHomeReminderErrorMessage: leaveHomeReminderErrorMessage
        )
    }

    var liveUVStatusPresentation: LiveUVStatusPresentation {
        SunclubStatusPresentation.liveUVStatusPresentation(
            uvStatus: uvStatus, uvReading: uvReading, uvForecast: uvForecast,
            canRefresh: settings.usesLiveUV || settings.selectedUVPlace != nil, liveUVAccessState: uvIndexService.liveUVAccessState
        )
    }

    var achievements: [SunclubAchievement] {
        SunclubGrowthAnalytics.achievements(
            records: records,
            changeBatches: changeBatches,
            settings: settings,
            growthSettings: growthSettings,
            historicalUVIndexes: historicalUVIndexes,
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
        accountabilityCoordinator.service.supportsDirectDelivery
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
        SunclubStatusPresentation.homeAccountabilityPresentation(
            hasCompletedOnboarding: settings.hasCompletedOnboarding, growthSettings: growthSettings,
            friends: friends, supportsDirectAccountabilityTransport: supportsDirectAccountabilityTransport
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
        accountabilityCoordinator.activate(displayName: displayName, growthSettings: &growthSettings)
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
            healthKitAuthorizationRequestID = nil
            guard growthSettings.healthKit.isEnabled else {
                return
            }
            growthSettings.healthKit.isEnabled = false
            persistGrowthSettings()
            return
        }

        let requestID = UUID()
        healthKitAuthorizationRequestID = requestID
        Task {
            let granted = await healthKitService.requestAuthorizationIfNeeded()
            guard healthKitAuthorizationRequestID == requestID else { return }
            let sampleCount: Int
            if granted {
                sampleCount = await healthKitService.recentUVSampleCount(
                    since: calendar.date(byAdding: .year, value: -1, to: currentDate()) ?? currentDate()
                )
            } else {
                sampleCount = 0
            }
            guard healthKitAuthorizationRequestID == requestID else { return }
            healthKitAuthorizationRequestID = nil
            growthSettings.healthKit.isEnabled = granted
            growthSettings.healthKit.importedSampleCount = sampleCount
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
        guard result.didChange != false else { return result }
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

    @discardableResult
    func refreshUVForecastIfNeeded(allowPermissionPrompt: Bool = false) -> Task<Void, Never> {
        let usesLiveUV = settings.usesLiveUV
        let refresh = uvCoordinator.refreshForecast(.init(
            usesLiveUV: usesLiveUV, selectedPlace: settings.selectedUVPlace,
            allowPermissionPrompt: allowPermissionPrompt
        ), acceptsResponse: { [weak self] in
            self?.settings.usesLiveUV == usesLiveUV
        })
        return Task {
            guard await refresh.value else { return }
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

        let importedSnapshot = accountabilityCoordinator.importInvite(envelope, growthSettings: &growthSettings)
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
        if !supportsDirectAccountabilityTransport {
            friendImportMessage = "Added \(importedSnapshot.name). Use Message when you want to send a reminder."
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
                try? await accountabilityCoordinator.service.sendInviteResponse(response)
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
                let profiles = try await accountabilityCoordinator.service.fetchProfiles(profileIDs: profileIDs)
                for profile in profiles {
                    applyAccountabilityProfile(profile)
                }
                persistGrowthSettings()
                syncWidgetSnapshot()
                reloadWidgetTimelines()
            } catch {
                friendImportMessage = "Activity sharing did not sync yet. You can still use Message."
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

        let envelope = accountabilityCoordinator.preparePoke(
            for: friend, connection: connection, displayName: resolvedAccountabilityDisplayName,
            growthSettings: &growthSettings
        )
        persistGrowthSettings()
        Task {
            let result = await accountabilityCoordinator.sendPoke(envelope, to: friend)
            recordPoke(result.poke)
            friendImportMessage = result.message
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
            let events = try await accountabilityCoordinator.service.fetchRemoteEvents(for: growthSettings.accountability.localProfileID)
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
            friendImportMessage = "Activity sharing did not sync yet."
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
        guard let notificationMessage = accountabilityCoordinator.acceptPoke(
            envelope, recipientHasLoggedToday: record(for: currentDate()) != nil, growthSettings: &growthSettings
        ) else { return nil }
        persistGrowthSettings()
        syncWidgetSnapshot()
        reloadWidgetTimelines()

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
                historicalUVIndexes: historicalUVIndexes,
                calendar: calendar
            ),
            preferredName: preferredDisplayName
        )
    }

    func skinHealthReportSummary(for interval: DateInterval) -> SunclubSkinHealthReportSummary {
        SunclubGrowthAnalytics.reportSummary(
            records: records,
            interval: interval,
            historicalUVIndexes: historicalUVIndexes,
            calendar: calendar
        )
    }

    var yearInReviewSummary: SunclubSkinHealthReportSummary? {
        let loggedDays = Set(records.map { calendar.startOfDay(for: $0.startOfDay) })
        guard loggedDays.count >= 30 else { return nil }

        let now = currentDate()
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        let interval = DateInterval(start: yearStart, end: now)
        return SunclubGrowthAnalytics.reportSummary(
            records: records,
            interval: interval,
            historicalUVIndexes: historicalUVIndexes,
            calendar: calendar
        )
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

    @discardableResult
    func recordApplication(
        for method: VerificationMethod,
        part: DayPart,
        on day: Date,
        source: LogSource,
        verifiedAt requestedTimestamp: Date? = nil,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) -> SunclubHistoryMutationResult {
        do {
            let request = try SunclubLogRequestResolver(calendar: calendar, now: currentDate()).application(
                method: method, part: part, day: day, source: source, timestamp: requestedTimestamp,
                duration: verificationDuration, spfLevel: spfLevel, notes: notes
            )
            let receipt = try upsertRecord(request)
            lastLogContext = AppLogContext(date: request.day, dayPart: part, source: source)
            logActionErrorMessage = nil
            return .success(receipt)
        } catch {
            return historyMutationFailure(error)
        }
    }

    @discardableResult
    func markAppliedToday(
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) -> SunclubHistoryMutationResult {
        let now = currentDate()
        return recordApplication(
            for: method,
            part: dayPart(for: now),
            on: now,
            source: .legacy,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes
        )
    }

    func oneTapLogInput(for day: Date) -> SunManualLogResolvedDefaults {
        let targetDay = startOfLocalDay(day)
        guard record(for: targetDay) == nil else {
            return .empty
        }

        return SunManualLogDefaultResolver.oneTapDefaults(
            from: records,
            excluding: targetDay,
            profileSPF: settings.sunscreenProfile?.spf,
            calendar: calendar
        )
    }

    @discardableResult
    func saveManualRecord(
        for day: Date,
        dayPart targetDayPart: DayPart? = nil,
        verifiedAt targetVerifiedAt: Date? = nil,
        spfLevel: Int?,
        notes: String?
    ) -> SunclubHistoryMutationResult {
        do {
            let existingRecord = record(for: day)
            let request = try SunclubLogRequestResolver(calendar: calendar, now: currentDate()).manualRecord(
                day: day, dayPart: targetDayPart, timestamp: targetVerifiedAt,
                existingTimestamp: existingRecord?.verifiedAt, spfLevel: spfLevel, notes: notes,
                existingMethod: existingRecord?.method
            )
            let receipt = try upsertRecord(request)
            lastLogContext = AppLogContext(date: request.day, dayPart: dayPart(for: request.verifiedAt), source: .history)
            logActionErrorMessage = nil
            return .success(receipt)
        } catch {
            return historyMutationFailure(error)
        }
    }

    @discardableResult
    func recordVerificationSuccess(
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil,
        verifiedAt: Date? = nil,
        context: AppLogContext? = nil
    ) -> SunclubHistoryMutationResult {
        let previousLongestStreak = settings.longestStreak
        let resolvedContext = context ?? currentLogContext(for: selectedDay, source: .manualLog)
        let mutationResult = recordApplication(
            for: method,
            part: resolvedContext.dayPart,
            on: resolvedContext.date,
            source: resolvedContext.source,
            verifiedAt: verifiedAt,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes
        )
        guard case let .success(receipt) = mutationResult, receipt.didChange else {
            return mutationResult
        }
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
        return mutationResult
    }

    func recordWatchSunscreenLog() throws -> SunclubWidgetSnapshot {
        guard settings.hasCompletedOnboarding else {
            throw SunclubQuickLogError.onboardingRequired
        }

        let now = currentDate()
        let input = oneTapLogInput(for: now)
        let result = recordApplication(
            for: .quickLog,
            part: dayPart(for: now),
            on: now,
            source: .watch,
            spfLevel: input.spfLevel,
            notes: input.oneTapNotes
        )
        if case let .failure(error) = result {
            throw error
        }
        if case let .success(receipt) = result, receipt.didChange, settings.reapplyReminderEnabled {
            scheduleReapplyReminder()
        }
        return widgetSnapshotStore.load()
    }

    func recordWatchReapplication() throws -> SunclubWidgetSnapshot {
        guard settings.hasCompletedOnboarding else {
            throw SunclubQuickLogError.onboardingRequired
        }

        let result = recordReapplication()
        if case let .failure(error) = result {
            throw error
        }
        return widgetSnapshotStore.load()
    }

    func clearVerificationSuccessPresentation() {
        verificationSuccessPresentation = nil
    }

    @discardableResult
    func deleteRecord(for day: Date) -> SunclubHistoryMutationResult {
        let target = calendar.startOfDay(for: day)
        do {
            let batch = try historyService.applyDayChange(
                for: target,
                kind: .deleteRecord,
                summary: "Deleted \(target.formatted(.dateTime.month().day())).",
                changedFields: [.isDeleted]
            ) { existingSnapshot in
                guard existingSnapshot != nil else {
                    return existingSnapshot
                }
                return nil
            }
            finishDurableChange(batch, reschedulesReminders: false)

            if batch != nil, calendar.isDate(target, inSameDayAs: currentDate()), record(for: target) == nil {
                cancelReapplyRemindersIfNeeded()
            }
            logActionErrorMessage = nil
            return .success(
                SunclubHistoryMutationReceipt(
                    batchID: batch?.id,
                    day: target,
                    verifiedAt: nil,
                    kind: .deleteRecord,
                    didChange: batch != nil
                )
            )
        } catch {
            return historyMutationFailure(error)
        }
    }

    @discardableResult
    func deleteAllHistory() -> SunclubHistoryMutationResult {
        let today = startOfLocalDay(currentDate())
        let includedToday = record(for: today) != nil

        do {
            let batch = try historyService.deleteAllRecords()
            finishDurableChange(batch, reschedulesReminders: false)

            if includedToday, record(for: today) == nil {
                cancelReapplyRemindersIfNeeded()
            }
            logActionErrorMessage = nil
            return .success(
                SunclubHistoryMutationReceipt(
                    batchID: batch?.id,
                    day: today,
                    verifiedAt: nil,
                    kind: .deleteRecord,
                    didChange: batch != nil
                )
            )
        } catch {
            return historyMutationFailure(error)
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

    func snoozeReapplyReminder(minutes: Int = 15) async -> NotificationOperationResult {
        guard settings.reapplyReminderEnabled else {
            return .failure("Reapply reminders are off. Turn them on in Settings, then try again.")
        }
        let plan = ReapplyReminderPlan(snoozeMinutes: minutes, now: currentDate(), calendar: calendar)
        return await notificationManager.scheduleReapplyReminder(
            plan: plan,
            route: preferredCheckInRoute
        )
    }

    func updateReapplySettings(enabled: Bool, intervalMinutes: Int) {
        let clampedIntervalMinutes = max(30, min(480, intervalMinutes))
        guard settings.reapplyReminderEnabled != enabled
                || settings.reapplyIntervalMinutes != clampedIntervalMinutes else {
            return
        }

        let batch = try? mutationService.updateReapply(
            enabled: enabled, intervalMinutes: clampedIntervalMinutes, summary: "Updated the reapply reminder."
        )
        guard batch != nil else { return }
        finishDurableChange(batch, reschedulesReminders: false)

        if !enabled {
            cancelReapplyRemindersIfNeeded()
        }
    }

    @discardableResult
    func recordReapplication(for day: Date? = nil, performedAt: Date? = nil) -> SunclubHistoryMutationResult {
        let now = performedAt ?? currentDate()
        let targetDay = startOfLocalDay(day ?? now)
        guard validatedLogDate(targetDay) != nil else {
            return .failure(.futureDate)
        }
        guard now <= currentDate() else {
            logActionErrorMessage = SunclubHistoryMutationError.futureTime.localizedDescription
            return .failure(.futureTime)
        }
        guard record(for: targetDay) != nil else {
            logActionErrorMessage = SunclubHistoryMutationError.missingRecord.localizedDescription
            return .failure(.missingRecord)
        }
        do {
            let batch = try mutationService.reapply(
                on: targetDay, at: now, summary: "Logged a reapply check-in."
            )
            guard let batch else {
                logActionErrorMessage = SunclubHistoryMutationError.missingRecord.localizedDescription
                return .failure(.missingRecord)
            }
            finishDurableChange(batch, reschedulesReminders: false)

            if calendar.isDate(targetDay, inSameDayAs: currentDate()) {
                if settings.reapplyReminderEnabled {
                    scheduleReapplyReminder()
                } else {
                    cancelReapplyRemindersIfNeeded()
                }
            }
            logActionErrorMessage = nil
            return .success(
                SunclubHistoryMutationReceipt(
                    batchID: batch.id,
                    day: targetDay,
                    verifiedAt: now,
                    kind: .reapply,
                    didChange: true
                )
            )
        } catch {
            return historyMutationFailure(error)
        }
    }

    @discardableResult
    func updateLiveUVPreference(enabled: Bool, allowPermissionPrompt: Bool = true) -> Bool {
        guard settings.usesLiveUV != enabled else {
            return true
        }

        do {
            let batch = try historyService.applySettingsChange(
                kind: .liveUVSettings,
                summary: "Updated the live UV preference.",
                changedFields: [.usesLiveUV]
            ) { snapshot in
                snapshot.usesLiveUV = enabled
            }
            finishDurableChange(
                batch,
                reschedulesReminders: false,
                refreshesUVForecast: false
            )
            logActionErrorMessage = nil
            refreshWeatherKitKillSwitchIfNeeded()
            let uvRefreshTask = refreshUVForecastIfNeeded(allowPermissionPrompt: allowPermissionPrompt)
            scheduleReminders(after: uvRefreshTask)
            return true
        } catch {
            _ = historyMutationFailure(error)
            return false
        }
    }

    @discardableResult
    func updateSelectedUVPlace(_ place: SunclubSelectedUVPlace?) -> Bool {
        guard settings.selectedUVPlace != place || (place != nil && settings.usesLiveUV) else {
            return true
        }

        do {
            var changedFields: Set<SunclubTrackedField> = [.selectedUVPlace]
            if place != nil, settings.usesLiveUV {
                changedFields.insert(.usesLiveUV)
            }
            let batch = try historyService.applySettingsChange(
                kind: .liveUVSettings,
                summary: place.map { "Selected \($0.displayName) for UV updates." } ?? "Removed the selected UV city.",
                changedFields: changedFields
            ) { snapshot in
                snapshot.selectedUVPlace = place
                if place != nil {
                    snapshot.usesLiveUV = false
                }
            }
            finishDurableChange(
                batch,
                reschedulesReminders: false,
                refreshesUVForecast: false
            )
            logActionErrorMessage = nil
            let uvRefreshTask = refreshUVForecastIfNeeded()
            scheduleReminders(after: uvRefreshTask)
            return true
        } catch {
            _ = historyMutationFailure(error)
            return false
        }
    }

    @discardableResult
    func updateSunscreenProfile(_ profile: SunclubSunscreenProfile?) -> Bool {
        guard settings.sunscreenProfile != profile else {
            return true
        }

        do {
            let batch = try historyService.applySettingsChange(
                kind: .manualLog,
                summary: profile.map { "Saved sunscreen profile \($0.name)." } ?? "Removed the saved sunscreen profile.",
                changedFields: [.sunscreenProfile]
            ) { snapshot in
                snapshot.sunscreenProfile = profile
            }
            finishDurableChange(batch, reschedulesReminders: false)
            logActionErrorMessage = nil
            return true
        } catch {
            _ = historyMutationFailure(error)
            return false
        }
    }

    func performLiveUVAction(_ action: LiveUVActionKind) {
        switch action {
        case .requestPermission:
            refreshWeatherKitKillSwitchIfNeeded()
            refreshUVForecastIfNeeded(allowPermissionPrompt: true)
        case .openSettings:
            break
        case .refresh:
            refreshWeatherKitKillSwitchIfNeeded()
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
        try recoveryCoordinator.exportDocument(
            preferences: SunclubRestorablePreferences(growthSettings: growthSettings)
        )
    }

    @discardableResult
    func exportBackup(to url: URL) throws -> SunclubBackupDocument {
        try recoveryCoordinator.export(
            to: url,
            preferences: SunclubRestorablePreferences(growthSettings: growthSettings)
        )
    }

    @discardableResult
    func importBackupDocument(_ document: SunclubBackupDocument) throws -> SunclubBackupImportSummary {
        let summary = try recoveryCoordinator.importDocument(
            document, currentPreferences: SunclubRestorablePreferences(growthSettings: growthFeatureStore.load())
        )
        finalizeImportedBackup(importedBatchCount: summary.importedBatchCount)
        return summary
    }

    @discardableResult
    func importBackup(from url: URL) throws -> SunclubBackupImportSummary {
        let summary = try recoveryCoordinator.importDocument(
            from: url, currentPreferences: SunclubRestorablePreferences(growthSettings: growthFeatureStore.load())
        )
        finalizeImportedBackup(importedBatchCount: summary.importedBatchCount)
        return summary
    }

    func record(for day: Date) -> DailyRecord? {
        let target = startOfLocalDay(day)
        if let projectedRecord = records.first(where: { calendar.isDate($0.startOfDay, inSameDayAs: target) }) {
            return projectedRecord
        }

        return (try? verificationStore.record(for: target)).flatMap { $0 }
    }

    func startOfLocalDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func canLog(on day: Date) -> Bool {
        startOfLocalDay(day) <= startOfLocalDay(referenceDate)
    }

    func validatedLogDate(_ day: Date) -> Date? {
        let target = startOfLocalDay(day)
        guard canLog(on: target) else {
            logActionErrorMessage = "Cannot log future date."
            return nil
        }
        logActionErrorMessage = nil
        return target
    }

    func dayPart(for date: Date) -> DayPart {
        DayPart.resolve(for: date, calendar: calendar)
    }

    func currentLogContext(
        for day: Date? = nil, source: LogSource = .manualLog, dayPart: DayPart? = nil
    ) -> AppLogContext {
        timelinePresentation.currentLogContext(for: day, source: source, dayPart: dayPart)
    }

    func prepareManualLogRouteContext(
        targetDate: Date? = nil,
        targetDayPart: DayPart? = nil,
        source: LogSource = .manualLog
    ) {
        pendingManualLogContext = currentLogContext(
            for: targetDate ?? selectedDay,
            source: source,
            dayPart: targetDayPart
        )
    }

    func consumeManualLogRouteContext() -> AppLogContext {
        defer { pendingManualLogContext = nil }
        if let pendingManualLogContext {
            return pendingManualLogContext
        }
        return currentLogContext(for: selectedDay, source: .manualLog)
    }

    func clearLogActionError() {
        logActionErrorMessage = nil
    }

    func advanceSelectedDayIfStale() {
        let bounds = timelineBounds
        let normalized = bounds.clamp(selectedDay, calendar: calendar)
        if normalized != selectedDay {
            selectedDay = normalized
        }
    }

    func selectDay(_ day: Date) {
        selectTimelineDay(day)
    }

    func selectTimelineDay(_ day: Date) {
        selectedDay = timelineClampedDay(day)
    }

    private func normalizeSelectedDayIfNeeded() {
        guard !isNormalizingSelectedDay else {
            return
        }

        let normalized = timelineBounds.clamp(selectedDay, calendar: calendar)
        guard normalized != selectedDay else {
            return
        }

        isNormalizingSelectedDay = true
        selectedDay = normalized
        isNormalizingSelectedDay = false
    }

    func futureDayPreview(for day: Date) -> FutureDayPreview? { timelinePresentation.futureDayPreview(for: day) }
    func timelineDayLogSummary(for day: Date) -> TimelineDayLogSummary { timelinePresentation.timelineDayLogSummary(for: day) }

    func refreshUVReadingIfNeeded(allowPermissionPrompt: Bool = false) {
        let input = SunclubUVCoordinator.Input(
            usesLiveUV: settings.usesLiveUV, selectedPlace: settings.selectedUVPlace,
            allowPermissionPrompt: allowPermissionPrompt
        )
        Task {
            guard await uvCoordinator.refreshReading(input) else { return }
            syncWidgetSnapshot()
            reloadWidgetTimelines()
            await liveActivityCoordinator.sync(using: self)
        }
    }

    func setUVReadingForTesting(_ reading: UVReading?) {
        uvCoordinator.overrideReading(reading)
    }

    func setUVForecastForTesting(_ forecast: SunclubUVForecast?) {
        uvCoordinator.forecast = forecast
    }

    func refreshNotificationHealth() {
        Task { await reminderCoordinator.refreshHealth(using: self) }
    }

    func setNotificationHealthSnapshotForTesting(_ snapshot: NotificationHealthSnapshot?) {
        reminderCoordinator.overrideHealth(snapshot)
    }

    func refreshLeaveHomeReminderStatus(allowPermissionPrompt: Bool = false) {
        Task {
            await reminderCoordinator.refreshHomeAuthorization(using: self, allowPermissionPrompt: allowPermissionPrompt)
        }
    }

    func setLeaveHomeAuthorizationStateForTesting(_ state: LeaveHomeAuthorizationState?) {
        reminderCoordinator.overrideHomeAuthorization(state)
    }

    func repairReminderSchedule() {
        Task { await reminderCoordinator.authorizeAndSchedule(using: self, scheduleWhenDenied: true) }
    }

    func requestNotificationAuthorizationAndSchedule() {
        Task { await reminderCoordinator.authorizeAndSchedule(using: self, scheduleWhenDenied: false) }
    }

    func dayStatus(for date: Date, now: Date? = nil) -> DayStatus {
        let set = Set(records.map { startOfLocalDay($0.startOfDay) })
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
            excluding: startOfLocalDay(day),
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
        records.map { startOfLocalDay($0.startOfDay) }
    }

    var daysWithExtras: Set<Date> { timelinePresentation.daysWithExtras }
    var dailyDetailsForTimeline: [Date: SunDayDetails] { timelinePresentation.dailyDetailsForTimeline }
    var elevatedUVDays: Set<Date> { timelinePresentation.elevatedUVDays }
    var dailyUVForecast: [SunclubUVDayForecast] { timelinePresentation.dailyUVForecast }

    var weatherAttribution: SunclubWeatherAttribution? {
        uvIndexService.attribution
    }

    func shouldSuppressDailyReminder(on day: Date) -> Bool {
        homeExitReminderMonitor.hasTriggeredReminder(on: day)
    }

    @discardableResult
    private func applyReminderSettingsChange(
        _ reminderSettings: SmartReminderSettings,
        summary: String
    ) -> Bool {
        let batch = try? mutationService.updateReminder(reminderSettings, summary: summary)
        guard batch != nil else { return false }
        finishDurableChange(batch, reschedulesReminders: true)
        refreshLeaveHomeReminderStatus()
        return true
    }

    private func upsertRecord(_ request: SunclubMutationService.RecordRequest) throws -> SunclubHistoryMutationReceipt {
        let result = try mutationService.upsert(request)
        let targetDay = result.day
        let batch = result.batch
        finishDurableChange(batch, reschedulesReminders: false)
        if batch != nil {
            exportHealthKitLogIfNeeded(for: targetDay)
            recordHistoricalUVIfApplicable(for: targetDay)
        }
        return SunclubHistoryMutationReceipt(
            batchID: batch?.id,
            day: targetDay,
            verifiedAt: request.verifiedAt,
            kind: request.kind,
            didChange: batch != nil
        )
    }

    private func recordHistoricalUVIfApplicable(for day: Date) {
        guard calendar.isDate(startOfLocalDay(day), inSameDayAs: startOfLocalDay(referenceDate)) else {
            return
        }
        guard let reading = uvReading, reading.source == .weatherKit else {
            return
        }
        historicalUVStore.record(uvIndex: reading.index, for: day)
    }

    var historicalUVIndexes: [Date: Int] {
        historicalUVStore.allEntries()
    }

    func refreshWeatherKitKillSwitchIfNeeded() {
        weatherKitKillSwitch?.refreshIfStale()
    }

    private func finishDurableChange(
        _ batch: SunclubChangeBatch?,
        reschedulesReminders: Bool,
        refreshesUVForecast: Bool = true
    ) {
        mutationService.followThrough(batch) { batch in
            refresh()
            syncAchievementCelebration()
            if refreshesUVForecast {
                refreshUVForecastIfNeeded()
            }
            publishAccountabilityProfileIfNeeded()
            Task {
                await liveActivityCoordinator.sync(using: self)
            }

            if reschedulesReminders {
                scheduleReminders()
            }

            refreshStreakRiskReminder()

            reloadWidgetTimelines()

            Task {
                await cloudSyncCoordinator.queueBatchIfNeeded(batch.id)
            }
        }
    }

    private func historyMutationFailure(_ underlyingError: Error) -> SunclubHistoryMutationResult {
        if let validationError = underlyingError as? SunclubHistoryMutationError {
            logActionErrorMessage = validationError.localizedDescription
            return .failure(validationError)
        }
        Self.logger.error("Durable history mutation failed: \(String(describing: underlyingError), privacy: .public)")
        let error = SunclubHistoryMutationError.persistenceFailure
        logActionErrorMessage = error.localizedDescription
        return .failure(error)
    }

    private func persistGrowthSettings() {
        growthFeatureStore.save(growthSettings)
        syncRestorablePreferencesRevisionIfNeeded()
    }

    private func applyRestorablePreferencesFromSettingsIfNeeded() {
        guard let preferences = settings.restorablePreferences,
              preferences != lastAppliedRestorablePreferences else {
            return
        }
        let previousUVBriefing = growthSettings.uvBriefing
        growthSettings = preferences.merging(into: growthSettings)
        growthFeatureStore.save(growthSettings)
        lastAppliedRestorablePreferences = preferences
        if growthSettings.uvBriefing != previousUVBriefing {
            scheduleReminders()
        }
    }

    private func syncRestorablePreferencesRevisionIfNeeded() {
        let preferences = SunclubRestorablePreferences(growthSettings: growthSettings)
        guard settings.restorablePreferences != preferences else {
            lastAppliedRestorablePreferences = preferences
            return
        }
        guard preferences.hasMeaningfulContent || settings.restorablePreferences != nil else {
            return
        }

        do {
            let batch = try historyService.applySettingsChange(
                kind: .preferenceSettings,
                summary: "Updated private restorable preferences.",
                changedFields: [.restorablePreferences]
            ) { snapshot in
                snapshot.restorablePreferences = preferences
            }
            lastAppliedRestorablePreferences = preferences
            finishDurableChange(batch, reschedulesReminders: false)
        } catch {
            _ = historyMutationFailure(error)
        }
    }

    private var resolvedAccountabilityDisplayName: String {
        accountabilityCoordinator.displayName(growthSettings: growthSettings)
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
        accountabilityCoordinator.upsertFriendSnapshot(snapshot, growthSettings: &growthSettings)
    }

    private func upsertConnection(_ connection: SunclubFriendConnection) {
        accountabilityCoordinator.upsertConnection(connection, growthSettings: &growthSettings)
    }

    private func updateConnection(_ id: UUID, update: (inout SunclubFriendConnection) -> Void) {
        accountabilityCoordinator.updateConnection(id, growthSettings: &growthSettings, update: update)
    }

    private func isValidRelationshipToken(_ token: String, for connection: SunclubFriendConnection) -> Bool {
        accountabilityCoordinator.isValidRelationshipToken(token, for: connection, growthSettings: growthSettings)
    }

    private func applyAccountabilityProfile(_ profile: SunclubAccountabilityProfile) {
        accountabilityCoordinator.applyAccountabilityProfile(profile, growthSettings: &growthSettings)
    }

    private func recordPoke(_ poke: SunclubAccountabilityPoke) {
        accountabilityCoordinator.recordPoke(poke, growthSettings: &growthSettings)
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
            try? await accountabilityCoordinator.service.publishProfile(profile)
            if growthSettings.accountability.subscriptionInstallVersion < Self.accountabilitySubscriptionInstallVersion {
                do {
                    try await accountabilityCoordinator.service.installSubscriptions(for: growthSettings.accountability.localProfileID)
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
