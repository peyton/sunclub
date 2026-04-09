import Foundation
import Observation
import os
import SwiftData
import WidgetKit

struct HomeTodayCardPresentation: Equatable {
    let title: String
    let detail: String
    let uvHeadline: String?
    let uvSymbolName: String?
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

struct ReapplyReminderPlan: Equatable {
    let baseIntervalMinutes: Int
    let intervalMinutes: Int
    let notificationTitle: String
    let notificationBody: String
    let confirmationText: String
    let confirmationSymbolName: String
    let fireDate: Date?
    let isElevated: Bool

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

    init(streak: Int, isPersonalBest: Bool = false) {
        self.streak = streak
        self.isPersonalBest = isPersonalBest
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

@MainActor
@Observable
final class AppState {
    private typealias VerificationValues = (
        method: VerificationMethod,
        duration: Double?,
        spfLevel: Int?,
        notes: String?
    )

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

    private(set) var lastRefreshError: String?

    private static let logger = Logger(subsystem: "com.sunclub", category: "AppState")
    private let calendar = Calendar.current
    private var uvReadingOverride: UVReading?
    private var notificationHealthOverride: NotificationHealthSnapshot?
    private var leaveHomeAuthorizationOverride: LeaveHomeAuthorizationState?

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
        historyService: SunclubHistoryService? = nil,
        cloudSyncCoordinator: CloudSyncControlling? = nil,
        widgetSnapshotStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
        growthFeatureStore: SunclubGrowthFeatureStoring = SunclubGrowthFeatureStore.shared,
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
        try? resolvedHistoryService.bootstrapIfNeeded()
        self.widgetSnapshotStore = widgetSnapshotStore
        if runtimeEnvironment.isRunningTests {
            self.growthFeatureStore = SunclubGrowthFeatureStore(
                userDefaults: UserDefaults(suiteName: UUID().uuidString)
            )
        } else {
            self.growthFeatureStore = growthFeatureStore
        }
        currentDate = clock
        settings = (try? resolvedHistoryService.settings()) ?? Self.loadOrCreateSettings(from: context)
        growthSettings = self.growthFeatureStore.load()
        if let cloudSyncCoordinator {
            self.cloudSyncCoordinator = cloudSyncCoordinator
        } else {
            self.cloudSyncCoordinator = Self.defaultCloudSyncCoordinator(
                historyService: resolvedHistoryService,
                runtimeEnvironment: runtimeEnvironment
            )
        }
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
                await self.cloudSyncCoordinator.start()
                self.refresh()
            }
        }
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

    func updateDailyReminder(hour: Int, minute: Int) {
        var reminderSettings = settings.smartReminderSettings
        let reminderTime = ReminderTime(hour: hour, minute: minute)
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
        reminderSettings.streakRiskEnabled = enabled
        applyReminderSettingsChange(
            reminderSettings,
            summary: "Updated the streak-risk reminder."
        )
    }

