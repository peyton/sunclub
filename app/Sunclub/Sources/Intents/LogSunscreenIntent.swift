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
