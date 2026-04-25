import SwiftUI

struct ReapplyCheckInView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var successFeedbackTrigger = 0

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Reapply Check-In", showsBack: true, onBack: {
                    router.goBack()
                })

                if let presentation = appState.reapplyCheckInPresentation {
                    reapplyContent(presentation: presentation)
                } else {
                    fallbackContent
                }

                Spacer(minLength: 0)
            }
        } footer: {
            footerAction
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
        .sensoryFeedback(.success, trigger: successFeedbackTrigger)
    }

    private func reapplyContent(presentation: ReapplyCheckInPresentation) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            SunScreenTitleBlock(
                eyebrow: "Reapply check-in",
                title: "Time to reapply?",
                detail: lastLogDetail,
                symbolName: "timer",
                tint: AppPalette.sun
            )

            SunclubCard(cornerRadius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Today stays one log", systemImage: "arrow.clockwise.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(presentation.detail)
                        .font(AppTypography.body)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let record = appState.record(for: appState.referenceDate), record.hasReapplied {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.sun)

                    Text("Reapply #\(record.reapplyCount) today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)

                    if let lastReapplied = record.lastReappliedAt {
                        Text("· \(lastReapplied, style: .relative) ago")
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.softInk)
                    }
                }
            }
        }
    }

    private var fallbackContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SunScreenTitleBlock(
                title: "No daily log yet",
                detail: "Reapply works after you've logged sunscreen for today. Log today first, then come back if you reapply.",
                symbolName: "sun.max.fill",
                tint: AppPalette.sun
            )
        }
    }

    @ViewBuilder
    private var footerAction: some View {
        if let presentation = appState.reapplyCheckInPresentation {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    reapplyButtons(presentation: presentation)
                }

                VStack(spacing: 10) {
                    reapplyButtons(presentation: presentation)
                }
            }
        } else {
            Button("Log Today") {
                let now = appState.referenceDate
                appState.prepareManualLogRouteContext(
                    targetDate: now,
                    targetDayPart: appState.dayPart(for: now),
                    source: .manualLog
                )
                router.open(
                    .manualLog,
                    targetDate: now,
                    targetDayPart: appState.dayPart(for: now)
                )
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("reapply.logTodayFallback")
        }
    }

    @ViewBuilder
    private func reapplyButtons(presentation: ReapplyCheckInPresentation) -> some View {
        Button(primaryReapplyTitle(for: presentation)) {
            appState.recordReapplication()
            successFeedbackTrigger += 1
            router.goHome()
        }
        .buttonStyle(SunPrimaryButtonStyle())
        .accessibilityIdentifier("reapply.log")

        Button("Skip Today") {
            router.goHome()
        }
        .buttonStyle(SunSecondaryButtonStyle())
        .accessibilityIdentifier("reapply.skip")
    }

    private var lastLogDetail: String {
        guard let record = appState.record(for: appState.referenceDate) else {
            return "Your sunscreen log is not saved yet."
        }

        return "Your last SPF log was \(record.verifiedAt.formatted(date: .omitted, time: .shortened))."
    }

    private func primaryReapplyTitle(for presentation: ReapplyCheckInPresentation) -> String {
        presentation.actionTitle.contains("Another") ? "Reapplied again" : "Reapplied"
    }
}

#Preview {
    SunclubPreviewHost {
        ReapplyCheckInView()
    }
}
