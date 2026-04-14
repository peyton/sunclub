import SwiftUI
import UIKit

struct AutomationView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var feedbackMessage = "Ready"

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Automation", showsBack: true, onBack: {
                    router.goBack()
                })

                AutomationHeroCard()

                AutomationSettingsPanel(
                    style: .full,
                    feedbackMessage: $feedbackMessage,
                    openURL: openURL
                )

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }
}

struct AutomationSettingsPanel: View {
    enum Style {
        case full
        case settings
    }

    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    let style: Style
    @Binding var feedbackMessage: String
    let openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if style == .settings {
                Text("Automation")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }

            preferenceSection
            shortcutSection
            shortcutOnlySection
            urlSection
            callbackSection

            Text(feedbackMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("automation.feedback")

            if style == .settings {
                Button("Open Automation Catalog") {
                    router.open(.automation)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.automation.openCatalog")
            }
        }
    }

    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Automation Access",
                detail: "URL actions can be called by other apps. Turn off writes if you only want links to open Sunclub screens."
            )

            preferenceToggle(
                title: "Allow Shortcut writes",
                detail: "Shortcuts can log sunscreen, reapply, update reminders, and change supported toggles.",
                keyPath: \.shortcutWritesEnabled,
                accessibilityIdentifier: "automation.shortcutWritesToggle"
            )

            preferenceToggle(
                title: "Allow URL open actions",
                detail: "Links can open Sunclub to supported screens.",
                keyPath: \.urlOpenActionsEnabled,
                accessibilityIdentifier: "automation.urlOpenToggle"
            )

            preferenceToggle(
                title: "Allow URL write actions",
                detail: "Links can log sunscreen, reapply, import invites, open Friends for a message nudge, and update supported settings.",
                keyPath: \.urlWriteActionsEnabled,
                accessibilityIdentifier: "automation.urlWriteToggle"
            )

            preferenceToggle(
                title: "Include callback result details",
                detail: "x-callback-url responses can include streak, record date, weekly count, and friend names.",
                keyPath: \.callbackResultDetailsEnabled,
                accessibilityIdentifier: "automation.callbackDetailsToggle"
            )
        }
        .padding(18)
        .background(cardBackground)
        .accessibilityIdentifier("automation.preferences")
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Apple Shortcuts",
                detail: "Create automations from Shortcuts, Siri, Control Center, widgets, and other intent surfaces."
            )

            ForEach(shortcutRows) { row in
                AutomationActionRow(row: row)
            }

            Button("Open Shortcuts") {
                if let url = URL(string: "shortcuts://") {
                    openURL(url)
                }
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityIdentifier("automation.openShortcuts")
        }
        .padding(18)
        .background(cardBackground)
        .accessibilityIdentifier("automation.shortcuts")
    }

    private var shortcutOnlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Shortcut File Actions",
                detail: "These return files to Shortcuts. They are not direct URL actions because the file needs a system handoff."
            )

            ForEach(shortcutOnlyRows) { row in
                AutomationActionRow(row: row)
            }
        }
        .padding(18)
        .background(cardBackground)
        .accessibilityIdentifier("automation.shortcutFileActions")
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "URL Actions",
                detail: "Use \(SunclubRuntimeConfiguration.urlScheme)://automation/... for direct links."
            )

            ForEach(urlExamples) { example in
                AutomationExampleCard(
                    example: example,
                    feedbackMessage: $feedbackMessage,
                    openURL: openURL
                )
            }
        }
        .padding(18)
        .background(cardBackground)
        .accessibilityIdentifier("automation.urlExamples")
    }

    private var callbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "x-callback-url",
                detail: "Use x-success and x-error to return status to another app."
            )

            ForEach(callbackExamples) { example in
                AutomationExampleCard(
                    example: example,
                    feedbackMessage: $feedbackMessage,
                    openURL: openURL
                )
            }
        }
        .padding(18)
        .background(cardBackground)
        .accessibilityIdentifier("automation.callbackExamples")
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func preferenceToggle(
        title: String,
        detail: String,
        keyPath: WritableKeyPath<SunclubAutomationPreferences, Bool>,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: preferenceBinding(keyPath)) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.sun)
            .accessibilityIdentifier(accessibilityIdentifier)

            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.controlFill.opacity(0.58))
        )
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<SunclubAutomationPreferences, Bool>) -> Binding<Bool> {
        Binding {
            appState.automationPreferences[keyPath: keyPath]
        } set: { newValue in
            var preferences = appState.automationPreferences
            preferences[keyPath: keyPath] = newValue
            appState.updateAutomationPreferences(preferences)
        }
    }

    private var shortcutRows: [AutomationActionRow.Model] {
        [
            AutomationActionRow.Model(title: "Log Sunscreen", detail: "Optional SPF and notes."),
            AutomationActionRow.Model(title: "Get Sunclub Status", detail: "Returns today, streak, and weekly count."),
            AutomationActionRow.Model(title: "Time Since Last Sunscreen", detail: "Returns minutes since the last log or reapply."),
            AutomationActionRow.Model(title: "Log Reapply", detail: "Adds a reapply check-in for today's record."),
            AutomationActionRow.Model(title: "Save Sunscreen Log", detail: "Today or a chosen date and time."),
            AutomationActionRow.Model(title: "Set Sunclub Reminder", detail: "Weekday or weekend reminder time."),
            AutomationActionRow.Model(title: "Set Sunclub Reapply Reminder", detail: "Turns reapply reminders on or off and can update the interval."),
            AutomationActionRow.Model(title: "Set Sunclub Toggle", detail: "Travel, UV, iCloud, Health, and alert toggles."),
            AutomationActionRow.Model(title: "Import Friend Invite", detail: "Adds a friend from an invite code."),
            AutomationActionRow.Model(title: "Poke Friend", detail: "Uses the friend picker from Shortcuts and opens Friends for a message nudge.")
        ]
    }

    private var shortcutOnlyRows: [AutomationActionRow.Model] {
        [
            AutomationActionRow.Model(title: "Export Sunclub Backup", detail: "Returns a backup file.", symbolName: "externaldrive.fill"),
            AutomationActionRow.Model(title: "Create Skin Health Report", detail: "Returns a PDF report.", symbolName: "doc.richtext.fill"),
            AutomationActionRow.Model(title: "Create Streak Card", detail: "Returns a shareable image.", symbolName: "photo.fill")
        ]
    }

    private var urlExamples: [AutomationExample] {
        [
            AutomationExample(
                id: "logToday",
                title: "Log Today",
                detail: "Log sunscreen with SPF and notes.",
                urlString: "\(scheme)://automation/log-today?spf=50&notes=Beach%20bag"
            ),
            AutomationExample(
                id: "status",
                title: "Status",
                detail: "Return today's status to the caller.",
                urlString: "\(scheme)://automation/status"
            ),
            AutomationExample(
                id: "timeSinceLastApplication",
                title: "Time Since Last Sunscreen",
                detail: "Return minutes since the last log or reapply.",
                urlString: "\(scheme)://automation/time-since-last-application"
            ),
            AutomationExample(
                id: "openAutomation",
                title: "Open Automation",
                detail: "Open this catalog.",
                urlString: "\(scheme)://automation/open?route=automation"
            ),
            AutomationExample(
                id: "openSettings",
                title: "Open Settings",
                detail: "Open settings without allowing URL writes.",
                urlString: "\(scheme)://automation/open?route=settings"
            ),
            AutomationExample(
                id: "saveLog",
                title: "Save Log",
                detail: "Backfill or update a day.",
                urlString: "\(scheme)://automation/save-log?date=2026-04-13&time=08:30&spf=50&notes=Morning"
            ),
            AutomationExample(
                id: "reapply",
                title: "Reapply",
                detail: "Add a reapply check-in.",
                urlString: "\(scheme)://automation/reapply"
            ),
            AutomationExample(
                id: "setReminder",
                title: "Set Reminder",
                detail: "Move a weekday reminder.",
                urlString: "\(scheme)://automation/set-reminder?kind=weekday&time=08:30"
            ),
            AutomationExample(
                id: "setReapply",
                title: "Set Reapply",
                detail: "Turn on the reapply reminder and set an interval.",
                urlString: "\(scheme)://automation/set-reapply?enabled=true&interval=90"
            ),
            AutomationExample(
                id: "setToggle",
                title: "Set Toggle",
                detail: "Turn on daily UV briefing.",
                urlString: "\(scheme)://automation/set-toggle?name=dailyUVBriefing&enabled=true"
            ),
            AutomationExample(
                id: "importFriend",
                title: "Import Friend Invite",
                detail: "Paste a real invite code before using this.",
                urlString: "\(scheme)://automation/import-friend?code=PASTE_INVITE_CODE",
                canTest: false
            ),
            AutomationExample(
                id: "pokeFriend",
                title: "Poke Friend",
                detail: "Use a saved friend UUID from your own automation.",
                urlString: "\(scheme)://automation/poke-friend?id=FRIEND_UUID",
                canTest: false
            )
        ]
    }

    private var callbackExamples: [AutomationExample] {
        [
            AutomationExample(
                id: "callbackStatus",
                title: "Status Callback",
                detail: "Returns action, status, and status fields.",
                urlString: "\(scheme)://x-callback-url/status?x-success=shortcuts://callback&x-error=shortcuts://callback"
            ),
            AutomationExample(
                id: "callbackLastApplication",
                title: "Last Application Callback",
                detail: "Returns the last application time and minutes-since field when details are on.",
                urlString: "\(scheme)://x-callback-url/time-since-last-application?x-success=shortcuts://callback&x-error=shortcuts://callback"
            ),
            AutomationExample(
                id: "callbackLogToday",
                title: "Log Callback",
                detail: "Returns recordDate, todayLogged, and streak fields when details are on.",
                urlString: "\(scheme)://x-callback-url/log-today?spf=50&x-success=shortcuts://callback&x-error=shortcuts://callback"
            ),
            AutomationExample(
                id: "callbackOpen",
                title: "Open Callback",
                detail: "UI-only actions return status=opened after routing.",
                urlString: "\(scheme)://x-callback-url/open?route=history&x-success=shortcuts://callback&x-error=shortcuts://callback"
            )
        ]
    }

    private var scheme: String {
        SunclubRuntimeConfiguration.urlScheme
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
    }
}

