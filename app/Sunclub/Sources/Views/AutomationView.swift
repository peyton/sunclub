import SwiftUI
import UIKit

struct AutomationView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var feedbackMessage = ""

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.wideReadable,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Shortcuts & Automation", showsBack: true, onBack: {
                    router.goBack()
                })

                Button {
                    openURL(SunclubWebLinks.automationDocs)
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        SunIcon.book.image.resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                        AppText("Shortcuts Guide", style: .bodyMedium)
                        Spacer(minLength: AppSpacing.xxs)
                        SunIcon.chevronRight.image.resizable().scaledToFit()
                            .frame(width: 16, height: 16)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(AppColor.Text.secondary)
                    .padding(.vertical, AppSpacing.xs)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("automation.docs")

                AutomationSettingsPanel(
                    style: .full,
                    feedbackMessage: $feedbackMessage,
                    openURL: openURL
                )

                Spacer(minLength: 0)
            }
        }
        .sunNavigationBarCompatibility()
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
                preferenceSection
            } else {
                shortcutSection
                shortcutOnlySection

                DisclosureGroup("Advanced link examples") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        urlSection
                        callbackSection
                    }
                    .padding(.top, AppSpacing.sm)
                }
                .font(AppTextStyle.bodyMedium.font)
                .accessibilityIdentifier("automation.advanced")

                Button("Automation permissions") {
                    if router.path.dropLast().last == .settingsShortcuts {
                        router.goBack()
                    } else {
                        router.push(.settingsShortcuts)
                    }
                }
                .sunGlassSecondaryButton()
                .accessibilityIdentifier("automation.openPermissions")
            }

            if !feedbackMessage.isEmpty {
                Text(feedbackMessage)
                    .font(AppFont.rounded(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("automation.feedback")
            }

            if style == .settings {
                Button("Open Shortcuts Catalog") {
                    if router.path.dropLast().last == .automation {
                        router.goBack()
                    } else {
                        router.push(.automation)
                    }
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.automation.openCatalog")
            }
        }
    }

    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Permissions",
                detail: "Choose which outside actions can open Sunclub or save changes."
            )

            preferenceToggle(
                title: "Allow Shortcut writes",
                detail: "Let Apple Shortcuts log sunscreen for you.",
                keyPath: \.shortcutWritesEnabled,
                accessibilityIdentifier: "automation.shortcutWritesToggle"
            )

            preferenceToggle(
                title: "Open Sunclub from links",
                detail: "Let trusted links open Sunclub screens.",
                keyPath: \.urlOpenActionsEnabled,
                accessibilityIdentifier: "automation.urlOpenToggle"
            )

            preferenceToggle(
                title: "Save changes from links",
                detail: "Let trusted links save logs or reminder settings.",
                keyPath: \.urlWriteActionsEnabled,
                accessibilityIdentifier: "automation.urlWriteToggle"
            )

            preferenceToggle(
                title: "Share result details",
                detail: "Send simple success or status details back to the calling app.",
                keyPath: \.callbackResultDetailsEnabled,
                accessibilityIdentifier: "automation.callbackDetailsToggle"
            )
        }
        .padding(18)
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 0.82,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
        .accessibilityIdentifier("automation.preferences")
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Apple Shortcuts",
                detail: "Use Siri, Control Center, widgets, and Shortcuts to log or check status."
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
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 0.82,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
        .accessibilityIdentifier("automation.shortcuts")
    }

    private var shortcutOnlySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Export Actions",
                detail: "Create backup, report, and share-card files from Shortcuts."
            )

            ForEach(shortcutOnlyRows) { row in
                AutomationActionRow(row: row)
            }
        }
        .padding(18)
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 0.82,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
        .accessibilityIdentifier("automation.shortcutFileActions")
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Link Examples",
                detail: "Copy a link when a Shortcut needs to open Sunclub directly."
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
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 0.82,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
        .accessibilityIdentifier("automation.urlExamples")
    }

    private var callbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Callback Examples",
                detail: "Use these only when another app needs a result after Sunclub finishes."
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
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 0.82,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
        .accessibilityIdentifier("automation.callbackExamples")
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppFont.rounded(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            Text(detail)
                .font(AppFont.rounded(size: 14))
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
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.sun)
            .accessibilityIdentifier(accessibilityIdentifier)

            Text(detail)
                .font(AppFont.rounded(size: 13))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
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
            AutomationActionRow.Model(title: String(localized: LogSunscreenIntent.title), detail: "Save today's log with optional SPF and notes."),
            AutomationActionRow.Model(title: String(localized: LogReapplyIntent.title), detail: "Log a reapplication."),
            AutomationActionRow.Model(title: String(localized: GetSunclubStatusIntent.title), detail: "Read log, UV, and reapplication status."),
            AutomationActionRow.Model(title: String(localized: GetTimeSinceLastSunscreenIntent.title), detail: "Check time since the last log or reapplication."),
            AutomationActionRow.Model(title: String(localized: SaveSunscreenLogIntent.title), detail: "Save a log for a chosen date and time."),
            AutomationActionRow.Model(title: String(localized: OpenSunclubRouteIntent.title), detail: "Open a Sunclub screen."),
            AutomationActionRow.Model(title: String(localized: SetSunclubReminderIntent.title), detail: "Change weekday or weekend reminder time."),
            AutomationActionRow.Model(title: String(localized: SetSunclubReapplyIntent.title), detail: "Turn reapply reminders on or change the interval."),
            AutomationActionRow.Model(title: String(localized: SetSunclubToggleIntent.title), detail: "Update travel, UV, iCloud, or alert preferences.")
        ]
    }

    private var shortcutOnlyRows: [AutomationActionRow.Model] {
        [
            AutomationActionRow.Model(title: String(localized: ExportSunclubBackupIntent.title), detail: "Create a JSON backup file.", icon: .cloud),
            AutomationActionRow.Model(title: String(localized: CreateSkinHealthReportIntent.title), detail: "Create a PDF history export.", icon: .book),
            AutomationActionRow.Model(title: String(localized: CreateStreakCardIntent.title), detail: "Create a shareable logged-days card.", icon: .calendar)
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
                detail: "Check today's status from a Shortcut.",
                urlString: "\(scheme)://automation/status"
            ),
            AutomationExample(
                id: "timeSinceLastApplication",
                title: "Time Since Last Sunscreen",
                detail: "Check how long it has been since the last log or reapply.",
                urlString: "\(scheme)://automation/time-since-last-application"
            ),
            AutomationExample(
                id: "openAutomation",
                title: "Open Shortcuts",
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
                urlString: "\(scheme)://automation/save-log?date=2026-04-13&time=08:30&part=morning&spf=50&notes=Morning"
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
                title: "Update Setting",
                detail: "Turn on daily UV briefing.",
                urlString: "\(scheme)://automation/set-toggle?name=dailyUVBriefing&enabled=true"
            )
        ]
    }

    private var callbackExamples: [AutomationExample] {
        [
            AutomationExample(
                id: "callbackStatus",
                title: "Status Callback",
                detail: "Sends today's status back to the calling app.",
                urlString: "\(scheme)://x-callback-url/status?x-success=shortcuts://callback&x-error=shortcuts://callback"
            ),
            AutomationExample(
                id: "callbackLastApplication",
                title: "Last Application Callback",
                detail: "Sends the last sunscreen time back when result details are on.",
                urlString: "\(scheme)://x-callback-url/time-since-last-application?x-success=shortcuts://callback&x-error=shortcuts://callback"
            ),
            AutomationExample(
                id: "callbackLogToday",
                title: "Log Callback",
                detail: "Saves today's log and sends the result back when details are on.",
                urlString: "\(scheme)://x-callback-url/log-today?spf=50&x-success=shortcuts://callback&x-error=shortcuts://callback"
            ),
            AutomationExample(
                id: "callbackOpen",
                title: "Open Callback",
                detail: "Opens a screen and confirms when routing is finished.",
                urlString: "\(scheme)://x-callback-url/open?route=history&x-success=shortcuts://callback&x-error=shortcuts://callback"
            )
        ]
    }

    private var scheme: String {
        SunclubRuntimeConfiguration.urlScheme
    }

}

