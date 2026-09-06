import Foundation
import SwiftData
import UniformTypeIdentifiers
import WidgetKit

enum SunclubAutomationInvocation: Equatable {
    case shortcut
    case widget
    case url
}

enum SunclubAutomationError: LocalizedError, Equatable {
    case onboardingRequired
    case shortcutWritesDisabled
    case urlOpenActionsDisabled
    case urlWriteActionsDisabled
    case unsupportedAction(String)
    case recordRequired

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
        case .invalidInput:
            return "invalidInput"
        case .unavailable:
            return "unavailable"
        }
    }

    var errorDescription: String? {
        switch self {
        case .onboardingRequired:
            return "Open Sunclub once to finish setup before using Shortcuts."
        case .shortcutWritesDisabled:
            return "Shortcut writes are off in Sunclub Shortcuts settings."
        case .urlOpenActionsDisabled:
            return "URL open actions are off in Sunclub Shortcuts settings."
        case .urlWriteActionsDisabled:
            return "URL write actions are off in Sunclub Shortcuts settings."
        case let .unsupportedAction(action):
            return "Sunclub does not support the Shortcuts action \(action)."
        case .recordRequired:
            return "Log sunscreen for today before using this shortcut."
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
    case settingsSunscreen = "settings-sunscreen"
    case settingsHealth = "settings-health"
    case automation
    case uvForecast = "uv-forecast"
    case privacy
    case support
    case achievements

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
        case .settingsSunscreen:
            return .settingsSunscreen
        case .settingsHealth:
            return .settingsHealth
        case .automation:
            return .automation
        case .uvForecast:
            return .uvForecast
        case .privacy:
            return .privacy
        case .support:
            return .support
        case .achievements:
            return .weeklySummary
        case .healthReport:
            return .history
        case .productScanner:
            return .manualLog
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
        case .settingsSunscreen:
            return "Sunscreen"
        case .settingsHealth:
            return "Apple Health"
        case .automation:
            return "Shortcuts"
        case .uvForecast:
            return "UV Forecast"
        case .privacy:
            return "Privacy"
        case .support:
            return "Support"
        case .achievements:
            return "Insights"
        case .healthReport:
            return "History"
        case .productScanner:
            return "Log Sunscreen"
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
    case dailyUVBriefing
    case extremeUVAlert
    case iCloudSync
    case healthKit

    var title: String {
        switch self {
        case .travelTimeZone:
            return "Travel Time Zone"
        case .streakRisk:
            return "Evening Log Reminder"
        case .dailyUVBriefing:
            return "Daily UV Briefing"
        case .extremeUVAlert:
            return "Extreme UV Alert"
        case .iCloudSync:
            return "iCloud Sync"
        case .healthKit:
            return "Apple Health"
        }
    }
}

enum SunclubAutomationAction: Equatable {
    case logToday(spfLevel: Int?, notes: String?)
    case saveLog(day: Date?, time: ReminderTime?, dayPart: DayPart?, spfLevel: Int?, notes: String?)
    case reapply
    case status
    case timeSinceLastApplication
    case setReminder(kind: SunclubAutomationReminderKind, time: ReminderTime)
    case setReapply(enabled: Bool, intervalMinutes: Int?)
    case setToggle(SunclubAutomationToggle, enabled: Bool)
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
        case .open:
            return "open"
        case .exportBackup:
            return "export-backup"
        case .createSkinHealthReport:
            return "export-sunclub-history"
        case .createStreakCard:
            return "create-logged-days-card"
        }
    }

    var isWriteAction: Bool {
        switch self {
        case .logToday,
             .saveLog,
             .reapply,
             .setReminder,
             .setReapply,
             .setToggle:
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
        case let .saveLog(day, _, _, _, _):
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
    var route: String?
    var fileURL: URL?
    var fileTypeIdentifier: String?
    var lastAppliedAt: String?
    var minutesSinceLastApplication: Int?
    // Nil preserves existing follow-through for actions outside durable history mutations.
    var didChange: Bool?

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
    // App-owned buttons may remain tappable while WidgetKit refreshes their state.
    private static let appOwnedDuplicateWindow: TimeInterval = 60

    @MainActor
    private struct RuntimeContext {
        let historyService: SunclubHistoryService
        let mutations: SunclubMutationService
        let modelContext: ModelContext
        let growthStore: SunclubGrowthFeatureStoring
        let widgetStore: SunclubWidgetSnapshotStore
        let now: Date

        init(
            modelContext: ModelContext,
            growthStore: SunclubGrowthFeatureStoring,
            widgetStore: SunclubWidgetSnapshotStore,
            now: Date,
            historyService: SunclubHistoryService? = nil
        ) {
            let history = historyService ?? SunclubHistoryService(context: modelContext, calendar: SunclubAutomationRuntime.calendar)
            self.historyService = history
            self.mutations = SunclubMutationService(history: history)
            self.modelContext = modelContext
            self.growthStore = growthStore
            self.widgetStore = widgetStore
            self.now = now
        }
    }

    private struct LogDraft {
        var day: Date
        var time: ReminderTime?
        var dayPart: DayPart?
        var spfLevel: Int?
        var notes: String?
    }

    private typealias RecordMutation = SunclubMutationService.RecordRequest

    /// App-owned entry points choose against durable history at execution time.
    static func performAdaptiveLogStandalone(
        now: Date = Date(), requiresExistingRecord: Bool = false
    ) throws -> SunclubAutomationResult {
        do {
            let container = try SunclubModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: false)
            return try performAdaptiveLog(
                context: ModelContext(container), growthStore: SunclubGrowthFeatureStore.shared,
                now: now, requiresExistingRecord: requiresExistingRecord
            )
        } catch let error as SunclubAutomationError {
            throw error
        } catch {
            throw SunclubAutomationError.unavailable(error.localizedDescription)
        }
    }

    static func performAdaptiveLog(
        context: ModelContext,
        growthStore: SunclubGrowthFeatureStoring,
        widgetStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
        now: Date = Date(),
        historyService: SunclubHistoryService? = nil,
        requiresExistingRecord: Bool = false
    ) throws -> SunclubAutomationResult {
        let history = historyService ?? SunclubHistoryService(context: context, calendar: calendar)
        try history.bootstrapIfNeeded()
        try history.refreshProjectedState()
        let growthSettings = growthStore.load()
        try validate(
            action: .logToday(spfLevel: nil, notes: nil), invocation: .widget,
            settings: history.settings(), preferences: growthSettings.automation
        )
        let record = try history.record(for: now)
        if requiresExistingRecord, record == nil {
            throw SunclubAutomationError.recordRequired
        }
        // Ignore repeated taps while a widget or control is still refreshing.
        if let record {
            let lastApplied = max(record.verifiedAt, record.lastReappliedAt ?? record.verifiedAt)
            if now.timeIntervalSince(lastApplied) < appOwnedDuplicateWindow {
                var result = try statusResult(action: "reapply", historyService: history, now: now)
                result.message = "Sunscreen was already logged just now."
                result.didChange = false
                return result
            }
        }
        let runtimeContext = RuntimeContext(
            modelContext: context, growthStore: growthStore, widgetStore: widgetStore,
            now: now, historyService: history
        )
        if record != nil {
            return try logReapply(runtimeContext: runtimeContext, growthSettings: growthSettings)
        }
        return try logToday(spfLevel: nil, notes: nil, runtimeContext: runtimeContext, growthSettings: growthSettings)
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

    static func performStandalone(
        _ homeAction: HomeDailyPlanAction,
        invocation: SunclubAutomationInvocation,
        now: Date = Date()
    ) throws -> SunclubAutomationResult {
        switch homeAction {
        case .logToday:
            return try performStandalone(
                .logToday(spfLevel: nil, notes: nil),
                invocation: invocation,
                now: now
            )
        case .logReapply:
            return try performStandalone(.reapply, invocation: invocation, now: now)
        default:
            throw SunclubAutomationError.unsupportedAction(homeAction.rawValue)
        }
    }

    static func perform(
        _ action: SunclubAutomationAction,
        invocation: SunclubAutomationInvocation,
        context: ModelContext,
        growthStore: SunclubGrowthFeatureStoring,
        widgetStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore(),
        now: Date = Date()
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
            growthSettings: &growthSettings
        )
    }

    private static func performValidated(
        _ action: SunclubAutomationAction,
        runtimeContext: RuntimeContext,
        growthSettings: inout SunclubGrowthSettings
    ) throws -> SunclubAutomationResult {
        switch action {
        case let .logToday(spfLevel, notes):
            return try logToday(
                spfLevel: normalizedSPF(spfLevel),
                notes: notes,
                runtimeContext: runtimeContext,
                growthSettings: growthSettings
            )
        case let .saveLog(day, time, dayPart, spfLevel, notes):
            return try saveLog(
                LogDraft(
                    day: day ?? runtimeContext.now,
                    time: time,
                    dayPart: dayPart,
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
        case let .open(route):
            return SunclubAutomationResult(
                action: action.identifier,
                status: "opened",
                message: "Opened \(route.title).",
                route: route.rawValue
            )
        case .exportBackup:
            return try exportBackup(
                context: runtimeContext.modelContext,
                growthSettings: growthSettings,
                action: action.identifier
            )
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
        case .widget:
            break
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
        let existingRecord = try runtimeContext.historyService.record(for: day)
        let isUpdate = existingRecord != nil
        let records = try runtimeContext.historyService.records()
        let sunscreenProfileSPF = try runtimeContext.historyService.settings().sunscreenProfile?.spf
        let defaultInput: SunManualLogResolvedDefaults = existingRecord == nil
            ? SunManualLogDefaultResolver.oneTapDefaults(
                from: records,
                excluding: day,
                profileSPF: sunscreenProfileSPF,
                calendar: calendar
            )
            : .empty
        let resolvedNotes = notes == nil ? defaultInput.oneTapNotes : normalizedNotes(notes)
        let mutation = try upsertRecord(
            RecordMutation(
                day: day,
                verifiedAt: runtimeContext.now,
                method: .quickLog,
                spfLevel: spfLevel ?? defaultInput.spfLevel,
                notes: resolvedNotes,
                replaceOptionalFields: false,
                preserveExistingDuration: false,
                kind: .manualLog,
                summary: "Logged sunscreen from automation."
            ),
            runtimeContext: runtimeContext
        )
        return try finishChangedTimeline(
            batch: mutation.batch,
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
        let today = calendar.startOfDay(for: runtimeContext.now)
        guard dayStart <= today else {
            throw SunclubAutomationError.invalidInput("Cannot log future date.")
        }
        let existingTimestamp = try runtimeContext.historyService.record(for: dayStart)?.verifiedAt
        let resolvedTime = draft.time ?? draft.dayPart.map { ReminderTime(hour: $0.defaultHour, minute: 0) }
        let verifiedAt = verifiedAt(
            for: dayStart,
            time: resolvedTime,
            existingTimestamp: existingTimestamp,
            now: runtimeContext.now
        )
        let kind: SunclubChangeKind = existingTimestamp == nil ? .historyBackfill : .historyEdit
        let mutation = try upsertRecord(
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
            batch: mutation.batch,
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

        let batch = try runtimeContext.mutations.reapply(
            on: day, at: runtimeContext.now, summary: "Logged a reapply check-in from automation."
        )
        return try finishChangedTimeline(
            batch: batch,
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
        let batch = try runtimeContext.mutations.updateReminder(
            reminderSettings,
            summary: "Updated reminder time from automation."
        )
        return try finishChangedTimeline(
            batch: batch,
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
        let batch = try runtimeContext.mutations.updateReapply(
            enabled: enabled, intervalMinutes: interval, summary: "Updated reapply reminder from automation."
        )
        return try finishChangedTimeline(
            batch: batch,
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
            let batch = try runtimeContext.mutations.updateReminder(
                reminderSettings, summary: "Updated \(toggle.title) from automation."
            )
            return try finishChangedTimeline(
                batch: batch, action: "set-toggle", message: "\(toggle.title) is \(enabled ? "on" : "off").",
                historyService: runtimeContext.historyService, growthSettings: growthSettings,
                widgetStore: runtimeContext.widgetStore, now: runtimeContext.now
            )
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

    private static func exportBackup(
        context: ModelContext,
        growthSettings: SunclubGrowthSettings,
        action: String
    ) throws -> SunclubAutomationResult {
        let document = try SunclubBackupService().exportDocument(
            from: context,
            restorablePreferences: SunclubRestorablePreferences(growthSettings: growthSettings)
        )
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
            message: "Exported Sunclub history.",
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
            message: "Created logged-days card.",
            fileURL: artifact.fileURL,
            fileTypeIdentifier: UTType.png.identifier
        )
    }

    private static func upsertRecord(
        _ mutation: RecordMutation, runtimeContext: RuntimeContext
    ) throws -> SunclubMutationService.RecordResult {
        try runtimeContext.mutations.upsert(mutation)
    }

    private static func finishChangedTimeline(
        batch: SunclubChangeBatch?,
        action: String,
        message: String,
        recordDate: Date? = nil,
        historyService: SunclubHistoryService,
        growthSettings: SunclubGrowthSettings,
        widgetStore: SunclubWidgetSnapshotStore,
        now: Date
    ) throws -> SunclubAutomationResult {
        var result = try statusResult(action: action, historyService: historyService, now: now)
        result.didChange = false
        result.lastAppliedAt = nil
        result.minutesSinceLastApplication = nil
        result.message = message
        result.recordDate = recordDate.map(dateString)
        try SunclubMutationService(history: historyService).followThrough(batch) { _ in
            result = try finishChangedTimeline(
                action: action, message: message, recordDate: recordDate,
                historyService: historyService, growthSettings: growthSettings,
                widgetStore: widgetStore, now: now
            )
        }
        return result
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
        try syncSnapshot(historyService: historyService, widgetStore: widgetStore, now: now)

        let weekly = CalendarAnalytics.weeklyReport(records: recordedDays, now: now, calendar: calendar)
        return SunclubAutomationResult(
            action: action,
            status: "ok",
            message: message,
            currentStreak: CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar),
            longestStreak: settings.longestStreak,
            todayLogged: Set(recordedDays).contains(calendar.startOfDay(for: now)),
            weeklyApplied: weekly.appliedCount,
            recordDate: recordDate.map(dateString),
            didChange: true
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
        widgetStore: SunclubWidgetSnapshotStore,
        now: Date
    ) throws {
        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: try historyService.settings(),
            records: try historyService.records(),
            now: now,
            calendar: calendar
        )
        widgetStore.save(snapshot)
        guard !RuntimeEnvironment.isRunningTests else {
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
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
