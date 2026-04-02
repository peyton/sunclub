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

                Spacer(minLength: 0)
            }
            .padding(.top, 56)
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

            Text(appState.reapplyReminderPlan.confirmationText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityIdentifier("success.reapplyMessage")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppPalette.warmGlow.opacity(0.4))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appState.reapplyReminderPlan.confirmationText)
        .accessibilityIdentifier("success.reapplyNote")
    }
}

#Preview {
    SunclubPreviewHost(scenario: .verificationSuccess) {
        VerificationSuccessView()
    }
}
