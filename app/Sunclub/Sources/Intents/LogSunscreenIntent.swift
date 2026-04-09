import AppIntents

struct LogSunscreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Sunscreen"
    static let description = IntentDescription("Logs today's sunscreen check-in in Sunclub.")
    static let openAppWhenRun = false
    static let isDiscoverable = true

    static var parameterSummary: some ParameterSummary {
        Summary("Log sunscreen")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try SunclubQuickLogAction.performStandalone()
            let streakLabel = result.streak == 1 ? "1-day streak" : "\(result.streak)-day streak"
            return .result(dialog: IntentDialog("Logged sunscreen for today. You're on a \(streakLabel)."))
        } catch let error as SunclubQuickLogError {
            let dialog: IntentDialog
            switch error {
            case .onboardingRequired:
                dialog = IntentDialog("Open Sunclub once to finish setup before using outside-app logging.")
            case .unavailable:
                dialog = IntentDialog("Sunclub could not log sunscreen right now.")
            }
            return .result(dialog: dialog)
        } catch {
            return .result(dialog: IntentDialog("Sunclub could not log sunscreen right now."))
        }
    }
}

enum SunclubWidgetRouteIntentValue: String, AppEnum {
    case summary
    case history
    case updateToday

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sunclub Route")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .summary: "Summary",
        .history: "History",
        .updateToday: "Update Today"
    ]

    var route: SunclubWidgetRoute {
        SunclubWidgetRoute(rawValue: rawValue) ?? .summary
    }
}

struct OpenSunclubRouteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Sunclub Route"
    static let description = IntentDescription("Opens Sunclub to a widget-selected route.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    @Parameter(title: "Route")
    var route: SunclubWidgetRouteIntentValue

    init() {
        route = .summary
    }

    init(route: SunclubWidgetRoute) {
        self.route = SunclubWidgetRouteIntentValue(rawValue: route.rawValue) ?? .summary
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$route)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SunclubWidgetSnapshotStore().setPendingRoute(route.route.appRoute)
        return .result()
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
    }
}
