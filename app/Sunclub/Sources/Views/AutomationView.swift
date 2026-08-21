import SwiftUI
import UIKit

struct AutomationView: View {
    @Environment(AppState.self) private var appState
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

                AutomationReferenceSummaryCard(
                    onLogSunscreen: openManualLog,
                    onReapplyReminder: {
                        router.push(.reapplyCheckIn)
                    }
                )

                AutomationHeroCard()

                Button {
                    openURL(SunclubWebLinks.automationDocs)
                } label: {
                    SunInfoRow(
                        title: "Shortcuts Guide",
                        detail: "Read setup examples, URL routes, and privacy controls.",
                        systemImage: "sparkles.rectangle.stack.fill",
                        tint: AppPalette.pool,
                        showsChevron: true
                    )
                    .padding(18)
                    .sunGlassCard(cornerRadius: AppRadius.card, interactive: true)
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

    private func openManualLog() {
        let now = appState.referenceDate
        let dayPart = appState.dayPart(for: now)
        appState.prepareManualLogRouteContext(
            targetDate: now,
            targetDayPart: dayPart,
            source: .manualLog
        )
        router.push(.manualLog, targetDate: now, targetDayPart: dayPart)
    }
}

private struct AutomationReferenceSummaryCard: View {
    let onLogSunscreen: () -> Void
    let onReapplyReminder: () -> Void

    var body: some View {
        AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Shortcuts")
                        .font(AppTextStyle.title.font)
                        .foregroundStyle(AppPalette.ink)

                    Text("Automate logging, get reminders, and stay consistent.")
                        .font(AppTextStyle.caption.font)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                automationRow(
                    title: "Log Sunscreen",
                    detail: "Add a log quickly from Home Screen or Apple Watch.",
                    symbolName: "wand.and.stars",
                    tint: AppPalette.pool,
                    action: onLogSunscreen,
                    accessibilityIdentifier: "automation.reference.logSunscreen"
                )

                automationRow(
                    title: "Reapply Reminder",
                    detail: "Get reminders based on your exposure and schedule.",
                    symbolName: "alarm.fill",
                    tint: AppPalette.coral,
                    action: onReapplyReminder,
                    accessibilityIdentifier: "automation.reference.reapplyReminder"
                )

                HStack(alignment: .center, spacing: 12) {
                    SunProductIcon(systemName: "hand.raised.fill", tint: AppPalette.sun, size: 36)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ask Before Running")
                            .font(AppTextStyle.bodyMedium.font)
                            .foregroundStyle(AppPalette.ink)

                        Text("Ask before saving logs or changing reminder settings.")
                            .font(AppTextStyle.caption.font)
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(referenceRowBackground)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("automation.reference.askBeforeRunning")
            }
        }
        .accessibilityIdentifier("automation.referenceSummary")
    }

    private func automationRow(
        title: String,
        detail: String,
        symbolName: String,
        tint: Color,
        action: @escaping () -> Void,
        accessibilityIdentifier: String
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                SunProductIcon(systemName: symbolName, tint: tint, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTextStyle.bodyMedium.font)
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(AppTextStyle.caption.font)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "plus")
                    .font(AppFont.rounded(size: 17, weight: .bold))
                    .foregroundStyle(AppPalette.pool)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppPalette.pool.opacity(0.12)))
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(referenceRowBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var referenceRowBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.84))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
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
                Text("Shortcuts")
                    .font(AppFont.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }

            preferenceSection
            shortcutSection
            shortcutOnlySection
            urlSection
            callbackSection

            if !feedbackMessage.isEmpty {
                Text(feedbackMessage)
                    .font(AppFont.rounded(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("automation.feedback")
            }

            if style == .settings {
                Button("Open Shortcuts Catalog") {
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
        .background(cardBackground)
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
        .background(cardBackground)
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
        .background(cardBackground)
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
        .background(cardBackground)
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
        .background(cardBackground)
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
            AutomationActionRow.Model(title: "Log Sunscreen", detail: "Save today's log with optional SPF and notes."),
            AutomationActionRow.Model(title: "Reapply Reminder", detail: "Add a reapply check-in or review the next reminder."),
            AutomationActionRow.Model(title: "Get Current UV Status", detail: "Check current UV index and severity."),
            AutomationActionRow.Model(title: "Get Reapplication Status", detail: "Check the last log and next reapply time."),
            AutomationActionRow.Model(title: "Review History Summary", detail: "Get recent logged-day counts and last log details."),
            AutomationActionRow.Model(title: "Time Since Last Sunscreen", detail: "Check how long it has been since the last log or reapply."),
            AutomationActionRow.Model(title: "Save Sunscreen Log", detail: "Backfill or update a chosen date and time."),
            AutomationActionRow.Model(title: "Set Sunclub Reminder", detail: "Change weekday or weekend reminder time."),
            AutomationActionRow.Model(title: "Set Sunclub Reapply Reminder", detail: "Turn reapply reminders on or change the interval."),
            AutomationActionRow.Model(title: "Set Sunclub Toggle", detail: "Update travel, UV, iCloud, or alert preferences.")
        ]
    }

    private var shortcutOnlyRows: [AutomationActionRow.Model] {
        [
            AutomationActionRow.Model(title: "Export Sunclub Backup", detail: "Create a JSON backup file.", symbolName: "externaldrive.fill"),
            AutomationActionRow.Model(title: "Export Sunclub History", detail: "Create a factual PDF history export.", symbolName: "doc.richtext.fill")
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
    }
}

private struct AutomationHeroCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SunProductIcon(systemName: "square.stack.3d.up.fill", tint: AppPalette.pool, size: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text("Shortcuts & Automation")
                    .font(AppFont.rounded(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Set up one-tap logging, reminders, and status checks while sensitive writes stay optional.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .sunGlassCard(cornerRadius: AppRadius.card)
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
        SunInfoRow(
            title: row.title,
            detail: row.detail,
            systemImage: row.symbolName,
            tint: AppPalette.success
        )
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
                        .font(AppFont.rounded(size: 13, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("automation.example.\(example.id).requiresValue")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppPalette.controlFill.opacity(0.58))
        )
        .accessibilityElement(children: .contain)
    }
}
