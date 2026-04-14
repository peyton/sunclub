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
    case accountability

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Widget Route")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .summary: "Summary",
        .history: "History",
        .updateToday: "Update Today",
        .accountability: "Accountability"
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
    case automation
    case achievements
    case friends
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
        .automation: "Automation",
        .achievements: "Achievements",
        .friends: "Friends",
        .healthReport: "Health Report",
        .productScanner: "SPF Scanner",
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
        case .automation:
            return .automation
        case .achievements:
            return .achievements
        case .friends:
            return .friends
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
        case .automation:
            self = .automation
        case .achievements:
            self = .achievements
        case .friends:
            self = .friends
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
        case .summary:
            self = .summary
        case .history:
            self = .history
        case .updateToday:
            self = .log
        case .accountability:
            self = .friends
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
    case liveUV
    case dailyUVBriefing
    case extremeUVAlert
    case iCloudSync
    case healthKit

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Toggle")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .travelTimeZone: "Travel Time Zone",
        .streakRisk: "Streak Risk",
        .liveUV: "Live UV",
        .dailyUVBriefing: "Daily UV Briefing",
        .extremeUVAlert: "Extreme UV Alert",
        .iCloudSync: "iCloud Sync",
        .healthKit: "HealthKit"
    ]

    var toggle: SunclubAutomationToggle {
        SunclubAutomationToggle(rawValue: rawValue) ?? .travelTimeZone
    }
}

struct SunclubFriendEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Friend")
    static let defaultQuery = SunclubFriendQuery()

    let id: UUID
    let name: String
    let status: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(status)")
    }

    init(snapshot: SunclubFriendSnapshot) {
        id = snapshot.id
        name = snapshot.name
        status = snapshot.hasLoggedToday
            ? "Logged today, \(snapshot.currentStreak)-day streak"
            : "Not logged today, \(snapshot.currentStreak)-day streak"
    }
}

private struct SendableGrowthFeatureStore: @unchecked Sendable {
    let store: SunclubGrowthFeatureStoring
}

struct SunclubFriendQuery: EntityQuery {
    private let growthStore: SendableGrowthFeatureStore

    init() {
        growthStore = SendableGrowthFeatureStore(store: SunclubGrowthFeatureStore.shared)
    }

    init(growthStore: SunclubGrowthFeatureStoring) {
        self.growthStore = SendableGrowthFeatureStore(store: growthStore)
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [SunclubFriendEntity] {
        let identifierSet = Set(identifiers)
        return SunclubAutomationRuntime.friends(growthStore: growthStore.store)
            .filter { identifierSet.contains($0.id) }
            .map(SunclubFriendEntity.init(snapshot:))
    }

    @MainActor
    func suggestedEntities() async throws -> [SunclubFriendEntity] {
        SunclubAutomationRuntime.friends(growthStore: growthStore.store).map(SunclubFriendEntity.init(snapshot:))
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
    static let description = IntentDescription("Gets today's Sunclub status, streak, and weekly applied count.")
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
                "Current streak: \(result.currentStreak ?? 0).",
                "This week: \(result.weeklyApplied ?? 0) days."
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
    static let title: LocalizedStringResource = "Create Skin Health Report"
    static let description = IntentDescription("Creates a PDF skin health report from Sunclub sunscreen history.")
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
        Summary("Create skin health report")
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
    static let title: LocalizedStringResource = "Create Streak Card"
    static let description = IntentDescription("Creates a Sunclub streak card image.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    static var parameterSummary: some ParameterSummary {
        Summary("Create streak card")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.createStreakCard)
            let file = try SunclubIntentSupport.file(from: result, fallbackType: .png)
            return .result(value: file, dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            let dialog = SunclubIntentSupport.dialog(for: error)
            return .result(value: IntentFile(data: Data(), filename: "sunclub-streak-card-error.txt", type: .plainText), dialog: dialog)
        }
    }
}

struct ImportFriendInviteIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Friend Invite"
    static let description = IntentDescription("Imports a Sunclub accountability friend invite code.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Invite Code")
    var code: String

    init() {
        code = ""
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Import friend invite")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.importFriend(code: code))
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
        }
    }
}

struct PokeFriendIntent: AppIntent {
    static let title: LocalizedStringResource = "Poke Friend"
    static let description = IntentDescription("Sends a local Sunclub accountability poke to a friend.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    @Parameter(title: "Friend")
    var friend: SunclubFriendEntity

    init() {}

    static var parameterSummary: some ParameterSummary {
        Summary("Poke \(\.$friend)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubIntentSupport.perform(.pokeFriend(id: friend.id))
            return .result(dialog: IntentDialog(stringLiteral: result.message))
        } catch {
            return .result(dialog: SunclubIntentSupport.dialog(for: error))
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
                "Open automation in \(.applicationName)",
                "Show \(.applicationName) automation"
            ],
            shortTitle: "Open Automation",
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
                "Create \(.applicationName) skin report",
                "Make a skin health report in \(.applicationName)"
            ],
            shortTitle: "Skin Report",
            systemImageName: "doc.richtext.fill"
        )
        AppShortcut(
            intent: CreateStreakCardIntent(),
            phrases: [
                "Create \(.applicationName) streak card",
                "Make a streak card in \(.applicationName)"
            ],
            shortTitle: "Streak Card",
            systemImageName: "photo.fill"
        )
    }
}
