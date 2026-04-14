import Foundation
import SwiftData
import UniformTypeIdentifiers
import WidgetKit

enum SunclubAutomationInvocation: Equatable {
    case shortcut
    case url
}

enum SunclubAutomationError: LocalizedError, Equatable {
    case onboardingRequired
    case shortcutWritesDisabled
    case urlOpenActionsDisabled
    case urlWriteActionsDisabled
    case unsupportedAction(String)
    case recordRequired
    case friendNotFound
    case invalidInput(String)
    case unavailable(String)

    var errorCode: String {
        switch self {
        case .onboardingRequired:
            return "onboardingRequired"
        case .shortcutWritesDisabled:
            return "shortcutWritesDisabled"
        case .urlOpenActionsDisabled:
            return "urlOpenActionsDisabled"
        case .urlWriteActionsDisabled:
            return "urlWriteActionsDisabled"
        case .unsupportedAction:
            return "unsupportedAction"
        case .recordRequired:
            return "recordRequired"
        case .friendNotFound:
            return "friendNotFound"
        case .invalidInput:
            return "invalidInput"
        case .unavailable:
            return "unavailable"
        }
    }

    var errorDescription: String? {
        switch self {
        case .onboardingRequired:
            return "Open Sunclub once to finish setup before using automation."
        case .shortcutWritesDisabled:
            return "Shortcut writes are off in Sunclub Automation settings."
        case .urlOpenActionsDisabled:
            return "URL open actions are off in Sunclub Automation settings."
        case .urlWriteActionsDisabled:
            return "URL write actions are off in Sunclub Automation settings."
        case let .unsupportedAction(action):
            return "Sunclub does not support the automation action \(action)."
        case .recordRequired:
            return "Log sunscreen for today before using this automation."
        case .friendNotFound:
            return "Sunclub could not find that accountability friend."
        case let .invalidInput(message):
            return message
        case let .unavailable(message):
            return message
        }
    }
}

enum SunclubAutomationRoute: String, CaseIterable, Codable, Sendable {
    case home
    case log
    case reapply
    case summary
    case history
    case settings
    case automation
    case achievements
    case friends
    case healthReport = "health-report"
    case productScanner = "product-scanner"
    case recovery

    var appRoute: AppRoute {
        switch self {
        case .home:
            return .home
        case .log:
            return .manualLog
        case .reapply:
            return .reapplyCheckIn
        case .summary:
            return .weeklySummary
        case .history:
            return .history
        case .settings:
            return .settings
        case .automation:
            return .automation
        case .achievements:
            return .achievements
        case .friends:
            return .friends
        case .healthReport:
            return .skinHealthReport
        case .productScanner:
            return .productScanner
        case .recovery:
            return .recovery
        }
    }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .log:
            return "Today's Log"
        case .reapply:
            return "Reapply"
        case .summary:
            return "Weekly Summary"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        case .automation:
            return "Automation"
        case .achievements:
            return "Achievements"
        case .friends:
            return "Friends"
        case .healthReport:
            return "Health Report"
        case .productScanner:
            return "SPF Scanner"
        case .recovery:
            return "Recovery"
        }
    }
}

enum SunclubAutomationReminderKind: String, CaseIterable, Codable, Sendable {
    case weekday
    case weekend

    var reminderKind: ReminderScheduleKind {
        switch self {
        case .weekday:
            return .weekday
        case .weekend:
            return .weekend
        }
    }
}

enum SunclubAutomationToggle: String, CaseIterable, Codable, Sendable {
    case travelTimeZone
    case streakRisk
    case liveUV
    case dailyUVBriefing
    case extremeUVAlert
    case iCloudSync
    case healthKit

    var title: String {
        switch self {
        case .travelTimeZone:
            return "Travel Time Zone"
        case .streakRisk:
            return "Streak Risk"
        case .liveUV:
            return "Live UV"
        case .dailyUVBriefing:
            return "Daily UV Briefing"
        case .extremeUVAlert:
            return "Extreme UV Alert"
        case .iCloudSync:
            return "iCloud Sync"
        case .healthKit:
            return "HealthKit"
        }
    }
}

enum SunclubAutomationAction: Equatable {
    case logToday(spfLevel: Int?, notes: String?)
    case saveLog(day: Date?, time: ReminderTime?, spfLevel: Int?, notes: String?)
    case reapply
    case status
    case timeSinceLastApplication
    case setReminder(kind: SunclubAutomationReminderKind, time: ReminderTime)
    case setReapply(enabled: Bool, intervalMinutes: Int?)
    case setToggle(SunclubAutomationToggle, enabled: Bool)
    case importFriend(code: String)
    case pokeFriend(id: UUID)
    case open(SunclubAutomationRoute)
    case exportBackup
    case createSkinHealthReport(start: Date?, end: Date?)
    case createStreakCard

