import AppIntents
import Foundation
import UniformTypeIdentifiers

private enum SunclubIntentSupport {
    @MainActor
    static func perform(_ action: SunclubAutomationAction) throws -> SunclubAutomationResult {
        try SunclubAutomationRuntime.performStandalone(action, invocation: .shortcut)
    }

    static func dialog(for error: Error) -> IntentDialog {
        if let automationError = error as? SunclubAutomationError {
            return IntentDialog(stringLiteral: automationError.localizedDescription)
        }
        return IntentDialog("Sunclub could not finish that automation right now.")
    }

    static func file(from result: SunclubAutomationResult, fallbackType: UTType) throws -> IntentFile {
        guard let fileURL = result.fileURL else {
            throw SunclubAutomationError.unavailable("Sunclub did not create a file for this automation.")
        }

        let type = result.fileTypeIdentifier.flatMap(UTType.init) ?? fallbackType
        var file = IntentFile(fileURL: fileURL, filename: fileURL.lastPathComponent, type: type)
        file.removedOnCompletion = true
        return file
    }

    static func time(from date: Date?) -> ReminderTime? {
        guard let date else { return nil }
        let calendar = Calendar.current
        return ReminderTime(
            hour: calendar.component(.hour, from: date),
            minute: calendar.component(.minute, from: date)
        )
    }

    static func defaultReminderDate(hour: Int = 8, minute: Int = 0) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

enum SunclubWidgetRouteIntentValue: String, AppEnum {
    case summary
    case history
    case updateToday

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Widget Route")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .summary: "Summary",
        .history: "History",
        .updateToday: "Update Today",
    ]

    var route: SunclubWidgetRoute {
        SunclubWidgetRoute(rawValue: rawValue) ?? .summary
    }
}

enum SunclubAutomationRouteIntentValue: String, AppEnum {
    case home
    case log
    case reapply
    case summary
    case history
    case settings
    case settingsSunscreen
    case settingsHealth
    case automation
    case uvForecast
    case privacy
    case support
    case achievements

    case healthReport
    case productScanner
    case recovery

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Route")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .home: "Home",
        .log: "Today's Log",
        .reapply: "Reapply",
        .summary: "Weekly Summary",
        .history: "History",
        .settings: "Settings",
        .settingsSunscreen: "Sunscreen",
        .settingsHealth: "Apple Health",
        .automation: "Shortcuts",
        .uvForecast: "UV Forecast",
        .privacy: "Privacy",
        .support: "Support",
        .achievements: "Insights",
        .healthReport: "History",
        .productScanner: "Log Sunscreen",
        .recovery: "Recovery"
    ]

    var route: SunclubAutomationRoute {
        switch self {
        case .home:
            return .home
        case .log:
            return .log
        case .reapply:
            return .reapply
        case .summary:
            return .summary
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
            return .achievements
        case .healthReport:
            return .healthReport
        case .productScanner:
            return .productScanner
        case .recovery:
            return .recovery
        }
    }

    init(route: SunclubAutomationRoute) {
        switch route {
        case .home:
            self = .home
        case .log:
            self = .log
        case .reapply:
            self = .reapply
        case .summary:
            self = .summary
        case .history:
            self = .history
        case .settings:
            self = .settings
        case .settingsSunscreen:
            self = .settingsSunscreen
        case .settingsHealth:
            self = .settingsHealth
        case .automation:
            self = .automation
        case .uvForecast:
            self = .uvForecast
        case .privacy:
            self = .privacy
        case .support:
            self = .support
        case .achievements:
            self = .achievements
        case .healthReport:
            self = .healthReport
        case .productScanner:
            self = .productScanner
        case .recovery:
            self = .recovery
        }
    }

    init(widgetRoute: SunclubWidgetRoute) {
        switch widgetRoute {
        case .today:
            self = .home
        case .settings:
            self = .settings
        case .summary:
            self = .summary
        case .history:
            self = .history
        case .updateToday:
            self = .log
        }
    }
}

enum SunclubReminderKindIntentValue: String, AppEnum {
    case weekday
    case weekend

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Reminder")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .weekday: "Weekday",
        .weekend: "Weekend"
    ]

    var kind: SunclubAutomationReminderKind {
        SunclubAutomationReminderKind(rawValue: rawValue) ?? .weekday
    }
}