    func updateLeaveHomeReminderEnabled(enabled: Bool, allowPermissionPrompt: Bool = true) {
        var reminderSettings = settings.smartReminderSettings
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

    var reminderDate: Date {
        reminderDate(for: ReminderPlanner.scheduleKind(for: Date(), calendar: calendar))
    }

    func reminderDate(for kind: ReminderScheduleKind) -> Date {
        let reminderTime = settings.smartReminderSettings.time(for: kind)
        let today = calendar.startOfDay(for: Date())
        return calendar.date(
            bySettingHour: reminderTime.hour,
            minute: reminderTime.minute,
            second: 0,
            of: today
        ) ?? today
    }

    var todayCardPresentation: HomeTodayCardPresentation {
        let hasLoggedToday = record(for: Date()) != nil
        let title = hasLoggedToday ? "Today's log is in" : "Ready for today's log"
        let defaultDetail = hasLoggedToday
            ? "Update today's SPF or note any time."
            : "One quick check-in keeps the streak steady."

        guard let level = uvReading?.level,
              let uvHeadline = level.homeHeadline else {
            return HomeTodayCardPresentation(
                title: title,
                detail: defaultDetail,
                uvHeadline: nil,
                uvSymbolName: nil
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
            uvHeadline: uvHeadline,
            uvSymbolName: level.symbolName
        )
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

        if record(for: Date()) == nil {
            actions.append(
                HomeRecoveryAction(
                    kind: .logToday,
                    title: "Today is open",
                    detail: "Log now before the day gets away.",
                    buttonTitle: "Log Today"
                )
            )
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        if record(for: yesterday) == nil {
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
              let todayRecord = record(for: Date()) else {
            return nil
        }

        if todayRecord.reapplyCount > 0 {
            let detail: String
            if let lastReappliedAt = todayRecord.lastReappliedAt {
                detail = "Checked in \(todayRecord.reapplyCount) \(todayRecord.reapplyCount == 1 ? "time" : "times") today. Last one at \(lastReappliedAt.formatted(date: .omitted, time: .shortened))."
            } else {
                detail = "Checked in \(todayRecord.reapplyCount) \(todayRecord.reapplyCount == 1 ? "time" : "times") today."
            }

            return ReapplyCheckInPresentation(
                title: "Reapply",
                detail: detail,
                actionTitle: "Log Another Reapply"
            )
        }

        return ReapplyCheckInPresentation(
            title: "Reapply",
            detail: "Use this whenever you reapply so today's reminders stay in step.",
            actionTitle: "Log Reapply"
        )
    }

    var reminderCoachingSuggestions: [ReminderCoachingSuggestion] {
        ReminderCoachingEngine.suggestions(
            from: records,
            settings: settings.smartReminderSettings,
            now: Date(),
            calendar: calendar
        )
    }

    var notificationHealthPresentation: NotificationHealthPresentation? {
        NotificationHealthEvaluator.presentation(
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
        guard settings.usesLiveUV else {
            return LiveUVStatusPresentation(
                title: "Estimated UV",
                detail: "Using Sunclub's built-in UV estimate.",
                actionTitle: nil,
                actionKind: nil
            )
        }

        switch uvIndexService.liveUVAccessState {
        case .live:
            return LiveUVStatusPresentation(
                title: "Live UV is on",
                detail: uvReading?.source.statusLabel ?? "Using live WeatherKit UV for the current reading.",
                actionTitle: nil,
                actionKind: nil
            )
        case .needsPermission:
            return LiveUVStatusPresentation(
                title: "Location permission needed",
                detail: "Turn on location access to use live UV. Sunclub will use an estimate until then.",
                actionTitle: "Allow Location",
                actionKind: .requestPermission
            )
        case .denied:
            return LiveUVStatusPresentation(
                title: "Location access is off",
                detail: "Open Settings to turn location access back on for live UV.",
                actionTitle: "Open Settings",
                actionKind: .openSettings
            )
        case .unavailable:
            return LiveUVStatusPresentation(
                title: "Using estimated UV",
                detail: "Live UV wasn't available, so Sunclub fell back to its estimate.",
                actionTitle: "Try Again",
                actionKind: .refresh
            )
        case .disabled:
            return LiveUVStatusPresentation(
                title: "Estimated UV",
                detail: "Using Sunclub's built-in UV estimate.",
                actionTitle: nil,
                actionKind: nil
            )
        }
    }

    var achievements: [SunclubAchievement] {
        SunclubGrowthAnalytics.achievements(
            records: records,
            changeBatches: changeBatches,
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
                return lhs.hasLoggedToday && !rhs.hasLoggedToday
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
        persistGrowthSettings()
    }

    func updateHealthKitEnabled(_ enabled: Bool) {
        if !enabled {
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
        if let dailyBriefingEnabled {
            growthSettings.uvBriefing.dailyBriefingEnabled = dailyBriefingEnabled
        }
        if let extremeAlertEnabled {
            growthSettings.uvBriefing.extremeAlertEnabled = extremeAlertEnabled
        }
        persistGrowthSettings()
        scheduleReminders()
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

    func setManualLogPrefill(spfLevel: Int?, notes: String) {
        manualLogPrefill = ManualLogPrefill(spfLevel: spfLevel, notes: notes)
    }

    func clearManualLogPrefill() {
        manualLogPrefill = nil
    }

    func friendShareCode() throws -> String {
        try SunclubFriendCodeCodec.encode(localFriendSnapshot)
    }

    func importFriendCode(_ code: String) throws {
        let importedSnapshot = try SunclubFriendCodeCodec.decode(code)
        if let existingIndex = growthSettings.friends.firstIndex(where: { $0.id == importedSnapshot.id || $0.name == importedSnapshot.name }) {
            growthSettings.friends[existingIndex] = importedSnapshot
        } else {
            growthSettings.friends.append(importedSnapshot)
        }
        persistGrowthSettings()
        friendImportMessage = importedSnapshot.hasLoggedToday && record(for: currentDate()) == nil
            ? "\(importedSnapshot.name) logged today. Have you?"
            : "Imported \(importedSnapshot.name)."
    }

    func removeFriend(_ id: UUID) {
        growthSettings.friends.removeAll { $0.id == id }
        persistGrowthSettings()
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
        let now = Date()
        upsertRecord(
            for: now,
            verifiedAt: now,
            verificationValues: (method, verificationDuration, spfLevel, notes),
            replaceOptionalFields: false,
            preserveExistingDuration: false,
            kind: .manualLog,
            summary: "Logged sunscreen for today."
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
            for: day,
            verifiedAt: timestamp,
            verificationValues: (.manual, nil, spfLevel, notes),
            replaceOptionalFields: true,
            preserveExistingDuration: true,
            kind: kind,
            summary: summary
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
        verificationSuccessPresentation = VerificationSuccessPresentation(
            streak: currentStreak,
            isPersonalBest: currentStreak > previousLongestStreak
        )
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
        if calendar.isDateInToday(target), record(for: target) == nil {
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
        let batch = try? historyService.applySettingsChange(
            kind: .reapplySettings,
            summary: "Updated the reapply reminder.",
            changedFields: [.reapplyReminderEnabled, .reapplyIntervalMinutes]
        ) { snapshot in
            snapshot.reapplyReminderEnabled = enabled
            snapshot.reapplyIntervalMinutes = max(30, min(480, intervalMinutes))
        }
        finishDurableChange(batch, reschedulesReminders: false)

        if !enabled {
            cancelReapplyRemindersIfNeeded()
        }
    }

    func recordReapplication(for day: Date = Date(), performedAt: Date? = nil) {
        let now = performedAt ?? Date()
        let batch = try? historyService.applyDayChange(
            for: day,
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

        if calendar.isDateInToday(day) {
            cancelReapplyRemindersIfNeeded()
        }
    }

    func updateLiveUVPreference(enabled: Bool, allowPermissionPrompt: Bool = true) {
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
        (try? verificationStore.record(for: day)).flatMap { $0 }
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

    func dayStatus(for date: Date, now: Date = Date()) -> DayStatus {
        let set = Set(records.map { calendar.startOfDay(for: $0.startOfDay) })
        return CalendarAnalytics.status(for: date, with: set, now: now, calendar: calendar)
    }

    func monthGrid(for month: Date) -> [Date] {
        CalendarAnalytics.monthGridDays(for: month, calendar: calendar)
    }

    func isCurrentMonth(_ date: Date, month: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    var currentStreak: Int {
        CalendarAnalytics.currentStreak(records: recordedDays, now: Date(), calendar: calendar)
    }

    func last7DaysReport() -> WeeklyReport {
        CalendarAnalytics.weeklyReport(records: records.map(\.startOfDay), now: Date(), calendar: calendar)
    }

    func sunscreenUsageInsights(recentNotesLimit: Int = 3) -> SunscreenUsageInsights {
        SunscreenUsageAnalytics.insights(from: records, recentNotesLimit: recentNotesLimit)
    }

    func manualLogSuggestionState(for day: Date) -> ManualLogSuggestionState {
        ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: day,
            calendar: calendar
        )
    }

    func monthlyReviewInsights(for month: Date) -> MonthlyReviewInsights {
        MonthlyReviewAnalytics.insights(
            from: records,
            month: month,
            now: Date(),
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

    private func upsertRecord(
        for day: Date,
        verifiedAt: Date,
        verificationValues: VerificationValues,
        replaceOptionalFields: Bool,
        preserveExistingDuration: Bool,
        kind: SunclubChangeKind,
        summary: String
    ) {
        let batch = try? historyService.applyDayChange(
            for: day,
            kind: kind,
            summary: summary,
            changedFields: [.verifiedAt, .methodRawValue, .verificationDuration, .spfLevel, .notes]
        ) { existingSnapshot in
            let normalizedNotes = Self.normalizedNotes(verificationValues.notes)
            if var snapshot = existingSnapshot {
                snapshot.verifiedAt = verifiedAt
                snapshot.methodRawValue = verificationValues.method.rawValue
                snapshot.verificationDuration = preserveExistingDuration
                    ? (verificationValues.duration ?? snapshot.verificationDuration)
                    : verificationValues.duration

                if replaceOptionalFields {
                    snapshot.spfLevel = verificationValues.spfLevel
                    snapshot.notes = normalizedNotes
                } else {
                    if let spfLevel = verificationValues.spfLevel {
                        snapshot.spfLevel = spfLevel
                    }
                    if let normalizedNotes {
                        snapshot.notes = normalizedNotes
                    }
                }
                return snapshot
            }

            return DailyRecordProjectionSnapshot(
                startOfDay: self.calendar.startOfDay(for: day),
                verifiedAt: verifiedAt,
                methodRawValue: verificationValues.method.rawValue,
                verificationDuration: verificationValues.duration,
                spfLevel: verificationValues.spfLevel,
                notes: normalizedNotes,
                reapplyCount: 0,
                lastReappliedAt: nil
            )
        }
        finishDurableChange(batch, reschedulesReminders: false)
        exportHealthKitLogIfNeeded(for: day)
    }

    private func defaultVerifiedAt(for day: Date) -> Date {
        let targetDay = calendar.startOfDay(for: day)
        let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
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
        guard let notes else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
            uvReading: uvReading,
            uvForecast: uvForecast,
            now: Date(),
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
