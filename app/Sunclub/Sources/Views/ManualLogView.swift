import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSPF: Int?
    @State private var notes: String = ""

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Log Sunscreen", showsBack: true, onBack: {
                    dismiss()
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
                    accessibilityPrefix: "manualLog"
                )

                Spacer(minLength: 0)
            }
        } footer: {
            Button("Log Today", action: logToday)
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("manualLog.logToday")
        }
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
}

#Preview {
    SunclubPreviewHost {
        ManualLogView()
    }
}
