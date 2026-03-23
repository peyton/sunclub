import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var selectedSPF: Int?
    @State private var notes: String = ""

    private let commonSPFLevels = [15, 30, 50, 70, 100]

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Log Sunscreen", showsBack: true) {
                    router.goHome()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Manual Check-In")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Confirm you've applied sunscreen today. Optionally log SPF level and a note.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }

                spfSelector

                notesField

                Spacer(minLength: 0)
            }
        } footer: {
            Button("Log Today") {
                appState.recordVerificationSuccess(method: .manual, verificationDuration: nil)
                if let spf = selectedSPF {
                    appState.record(for: Date())?.spfLevel = spf
                }
                if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appState.record(for: Date())?.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                appState.save()
                if appState.settings.reapplyReminderEnabled {
                    appState.scheduleReapplyReminder()
                }
                router.open(.verifySuccess)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("manualLog.logToday")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var spfSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPF Level")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                ForEach(commonSPFLevels, id: \.self) { level in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSPF = selectedSPF == level ? nil : level
                        }
                    } label: {
                        Text("\(level)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedSPF == level ? .white : AppPalette.ink)
                            .frame(width: 48, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedSPF == level ? AppPalette.sun : Color.white.opacity(0.72))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedSPF == level ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityIdentifier("manualLog.spfSelector")
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            TextField("e.g. Applied before morning run", text: $notes)
                .font(.system(size: 15))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }
                .accessibilityIdentifier("manualLog.notesField")
        }
    }
}

#Preview {
    SunclubPreviewHost {
        ManualLogView()
    }
}
