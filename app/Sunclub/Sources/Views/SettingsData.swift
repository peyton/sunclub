import SwiftUI
import UIKit

extension SettingsView {
    var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Backup")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Text("Export a backup before you reinstall the app or move to a new device. Backups contain private logs, settings, automation choices, and connection data, so store them securely. Import restores this phone first and leaves iCloud unchanged until you send those changes.")
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
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    var iCloudSection: some View {
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
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    @ViewBuilder
    func pendingImportActions(for session: SunclubImportSession) -> some View {
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

    var iCloudStatusTint: Color {
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

    var iCloudStatusSymbol: String {
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

    func beginBackupExport() {
        do {
            backupDocument = try appState.exportBackupDocument()
            isExportingBackup = true
        } catch {
            presentBackupError(error)
        }
    }

    func importBackup(from url: URL) {
        do {
            let summary = try appState.importBackup(from: url)
            syncLocalState()
            backupStatus = BackupFeedback(message: summary.statusMessage, tint: AppPalette.softInk)
        } catch {
            presentBackupError(error)
        }
    }

    func presentBackupError(_ error: any Error) {
        backupAlert = BackupAlert(
            title: "Backup Failed",
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        )
    }

    func backupActionButton(
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

    @ViewBuilder
    var backupHarnessSection: some View {
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