private struct AutomationActionRow: View {
    struct Model: Identifiable {
        let title: String
        let detail: String
        let icon: SunIcon

        var id: String { title }

        init(title: String, detail: String, icon: SunIcon = .sparkles) {
            self.title = title
            self.detail = detail
            self.icon = icon
        }
    }

    let row: Model

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            row.icon.image.resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(AppColor.Text.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                AppText(row.title, style: .bodyMedium)
                AppText(row.detail, style: .caption, color: AppColor.Text.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AutomationExample: Identifiable {
    let id: String
    let title: String
    let detail: String
    let urlString: String
    let canTest: Bool

    var testURL: URL? {
        guard canTest,
              let url = URL(string: urlString),
              case let .automation(request) = SunclubDeepLink(url: url),
              !request.action.isWriteAction else { return nil }
        return url
    }

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
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(example.detail)
                    .font(AppFont.rounded(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(example.urlString)
                .font(AppFont.monospace(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
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

                if let url = example.testURL {
                    Button("Test") {
                        feedbackMessage = "Opened \(example.title)."
                        openURL(url)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityLabel("Test \(example.title) URL")
                    .accessibilityIdentifier("automation.example.\(example.id).test")
                } else {
                    Text("Copy this example into your own Shortcut to use it.")
                        .font(AppFont.rounded(size: 13, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("automation.example.\(example.id).requiresValue")
                }
            }
        }
        .padding(14)
        .sunGlassCard(
            cornerRadius: AppRadius.medium,
            fillOpacity: 0.58,
            legacyFill: AppPalette.controlFill,
            legacyStroke: .clear,
            legacyShadow: nil
        )
        .accessibilityElement(children: .contain)
    }
}
