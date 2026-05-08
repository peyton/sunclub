import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedReminderPicker: ReminderScheduleKind?
    @State private var pickerTime = Date()
    @State private var reapplyEnabled = false
    @State private var reapplyInterval = 120
    @State private var followsTravelTimeZone = true
    @State private var streakRiskEnabled = true
    @State private var leaveHomeReminderEnabled = false
    @State private var liveUVEnabled = false
    @State private var healthKitEnabled = false
    @State private var dailyUVBriefingEnabled = true
    @State private var extremeUVAlertsEnabled = false
    @State private var iCloudSyncEnabled = true
    @State private var backupDocument: SunclubBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupStatus: BackupFeedback?
    @State private var backupAlert: BackupAlert?
    @State private var automationFeedback = ""
    @State private var selectedSettingsDetail: SettingsDetail?

    private let reapplyOptions = [30, 60, 90, 120, 180, 240]
    let showsBackButton: Bool

    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
    }

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.wideReadable,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: 30) {
                SunLightHeader(title: settingsTitle, showsBack: showsSettingsBackButton, onBack: {
                    handleSettingsBack()
                })

                if let selectedSettingsDetail {
                    settingsDetailContent(for: selectedSettingsDetail)
                } else {
                    settingsHome
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, tabBarScrollUnderlapPadding)
        }
        .sheet(item: $selectedReminderPicker) { schedule in
            reminderPickerSheet(for: schedule)
        }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: SunclubBackupDocument.contentType,
            defaultFilename: backupDocument?.suggestedFilename
        ) { result in
            switch result {
            case .success:
                backupStatus = BackupFeedback(
                    message: "Backup exported.",
                    tint: AppPalette.softInk
                )
            case let .failure(error):
                presentBackupError(error)
            }
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: SunclubBackupDocument.readableContentTypes
        ) { result in
            switch result {
            case let .success(url):
                importBackup(from: url)
            case let .failure(error):
                presentBackupError(error)
            }
        }
        .alert(item: $backupAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            syncLocalState()
            appState.refreshNotificationHealth()
            appState.refreshLeaveHomeReminderStatus()
            appState.refreshUVForecastIfNeeded()
            appState.refreshHealthKitStatus()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var settingsTitle: String {
        selectedSettingsDetail?.title ?? "Settings"
    }

    private var showsSettingsBackButton: Bool {
        showsBackButton || selectedSettingsDetail != nil
    }

    private var tabBarScrollUnderlapPadding: CGFloat {
        showsBackButton ? 0 : SunLayout.tabBarScrollUnderlapPadding
    }

    private func handleSettingsBack() {
        if selectedSettingsDetail != nil {
            selectedSettingsDetail = nil
        } else {
            router.goBack()
        }
    }

    private var settingsHome: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsHubIntro

            settingsHomeGroup(title: "Daily Use") {
                settingsHomeRow(
                    title: "Sunscreen & Reminders",
                    detail: "SPF defaults, daily reminder times, and reapply timing.",
                    symbolName: "sun.max.fill",
                    tint: AppPalette.sun,
                    accessibilityIdentifier: "settings.section.reminders"
                ) {
                    selectedSettingsDetail = .sunscreenReminders
                }

                settingsHomeRow(
                    title: "Reapply Reminder",
                    detail: sectionDetail(for: .progress),
                    symbolName: "clock.badge.checkmark.fill",
                    tint: AppPalette.sun,
                    accessibilityIdentifier: "settings.section.progress"
                ) {
                    selectedSettingsDetail = .sunscreenReminders
                }

                settingsHomeRow(
                    title: "Notifications",
                    detail: reminderHeadline,
                    symbolName: "bell.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.reference.notifications"
                ) {
                    selectedSettingsDetail = .notifications
                }
            }

            settingsHomeGroup(title: "Data & Integrations") {
                settingsHomeRow(
                    title: "UV & Weather",
                    detail: sectionDetail(for: .advanced),
                    symbolName: "cloud.sun.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.section.advanced"
                ) {
                    selectedSettingsDetail = .healthWeather
                }

                settingsHomeRow(
                    title: "iCloud & Data",
                    detail: sectionDetail(for: .data),
                    symbolName: "icloud.fill",
                    tint: AppPalette.aloe,
                    accessibilityIdentifier: "settings.section.data"
                ) {
                    selectedSettingsDetail = .data
                }

                settingsHomeRow(
                    title: "Shortcuts",
                    detail: sectionDetail(for: .automation),
                    symbolName: "wand.and.stars",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.section.automation"
                ) {
                    selectedSettingsDetail = .shortcuts
                }
            }

            settingsHomeGroup(title: "Privacy & Support") {
                settingsHomeRow(
                    title: "Privacy",
                    detail: "Data, iCloud, export, and deletion practices.",
                    symbolName: "lock.shield.fill",
                    tint: AppPalette.aloe,
                    accessibilityIdentifier: "settings.privacy.quick"
                ) {
                    router.push(.privacy)
                }

                settingsHomeRow(
                    title: "Support",
                    detail: "Help center, email support, and feedback.",
                    symbolName: "lifepreserver.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.support.quick"
                ) {
                    router.push(.support)
                }

                settingsHomeRow(
                    title: "Help & Legal",
                    detail: "Documentation, privacy policy, email support, and support links.",
                    symbolName: "questionmark.circle.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.section.help"
                ) {
                    selectedSettingsDetail = .help
                }

                settingsHomeRow(
                    title: "Documentation",
                    detail: "Setup, widgets, Shortcuts, and privacy details.",
                    symbolName: "book.pages.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.docs.quick"
                ) {
                    openURL(SunclubWebLinks.docs)
                }
            }
        }
    }

    private var settingsHubIntro: some View {
        AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep your sun routine tuned.")
                    .font(AppFont.rounded(size: 24, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Manage reminders, privacy, sync, Shortcuts, and display preferences from one place.")
                    .font(AppFont.rounded(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingsHomeGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(spacing: 0) {
                content()
            }
            .background(cardBackground)
        }
    }

    private func settingsHomeRow(
        title: String,
        detail: String,
        symbolName: String,
        tint: Color,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsReferenceRowContent(
                title: title,
                detail: detail,
                symbolName: symbolName,
                tint: tint,
                trailingText: nil,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    private func settingsDetailContent(for detail: SettingsDetail) -> some View {
        switch detail {
        case .sunscreenReminders:
            VStack(alignment: .leading, spacing: 22) {
                smarterReminderSection
                reapplySection
                reminderCoachingSection
            }
        case .notifications:
            VStack(alignment: .leading, spacing: 22) {
                notificationOverviewCard
                notificationHealthSection
                smarterReminderSection
            }
        case .healthWeather:
            VStack(alignment: .leading, spacing: 22) {
                leaveHomeReminderSection
                uvAndHealthSection
            }
        case .data:
            VStack(alignment: .leading, spacing: 22) {
                iCloudSection
                backupSection
            }
        case .shortcuts:
            VStack(alignment: .leading, spacing: 22) {
                AutomationSettingsPanel(
                    style: .settings,
                    feedbackMessage: $automationFeedback,
                    openURL: openURL
                )
            }
        case .help:
            helpAndLegalSection
        }
    }

    private var notificationOverviewCard: some View {
        AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 12) {
                SunProductIcon(systemName: "bell.fill", tint: AppPalette.pool, size: 42)

                Text("Reminder timing")
                    .font(AppFont.rounded(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Text("Adjust daily reminders, reapply timing, and notification access in one place.")
                    .font(AppFont.rounded(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var smarterReminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Reminders")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(reminderHeadline)
                .font(AppFont.rounded(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("settings.reminderSummary")

            Text(reminderDescription)
                .font(AppFont.rounded(size: 15))
                .foregroundStyle(AppPalette.softInk)

            if let preview = appState.nextDailyReminderPreview {
                Text(preview.summary)
                    .font(AppFont.rounded(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.nextReminderPreview")
            }

            if let status = appState.notificationHealthStatusPresentation {
                VStack(alignment: .leading, spacing: 10) {
                    SunStatusCard(
                        title: status.title,
                        detail: status.detail,
                        tint: notificationStatusTint(for: status),
                        symbol: status.symbolName
                    )
                    .accessibilityIdentifier("settings.notificationStatus")

                    if let actionTitle = status.actionTitle,
                       let actionKind = status.actionKind {
                        Button(actionTitle) {
                            handleNotificationStatusAction(actionKind)
                        }
                        .buttonStyle(SunSecondaryButtonStyle())
                        .accessibilityIdentifier("settings.notificationStatus.action")
                    }
                }
            }

            VStack(spacing: 12) {
                reminderCard(for: .weekday, detail: "Used Monday through Friday")
                reminderCard(for: .weekend, detail: "Used Saturday and Sunday")
            }

            ReminderToggleCard(
                title: "Follow local time when traveling",
                detail: followsTravelTimeZone
                    ? "Reminders follow the time zone you're currently in."
                    : "Reminders stay on \(anchoredTimeZoneLabel).",
                isOn: $followsTravelTimeZone,
                accessibilityIdentifier: "settings.travelToggle"
            )
            .onChange(of: followsTravelTimeZone) { _, newValue in
                appState.updateTravelTimeZoneHandling(followsTravelTimeZone: newValue)
            }

            ReminderToggleCard(
                title: "Evening log reminder",
                detail: streakRiskEnabled
                    ? "If today is still open in the evening, Sunclub can remind you to add a sunscreen log."
                    : "Sunclub will not send an evening note for missing daily logs.",
                isOn: $streakRiskEnabled,
                accessibilityIdentifier: "settings.eveningLogReminderToggle"
            )
            .onChange(of: streakRiskEnabled) { _, newValue in
                appState.updateStreakRiskReminder(enabled: newValue)
            }

        }
    }

    private func reminderCard(for kind: ReminderScheduleKind, detail: String) -> some View {
        Button {
            pickerTime = appState.reminderDate(for: kind)
            selectedReminderPicker = kind
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.title)
                        .font(AppFont.rounded(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(AppFont.rounded(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Text(formattedReminderTime(for: kind))
                        .font(AppFont.rounded(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Image(systemName: "chevron.right")
                        .font(AppFont.rounded(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                }
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier(for: kind))
    }

    private var leaveHomeReminderCard: some View {
        let presentation = appState.leaveHomeReminderStatusPresentation

        return VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $leaveHomeReminderEnabled) {
                Text("Remind me when I leave home")
                    .font(AppFont.rounded(size: 17, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.sun)
            .onChange(of: leaveHomeReminderEnabled) { _, newValue in
                appState.updateLeaveHomeReminderEnabled(enabled: newValue)
            }
            .accessibilityIdentifier("settings.leaveHomeToggle")

            Text("Use your first trip out as the day's reminder.")
                .font(AppFont.rounded(size: 14))
                .foregroundStyle(AppPalette.softInk)

            if leaveHomeReminderEnabled || appState.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil {
                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: leaveHomeReminderTint(for: presentation.tone),
                    symbol: presentation.symbol
                )
                .accessibilityIdentifier("settings.leaveHome.status")
            }

            if let actionTitle = presentation.actionTitle,
               let actionKind = presentation.actionKind,
               leaveHomeReminderEnabled || appState.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil {
                Button(actionTitle) {
                    handleLeaveHomeReminderAction(actionKind)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.leaveHome.action")
            }

            if appState.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil {
                Button("Reset Home") {
                    appState.clearSavedHomeLocation()
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.leaveHome.resetHome")
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var leaveHomeReminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Leave-Home Reminder")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text("Optional. Use this only if you want Sunclub to remind you when you first head out.")
                .font(AppFont.rounded(size: 14))
                .foregroundStyle(AppPalette.softInk)

            leaveHomeReminderCard
        }
    }

    private var reapplySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reapply Reminder")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $reapplyEnabled) {
                    Text("Remind to reapply")
                        .font(AppFont.rounded(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .onChange(of: reapplyEnabled) { _, newValue in
                    appState.updateReapplySettings(enabled: newValue, intervalMinutes: reapplyInterval)
                }
                .accessibilityIdentifier("settings.reapplyToggle")

                if reapplyEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interval")
                            .font(AppFont.rounded(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)

                        LazyVGrid(columns: reapplyIntervalColumns, spacing: 8) {
                            ForEach(reapplyOptions, id: \.self) { minutes in
                                reapplyIntervalButton(minutes)
                            }
                        }
                        .accessibilityIdentifier("settings.reapplyInterval")
                    }
                }

                Text("Interval reminders are timing aids, not medical advice. Sunclub stops scheduling them after the estimated sunset cutoff.")
                    .font(AppFont.rounded(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    @ViewBuilder
    private var reminderCoachingSection: some View {
        let suggestions = appState.reminderCoachingSuggestions

        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suggested Times")
                    .font(AppFont.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                VStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(suggestion.title)
                                .font(AppFont.rounded(size: 17, weight: .semibold))
                                .foregroundStyle(AppPalette.ink)

                            Text(suggestion.detail)
                                .font(AppFont.rounded(size: 14))
                                .foregroundStyle(AppPalette.softInk)

                            Button(suggestion.actionTitle) {
                                appState.applyReminderCoachingSuggestion(suggestion)
                                syncLocalState()
                            }
                            .buttonStyle(SunSecondaryButtonStyle())
                            .accessibilityIdentifier("settings.coaching.\(suggestion.kind.rawValue)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(cardBackground)
                    }
                }
            }
        }
    }

    private var notificationHealthSection: some View {
        Group {
            if let presentation = appState.notificationHealthPresentation {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Notification Help")
                        .font(AppFont.rounded(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    VStack(alignment: .leading, spacing: 14) {
                        SunStatusCard(
                            title: presentation.title,
                            detail: presentation.detail,
                            tint: AppColor.warning.opacity(0.72),
                            symbol: "bell.badge.fill"
                        )

                        Button(presentation.actionTitle) {
                            handleNotificationHealthAction(for: presentation)
                        }
                        .buttonStyle(SunSecondaryButtonStyle())
                        .accessibilityIdentifier("settings.notificationHealth.action")
                    }
                    .padding(18)
                    .background(cardBackground)
                }
            }
        }
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Backup")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Text("Export a backup before you reinstall the app or move to a new device. Import restores this phone first and leaves iCloud unchanged until you send those changes.")
                    .font(AppFont.rounded(size: 14))
                    .foregroundStyle(AppPalette.softInk)

                backupActionButton(
                    title: "Export Backup",
                    symbolName: "square.and.arrow.up",
                    accessibilityIdentifier: "settings.backup.export",
                    action: beginBackupExport
                )

                backupActionButton(
                    title: "Import Backup",
                    symbolName: "square.and.arrow.down",
                    accessibilityIdentifier: "settings.backup.import",
                    action: { isImportingBackup = true }
                )

                Text("Imports stay reversible. Use Recovery & Changes if you want to undo one or send it to iCloud later.")
                    .font(AppFont.rounded(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                if appState.isUITesting {
                    backupHarnessSection
                }

                if let backupStatus {
                    Text(backupStatus.message)
                        .font(AppFont.rounded(size: 13, weight: .medium))
                        .foregroundStyle(backupStatus.tint)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.backupStatus")
                }
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HealthKit")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $healthKitEnabled) {
                    Text("Sync sunscreen logs to Apple Health")
                        .font(AppFont.rounded(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .accessibilityIdentifier("settings.healthKitToggle")
                .onChange(of: healthKitEnabled) { _, newValue in
                    appState.updateHealthKitEnabled(newValue)
                }

                let detail = appState.healthKitAvailable
                    ? "Sunclub writes UV exposure samples when you log. Imported Health UV samples in the last year: \(appState.growthSettings.healthKit.importedSampleCount)."
                    : "Health data is unavailable on this device."

                SunStatusCard(
                    title: healthKitEnabled ? "Health sync is on" : "Health sync is off",
                    detail: detail,
                    tint: AppPalette.sun,
                    symbol: "heart.text.square.fill"
                )
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    private var uvBriefingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily UV Briefing")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                ReminderToggleCard(
                    title: "Morning UV briefing",
                    detail: dailyUVBriefingEnabled
                        ? "Send a morning note with peak UV and protection advice."
                        : "Only the standard sunscreen reminders stay on.",
                    isOn: $dailyUVBriefingEnabled,
                    accessibilityIdentifier: "settings.uvBriefingToggle"
                )
                .onChange(of: dailyUVBriefingEnabled) { _, newValue in
                    appState.updateUVBriefingPreferences(dailyBriefingEnabled: newValue)
                }

                ReminderToggleCard(
                    title: "Extreme UV alert",
                    detail: extremeUVAlertsEnabled
                        ? "Sunclub sends an extra heads-up on extreme UV days."
                        : "No extra UV alert is sent even on extreme days.",
                    isOn: $extremeUVAlertsEnabled,
                    accessibilityIdentifier: "settings.extremeUVToggle"
                )
                .onChange(of: extremeUVAlertsEnabled) { _, newValue in
                    appState.updateUVBriefingPreferences(extremeAlertEnabled: newValue)
                }
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    private var liveUVSection: some View {
        let presentation = appState.liveUVStatusPresentation

        return VStack(alignment: .leading, spacing: 14) {
            Text("Live UV")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $liveUVEnabled) {
                    Text("Use Apple Weather for Live UV")
                        .font(AppFont.rounded(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .onChange(of: liveUVEnabled) { _, newValue in
                    appState.updateLiveUVPreference(
                        enabled: newValue,
                        allowPermissionPrompt: newValue
                    )
                }
                .accessibilityIdentifier("settings.liveUVToggle")

                Text("Optional and off by default. Manual logging, reminders, widgets, and watch surfaces keep using Sunclub's local estimate if Live UV is off or unavailable.")
                    .font(AppFont.rounded(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: liveUVStatusTint(for: presentation),
                    symbol: "sun.max.circle.fill"
                )
                .accessibilityIdentifier("settings.liveUV.status")

                Text("When Apple Weather UV appears in Sunclub, the main app shows Apple Weather attribution and a Data Sources link.")
                    .font(AppFont.rounded(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle = presentation.actionTitle,
                   let actionKind = presentation.actionKind {
                    Button(actionTitle) {
                        handleLiveUVAction(actionKind)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("settings.liveUV.action")
                }
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    private var uvAndHealthSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("UV & Weather")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            liveUVSection
            uvBriefingSection
            healthKitSection
        }
    }

    private var helpAndLegalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Support")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 12) {
                webLinkButton(
                    title: "Documentation",
                    detail: "Setup, shortcuts, widgets, and data notes.",
                    symbolName: "book.pages.fill",
                    url: SunclubWebLinks.docs,
                    accessibilityIdentifier: "settings.docs"
                )

                webLinkButton(
                    title: "Help Center",
                    detail: "Open Sunclub support in your browser.",
                    symbolName: "questionmark.circle.fill",
                    url: SunclubWebLinks.support,
                    accessibilityIdentifier: "settings.support"
                )

                webLinkButton(
                    title: "Privacy Policy",
                    detail: "Read how Sunclub handles app data and optional Apple features.",
                    symbolName: "lock.shield.fill",
                    url: SunclubWebLinks.privacy,
                    accessibilityIdentifier: "settings.privacyPolicy"
                )

                webLinkButton(
                    title: "Email Support",
                    detail: "Send an email to support@mail.sunclub.peyton.app.",
                    symbolName: "envelope.fill",
                    url: SunclubWebLinks.supportEmail,
                    accessibilityIdentifier: "settings.emailSupport"
                )
            }

            Text("Sunclub is a habit tracker, not medical advice.")
                .font(AppFont.rounded(size: 13))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reminderHeadline: String {
        let weekday = formattedReminderTime(for: .weekday)
        let weekend = formattedReminderTime(for: .weekend)

        if weekday == weekend {
            return "Every day at \(weekday)"
        }

        return "Weekdays \(weekday), weekends \(weekend)"
    }

    private var reminderDescription: String {
        let travelLine = followsTravelTimeZone
            ? "Follows local time while you travel."
            : "Stays on \(anchoredTimeZoneLabel) while you travel."
        let eveningLine = streakRiskEnabled
            ? " Evening log reminder on."
            : " Evening log reminder off."
        return travelLine + eveningLine
    }

    private var anchoredTimeZoneLabel: String {
        let timeZone = appState.settings.smartReminderSettings.anchoredTimeZone
        return timeZone.localizedName(for: .generic, locale: .current)
            ?? timeZone.identifier.replacingOccurrences(of: "_", with: " ")
    }

    private var iCloudSection: some View {
        let presentation = appState.cloudSyncStatusPresentation

        return VStack(alignment: .leading, spacing: 14) {
            Text("iCloud")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $iCloudSyncEnabled) {
                    Text("Sync history with iCloud")
                        .font(AppFont.rounded(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .onChange(of: iCloudSyncEnabled) { _, newValue in
                    appState.updateCloudSyncEnabled(newValue)
                }
                .accessibilityIdentifier("settings.icloudToggle")

                if iCloudSyncEnabled {
                    if let lastSyncAt = appState.syncPreference?.lastSyncAt {
                        Text("Last synced \(lastSyncAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(AppFont.rounded(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)
                    } else {
                        Text("iCloud sync is on")
                            .font(AppFont.rounded(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)
                    }
                }

                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: iCloudStatusTint,
                    symbol: iCloudStatusSymbol
                )
                .accessibilityIdentifier("settings.icloudStatus")

                if let actionTitle = presentation.actionTitle {
                    Button(actionTitle) {
                        handleCloudSyncAction()
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("settings.icloudAction")
                }

                if let session = appState.recentImportSession,
                   session.publishedAt == nil {
                    pendingImportActions(for: session)
                }

                Button("Recovery & Changes") {
                    router.push(.recovery)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.recovery")
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    @ViewBuilder
    private func pendingImportActions(for session: SunclubImportSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(SunclubCopy.Sync.savedOnlyOnThisPhone(appState.cloudSyncStatusPresentation.pendingImportedBatchCount))
                .font(AppFont.rounded(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.icloud.pendingImports")

            Button("Send to iCloud") {
                appState.publishImportedChanges(for: session.id)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("settings.icloud.publishImported")

            Button("Undo Import") {
                appState.restoreImportedChanges(for: session.id)
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityIdentifier("settings.icloud.restoreImported")
        }
    }

    private var iCloudStatusTint: Color {
        switch appState.syncPreference?.status ?? .idle {
        case .error:
            return AppColor.warning.opacity(0.75)
        case .paused:
            return AppPalette.softInk
        case .syncing:
            return AppPalette.sun
        case .idle:
            return AppPalette.success
        }
    }

    private var iCloudStatusSymbol: String {
        switch appState.syncPreference?.status ?? .idle {
        case .error:
            return "exclamationmark.icloud.fill"
        case .paused:
            return "icloud.slash"
        case .syncing:
            return "arrow.trianglehead.2.clockwise.icloud"
        case .idle:
            return "icloud.fill"
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
    }

    private func formattedReminderTime(for kind: ReminderScheduleKind) -> String {
        appState.reminderDate(for: kind).formatted(date: .omitted, time: .shortened)
    }

    private func accessibilityIdentifier(for kind: ReminderScheduleKind) -> String {
        switch kind {
        case .weekday:
            return "settings.weekdayReminderTime"
        case .weekend:
            return "settings.weekendReminderTime"
        }
    }

    private func leaveHomeReminderTint(for tone: LeaveHomeReminderTone) -> Color {
        switch tone {
        case .neutral:
            return AppPalette.softInk
        case .success:
            return AppPalette.success
        case .warning:
            return AppColor.warning.opacity(0.72)
        }
    }

    private func sectionDetail(for section: SettingsSection) -> String {
        switch section {
        case .reminders:
            return reminderHeadline
        case .progress:
            return reapplyEnabled
                ? "Reapply reminder every \(formattedAccessibleInterval(reapplyInterval))."
                : "Reapply reminders are off."
        case .data:
            return appState.cloudSyncStatusPresentation.title
        case .automation:
            let writes = appState.automationPreferences.shortcutWritesEnabled ? "writes on" : "writes off"
            let links = appState.automationPreferences.urlOpenActionsEnabled ? "links on" : "links off"
            return "Shortcuts \(writes), URL \(links)."
        case .advanced:
            let liveUV = liveUVEnabled ? "Live UV on" : "Live UV off"
            let health = healthKitEnabled ? "Health sync on" : "Health sync off"
            return "\(liveUV). \(health)."
        case .help:
            return "Support, privacy, and contact links."
        }
    }

    private func syncLocalState() {
        let reminderSettings = appState.settings.smartReminderSettings
        followsTravelTimeZone = reminderSettings.followsTravelTimeZone
        streakRiskEnabled = reminderSettings.streakRiskEnabled
        leaveHomeReminderEnabled = reminderSettings.leaveHomeReminder.isEnabled
        liveUVEnabled = appState.settings.usesLiveUV
        reapplyEnabled = appState.settings.reapplyReminderEnabled
        reapplyInterval = appState.settings.reapplyIntervalMinutes
        healthKitEnabled = appState.growthSettings.healthKit.isEnabled
        dailyUVBriefingEnabled = appState.growthSettings.uvBriefing.dailyBriefingEnabled
        extremeUVAlertsEnabled = appState.growthSettings.uvBriefing.extremeAlertEnabled
        iCloudSyncEnabled = appState.syncPreference?.isICloudSyncEnabled ?? true
    }

    private func beginBackupExport() {
        do {
            backupDocument = try appState.exportBackupDocument()
            isExportingBackup = true
        } catch {
            presentBackupError(error)
        }
    }

    private func importBackup(from url: URL) {
        do {
            let summary = try appState.importBackup(from: url)
            syncLocalState()
            backupStatus = BackupFeedback(message: summary.statusMessage, tint: AppPalette.softInk)
        } catch {
            presentBackupError(error)
        }
    }

    private func presentBackupError(_ error: any Error) {
        backupAlert = BackupAlert(
            title: "Backup Failed",
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        )
    }

    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h\(remaining)m" : "\(hours)h"
    }

    private var reapplyIntervalColumns: [GridItem] {
        let minimumWidth: CGFloat = dynamicTypeSize.isAccessibilitySize ? 124 : 64
        return [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)]
    }

    private func reapplyIntervalButton(_ minutes: Int) -> some View {
        let isSelected = reapplyInterval == minutes

        return Button {
            guard !isSelected else {
                return
            }
            reapplyInterval = minutes
            appState.updateReapplySettings(enabled: reapplyEnabled, intervalMinutes: minutes)
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(AppFont.rounded(size: 10, weight: .bold))
                }

                Text(formatInterval(minutes))
                    .font(AppFont.rounded(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? AppPalette.onAccent : AppPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(isSelected ? AppPalette.sun : AppPalette.cardFill.opacity(0.72))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reapply interval \(formattedAccessibleInterval(minutes))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("settings.reapplyInterval.\(minutes)")
    }

    private func handleNotificationHealthAction(for presentation: NotificationHealthPresentation) {
        switch presentation.state {
        case .denied:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        case .stale:
            appState.repairReminderSchedule()
        case .healthy:
            break
        }
    }

    private func handleNotificationStatusAction(_ action: NotificationHealthStatusAction) {
        switch action {
        case .requestPermission:
            appState.requestNotificationAuthorizationAndSchedule()
        }
    }

    private func liveUVStatusTint(for presentation: LiveUVStatusPresentation) -> Color {
        switch presentation.actionKind {
        case .some(.openSettings), .some(.requestPermission):
            return AppColor.warning.opacity(0.72)
        case .some(.refresh):
            return liveUVEnabled ? AppPalette.sun : AppPalette.softInk
        case .none:
            return liveUVEnabled ? AppPalette.sun : AppPalette.softInk
        }
    }

    private func handleLiveUVAction(_ action: LiveUVActionKind) {
        switch action {
        case .openSettings:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        case .requestPermission, .refresh:
            appState.performLiveUVAction(action)
        }
    }

    private func notificationStatusTint(for status: NotificationHealthStatusPresentation) -> Color {
        if status.actionKind != nil {
            return AppPalette.sun
        }

        return status.needsAttention ? AppColor.warning.opacity(0.72) : AppPalette.success
    }

    private func handleLeaveHomeReminderAction(_ action: LeaveHomeReminderActionKind) {
        switch action {
        case .setHomeFromCurrentLocation:
            appState.saveCurrentLocationAsHome()
        case .requestAlwaysAuthorization:
            appState.requestLeaveHomeMonitoringPermission()
        case .openSettings:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        }
    }

    private func handleCloudSyncAction() {
        switch appState.syncPreference?.status ?? .idle {
        case .paused:
            iCloudSyncEnabled = true
            appState.updateCloudSyncEnabled(true)
        case .error, .idle, .syncing:
            guard appState.syncPreference?.status != .syncing else {
                return
            }
            appState.syncCloudNow()
        }
    }

    private func formattedAccessibleInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        }

        let hours = minutes / 60
        let remaining = minutes % 60
        let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
        guard remaining > 0 else {
            return hourText
        }

        let minuteText = remaining == 1 ? "1 minute" : "\(remaining) minutes"
        return "\(hourText) \(minuteText)"
    }

    private func reminderPickerSheet(for schedule: ReminderScheduleKind) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    schedule.title,
                    selection: $pickerTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button("Save Time") {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: pickerTime)
                    appState.updateReminderTime(
                        for: schedule,
                        hour: components.hour ?? 8,
                        minute: components.minute ?? 0
                    )
                    syncLocalState()
                    selectedReminderPicker = nil
                }
                .buttonStyle(SunPrimaryButtonStyle())
            }
            .padding(24)
            .navigationTitle(schedule.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedReminderPicker = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func backupActionButton(
        title: String,
        symbolName: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func webLinkButton(
        title: String,
        detail: String,
        symbolName: String,
        url: URL,
        accessibilityIdentifier: String
    ) -> some View {
        Button {
            openURL(url)
        } label: {
            SunInfoRow(
                title: title,
                detail: detail,
                systemImage: symbolName,
                tint: AppPalette.pool,
                showsChevron: true
            )
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func settingsReferenceRowContent(
        title: String,
        detail: String,
        symbolName: String,
        tint: Color,
        trailingText: String?,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SunProductIcon(systemName: symbolName, tint: tint, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.ink)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var profileDetail: String {
        let name = appState.preferredDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Name, sharing identity, and friend nudges."
        }
        return "\(name), sharing identity, and friend nudges."
    }

    @ViewBuilder
    private var backupHarnessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let exportURL = RuntimeEnvironment.fileURLArgument(withPrefix: "UITEST_EXPORT_BACKUP_URL=") {
                Button("Export Test Backup") {
                    do {
                        _ = try appState.exportBackup(to: exportURL)
                        backupStatus = BackupFeedback(
                            message: "Backup exported.",
                            tint: AppPalette.softInk
                        )
                    } catch {
                        presentBackupError(error)
                    }
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("settings.backup.exportHarness")
            }

            if let importURL = RuntimeEnvironment.fileURLArgument(withPrefix: "UITEST_IMPORT_BACKUP_URL=") {
                Button("Import Test Backup") {
                    importBackup(from: importURL)
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("settings.backup.importHarness")
            }

            Text("History entries: \(appState.records.count)")
                .font(AppFont.rounded(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityIdentifier("settings.backupRecordCount")
        }
    }
}

private enum SettingsDetail: Hashable {
    case sunscreenReminders
    case notifications
    case healthWeather
    case data
    case shortcuts
    case help

    var title: String {
        switch self {
        case .sunscreenReminders:
            return "Sunscreen & Reminders"
        case .notifications:
            return "Notifications"
        case .healthWeather:
            return "UV & Weather"
        case .data:
            return "iCloud & Data"
        case .shortcuts:
            return "Shortcuts"
        case .help:
            return "Help & Legal"
        }
    }
}

private enum SettingsSection: String, Hashable {
    case reminders
    case progress
    case data
    case automation
    case advanced
    case help
}

private struct ReminderToggleCard: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.sun)
            .accessibilityIdentifier(accessibilityIdentifier)

            Text(detail)
                .font(AppFont.rounded(size: 14))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppPalette.hairlineStroke, lineWidth: 1)
                }
        )
    }
}

private struct BackupFeedback {
    let message: String
    let tint: Color
}

private struct BackupAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    SunclubPreviewHost {
        SettingsView()
    }
}
