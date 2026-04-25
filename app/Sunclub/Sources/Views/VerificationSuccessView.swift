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
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(spacing: 22) {
                ZStack(alignment: .bottomTrailing) {
                    SunSuccessBurst(
                        size: 168,
                        milestone: SunSuccessBurst.milestoneLevel(for: presentation.streak)
                    )

                    Circle()
                        .fill(AppPalette.success)
                        .frame(width: 42, height: 42)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(AppFont.rounded(size: 18, weight: .bold))
                                .foregroundStyle(AppPalette.onAccent)
                        }
                        .offset(x: 10, y: 8)
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(presentation.title)
                        .font(AppFont.rounded(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("success.title")

                    Text(presentation.detail)
                        .font(AppFont.rounded(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)

                    if presentation.isPersonalBest && presentation.streak > 1 {
                        Text("New personal best!")
                            .font(AppFont.rounded(size: 15, weight: .semibold))
                            .foregroundStyle(AppPalette.sun)
                            .accessibilityIdentifier("success.personalBest")
                    }
                }
                .frame(maxWidth: .infinity)

                successNextStepCard

                Spacer(minLength: 0)
            }
            .padding(.top, 34)
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
                    Button("Edit log") {
                        appState.clearVerificationSuccessPresentation()
                        let context = appState.lastLogContext
                            ?? appState.currentLogContext(for: appState.selectedDay, source: .manualLog)
                        appState.prepareManualLogRouteContext(
                            targetDate: context.date,
                            targetDayPart: context.dayPart,
                            source: .manualLog
                        )
                        router.open(
                            .manualLog,
                            targetDate: context.date,
                            targetDayPart: context.dayPart
                        )
                    }
                    .buttonStyle(SunTextButtonStyle())
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

    private var successNextStepCard: some View {
        SunclubCard(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        successMetricPills
                    }

                    VStack(spacing: 10) {
                        successMetricPills
                    }
                }

                if appState.settings.reapplyReminderEnabled {
                    reapplyConfirmation
                } else {
                    Text(successProgressNote)
                        .font(AppTypography.body)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("success.nextStepCard")
    }

    @ViewBuilder
    private var successMetricPills: some View {
        SunMetricPill(
            value: "\(presentation.streak)",
            label: presentation.streak == 1 ? "day in a row" : "days in a row",
            symbolName: "flame.fill",
            tint: AppPalette.streakAccent,
            accessibilityIdentifier: "success.streakMetric"
        )

        SunMetricPill(
            value: nextReminderValue,
            label: "next reminder",
            symbolName: "bell.fill",
            tint: AppPalette.sun,
            accessibilityIdentifier: "success.nextReminderMetric"
        )
    }

    private var nextReminderValue: String {
        guard let preview = appState.nextDailyReminderPreview else {
            return "Off"
        }

        return preview.fireDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private var reapplyConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next up")
                .font(AppFont.rounded(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                Image(systemName: appState.reapplyReminderPlan.confirmationSymbolName)
                    .font(AppFont.rounded(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.sun)

                Text(appState.reapplyReminderPlan.confirmationText)
                    .font(AppFont.rounded(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("success.reapplyMessage")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
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
