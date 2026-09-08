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
                    ViewThatFits(in: .horizontal) {
                        HStack { commonSPFButtons }
                        VStack(alignment: .leading) { commonSPFButtons }
                    }
                    .disabled(logSaved)
                    Stepper("SPF \(spf)", value: $spf, in: 1...100)
                        .font(AppTextStyle.bodyMedium.font)
                        .frame(minHeight: 44)
                        .disabled(logSaved)
                        .accessibilityIdentifier("spfEditor.value")
                    Toggle("Use for future logs", isOn: $useForFutureLogs)
                        .font(AppTextStyle.body.font)
                        .disabled(logSaved)
                        .accessibilityIdentifier("spfEditor.useForFutureLogs")
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

    @ViewBuilder
    private var commonSPFButtons: some View {
        ForEach([15, 30, 50], id: \.self) { value in
            Button("SPF \(value)") { spf = value }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityAddTraits(spf == value ? .isSelected : [])
                .accessibilityIdentifier("spfEditor.quick.\(value)")
        }
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
