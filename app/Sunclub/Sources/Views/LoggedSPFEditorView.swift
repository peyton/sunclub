import SwiftUI

struct LoggedSPFEditTarget: Identifiable {
    let id: UUID
    let snapshot: DailyRecordProjectionSnapshot

    init(record: DailyRecord) {
        id = record.id
        snapshot = record.projectionSnapshot
    }
}

/// Saves the log once; a default-setting retry never replays that write.
struct LoggedSPFEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let target: LoggedSPFEditTarget
    @State private var spf: Int
    @State private var useForFutureLogs = false
    @State private var logSaved = false
    @State private var error: String?

    init(target: LoggedSPFEditTarget) {
        self.target = target
        _spf = State(initialValue: target.snapshot.spfLevel ?? 50)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    AppText("SPF for this log", style: .title)
                    AppText(target.snapshot.verifiedAt.formatted(date: .abbreviated, time: .shortened), style: .caption, color: AppColor.Text.secondary)
                    Stepper("SPF \(spf)", value: $spf, in: 1...100)
                        .font(AppTextStyle.bodyMedium.font)
                        .frame(minHeight: 44)
                        .disabled(logSaved)
                        .accessibilityIdentifier("spfEditor.value")
                    Toggle("Use for future logs", isOn: $useForFutureLogs)
                        .font(AppTextStyle.body.font)
                        .disabled(logSaved)
                        .accessibilityIdentifier("spfEditor.useForFutureLogs")
                    if useForFutureLogs {
                        AppText(appState.settings.sunscreenProfile == nil
                            ? "Saves a sunscreen profile named Sunscreen. You can add its product name in Settings."
                            : "Updates your saved sunscreen’s SPF. Its name and water-resistance label stay the same.",
                            style: .caption, color: AppColor.Text.secondary)
                    }
                    if let error {
                        AppText(error, style: .body, color: AppColor.warning)
                            .accessibilityIdentifier("spfEditor.error")
                    }
                    Button(action: save) {
                        AppText(logSaved ? "Retry saving default" : "Save SPF", style: .bodyMedium, color: AppColor.primaryActionForeground)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                        .sunGlassPrimaryButton()
                        .accessibilityIdentifier("spfEditor.save")
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(logSaved ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        if !logSaved {
            let result = appState.updateLoggedSPF(recordID: target.id, expected: target.snapshot, spf: spf)
            guard result.succeeded else {
                error = result.error == .staleChange
                    ? "This log changed while you were editing. Close this sheet and open SPF again to review the latest log."
                    : result.error?.localizedDescription
                return
            }
            logSaved = true
        }
        if useForFutureLogs && !appState.updateFutureLogSPF(spf) {
            error = "Your log’s SPF was saved, but the future default was not. Retry to save only the default."
            return
        }
        dismiss()
    }
}
