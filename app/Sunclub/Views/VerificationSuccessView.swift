import SwiftUI

struct VerificationSuccessView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    private var presentation: VerificationSuccessPresentation {
        appState.verificationSuccessPresentation
            ?? VerificationSuccessPresentation(streak: appState.currentStreak)
    }

    var body: some View {
        SunLightScreen {
            VStack(spacing: 28) {
                Spacer(minLength: 120)

                Circle()
                    .fill(AppPalette.success)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Text("Logged")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("success.title")

                    Text(presentation.detail)
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)

                    if presentation.isPersonalBest && presentation.streak > 1 {
                        Text("New personal best!")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.sun)
                            .accessibilityIdentifier("success.personalBest")
                    }
                }
                .frame(maxWidth: .infinity)

                if appState.settings.reapplyReminderEnabled {
                    reapplyConfirmation
                }

                Spacer(minLength: 200)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            Button("Done") {
                appState.clearVerificationSuccessPresentation()
                if appState.settings.reapplyReminderEnabled {
                    appState.scheduleReapplyReminder()
                }
                router.goHome()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("success.done")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var reapplyConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppPalette.sun)

            Text("Reapply reminder in \(formatInterval(appState.settings.reapplyIntervalMinutes))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppPalette.warmGlow.opacity(0.4))
        )
        .accessibilityIdentifier("success.reapplyNote")
    }

    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
        }
    }
}

#Preview {
    SunclubPreviewHost(scenario: .verificationSuccess) {
        VerificationSuccessView()
    }
}
