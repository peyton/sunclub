import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var selectedSPF: Int?
    @State private var notes: String = ""
    @State private var hasLoadedInitialState = false

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Log Sunscreen", showsBack: true, onBack: {
                    router.goBack()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text("Manual Check-In")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Confirm you've applied sunscreen today. Optionally log SPF level and a note.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
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
        appState.record(for: Date()) == nil ? "Log Today" : "Update Today"
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else {
            return
        }

        hasLoadedInitialState = true

        if let existingRecord = appState.record(for: Date()) {
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
