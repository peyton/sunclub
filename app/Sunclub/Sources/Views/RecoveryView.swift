import SwiftUI

struct RecoveryView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Recovery & Changes", showsBack: true, onBack: {
                    router.goBack()
                })

                overviewSection

                if let session = appState.recentImportSession {
                    importSection(for: session)
                }

                if !appState.conflicts.isEmpty {
                    conflictsSection
                }

                changesSection

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Status")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            SunStatusCard(
                title: appState.cloudSyncStatusPresentation.title,
                detail: overviewDetail,
                tint: statusTint,
                symbol: overviewSymbol
            )
            .accessibilityIdentifier("recovery.overview")
        }
    }

    private func importSection(for session: SunclubImportSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Imported Backup")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Text(importTitle(for: session))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(importDetail(for: session))
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("recovery.importDetail")

                if session.publishedAt == nil {
                    Button("Send to iCloud") {
                        appState.publishImportedChanges(for: session.id)
                    }
                    .buttonStyle(SunPrimaryButtonStyle())
                    .accessibilityIdentifier("recovery.import.publish")

                    Button("Undo Import") {
                        appState.restoreImportedChanges(for: session.id)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("recovery.import.restore")
                }
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    private var conflictsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Needs Review")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(spacing: 12) {
                ForEach(Array(appState.conflicts.prefix(5))) { conflict in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(conflict.summary)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)
                            .accessibilityIdentifier("recovery.conflict.summary")

                        Text("Sunclub kept the visible result and saved the merge so you can review it here.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Undo Auto-Merge") {
                            appState.undoChange(conflict.mergedBatchID)
                            appState.resolveConflict(conflict.id)
                        }
                        .buttonStyle(SunPrimaryButtonStyle())
                        .accessibilityIdentifier("recovery.conflict.undo")

                        Button("Mark Reviewed") {
                            appState.resolveConflict(conflict.id)
                        }
                        .buttonStyle(SunSecondaryButtonStyle())
                        .accessibilityIdentifier("recovery.conflict.resolve")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(cardBackground)
                }
            }
        }
    }

    private var changesSection: some View {
        let visibleBatches = appState.changeBatches
            .filter { $0.kind != .migrationSeed }
            .prefix(12)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Recent Updates")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(spacing: 12) {
                ForEach(Array(visibleBatches.enumerated()), id: \.element.id) { index, batch in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: batchSymbol(for: batch))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppPalette.sun)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(batch.kind.displayTitle)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppPalette.ink)

                                Text(batch.summary)
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppPalette.softInk)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(batch.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppPalette.softInk)
                            }

                            Spacer(minLength: 0)
                        }

                        if batch.undoneByBatchID == nil, batch.kind.supportsUndo {
                            Button("Undo") {
                                appState.undoChange(batch.id)
                            }
                            .buttonStyle(SunSecondaryButtonStyle())
                            .accessibilityIdentifier("recovery.batch.\(index).undo")
                        } else if batch.undoneByBatchID != nil {
                            Button("Redo") {
                                appState.redoChange(batch.id)
                            }
                            .buttonStyle(SunSecondaryButtonStyle())
                            .accessibilityIdentifier("recovery.batch.\(index).redo")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(cardBackground)
                }
            }
        }
    }

    private var overviewDetail: String {
        var lines: [String] = [appState.cloudSyncStatusPresentation.detail]

        if appState.pendingImportedBatchCount > 0 {
            lines.append(SunclubCopy.Sync.savedOnlyOnThisPhone(appState.pendingImportedBatchCount))
        }

        if !appState.conflicts.isEmpty {
            lines.append(SunclubCopy.Sync.mergedChangesNeedReview(appState.conflicts.count))
        }

        return lines.joined(separator: " ")
    }

    private var overviewSymbol: String {
        if !appState.conflicts.isEmpty {
            return "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
        }
        if appState.pendingImportedBatchCount > 0 {
            return "icloud.and.arrow.up"
        }
        return "clock.arrow.trianglehead.counterclockwise.rotate.90"
    }

    private var statusTint: Color {
        if !appState.conflicts.isEmpty {
            return Color.red.opacity(0.75)
        }
        if appState.pendingImportedBatchCount > 0 {
            return AppPalette.sun
        }
        return AppPalette.success
    }

    private func importTitle(for session: SunclubImportSession) -> String {
        if let publishedAt = session.publishedAt {
            return "Published to iCloud on \(publishedAt.formatted(date: .abbreviated, time: .shortened))"
        }

        if session.publishRequestedAt != nil {
            return "Publishing to iCloud"
        }

        return "Saved on this phone"
    }

    private func importDetail(for session: SunclubImportSession) -> String {
        if session.publishedAt != nil {
            return "This backup is now part of your synced history and can still be reviewed here."
        }

        return "This backup changed only this phone. iCloud stays unchanged until you send it."
    }

    private func batchSymbol(for batch: SunclubChangeBatch) -> String {
        switch batch.kind {
        case .manualLog, .historyBackfill:
            return "plus.circle.fill"
        case .historyEdit:
            return "square.and.pencil"
        case .deleteRecord:
            return "trash.fill"
        case .undo:
            return "arrow.uturn.backward.circle.fill"
        case .redo:
            return "arrow.uturn.forward.circle.fill"
        case .restore:
            return "arrow.counterclockwise.circle.fill"
        case .importLocal, .importPublish:
            return "tray.and.arrow.down.fill"
        case .conflictAutoMerge:
            return "arrow.triangle.merge"
        default:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
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
}

private extension SunclubChangeKind {
    var supportsUndo: Bool {
        switch self {
        case .migrationSeed, .undo, .redo:
            return false
        default:
            return true
        }
    }
}

#Preview {
    SunclubPreviewHost {
        RecoveryView()
    }
}
