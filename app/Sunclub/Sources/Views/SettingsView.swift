import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(AppRouter.self) var router
    @Environment(\.openURL) var openURL
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @State var selectedReminderPicker: ReminderScheduleKind?
    @State var pickerTime = Date()
    @State var reapplyEnabled = false
    @State var reapplyInterval = 120
    @State var followsTravelTimeZone = true
    @State var streakRiskEnabled = true
    @State var leaveHomeReminderEnabled = false
    @State var liveUVEnabled = false
    @State var healthKitEnabled = false
    @State var dailyUVBriefingEnabled = true
    @State var extremeUVAlertsEnabled = false
    @State var iCloudSyncEnabled = true
    @State var backupDocument: SunclubBackupDocument?
    @State var isExportingBackup = false
    @State var isImportingBackup = false
    @State var backupStatus: BackupFeedback?
    @State var backupAlert: BackupAlert?
    @State var automationFeedback = ""
    @State var notificationToolFeedback = ""
    @State var isChoosingUVCity = false

    let reapplyOptions = [30, 60, 90, 120, 180, 240]
    let showsBackButton: Bool
    let detail: SettingsDetail?

    init(showsBackButton: Bool = true, detail: SettingsDetail? = nil) {
        self.showsBackButton = showsBackButton
        self.detail = detail
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

                if let detail {
                    settingsDetailContent(for: detail)
                } else {
                    settingsHome
                }

                Spacer(minLength: 0)
            }
        }
        .sheet(item: $selectedReminderPicker) { schedule in
            reminderPickerSheet(for: schedule)
        }
        .sheet(isPresented: $isChoosingUVCity) {
            CitySearchView { place in
                guard appState.updateSelectedUVPlace(place) else {
                    return false
                }
                liveUVEnabled = false
                return true
            }
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
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
    }

    var settingsTitle: String {
        detail?.title ?? "Settings"
    }

    var showsSettingsBackButton: Bool {
        showsBackButton || detail != nil
    }

    func handleSettingsBack() {
        router.goBack()
    }

    func syncLocalState() {
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

    func handleCloudSyncAction() {
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

    func formattedAccessibleInterval(_ minutes: Int) -> String {
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

}

enum SettingsDetail: Hashable {
    case sunscreenReminders
    case reapplyReminder
    case notifications
    case healthWeather
    case data
    case shortcuts
    case help

    var title: String {
        switch self {
        case .sunscreenReminders:
            return "Sunscreen & Reminders"
        case .reapplyReminder:
            return "Reapply Reminder"
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


enum SettingsSection: String, Hashable {
    case reminders
    case progress
    case data
    case automation
    case advanced
    case help
}

struct ReminderToggleCard: View {
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
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 0.82,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
    }
}

struct BackupFeedback {
    let message: String
    let tint: Color
}

struct BackupAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    SunclubPreviewHost {
        SettingsView()
    }
}