enum SunclubToggleIntentValue: String, AppEnum {
    case travelTimeZone
    case streakRisk
    case dailyUVBriefing
    case extremeUVAlert
    case iCloudSync
    case healthKit

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Toggle")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .travelTimeZone: "Travel Time Zone",
        .streakRisk: "Evening Log Reminder",
        .dailyUVBriefing: "Daily UV Briefing",
        .extremeUVAlert: "Extreme UV Alert",
        .iCloudSync: "iCloud Sync",
        .healthKit: "HealthKit"
    ]

    var toggle: SunclubAutomationToggle {
        switch self {
        case .travelTimeZone:
            return .travelTimeZone
        case .streakRisk:
            return .streakRisk
        case .dailyUVBriefing:
            return .dailyUVBriefing
        case .extremeUVAlert:
            return .extremeUVAlert
        case .iCloudSync:
            return .iCloudSync
        case .healthKit:
            return .healthKit
        }
    }
}

struct LogSunscreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Sunscreen"
    static let description = IntentDescription("Logs today's sunscreen check-in in Sunclub.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "SPF", description: "Optional SPF level.")
    var spfLevel: Int?

    @Parameter(title: "Notes", description: "Optional sunscreen notes.")
    var notes: String?

    init() {
        spfLevel = nil
        notes = nil
    }

    init(spfLevel: Int? = nil, notes: String? = nil) {
        self.spfLevel = spfLevel
        self.notes = notes
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log sunscreen")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.logToday(spfLevel: spfLevel, notes: notes))
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
        }
    }
}

/// App-owned widget/control action. Public Shortcut intents retain their fixed meaning.
/// LiveActivityIntent runs in the app process so a widget tap can update its active timer.
struct LogSunscreenWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log sunscreen"
    static let description = IntentDescription("Logs sunscreen or a reapplication using today's current history.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        do {
            let result = try SunclubAutomationRuntime.performAdaptiveLogStandalone()
            if result.didChange == true {
                let snapshot = SunclubWidgetSnapshotStore().load()
                let now = Date()
                await SunclubLoggingReminderBridge.sync(snapshot: snapshot, now: now)
                await SunclubLiveActivitySnapshotBridge.updateExisting(
                    snapshot: SunclubWidgetSnapshotStore().load(), now: Date()
                )
            }
        } catch SunclubAutomationError.onboardingRequired {
            SunclubWidgetSnapshotStore().setPendingRoute(.home)
            return .result(opensIntent: OpenSunclubRouteIntent(route: SunclubAutomationRoute.home))
        }
        return .result()
    }
}

struct LogReapplicationLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log reapplication"
    static let description = IntentDescription("Logs a reapplication for today's sunscreen record.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        do {
            let result = try SunclubAutomationRuntime.performAdaptiveLogStandalone(requiresExistingRecord: true)
            if result.didChange == true {
                let snapshot = SunclubWidgetSnapshotStore().load()
                let now = Date()
                await SunclubLoggingReminderBridge.sync(snapshot: snapshot, now: now)
                await SunclubLiveActivitySnapshotBridge.updateExisting(
                    snapshot: SunclubWidgetSnapshotStore().load(), now: Date()
                )
            }
        } catch SunclubAutomationError.onboardingRequired {
            SunclubWidgetSnapshotStore().setPendingRoute(.home)
            return .result(opensIntent: OpenSunclubRouteIntent(route: SunclubAutomationRoute.home))
        } catch SunclubAutomationError.recordRequired {
            SunclubWidgetSnapshotStore().setPendingRoute(.home)
            return .result(opensIntent: OpenSunclubRouteIntent(route: SunclubAutomationRoute.home))
        }
        return .result()
    }
}

struct LogTodayWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Today"
    static let description = IntentDescription("Logs today's sunscreen check-in from a Sunclub widget.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try SunclubAutomationRuntime.performStandalone(
            .logToday(spfLevel: nil, notes: nil),
            invocation: .widget
        )
        return .result()
    }
}

struct LogReapplyWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Reapply"
    static let description = IntentDescription("Logs a sunscreen reapply check-in from a Sunclub widget.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = try SunclubAutomationRuntime.performStandalone(.reapply, invocation: .widget)
        return .result()
    }
}