    var identifier: String {
        switch self {
        case .logToday:
            return "log-today"
        case .saveLog:
            return "save-log"
        case .reapply:
            return "reapply"
        case .status:
            return "status"
        case .timeSinceLastApplication:
            return "time-since-last-application"
        case .setReminder:
            return "set-reminder"
        case .setReapply:
            return "set-reapply"
        case .setToggle:
            return "set-toggle"
        case .importFriend:
            return "import-friend"
        case .pokeFriend:
            return "poke-friend"
        case .open:
            return "open"
        case .exportBackup:
            return "export-backup"
        case .createSkinHealthReport:
            return "create-skin-health-report"
        case .createStreakCard:
            return "create-streak-card"
        }
    }

    var isWriteAction: Bool {
        switch self {
        case .logToday,
             .saveLog,
             .reapply,
             .setReminder,
             .setReapply,
             .setToggle,
             .importFriend,
             .pokeFriend:
            return true
        case .status, .timeSinceLastApplication, .open, .exportBackup, .createSkinHealthReport, .createStreakCard:
            return false
        }
    }

    var isOpenAction: Bool {
        if case .open = self {
            return true
        }
        return false
    }

    var logsCurrentDay: Bool {
        switch self {
        case .logToday:
            return true
        case let .saveLog(day, _, _, _):
            guard let day else { return true }
            return Calendar.current.isDateInToday(day)
        default:
            return false
        }
    }
}

struct SunclubAutomationResult: Equatable {
    var action: String
    var status: String
    var message: String
    var currentStreak: Int?
    var longestStreak: Int?
    var todayLogged: Bool?
    var weeklyApplied: Int?
    var recordDate: String?
    var friend: String?
    var route: String?
    var fileURL: URL?
    var fileTypeIdentifier: String?
    var lastAppliedAt: String?
    var minutesSinceLastApplication: Int?

    var callbackQueryItems: [URLQueryItem] {
        var items = [
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "status", value: status)
        ]

        items.append(URLQueryItem(name: "message", value: message))
        if let currentStreak {
            items.append(URLQueryItem(name: "currentStreak", value: String(currentStreak)))
        }
        if let longestStreak {
            items.append(URLQueryItem(name: "longestStreak", value: String(longestStreak)))
        }
        if let todayLogged {
            items.append(URLQueryItem(name: "todayLogged", value: todayLogged ? "true" : "false"))
        }
        if let weeklyApplied {
            items.append(URLQueryItem(name: "weeklyApplied", value: String(weeklyApplied)))
        }
        if let recordDate {
            items.append(URLQueryItem(name: "recordDate", value: recordDate))
        }
        if let friend {
            items.append(URLQueryItem(name: "friend", value: friend))
        }
        if let route {
            items.append(URLQueryItem(name: "route", value: route))
        }
        if let lastAppliedAt {
            items.append(URLQueryItem(name: "lastAppliedAt", value: lastAppliedAt))
        }
        if let minutesSinceLastApplication {
            items.append(URLQueryItem(name: "minutesSinceLastApplication", value: String(minutesSinceLastApplication)))
        }

        return items
    }
}

enum SunclubXCallbackResponse {
    static func successURL(
        baseURL: URL,
        result: SunclubAutomationResult,
        includesDetails: Bool
    ) -> URL {
        callbackURL(
            baseURL: baseURL,
            action: result.action,
            status: result.status,
            detailItems: includesDetails ? result.callbackQueryItems.dropFirst(2).map { $0 } : []
        )
    }

    static func errorURL(
        baseURL: URL,
        action: String,
        error: SunclubAutomationError,
        includesDetails: Bool
    ) -> URL {
        let details = includesDetails
            ? [
                URLQueryItem(name: "errorCode", value: error.errorCode),
                URLQueryItem(name: "errorMessage", value: error.localizedDescription)
            ]
            : []
        return callbackURL(baseURL: baseURL, action: action, status: "error", detailItems: details)
    }

    private static func callbackURL(
        baseURL: URL,
        action: String,
        status: String,
        detailItems: [URLQueryItem]
    ) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
        }

        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "action", value: action))
        items.append(URLQueryItem(name: "status", value: status))
        items.append(contentsOf: detailItems)
        components.queryItems = items
        return components.url ?? baseURL
    }
}

@MainActor
enum SunclubAutomationRuntime {
    private static let calendar = Calendar.current

    @MainActor
    private struct RuntimeContext {
        let historyService: SunclubHistoryService
        let modelContext: ModelContext
        let growthStore: SunclubGrowthFeatureStoring
        let widgetStore: SunclubWidgetSnapshotStore
        let now: Date

        init(
            modelContext: ModelContext,
            growthStore: SunclubGrowthFeatureStoring,
            widgetStore: SunclubWidgetSnapshotStore,
            now: Date
        ) {
            self.historyService = SunclubHistoryService(context: modelContext, calendar: SunclubAutomationRuntime.calendar)
            self.modelContext = modelContext
            self.growthStore = growthStore
            self.widgetStore = widgetStore
            self.now = now
        }
    }

