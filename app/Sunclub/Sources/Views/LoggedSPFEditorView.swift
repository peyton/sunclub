import SwiftUI
import Observation

/// The presenting screen owns the draft when a display change recreates the sheet.
@MainActor
@Observable
final class LoggedSPFEditTarget: Identifiable {
    let id: UUID
    let snapshot: DailyRecordProjectionSnapshot
    var spf: Int
    var useForFutureLogs = false
    var logSaved = false
    var error: String?

    init(record: DailyRecord) {
        id = record.id
        snapshot = record.projectionSnapshot
        spf = snapshot.spfLevel ?? 50
    }
}

/// Saves the log once; a default-setting retry never replays that write.
struct LoggedSPFEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var target: LoggedSPFEditTarget

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        AppText("SPF for this log", style: .title)
                            .accessibilityAddTraits(.isHeader)
                        AppText(target.snapshot.verifiedAt.formatted(date: .abbreviated, time: .shortened), style: .caption, color: AppColor.Text.secondary)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { commonSPFButtons }
                        VStack(alignment: .leading) { commonSPFButtons }
                    }
                    .disabled(target.logSaved)
                    Stepper("SPF \(target.spf)", value: $target.spf, in: 1...100)
                        .font(AppTextStyle.bodyMedium.font)
                        .frame(minHeight: 44)
                        .disabled(target.logSaved)
                        .accessibilityIdentifier("spfEditor.value")
                    Divider().overlay(AppColor.stroke).accessibilityHidden(true)
                    Toggle("Use for future logs", isOn: $target.useForFutureLogs)
                        .font(AppTextStyle.body.font)
                        .disabled(target.logSaved)
                        .accessibilityIdentifier("spfEditor.useForFutureLogs")
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColor.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(target.logSaved ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target.logSaved ? "Retry saving default" : "Save SPF", action: save)
                        .accessibilityIdentifier("spfEditor.save")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert(
            target.logSaved ? "Default SPF not saved" : "SPF not saved",
            isPresented: Binding(
                get: { target.error != nil },
                set: { if !$0 { target.error = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(target.error ?? "")
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var commonSPFButtons: some View {
        ForEach([15, 30, 50], id: \.self) { value in
            Button("SPF \(value)") { target.spf = value }
                .font(AppTextStyle.bodyMedium.font)
                .padding(.horizontal, AppSpacing.sm)
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(target.spf == value ? AppColor.primaryActionForeground : AppColor.Text.primary)
                .background(target.spf == value ? AppColor.primaryAction : AppColor.surfaceElevated, in: Capsule())
                .buttonStyle(.plain)
                .accessibilityAddTraits(target.spf == value ? .isSelected : [])
                .accessibilityIdentifier("spfEditor.quick.\(value)")
        }
    }

    private func save() {
        if !target.logSaved {
            let result = appState.updateLoggedSPF(recordID: target.id, expected: target.snapshot, spf: target.spf)
            guard result.succeeded else {
                target.error = result.error == .staleChange
                    ? "This log changed while you were editing. Close this sheet and open SPF again to review the latest log."
                    : result.error?.localizedDescription
                return
            }
            target.logSaved = true
        }
        if target.useForFutureLogs && !appState.updateFutureLogSPF(target.spf) {
            target.error = "Your log’s SPF was saved, but the future default was not. Retry to save only the default."
            return
        }
        dismiss()
    }
}