struct SaveSunscreenLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Sunscreen Log"
    static let description = IntentDescription("Saves or updates a Sunclub sunscreen log for today or a selected date.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Date", description: "Optional log date. Defaults to today.")
    var day: Date?

    @Parameter(title: "Time", description: "Optional application time.")
    var time: Date?

    @Parameter(title: "SPF", description: "Optional SPF level.")
    var spfLevel: Int?

    @Parameter(title: "Notes", description: "Optional sunscreen notes.")
    var notes: String?

    init() {
        day = nil
        time = nil
        spfLevel = nil
        notes = nil
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Save sunscreen log")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(
                .saveLog(
                    day: day,
                    time: SunclubIntentSupport.time(from: time),
                    dayPart: nil,
                    spfLevel: spfLevel,
                    notes: notes
                )
            )
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
        }
    }
}

struct LogReapplyIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Reapply"
    static let description = IntentDescription("Logs a reapply check-in for today's Sunclub sunscreen record.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    static var parameterSummary: some ParameterSummary {
        Summary("Log reapply")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.reapply)
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
        }
    }
}

struct GetSunclubStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Sunclub Status"
    static let description = IntentDescription("Gets today's Sunclub status, weekly logged count, and reapply timing.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    static var parameterSummary: some ParameterSummary {
        Summary("Get Sunclub status")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.status)
            var statusLines = [
                result.message,
                "This week: \(result.weeklyApplied ?? 0) days logged."
            ]
            if let minutesSinceLastApplication = result.minutesSinceLastApplication {
                statusLines.append("Last application: \(minutesSinceLastApplication) minutes ago.")
            }
            let status = statusLines.joined(separator: " ")
            return .result(value: status, dialog: IntentDialog(stringLiteral: status))
        } catch {
            let dialog = SunclubIntentSupport.dialog(for: error)
            return .result(value: "Sunclub could not finish that automation right now.", dialog: dialog)
        }
    }
}

struct GetTimeSinceLastSunscreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Time Since Last Sunscreen"
    static let description = IntentDescription("Gets how long it has been since the last Sunclub sunscreen application or reapply.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    static var parameterSummary: some ParameterSummary {
        Summary("Get time since last sunscreen")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.timeSinceLastApplication)
            return .result(value: result.message, dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            let dialog = SunclubIntentSupport.dialog(for: error)
            return .result(value: "Sunclub could not finish that automation right now.", dialog: dialog)
        }
    }
}

struct OpenSunclubRouteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Sunclub"
    static let description = IntentDescription("Opens Sunclub to a selected screen.")
    static let openAppWhenRun = true
    static let isDiscoverable = true

    @Parameter(title: "Route")
    var route: SunclubAutomationRouteIntentValue

    init() {
        route = .home
    }

    init(route: SunclubWidgetRoute) {
        self.route = SunclubAutomationRouteIntentValue(widgetRoute: route)
    }

    init(route: SunclubAutomationRoute) {
        self.route = SunclubAutomationRouteIntentValue(route: route)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$route)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolvedRoute = route.route
        SunclubWidgetSnapshotStore().setPendingRoute(resolvedRoute.appRoute)
        return .result(dialog: IntentDialog("Opening Sunclub."))
    }
}

struct SetSunclubReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Sunclub Reminder"
    static let description = IntentDescription("Sets a weekday or weekend sunscreen reminder time.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Kind")
    var kind: SunclubReminderKindIntentValue

    @Parameter(title: "Time")
    var time: Date

    init() {
        kind = .weekday
        time = SunclubIntentSupport.defaultReminderDate()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$kind) reminder")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let reminderTime = SunclubIntentSupport.time(from: time) ?? ReminderTime(hour: 8, minute: 0)
            let result = try SunclubIntentSupport.perform(.setReminder(kind: kind.kind, time: reminderTime))
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
        }
    }
}

struct SetSunclubReapplyIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Sunclub Reapply Reminder"
    static let description = IntentDescription("Turns the reapply reminder on or off and optionally updates the interval.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Enabled")
    var enabled: Bool

    @Parameter(title: "Interval Minutes", description: "Optional interval from 30 to 480 minutes.")
    var intervalMinutes: Int?

    init() {
        enabled = true
        intervalMinutes = nil
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set reapply reminder")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(
                .setReapply(enabled: enabled, intervalMinutes: intervalMinutes)
            )
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
        }
    }
}

