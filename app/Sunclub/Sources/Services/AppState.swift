import Foundation
import Observation
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
        streak == 1 ? "You're on a 1-day streak." : "You're on a \(streak)-day streak."
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
    private let backupService: SunclubBackupService
    private let widgetSnapshotStore: SunclubWidgetSnapshotStore
    private let currentDate: () -> Date
    private(set) var records: [DailyRecord] = []
    private(set) var changeBatches: [SunclubChangeBatch] = []
    private(set) var importSessions: [SunclubImportSession] = []
    private(set) var conflicts: [SunclubConflictItem] = []
    private(set) var syncPreference: CloudSyncPreference?
    private(set) var uvReading: UVReading?
    private(set) var notificationHealthSnapshot: NotificationHealthSnapshot = .unknown
    private(set) var leaveHomeAuthorizationState: LeaveHomeAuthorizationState = .notDetermined
    private(set) var leaveHomeReminderErrorMessage: String?

    private let calendar = Calendar.current
    private var uvReadingOverride: UVReading?
    private var notificationHealthOverride: NotificationHealthSnapshot?
    private var leaveHomeAuthorizationOverride: LeaveHomeAuthorizationState?

    convenience init(context: ModelContext) {
        self.init(
            context: context,
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService()
        )
    }

    convenience init(
        context: ModelContext,
        notificationManager: NotificationScheduling
    ) {
        self.init(
            context: context,
            notificationManager: notificationManager,
            uvIndexService: UVIndexService()
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
            homeExitReminderMonitor: homeExitReminderMonitor
        )
    }

    init(
        context: ModelContext,
        notificationManager: NotificationScheduling,
        uvIndexService: UVIndexService,
        backupService: SunclubBackupService = SunclubBackupService(),
        historyService: SunclubHistoryService? = nil,
        cloudSyncCoordinator: CloudSyncControlling? = nil,
        homeExitReminderMonitor: HomeExitReminderMonitoring? = nil,
        widgetSnapshotStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
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
        self.backupService = backupService
        try? resolvedHistoryService.bootstrapIfNeeded()
        self.widgetSnapshotStore = widgetSnapshotStore
        currentDate = clock
        settings = (try? resolvedHistoryService.settings()) ?? Self.loadOrCreateSettings(from: context)
        if let cloudSyncCoordinator {
            self.cloudSyncCoordinator = cloudSyncCoordinator
        } else if RuntimeEnvironment.isRunningTests || !RuntimeEnvironment.hasAppGroupContainer {
            self.cloudSyncCoordinator = NoopCloudSyncCoordinator(historyService: resolvedHistoryService)
        } else {
            self.cloudSyncCoordinator = CloudSyncCoordinator(historyService: resolvedHistoryService)
        }
        self.homeExitReminderMonitor.setStateProvider { [weak self] in
            self
        }
        refresh()
        refreshUVReadingIfNeeded()
        refreshNotificationHealth()
        refreshLeaveHomeReminderStatus()

        if !RuntimeEnvironment.isRunningTests {
            Task {
                await self.cloudSyncCoordinator.start()
                self.refresh()
            }
        }
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
        } catch {
            records = []
            changeBatches = []
            importSessions = []
            conflicts = []
            syncPreference = nil
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
        try? modelContext.save()
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
                title: "iCloud sync is paused",
                detail: "This device keeps changes local until you turn iCloud sync back on.",
                actionTitle: "Resume Sync",
                pendingImportedBatchCount: pendingImportedBatchCount
            )
        case .syncing:
            return CloudSyncStatusPresentation(
                title: "Syncing with iCloud",
                detail: "Sunclub is sending recent changes and checking for updates from your other devices.",
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
                detail = "Sync is on and Sunclub will keep your history in iCloud."
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
        let title = hasLoggedToday ? "Already logged today" : "Ready to log today"
        let defaultDetail = hasLoggedToday
            ? "You can update today's check-in any time. Sunclub will keep just one record for today."
            : "Log today manually to keep your sunscreen routine moving."

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
                : "Log today manually, then plan to reapply sooner while UV stays elevated."
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
                    title: "Today is still open",
                    detail: "Log today from Home so the streak keeps moving.",
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
                    detail: "Backfill yesterday without digging into History first.",
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
                detail = "Checked in \(todayRecord.reapplyCount)x today. Last reapply: \(lastReappliedAt.formatted(date: .omitted, time: .shortened))."
            } else {
                detail = "Checked in \(todayRecord.reapplyCount)x today."
            }

            return ReapplyCheckInPresentation(
                title: "Reapply follow-through",
                detail: detail,
                actionTitle: "Log Another Reapply"
            )
        }

        return ReapplyCheckInPresentation(
            title: "Reapply follow-through",
            detail: "When you reapply, check it in here so the reminder loop reflects what actually happened.",
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
                    detail: "Open the system Settings app to let Sunclub save Home from your current location.",
                    symbol: "location.slash",
                    tone: .warning,
                    actionTitle: "Open Settings",
                    actionKind: .openSettings
                )
            default:
                return LeaveHomeReminderStatusPresentation(
                    title: "Home is not set",
                    detail: leaveHomeReminderErrorMessage
                        ?? "Save your current location as Home so Sunclub can watch for the first exit before your normal reminder time.",
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
                detail: "Turn this on when you want Sunclub to use your first home exit as the morning reminder trigger.",
                symbol: "house.fill",
                tone: .neutral,
                actionTitle: nil,
                actionKind: nil
            )
        }

        switch leaveHomeAuthorizationState {
        case .always:
            return LeaveHomeReminderStatusPresentation(
                title: "First exit is armed",
                detail: "Sunclub will watch Home with a \(Int(leaveHomeReminder.radiusMeters)) m radius and send one reminder before your normal weekday or weekend reminder time if today is still open.",
                symbol: "figure.walk.departure",
                tone: .success,
                actionTitle: nil,
                actionKind: nil
            )
        case .notDetermined, .whenInUse, .unknown:
            return LeaveHomeReminderStatusPresentation(
                title: "Background location needed",
                detail: "Leave-home reminders need Always location access so Sunclub can catch your first exit even when the app is not open.",
                symbol: "location.fill",
                tone: .warning,
                actionTitle: "Allow Background Access",
                actionKind: .requestAlwaysAuthorization
            )
        case .denied, .restricted:
            return LeaveHomeReminderStatusPresentation(
                title: "Location access is off",
                detail: "Open the system Settings app to re-enable Always location access for leave-home reminders.",
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
                detail: "Sunclub is using a local UV estimate and stays fully offline.",
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
                detail: "Turn on location access to use WeatherKit when live UV is available. Sunclub will keep using an estimate until then.",
                actionTitle: "Allow Location",
                actionKind: .requestPermission
            )
        case .denied:
            return LiveUVStatusPresentation(
                title: "Location access is off",
                detail: "Open the system Settings app to re-enable location access for live UV. Sunclub is using an estimate right now.",
                actionTitle: "Open Settings",
                actionKind: .openSettings
            )
        case .unavailable:
            return LiveUVStatusPresentation(
                title: "Using estimated UV",
                detail: "WeatherKit or your current location was unavailable, so Sunclub fell back to the local estimate.",
                actionTitle: "Try Again",
                actionKind: .refresh
            )
        case .disabled:
            return LiveUVStatusPresentation(
                title: "Estimated UV",
                detail: "Sunclub is using a local UV estimate and stays fully offline.",
                actionTitle: nil,
                actionKind: nil
            )
        }
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
    }

    func performLiveUVAction(_ action: LiveUVActionKind) {
        switch action {
        case .requestPermission:
            refreshUVReadingIfNeeded(allowPermissionPrompt: true)
        case .openSettings:
            break
        case .refresh:
            refreshUVReadingIfNeeded()
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
        cancelReapplyRemindersIfNeeded()
        scheduleReminders()
        refreshStreakRiskReminder()
        refreshNotificationHealth()
        refreshLeaveHomeReminderStatus()
        refreshUVReadingIfNeeded()
        _ = importedBatchCount
        reloadWidgetTimelines()
    }

    private func syncWidgetSnapshot() {
        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: settings,
            records: records,
            now: Date(),
            calendar: calendar
        )
        widgetSnapshotStore.save(snapshot)
    }

    private func reloadWidgetTimelines() {
        guard !RuntimeEnvironment.isRunningTests else {
            return
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
