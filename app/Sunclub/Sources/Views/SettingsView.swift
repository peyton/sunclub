import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var selectedReminderPicker: ReminderScheduleKind?
    @State private var pickerTime = Date()
    @State private var reapplyEnabled = false
    @State private var reapplyInterval = 120
    @State private var followsTravelTimeZone = true
    @State private var streakRiskEnabled = true
    @State private var usesLiveUV = false
    @State private var iCloudSyncEnabled = true
    @State private var backupDocument: SunclubBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var backupStatus: BackupFeedback?
    @State private var backupAlert: BackupAlert?

    private let reapplyOptions = [30, 60, 90, 120, 180, 240]

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 30) {
                SunLightHeader(title: "Settings", showsBack: true, onBack: {
                    router.goBack()
                })

                smarterReminderSection
                reminderCoachingSection
                notificationHealthSection
                reapplySection
                liveUVSection
                iCloudSection
                backupSection

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
            appState.refreshUVReadingIfNeeded()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var smarterReminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Smarter Reminders")
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
                    ? "Sunclub adjusts reminders to the time zone you are currently in."
                    : "Sunclub keeps reminders pinned to \(anchoredTimeZoneLabel).",
                isOn: $followsTravelTimeZone,
                accessibilityIdentifier: "settings.travelToggle"
            )
            .onChange(of: followsTravelTimeZone) { _, newValue in
                appState.updateTravelTimeZoneHandling(followsTravelTimeZone: newValue)
            }

            ReminderToggleCard(
                title: "Streak at risk nudge",
                detail: streakRiskEnabled
                    ? "If you have an active streak, Sunclub sends an evening save-it reminder before the day closes."
                    : "Sunclub only sends the main reminder schedule.",
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

    private var reapplySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reapplication Reminder")
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

                        HStack(spacing: 8) {
                            ForEach(reapplyOptions, id: \.self) { minutes in
                                Button {
                                    reapplyInterval = minutes
                                    appState.updateReapplySettings(enabled: reapplyEnabled, intervalMinutes: minutes)
                                } label: {
                                    Text(formatInterval(minutes))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(reapplyInterval == minutes ? .white : AppPalette.ink)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(reapplyInterval == minutes ? AppPalette.sun : Color.white.opacity(0.72))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .accessibilityIdentifier("settings.reapplyInterval")
                    }
                }

                Text("Get a reminder to reapply sunscreen after your daily check-in.")
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
                Text("Reminder Coaching")
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Notification Health")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                if let presentation = appState.notificationHealthPresentation {
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
                } else {
                    SunStatusCard(
                        title: "Notifications look healthy",
                        detail: "Daily reminders are scheduled and ready to keep the sunscreen loop moving.",
                        tint: AppPalette.success,
                        symbol: "bell.fill"
                    )
                }
            }
            .padding(18)
            .background(cardBackground)
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
                Text("Export a local backup file before you reinstall the app or move to a new device. Import restores this device first and keeps iCloud unchanged until you explicitly publish the imported changes.")
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

                Text("Local import stays recoverable. Use Recovery & Changes if you want to undo it or publish it to iCloud later.")
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
            ? "Travel mode keeps reminders on local time."
            : "Travel mode is off, so reminders stay on \(anchoredTimeZoneLabel)."
        let streakLine = streakRiskEnabled
            ? " Evening nudges rescue active streaks."
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
            Text("\(appState.cloudSyncStatusPresentation.pendingImportedBatchCount) imported change(s) are still local-only.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.icloud.pendingImports")

            Button("Publish Imported Changes") {
                appState.publishImportedChanges(for: session.id)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("settings.icloud.publishImported")

            Button("Restore Pre-Import State") {
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
            .fill(Color.white.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
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

    private func syncLocalState() {
        let reminderSettings = appState.settings.smartReminderSettings
        followsTravelTimeZone = reminderSettings.followsTravelTimeZone
        streakRiskEnabled = reminderSettings.streakRiskEnabled
        reapplyEnabled = appState.settings.reapplyReminderEnabled
        reapplyInterval = appState.settings.reapplyIntervalMinutes
        usesLiveUV = appState.settings.usesLiveUV
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
            appState.syncCloudNow()
        }
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
                .fill(Color.white.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
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