struct SetSunclubToggleIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Sunclub Toggle"
    static let description = IntentDescription("Turns an automatable Sunclub setting on or off.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Toggle")
    var toggle: SunclubToggleIntentValue

    @Parameter(title: "Enabled")
    var enabled: Bool

    init() {
        toggle = .travelTimeZone
        enabled = true
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$toggle)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.setToggle(toggle.toggle, enabled: enabled))
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
        }
    }
}

struct ExportSunclubBackupIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Sunclub Backup"
    static let description = IntentDescription("Exports a Sunclub backup file.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    static var parameterSummary: some ParameterSummary {
        Summary("Export Sunclub backup")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.exportBackup)
            let file = try SunclubIntentSupport.file(from: result, fallbackType: .json)
            return .result(value: file, dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            let dialog = SunclubIntentSupport.dialog(for: error)
            return .result(value: IntentFile(data: Data(), filename: "sunclub-backup-error.txt", type: .plainText), dialog: dialog)
        }
    }
}

struct CreateSkinHealthReportIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Sunclub History"
    static let description = IntentDescription("Creates a PDF export from Sunclub sunscreen history.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Start Date", description: "Optional report start date.")
    var startDate: Date?

    @Parameter(title: "End Date", description: "Optional report end date.")
    var endDate: Date?

    init() {
        startDate = nil
        endDate = nil
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Export Sunclub history")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(
                .createSkinHealthReport(start: startDate, end: endDate)
            )
            let file = try SunclubIntentSupport.file(from: result, fallbackType: .pdf)
            return .result(value: file, dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            let dialog = SunclubIntentSupport.dialog(for: error)
            return .result(value: IntentFile(data: Data(), filename: "sunclub-report-error.txt", type: .plainText), dialog: dialog)
        }
    }
}

struct CreateStreakCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Logged Days Card"
    static let description = IntentDescription("Creates a Sunclub logged-days image.")
    static let openAppWhenRun = false
    static let isDiscoverable = false

    static var parameterSummary: some ParameterSummary {
        Summary("Create logged-days card")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.createStreakCard)
            let file = try SunclubIntentSupport.file(from: result, fallbackType: .png)
            return .result(value: file, dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            let dialog = SunclubIntentSupport.dialog(for: error)
            return .result(value: IntentFile(data: Data(), filename: "sunclub-logged-days-error.txt", type: .plainText), dialog: dialog)
        }
    }
}

struct SunclubAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSunscreenIntent(),
            phrases: [
                "Log sunscreen in \(.applicationName)",
                "Log today's sunscreen in \(.applicationName)"
            ],
            shortTitle: "Log Sunscreen",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: LogReapplyIntent(),
            phrases: [
                "Log reapply in \(.applicationName)",
                "Reapply sunscreen in \(.applicationName)"
            ],
            shortTitle: "Log Reapply",
            systemImageName: "arrow.clockwise.circle.fill"
        )
        AppShortcut(
            intent: GetSunclubStatusIntent(),
            phrases: [
                "Get \(.applicationName) status",
                "Check sunscreen status in \(.applicationName)"
            ],
            shortTitle: "Sunclub Status",
            systemImageName: "checkmark.seal.fill"
        )
        AppShortcut(
            intent: GetTimeSinceLastSunscreenIntent(),
            phrases: [
                "How long since sunscreen in \(.applicationName)",
                "Time since sunscreen in \(.applicationName)"
            ],
            shortTitle: "Last Sunscreen",
            systemImageName: "clock.fill"
        )
        AppShortcut(
            intent: OpenSunclubRouteIntent(route: .automation),
            phrases: [
                "Open Shortcuts in \(.applicationName)",
                "Show \(.applicationName) Shortcuts"
            ],
            shortTitle: "Open Shortcuts",
            systemImageName: "wand.and.stars"
        )
        AppShortcut(
            intent: ExportSunclubBackupIntent(),
            phrases: [
                "Export \(.applicationName) backup",
                "Back up \(.applicationName)"
            ],
            shortTitle: "Export Backup",
            systemImageName: "externaldrive.fill"
        )
        AppShortcut(
            intent: CreateSkinHealthReportIntent(),
            phrases: [
                "Export \(.applicationName) history",
                "Make a history export in \(.applicationName)"
            ],
            shortTitle: "History Export",
            systemImageName: "doc.richtext.fill"
        )
    }
}
