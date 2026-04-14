import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedReminderPicker: ReminderScheduleKind?
    @State private var pickerTime = Date()
    @State private var reapplyEnabled = false
    @State private var reapplyInterval = 120
    @State private var followsTravelTimeZone = true
    @State private var streakRiskEnabled = true
    @State private var leaveHomeReminderEnabled = false
    @State private var usesLiveUV = false
    @State private var healthKitEnabled = false
    @State private var dailyUVBriefingEnabled = true
    @State private var extremeUVAlertsEnabled = false
    @State private var iCloudSyncEnabled = true
    @State private var backupDocument: SunclubBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupStatus: BackupFeedback?
    @State private var backupAlert: BackupAlert?
    @State private var automationFeedback = "Ready"
    @State private var expandedSections: Set<SettingsSection> = []

    private let reapplyOptions = [30, 60, 90, 120, 180, 240]

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 30) {
                SunLightHeader(title: "Settings", showsBack: true, onBack: {
                    router.goBack()
                })

                settingsGroup(.reminders) {
                    smarterReminderSection
                    reminderCoachingSection
                    notificationHealthSection
                }

                settingsGroup(.progress) {
                    reapplySection
                }

                settingsGroup(.data) {
                    iCloudSection
                    backupSection
                }

                settingsGroup(.automation) {
                    AutomationSettingsPanel(
                        style: .settings,
                        feedbackMessage: $automationFeedback,
                        openURL: openURL
                    )
                }

                settingsGroup(.advanced) {
                    leaveHomeReminderSection
                    uvAndHealthSection
                }

                settingsGroup(.help) {
                    helpAndLegalSection
                }

                Spacer(minLength: 0)
            }
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
            appState.refreshUVReadingIfNeeded()
            appState.refreshUVForecastIfNeeded()
            appState.refreshHealthKitStatus()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private func settingsGroup<Content: View>(
        _ section: SettingsSection,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
                    toggleSection(section)
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: section.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.sun)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)

                        Text(section.detail)
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSectionExpanded(section) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                }
                .padding(18)
                .background(cardBackground)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isSectionExpanded(section) ? "Expanded" : "Collapsed")
            .accessibilityHint(isSectionExpanded(section) ? "Hides \(section.title) settings." : "Shows \(section.title) settings.")
            .accessibilityIdentifier("settings.section.\(section.rawValue)")

            if isSectionExpanded(section) {
                content()
            }
        }
    }

    private var smarterReminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Reminders")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(reminderHeadline)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("settings.reminderSummary")

            Text(reminderDescription)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)

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
                title: "Streak at risk nudge",
                detail: streakRiskEnabled
                    ? "If your streak is still open, Sunclub sends an evening reminder before the day ends."
                    : "Sunclub only sends your main reminder.",
                isOn: $streakRiskEnabled,
                accessibilityIdentifier: "settings.streakRiskToggle"
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Text(formattedReminderTime(for: kind))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
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
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.sun)
            .onChange(of: leaveHomeReminderEnabled) { _, newValue in
                appState.updateLeaveHomeReminderEnabled(enabled: newValue)
            }
            .accessibilityIdentifier("settings.leaveHomeToggle")

            Text("Use your first trip out as the day's reminder.")
                .font(.system(size: 14))
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text("Optional. Use this only if you want Sunclub to remind you when you first head out.")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)

            leaveHomeReminderCard
        }
    }

    private var reapplySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reapply Reminder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $reapplyEnabled) {
                    Text("Remind to reapply")
                        .font(.system(size: 17, weight: .medium))
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
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)

                        LazyVGrid(columns: reapplyIntervalColumns, spacing: 8) {
                            ForEach(reapplyOptions, id: \.self) { minutes in
                                reapplyIntervalButton(minutes)
                            }
                        }
                        .accessibilityIdentifier("settings.reapplyInterval")
                    }
                }

                Text("Get a reminder to reapply after today's log.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    @ViewBuilder
    private var reminderCoachingSection: some View {
        if !appState.reminderCoachingSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suggested Times")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                VStack(spacing: 12) {
                    ForEach(appState.reminderCoachingSuggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(suggestion.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppPalette.ink)

                            Text(suggestion.detail)
                                .font(.system(size: 14))
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    VStack(alignment: .leading, spacing: 14) {
                        SunStatusCard(
                            title: presentation.title,
                            detail: presentation.detail,
                        tint: Color.red.opacity(0.72),
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

    private var liveUVSection: some View {
        let presentation = appState.liveUVStatusPresentation

        return VStack(alignment: .leading, spacing: 14) {
            Text("UV Data")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $usesLiveUV) {
                    Text("Use live UV when available")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .onChange(of: usesLiveUV) { _, newValue in
                    appState.updateLiveUVPreference(enabled: newValue)
                }
                .accessibilityIdentifier("settings.liveUVToggle")

                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: AppPalette.sun,
                    symbol: "sun.max.fill"
                )

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

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Backup")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Text("Export a backup before you reinstall the app or move to a new device. Import restores this phone first and leaves iCloud unchanged until you send those changes.")
                    .font(.system(size: 14))
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
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                if appState.isUITesting {
                    backupHarnessSection
                }

                if let backupStatus {
                    Text(backupStatus.message)
                        .font(.system(size: 13, weight: .medium))
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $healthKitEnabled) {
                    Text("Sync sunscreen logs to Apple Health")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
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
                .font(.system(size: 14, weight: .semibold))
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

    private var uvAndHealthSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("UV & Health")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            liveUVSection
            uvBriefingSection
            healthKitSection
        }
    }

    private var helpAndLegalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Support")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 12) {
                webLinkButton(
                    title: "Support",
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
                .font(.system(size: 13))
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
        let streakLine = streakRiskEnabled
            ? " Evening streak nudges are on."
            : " Evening streak nudges are off."
        return travelLine + streakLine
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $iCloudSyncEnabled) {
                    Text("Sync history with iCloud")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .onChange(of: iCloudSyncEnabled) { _, newValue in
                    appState.updateCloudSyncEnabled(newValue)
                }
                .accessibilityIdentifier("settings.icloudToggle")

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
                    router.open(.recovery)
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
                .font(.system(size: 14, weight: .medium))
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
            return Color.red.opacity(0.75)
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
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
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
            return Color.red.opacity(0.72)
        }
    }

    private func isSectionExpanded(_ section: SettingsSection) -> Bool {
        expandedSections.contains(section)
    }

    private func toggleSection(_ section: SettingsSection) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    private func syncLocalState() {
        let reminderSettings = appState.settings.smartReminderSettings
        followsTravelTimeZone = reminderSettings.followsTravelTimeZone
        streakRiskEnabled = reminderSettings.streakRiskEnabled
        leaveHomeReminderEnabled = reminderSettings.leaveHomeReminder.isEnabled
        reapplyEnabled = appState.settings.reapplyReminderEnabled
        reapplyInterval = appState.settings.reapplyIntervalMinutes
        usesLiveUV = appState.settings.usesLiveUV
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
                        .font(.system(size: 10, weight: .bold))
                }

                Text(formatInterval(minutes))
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? AppPalette.onAccent : AppPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
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
            HStack(spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
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
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityIdentifier("settings.backupRecordCount")
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

    var title: String {
        switch self {
        case .reminders:
            return "Reminders"
        case .progress:
            return "Progress"
        case .data:
            return "Data & Sync"
        case .automation:
            return "Automation"
        case .advanced:
            return "Advanced"
        case .help:
            return "Help & Legal"
        }
    }

    var detail: String {
        switch self {
        case .reminders:
            return "Daily times and travel behavior."
        case .progress:
            return "Reapply reminders and progress helpers."
        case .data:
            return "iCloud, backup, import, and recovery."
        case .automation:
            return "Shortcuts, URL actions, and x-callback-url."
        case .advanced:
            return "Location, UV data, and Health settings."
        case .help:
            return "Support, privacy, and contact links."
        }
    }

    var symbolName: String {
        switch self {
        case .reminders:
            return "bell.fill"
        case .progress:
            return "chart.line.uptrend.xyaxis"
        case .data:
            return "icloud.fill"
        case .automation:
            return "wand.and.stars"
        case .advanced:
            return "slider.horizontal.3"
        case .help:
            return "questionmark.circle.fill"
        }
    }
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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.sun)
            .accessibilityIdentifier(accessibilityIdentifier)

            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
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
