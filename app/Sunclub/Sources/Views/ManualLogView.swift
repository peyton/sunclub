import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var selectedSPF: Int?
    @State private var notes: String = ""
    @State private var hasLoadedInitialState = false

    private var existingRecord: DailyRecord? {
        appState.record(for: Date())
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Today's Log", showsBack: true, onBack: {
                    router.goBack()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text(existingRecord == nil ? "Log today" : "Update today's log")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(
                        existingRecord == nil
                            ? "Confirm today's sunscreen and add SPF or a note if you want."
                            : "You're editing today's entry. Update the SPF or note below."
                    )
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }

                if let existingRecord {
                    SunStatusCard(
                        title: "Logged at \(existingRecord.verifiedAt.formatted(date: .omitted, time: .shortened))",
                        detail: "Sunclub keeps one entry for today. Save here to update it.",
                        tint: AppPalette.success,
                        symbol: "checkmark.circle.fill"
                    )
                }

                SunManualLogFields(
                    selectedSPF: $selectedSPF,
                    notes: $notes,
                    accessibilityPrefix: "manualLog",
                    suggestions: appState.manualLogSuggestionState(for: Date())
                )

                Spacer(minLength: 0)
            }
        } footer: {
            Button(primaryActionTitle, action: logToday)
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("manualLog.logToday")
        }
        .onAppear(perform: syncInitialStateIfNeeded)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private func logToday() {
        appState.recordVerificationSuccess(
            method: .manual,
            verificationDuration: nil,
            spfLevel: selectedSPF,
            notes: notes
        )
        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        router.open(.verifySuccess)
    }

    private var primaryActionTitle: String {
        existingRecord == nil ? "Log Today" : "Update Today"
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else {
            return
        }

        hasLoadedInitialState = true

        if let existingRecord {
            selectedSPF = existingRecord.spfLevel
            notes = existingRecord.notes ?? ""
            return
        }

        let suggestions = appState.manualLogSuggestionState(for: Date())
        selectedSPF = suggestions.defaultSPF
    }
}

#Preview {
    SunclubPreviewHost {
        ManualLogView()
    }
}