private struct AutomationHeroCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Choose what other apps can do.")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Logging and status can run from Shortcuts or URLs. Review-heavy flows open Sunclub first.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .sunGlassCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("automation.hero")
    }
}

private struct AutomationActionRow: View {
    struct Model: Identifiable {
        let title: String
        let detail: String
        let symbolName: String

        var id: String { title }

        init(title: String, detail: String, symbolName: String = "checkmark.circle.fill") {
            self.title = title
            self.detail = detail
            self.symbolName = symbolName
        }
    }

    let row: Model

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppPalette.success)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(row.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AutomationExample: Identifiable {
    let id: String
    let title: String
    let detail: String
    let urlString: String
    let canTest: Bool

    init(
        id: String,
        title: String,
        detail: String,
        urlString: String,
        canTest: Bool = true
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.urlString = urlString
        self.canTest = canTest
    }
}

private struct AutomationExampleCard: View {
    let example: AutomationExample
    @Binding var feedbackMessage: String
    let openURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(example.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(example.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(example.urlString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppPalette.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppPalette.editorFill.opacity(0.82))
                )
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("automation.example.\(example.id).url")

            HStack(spacing: 10) {
                Button("Copy") {
                    UIPasteboard.general.string = example.urlString
                    feedbackMessage = "Copied \(example.title)."
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityLabel("Copy \(example.title) URL")
                .accessibilityIdentifier("automation.example.\(example.id).copy")

                if example.canTest {
                    Button("Test") {
                        guard let url = URL(string: example.urlString) else {
                            feedbackMessage = "That example URL is invalid."
                            return
                        }
                        feedbackMessage = "Opened \(example.title)."
                        openURL(url)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityLabel("Test \(example.title) URL")
                    .accessibilityIdentifier("automation.example.\(example.id).test")
                } else {
                    Text("Paste your own value before testing.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("automation.example.\(example.id).requiresValue")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.controlFill.opacity(0.58))
        )
        .accessibilityElement(children: .contain)
    }
}
