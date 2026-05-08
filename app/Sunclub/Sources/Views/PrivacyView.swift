import SwiftUI

struct PrivacyView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var backupDocument: SunclubBackupDocument?
    @State private var isExportingBackup = false
    @State private var isConfirmingDeleteHistory = false
    @State private var exportError: String?

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "Privacy", showsBack: true, onBack: {
                    router.goBack()
                })

                SunScreenTitleBlock(
                    title: "Privacy controls",
                    detail: "Export, review, or remove sunscreen history without changing the app's private-by-default posture.",
                    symbolName: "lock.fill",
                    tint: AppPalette.aloe
                )

                privacyRows

                Button {
                    openURL(SunclubWebLinks.privacy)
                } label: {
                    HStack(spacing: 6) {
                        Text("Learn more about our privacy practices")
                        Image(systemName: "arrow.right")
                            .font(AppFont.rounded(size: 12, weight: .semibold))
                    }
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.pool)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("privacy.learnMore")

                Spacer(minLength: 0)
            }
        }
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: SunclubBackupDocument.contentType,
            defaultFilename: backupDocument?.suggestedFilename
        ) { result in
            if case let .failure(error) = result {
                exportError = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Delete sunscreen history?",
            isPresented: $isConfirmingDeleteHistory,
            titleVisibility: .visible
        ) {
            Button("Delete History", role: .destructive) {
                deleteHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes sunscreen log entries. If iCloud Sync is on, the deletion syncs to your devices. Recent changes remain reviewable in Recovery & Changes.")
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var privacyRows: some View {
        VStack(alignment: .leading, spacing: 16) {
            SunInfoRow(
                title: "No ads or data selling",
                detail: "Sunclub does not sell your data or use it for advertising.",
                systemImage: "shield.checkered",
                tint: AppPalette.aloe
            )
            .padding(16)
            .background(referenceRowBackground)

            SunInfoRow(
                title: "Private iCloud sync",
                detail: "When sync is on, your sunscreen history follows your devices through your iCloud account.",
                systemImage: "icloud",
                tint: AppPalette.aloe
            )
            .padding(16)
            .background(referenceRowBackground)

            SunInfoRow(
                title: "Export or delete anytime",
                detail: "Use the controls below to export history or remove sunscreen logs after confirmation.",
                systemImage: "square.and.arrow.up",
                tint: AppPalette.aloe
            )
            .padding(16)
            .background(referenceRowBackground)

            privacyActionRow(
                title: "Export Sunclub history",
                detail: "Create a JSON backup with logs and settings.",
                systemImage: "square.and.arrow.up.fill",
                accessibilityIdentifier: "privacy.exportHistory",
                action: beginBackupExport
            )

            privacyActionRow(
                title: "Delete Sunclub history",
                detail: "Remove sunscreen logs after confirmation. iCloud Sync shares the deletion across your devices.",
                systemImage: "trash.fill",
                accessibilityIdentifier: "privacy.deleteHistory",
                action: { isConfirmingDeleteHistory = true }
            )
        }
    }

    private func privacyActionRow(
        title: String,
        detail: String,
        systemImage: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SunInfoRow(
                title: title,
                detail: detail,
                systemImage: systemImage,
                tint: AppPalette.aloe,
                showsChevron: true
            )
            .padding(16)
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

    private func beginBackupExport() {
        do {
            backupDocument = try appState.exportBackupDocument()
            isExportingBackup = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteHistory() {
        let days = Set(appState.records.map { appState.startOfLocalDay($0.startOfDay) })
        for day in days {
            appState.deleteRecord(for: day)
        }
    }
}

#Preview {
    SunclubPreviewHost {
        PrivacyView()
    }
}
