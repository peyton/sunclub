import SwiftUI

struct VerificationSuccessView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var completionFeedbackTrigger = 0

    private var presentation: VerificationSuccessPresentation {
        appState.verificationSuccessPresentation
            ?? VerificationSuccessPresentation(streak: appState.currentStreak)
    }

    var body: some View {
        SunLightScreen {
            VStack(spacing: 28) {
                ZStack(alignment: .bottomTrailing) {
                    SunSuccessBurst(
                        size: 186,
                        milestone: SunSuccessBurst.milestoneLevel(for: presentation.streak)
                    )

                    Circle()
                        .fill(AppPalette.success)
                        .frame(width: 42, height: 42)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppPalette.onAccent)
                        }
                        .offset(x: 10, y: 8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(presentation.title)
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
                } else {
                    Text(successProgressNote)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 56)
            .frame(maxWidth: .infinity)
        } footer: {
            VStack(spacing: 10) {
                Button(SunclubCopy.Success.actionTitle) {
                    appState.clearVerificationSuccessPresentation()
                    if appState.settings.reapplyReminderEnabled {
                        appState.scheduleReapplyReminder()
                    }
                    router.goHome()
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("success.done")

                if presentation.canAddDetails {
                    Button("Add SPF or Note") {
                        appState.clearVerificationSuccessPresentation()
                        router.open(.manualLog)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("success.addDetails")
                }
            }
        }
        .onAppear {
            completionFeedbackTrigger += 1
        }
        .sensoryFeedback(.success, trigger: completionFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var successProgressNote: String {
        if presentation.canAddDetails {
            return "Your streak is saved. SPF is optional; add it only if it helps later."
        }

        return "Your streak and progress are saved."
    }

    private var reapplyConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                Image(systemName: appState.reapplyReminderPlan.confirmationSymbolName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.sun)

                Text(appState.reapplyReminderPlan.confirmationText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("success.reapplyMessage")
            }
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