    private struct LogDraft {
        var day: Date
        var time: ReminderTime?
        var spfLevel: Int?
        var notes: String?
    }

    private struct RecordMutation {
        var day: Date
        var verifiedAt: Date
        var method: VerificationMethod
        var spfLevel: Int?
        var notes: String?
        var replaceOptionalFields: Bool
        var preserveExistingDuration: Bool
        var kind: SunclubChangeKind
        var summary: String
    }

    static func performStandalone(
        _ action: SunclubAutomationAction,
        invocation: SunclubAutomationInvocation,
        now: Date = Date()
    ) throws -> SunclubAutomationResult {
        do {
            let container = try SunclubModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: false)
            return try perform(
                action,
                invocation: invocation,
                context: ModelContext(container),
                growthStore: SunclubGrowthFeatureStore.shared,
                now: now
            )
        } catch let error as SunclubAutomationError {
            throw error
        } catch {
            throw SunclubAutomationError.unavailable(error.localizedDescription)
        }
    }

    static func perform(
        _ action: SunclubAutomationAction,
        invocation: SunclubAutomationInvocation,
        context: ModelContext,
        growthStore: SunclubGrowthFeatureStoring,
        widgetStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
        now: Date = Date(),
        supportsDirectAccountabilityTransport: Bool = SunclubRuntimeConfiguration.isPublicAccountabilityTransportEnabled
    ) throws -> SunclubAutomationResult {
        let runtimeContext = RuntimeContext(
            modelContext: context,
            growthStore: growthStore,
            widgetStore: widgetStore,
            now: now
        )
        try runtimeContext.historyService.bootstrapIfNeeded()
        let settings = try runtimeContext.historyService.settings()
        var growthSettings = growthStore.load()

        try validate(action: action, invocation: invocation, settings: settings, preferences: growthSettings.automation)
        return try performValidated(
            action,
            runtimeContext: runtimeContext,
            growthSettings: &growthSettings,
            supportsDirectAccountabilityTransport: supportsDirectAccountabilityTransport
        )
    }

    private static func performValidated(
        _ action: SunclubAutomationAction,
        runtimeContext: RuntimeContext,
        growthSettings: inout SunclubGrowthSettings,
        supportsDirectAccountabilityTransport: Bool
    ) throws -> SunclubAutomationResult {
        switch action {
        case let .logToday(spfLevel, notes):
            return try logToday(
                spfLevel: normalizedSPF(spfLevel),
                notes: normalizedNotes(notes),
                runtimeContext: runtimeContext,
                growthSettings: growthSettings
            )
        case let .saveLog(day, time, spfLevel, notes):
            return try saveLog(
                LogDraft(
                    day: day ?? runtimeContext.now,
                    time: time,
                    spfLevel: normalizedSPF(spfLevel),
                    notes: normalizedNotes(notes)
                ),
                runtimeContext: runtimeContext,
                growthSettings: growthSettings
            )
        case .reapply:
            return try logReapply(runtimeContext: runtimeContext, growthSettings: growthSettings)
        case .status:
            return try statusResult(
                action: action.identifier,
                historyService: runtimeContext.historyService,
                now: runtimeContext.now
            )
        case .timeSinceLastApplication:
            return try timeSinceLastApplicationResult(
                action: action.identifier,
                historyService: runtimeContext.historyService,
                now: runtimeContext.now
            )
        case let .setReminder(kind, time):
            return try setReminder(
                kind: kind,
                time: time,
                runtimeContext: runtimeContext,
                growthSettings: growthSettings
            )
        case let .setReapply(enabled, intervalMinutes):
            return try setReapply(
                enabled: enabled,
                intervalMinutes: intervalMinutes,
                runtimeContext: runtimeContext,
                growthSettings: growthSettings
            )
        case let .setToggle(toggle, enabled):
            return try setToggle(
                toggle,
                enabled: enabled,
                runtimeContext: runtimeContext,
                growthSettings: &growthSettings
            )
        case let .importFriend(code):
            return try importFriend(
                code: code,
                runtimeContext: runtimeContext,
                growthSettings: &growthSettings,
                supportsDirectAccountabilityTransport: supportsDirectAccountabilityTransport
            )
        case let .pokeFriend(id):
            return try pokeFriend(
                id: id,
                runtimeContext: runtimeContext,
                growthSettings: &growthSettings,
                supportsDirectAccountabilityTransport: supportsDirectAccountabilityTransport
            )
        case let .open(route):
            return SunclubAutomationResult(
                action: action.identifier,
                status: "opened",
                message: "Opened \(route.title).",
                route: route.rawValue
            )
        case .exportBackup:
            return try exportBackup(context: runtimeContext.modelContext, action: action.identifier)
        case let .createSkinHealthReport(start, end):
            return try createSkinHealthReport(
                start: start,
                end: end,
                historyService: runtimeContext.historyService,
                growthSettings: growthSettings,
                now: runtimeContext.now,
                action: action.identifier
            )
        case .createStreakCard:
            return try createStreakCard(
                historyService: runtimeContext.historyService,
                growthSettings: growthSettings,
                now: runtimeContext.now,
                action: action.identifier
            )
        }
    }

    static func friends(growthStore: SunclubGrowthFeatureStoring = SunclubGrowthFeatureStore.shared) -> [SunclubFriendSnapshot] {
        growthStore.load().friends.sorted { lhs, rhs in
            if lhs.hasLoggedToday != rhs.hasLoggedToday {
                return !lhs.hasLoggedToday && rhs.hasLoggedToday
            }
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func validate(
        action: SunclubAutomationAction,
        invocation: SunclubAutomationInvocation,
        settings: Settings,
        preferences: SunclubAutomationPreferences
    ) throws {
        if action.isWriteAction, !settings.hasCompletedOnboarding {
            throw SunclubAutomationError.onboardingRequired
        }

        switch invocation {
        case .shortcut:
            if action.isWriteAction, !preferences.shortcutWritesEnabled {
                throw SunclubAutomationError.shortcutWritesDisabled
            }
        case .url:
            if action.isOpenAction, !preferences.urlOpenActionsEnabled {
                throw SunclubAutomationError.urlOpenActionsDisabled
            }
            if action.isWriteAction, !preferences.urlWriteActionsEnabled {
                throw SunclubAutomationError.urlWriteActionsDisabled
            }
        }
    }

    private static func logToday(
        spfLevel: Int?,
        notes: String?,
        runtimeContext: RuntimeContext,
        growthSettings: SunclubGrowthSettings
    ) throws -> SunclubAutomationResult {
        let day = calendar.startOfDay(for: runtimeContext.now)
        let isUpdate = try runtimeContext.historyService.record(for: day) != nil
        try upsertRecord(
            RecordMutation(
                day: day,
                verifiedAt: runtimeContext.now,
                method: .quickLog,
                spfLevel: spfLevel,
                notes: notes,
                replaceOptionalFields: false,
                preserveExistingDuration: false,
                kind: .manualLog,
                summary: "Logged sunscreen from automation."
            ),
            runtimeContext: runtimeContext
        )
        return try finishChangedTimeline(
            action: "log-today",
            message: isUpdate ? "Updated today's sunscreen log." : "Logged sunscreen for today.",
            recordDate: day,
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )
    }

    private static func saveLog(
        _ draft: LogDraft,
        runtimeContext: RuntimeContext,
        growthSettings: SunclubGrowthSettings
    ) throws -> SunclubAutomationResult {
        let dayStart = calendar.startOfDay(for: draft.day)
        let existingTimestamp = try runtimeContext.historyService.record(for: dayStart)?.verifiedAt
        let verifiedAt = verifiedAt(
            for: dayStart,
            time: draft.time,
            existingTimestamp: existingTimestamp,
            now: runtimeContext.now
        )
        let kind: SunclubChangeKind = existingTimestamp == nil ? .historyBackfill : .historyEdit
        try upsertRecord(
            RecordMutation(
                day: dayStart,
                verifiedAt: verifiedAt,
                method: .manual,
                spfLevel: draft.spfLevel,
                notes: draft.notes,
                replaceOptionalFields: true,
                preserveExistingDuration: true,
                kind: kind,
                summary: kind == .historyBackfill ? "Backfilled sunscreen from automation." : "Updated sunscreen from automation."
            ),
            runtimeContext: runtimeContext
        )
        return try finishChangedTimeline(
            action: "save-log",
            message: kind == .historyBackfill ? "Backfilled sunscreen log." : "Updated sunscreen log.",
            recordDate: dayStart,
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )
    }

    private static func logReapply(
        runtimeContext: RuntimeContext,
        growthSettings: SunclubGrowthSettings
    ) throws -> SunclubAutomationResult {
        let day = calendar.startOfDay(for: runtimeContext.now)
        guard try runtimeContext.historyService.record(for: day) != nil else {
            throw SunclubAutomationError.recordRequired
        }

        _ = try runtimeContext.historyService.applyDayChange(
            for: day,
            kind: .reapply,
            summary: "Logged a reapply check-in from automation.",
            changedFields: [.reapplyCount, .lastReappliedAt]
        ) { existingSnapshot in
            guard var snapshot = existingSnapshot else {
                return nil
            }
            snapshot.reapplyCount += 1
            snapshot.lastReappliedAt = runtimeContext.now
            return snapshot
        }
        try runtimeContext.modelContext.save()
        return try finishChangedTimeline(
            action: "reapply",
            message: "Logged a reapply check-in.",
            recordDate: day,
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )
    }

    private static func setReminder(
        kind: SunclubAutomationReminderKind,
        time: ReminderTime,
        runtimeContext: RuntimeContext,
        growthSettings: SunclubGrowthSettings
    ) throws -> SunclubAutomationResult {
        let settings = try runtimeContext.historyService.settings()
        var reminderSettings = settings.smartReminderSettings
        switch kind {
        case .weekday:
            reminderSettings.weekdayTime = time
        case .weekend:
            reminderSettings.weekendTime = time
        }
        try applyReminderSettings(
            reminderSettings,
            summary: "Updated reminder time from automation.",
            historyService: runtimeContext.historyService
        )
        try runtimeContext.modelContext.save()
        return try finishChangedTimeline(
            action: "set-reminder",
            message: "Updated \(kind.rawValue) reminder to \(formatted(time)).",
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )
    }

    private static func setReapply(
        enabled: Bool,
        intervalMinutes: Int?,
        runtimeContext: RuntimeContext,
        growthSettings: SunclubGrowthSettings
    ) throws -> SunclubAutomationResult {
        let settings = try runtimeContext.historyService.settings()
        let interval = max(30, min(480, intervalMinutes ?? settings.reapplyIntervalMinutes))
        _ = try runtimeContext.historyService.applySettingsChange(
            kind: .reapplySettings,
            summary: "Updated reapply reminder from automation.",
            changedFields: [.reapplyReminderEnabled, .reapplyIntervalMinutes]
        ) { snapshot in
            snapshot.reapplyReminderEnabled = enabled
            snapshot.reapplyIntervalMinutes = interval
        }
        try runtimeContext.modelContext.save()
        return try finishChangedTimeline(
            action: "set-reapply",
            message: enabled ? "Reapply reminder is on." : "Reapply reminder is off.",
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )
    }

    private static func setToggle(
        _ toggle: SunclubAutomationToggle,
        enabled: Bool,
        runtimeContext: RuntimeContext,
        growthSettings: inout SunclubGrowthSettings
    ) throws -> SunclubAutomationResult {
        switch toggle {
        case .travelTimeZone, .streakRisk:
            let settings = try runtimeContext.historyService.settings()
            var reminderSettings = settings.smartReminderSettings
            if toggle == .travelTimeZone {
                reminderSettings.followsTravelTimeZone = enabled
                if !enabled {
                    reminderSettings.anchoredTimeZoneIdentifier = TimeZone.autoupdatingCurrent.identifier
                }
            } else {
                reminderSettings.streakRiskEnabled = enabled
            }
            try applyReminderSettings(
                reminderSettings,
                summary: "Updated \(toggle.title) from automation.",
                historyService: runtimeContext.historyService
            )
        case .liveUV:
            _ = try runtimeContext.historyService.applySettingsChange(
                kind: .liveUVSettings,
                summary: "Updated live UV from automation.",
                changedFields: [.usesLiveUV]
            ) { snapshot in
                snapshot.usesLiveUV = enabled
            }
        case .dailyUVBriefing:
            growthSettings.uvBriefing.dailyBriefingEnabled = enabled
            runtimeContext.growthStore.save(growthSettings)
        case .extremeUVAlert:
            growthSettings.uvBriefing.extremeAlertEnabled = enabled
            runtimeContext.growthStore.save(growthSettings)
        case .iCloudSync:
            let preference = try runtimeContext.historyService.syncPreference()
            preference.isICloudSyncEnabled = enabled
            preference.status = enabled ? .idle : .paused
        case .healthKit:
            growthSettings.healthKit.isEnabled = enabled
            runtimeContext.growthStore.save(growthSettings)
        }

        try runtimeContext.modelContext.save()
        return try finishChangedTimeline(
            action: "set-toggle",
            message: "\(toggle.title) is \(enabled ? "on" : "off").",
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )
    }

    private static func importFriend(
        code: String,
        runtimeContext: RuntimeContext,
        growthSettings: inout SunclubGrowthSettings,
        supportsDirectAccountabilityTransport: Bool
    ) throws -> SunclubAutomationResult {
        let envelope = try SunclubAccountabilityCodec.envelope(from: code)
        guard envelope.profileID != growthSettings.accountability.localProfileID else {
            throw SunclubAutomationError.invalidInput("That invite belongs to this Sunclub profile.")
        }

        if !growthSettings.accountability.isActive {
            let name = growthSettings.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
            growthSettings.accountability.displayName = name.isEmpty ? "Sunclub Friend" : name
            growthSettings.accountability.activatedAt = runtimeContext.now
            _ = growthSettings.accountability.ensureInviteToken(now: runtimeContext.now)
        }

        var importedSnapshot = envelope.snapshot
        importedSnapshot.name = envelope.displayName.isEmpty ? importedSnapshot.name : envelope.displayName
        if let existingConnection = growthSettings.accountability.connections.first(where: { $0.friendProfileID == envelope.profileID }) {
            importedSnapshot.id = existingConnection.friendSnapshotID
        }
        upsertFriendSnapshot(importedSnapshot, growthSettings: &growthSettings)
        upsertConnection(
            SunclubFriendConnection(
                friendProfileID: envelope.profileID,
                friendSnapshotID: importedSnapshot.id,
                friendDisplayName: importedSnapshot.name,
                relationshipToken: envelope.relationshipToken,
                acceptedAt: runtimeContext.now,
                canDirectPoke: supportsDirectAccountabilityTransport
            ),
            growthSettings: &growthSettings
        )
        runtimeContext.growthStore.save(growthSettings)
        try syncSnapshot(
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )

        return SunclubAutomationResult(
            action: "import-friend",
            status: "ok",
            message: "Added \(importedSnapshot.name).",
            friend: importedSnapshot.name
        )
    }

    private static func pokeFriend(
        id: UUID,
        runtimeContext: RuntimeContext,
        growthSettings: inout SunclubGrowthSettings,
        supportsDirectAccountabilityTransport: Bool
    ) throws -> SunclubAutomationResult {
        guard let friend = growthSettings.friends.first(where: { $0.id == id }) else {
            throw SunclubAutomationError.friendNotFound
        }

        guard supportsDirectAccountabilityTransport,
              let connection = growthSettings.accountability.connections.first(where: { $0.friendSnapshotID == id }),
              connection.canDirectPoke else {
            return SunclubAutomationResult(
                action: "poke-friend",
                status: "needs-message",
                message: "Open Sunclub to message \(friend.name).",
                friend: friend.name,
                route: AppRoute.friends.rawValue
            )
        }

        let message = friend.hasLoggedToday
            ? "\(friend.name) logged today. Reapply if the sun is still out."
            : "\(friend.name) still has an open sunscreen day."
        growthSettings.accountability.pokeHistory.insert(
            SunclubAccountabilityPoke(
                friendProfileID: connection.friendProfileID,
                friendName: friend.name,
                direction: .sent,
                channel: .direct,
                status: .sent,
                message: message,
                createdAt: runtimeContext.now
            ),
            at: 0
        )
        growthSettings.accountability.pokeHistory = Array(growthSettings.accountability.pokeHistory.prefix(50))
        if let index = growthSettings.accountability.connections.firstIndex(where: { $0.friendSnapshotID == id }) {
            growthSettings.accountability.connections[index].lastPokeSentAt = runtimeContext.now
        }
        runtimeContext.growthStore.save(growthSettings)
        try syncSnapshot(
            historyService: runtimeContext.historyService,
            growthSettings: growthSettings,
            widgetStore: runtimeContext.widgetStore,
            now: runtimeContext.now
        )

        return SunclubAutomationResult(
            action: "poke-friend",
            status: "ok",
            message: "Poked \(friend.name).",
            friend: friend.name
        )
    }

    private static func exportBackup(context: ModelContext, action: String) throws -> SunclubAutomationResult {
        let document = try SunclubBackupService().exportDocument(from: context)
        let fileURL = try temporaryFileURL(named: document.suggestedFilename)
        try document.serializedData().write(to: fileURL, options: .atomic)
        return SunclubAutomationResult(
            action: action,
            status: "ok",
            message: "Created Sunclub backup.",
            fileURL: fileURL,
            fileTypeIdentifier: SunclubBackupDocument.contentType.identifier
        )
    }

    private static func createSkinHealthReport(
        start: Date?,
        end: Date?,
        historyService: SunclubHistoryService,
        growthSettings: SunclubGrowthSettings,
        now: Date,
        action: String
    ) throws -> SunclubAutomationResult {
        let records = try historyService.records()
        guard !records.isEmpty else {
            throw SunclubAutomationError.recordRequired
        }
        let defaultStart = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let lower = min(start ?? defaultStart, end ?? now)
        let upper = max(start ?? defaultStart, end ?? now)
        let interval = DateInterval(start: calendar.startOfDay(for: lower), end: upper)
        let artifact = try SunclubShareArtifactService.makeSkinHealthReport(
            summary: SunclubGrowthAnalytics.reportSummary(records: records, interval: interval, calendar: calendar),
            preferredName: growthSettings.preferredName
        )
        return SunclubAutomationResult(
            action: action,
            status: "ok",
            message: "Created skin health report.",
            fileURL: artifact.fileURL,
            fileTypeIdentifier: UTType.pdf.identifier
        )
    }

    private static func createStreakCard(
        historyService: SunclubHistoryService,
        growthSettings: SunclubGrowthSettings,
        now: Date,
        action: String
    ) throws -> SunclubAutomationResult {
        let settings = try historyService.settings()
        let records = try historyService.records()
        let recordedDays = records.map { calendar.startOfDay(for: $0.startOfDay) }
        let artifact = try SunclubShareArtifactService.makeStreakCard(
            currentStreak: CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar),
            longestStreak: settings.longestStreak,
            recordedDays: recordedDays,
            seasonStyle: SunclubGrowthAnalytics.seasonalStyle(for: now, calendar: calendar),
            now: now,
            calendar: calendar
        )
        return SunclubAutomationResult(
            action: action,
            status: "ok",
            message: "Created streak card.",
            fileURL: artifact.fileURL,
            fileTypeIdentifier: UTType.png.identifier
        )
    }

    private static func upsertRecord(_ mutation: RecordMutation, runtimeContext: RuntimeContext) throws {
        _ = try runtimeContext.historyService.applyDayChange(
            for: mutation.day,
            kind: mutation.kind,
            summary: mutation.summary,
            changedFields: [.verifiedAt, .methodRawValue, .verificationDuration, .spfLevel, .notes]
        ) { existingSnapshot in
            if var snapshot = existingSnapshot {
                snapshot.verifiedAt = mutation.verifiedAt
                snapshot.methodRawValue = mutation.method.rawValue
                if !mutation.preserveExistingDuration {
                    snapshot.verificationDuration = nil
                }
                if mutation.replaceOptionalFields {
                    snapshot.spfLevel = mutation.spfLevel
                    snapshot.notes = mutation.notes
                } else {
                    if let spfLevel = mutation.spfLevel {
                        snapshot.spfLevel = spfLevel
                    }
                    if let notes = mutation.notes {
                        snapshot.notes = notes
                    }
                }
                return snapshot
            }

            return DailyRecordProjectionSnapshot(
                startOfDay: calendar.startOfDay(for: mutation.day),
                verifiedAt: mutation.verifiedAt,
                methodRawValue: mutation.method.rawValue,
                verificationDuration: nil,
                spfLevel: mutation.spfLevel,
                notes: mutation.notes,
                reapplyCount: 0,
                lastReappliedAt: nil
            )
        }
        try runtimeContext.modelContext.save()
    }

    private static func finishChangedTimeline(
        action: String,
        message: String,
        recordDate: Date? = nil,
        historyService: SunclubHistoryService,
        growthSettings: SunclubGrowthSettings,
        widgetStore: SunclubWidgetSnapshotStore,
        now: Date
    ) throws -> SunclubAutomationResult {
        try historyService.refreshProjectedState()
        let settings = try historyService.settings()
        let records = try historyService.records()
        let recordedDays = records.map { calendar.startOfDay(for: $0.startOfDay) }
        let longestStreak = CalendarAnalytics.longestStreak(records: recordedDays, calendar: calendar)
        if settings.longestStreak != longestStreak {
            settings.longestStreak = longestStreak
            try historyService.fetchContext().save()
        }
        try syncSnapshot(historyService: historyService, growthSettings: growthSettings, widgetStore: widgetStore, now: now)

        let weekly = CalendarAnalytics.weeklyReport(records: recordedDays, now: now, calendar: calendar)
        return SunclubAutomationResult(
            action: action,
            status: "ok",
            message: message,
            currentStreak: CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar),
            longestStreak: settings.longestStreak,
            todayLogged: Set(recordedDays).contains(calendar.startOfDay(for: now)),
            weeklyApplied: weekly.appliedCount,
            recordDate: recordDate.map(dateString)
        )
    }

    private static func statusResult(
        action: String,
        historyService: SunclubHistoryService,
        now: Date
    ) throws -> SunclubAutomationResult {
        try historyService.refreshProjectedState()
        let settings = try historyService.settings()
        let records = try historyService.records()
        let recordedDays = records.map { calendar.startOfDay(for: $0.startOfDay) }
        let todayLogged = Set(recordedDays).contains(calendar.startOfDay(for: now))
        let weekly = CalendarAnalytics.weeklyReport(records: recordedDays, now: now, calendar: calendar)
        return SunclubAutomationResult(
            action: action,
            status: "ok",
            message: todayLogged ? "Today is logged." : "Today is still open.",
            currentStreak: CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar),
            longestStreak: settings.longestStreak,
            todayLogged: todayLogged,
            weeklyApplied: weekly.appliedCount,
            lastAppliedAt: mostRecentApplication(in: records).map(dateTimeString),
            minutesSinceLastApplication: minutesSinceLastApplication(in: records, now: now)
        )
    }

    private static func timeSinceLastApplicationResult(
        action: String,
        historyService: SunclubHistoryService,
        now: Date
    ) throws -> SunclubAutomationResult {
        try historyService.refreshProjectedState()
        let settings = try historyService.settings()
        let records = try historyService.records()
        let recordedDays = records.map { calendar.startOfDay(for: $0.startOfDay) }
        let todayLogged = Set(recordedDays).contains(calendar.startOfDay(for: now))
        let weekly = CalendarAnalytics.weeklyReport(records: recordedDays, now: now, calendar: calendar)
        let currentStreak = CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar)
        guard let lastApplication = mostRecentApplication(in: records),
              let minutes = minutesSinceLastApplication(from: lastApplication, now: now) else {
            return SunclubAutomationResult(
                action: action,
                status: "ok",
                message: "No sunscreen application has been logged yet.",
                currentStreak: currentStreak,
                longestStreak: settings.longestStreak,
                todayLogged: todayLogged,
                weeklyApplied: weekly.appliedCount
            )
        }

        return SunclubAutomationResult(
            action: action,
            status: "ok",
            message: timeSinceLastApplicationMessage(minutes: minutes),
            currentStreak: currentStreak,
            longestStreak: settings.longestStreak,
            todayLogged: todayLogged,
            weeklyApplied: weekly.appliedCount,
            lastAppliedAt: dateTimeString(lastApplication),
            minutesSinceLastApplication: minutes
        )
    }

    private static func mostRecentApplication(in records: [DailyRecord]) -> Date? {
        records.flatMap { record in
            [record.verifiedAt, record.lastReappliedAt].compactMap { $0 }
        }
        .max()
    }

    private static func minutesSinceLastApplication(in records: [DailyRecord], now: Date) -> Int? {
        mostRecentApplication(in: records).flatMap { minutesSinceLastApplication(from: $0, now: now) }
    }

    private static func minutesSinceLastApplication(from date: Date, now: Date) -> Int? {
        max(calendar.dateComponents([.minute], from: date, to: now).minute ?? 0, 0)
    }

    private static func timeSinceLastApplicationMessage(minutes: Int) -> String {
        if minutes < 60 {
            return "Last sunscreen application was \(minutes) minutes ago."
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "Last sunscreen application was \(hours) \(hours == 1 ? "hour" : "hours") ago."
        }

        return "Last sunscreen application was \(hours) \(hours == 1 ? "hour" : "hours") and \(remainingMinutes) minutes ago."
    }

    private static func syncSnapshot(
        historyService: SunclubHistoryService,
        growthSettings: SunclubGrowthSettings,
        widgetStore: SunclubWidgetSnapshotStore,
        now: Date
    ) throws {
        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: try historyService.settings(),
            records: try historyService.records(),
            growthSettings: growthSettings,
            now: now,
            calendar: calendar
        )
        widgetStore.save(snapshot)
        guard !RuntimeEnvironment.isRunningTests else {
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func applyReminderSettings(
        _ reminderSettings: SmartReminderSettings,
        summary: String,
        historyService: SunclubHistoryService
    ) throws {
        let normalized = reminderSettings.normalized(
            fallbackHour: reminderSettings.weekdayTime.hour,
            fallbackMinute: reminderSettings.weekdayTime.minute
        )
        let encoded = try? JSONEncoder().encode(normalized)
        _ = try historyService.applySettingsChange(
            kind: .reminderSettings,
            summary: summary,
            changedFields: [.reminderHour, .reminderMinute, .smartReminderSettingsData]
        ) { snapshot in
            snapshot.reminderHour = normalized.weekdayTime.hour
            snapshot.reminderMinute = normalized.weekdayTime.minute
            snapshot.smartReminderSettingsData = encoded
        }
    }

    private static func verifiedAt(
        for day: Date,
        time: ReminderTime?,
        existingTimestamp: Date?,
        now: Date
    ) -> Date {
        let resolvedTime = time ?? existingTimestamp.map {
            ReminderTime(hour: calendar.component(.hour, from: $0), minute: calendar.component(.minute, from: $0))
        } ?? ReminderTime(hour: calendar.component(.hour, from: now), minute: calendar.component(.minute, from: now))

        return calendar.date(
            bySettingHour: resolvedTime.hour,
            minute: resolvedTime.minute,
            second: 0,
            of: day
        ) ?? day
    }

    private static func upsertFriendSnapshot(_ snapshot: SunclubFriendSnapshot, growthSettings: inout SunclubGrowthSettings) {
        if let index = growthSettings.friends.firstIndex(where: { $0.id == snapshot.id || $0.name == snapshot.name }) {
            growthSettings.friends[index] = snapshot
        } else {
            growthSettings.friends.append(snapshot)
        }
    }

    private static func upsertConnection(_ connection: SunclubFriendConnection, growthSettings: inout SunclubGrowthSettings) {
        if let index = growthSettings.accountability.connections.firstIndex(where: { $0.friendProfileID == connection.friendProfileID }) {
            growthSettings.accountability.connections[index] = connection
        } else {
            growthSettings.accountability.connections.append(connection)
        }
    }

    private static func normalizedSPF(_ spfLevel: Int?) -> Int? {
        SunManualLogInput.normalizedSPF(spfLevel)
    }

    private static func normalizedNotes(_ notes: String?) -> String? {
        SunManualLogInput.normalizedNotes(notes)
    }

    private static func formatted(_ time: ReminderTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func dateTimeString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private static func temporaryFileURL(named filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sunclub-automation", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(filename, isDirectory: false)
    }
}
