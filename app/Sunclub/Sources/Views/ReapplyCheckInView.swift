import SwiftUI

struct ReapplyCheckInView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var successFeedbackTrigger = 0
    @State private var isSnoozing = false
    @State private var snoozeErrorMessage: String?

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Reapply", showsBack: true, onBack: {
                    router.goBack()
                })

                if let errorMessage = appState.logActionErrorMessage {
                    SunStatusCard(
                        title: "Reapplication not saved",
                        detail: errorMessage,
                        tint: AppColor.warning.opacity(0.8),
                        symbol: "exclamationmark.triangle.fill"
                    )
                    .accessibilityIdentifier("reapply.saveError")
                }

                if let snoozeErrorMessage {
                    SunStatusCard(
                        title: "Reminder not scheduled",
                        detail: snoozeErrorMessage,
                        tint: AppColor.warning.opacity(0.8),
                        symbol: "bell.slash.fill"
                    )
                    .accessibilityIdentifier("reapply.snoozeError")
                }

                if appState.reapplyCheckInPresentation != nil {
                    reapplyContent
                } else {
                    fallbackContent
                }

                Spacer(minLength: 0)
            }
        } footer: {
            footerAction
        }
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
        .sensoryFeedback(.success, trigger: successFeedbackTrigger)
    }

    private var reapplyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppText(reapplyDetail, style: .body, color: AppColor.Text.secondary)

            if let record = appState.record(for: appState.referenceDate), record.hasReapplied {
                HStack(spacing: 8) {
                    SunIcon.check.image.resizable().scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(AppColor.accent)
                        .accessibilityHidden(true)

                    Text("\(record.reapplyCount) reapply \(record.reapplyCount == 1 ? "log" : "logs") today")
                        .font(AppFont.rounded(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)

                    if let lastReapplied = record.lastReappliedAt {
                        Text("· \(lastReapplied, style: .relative) ago")
                            .font(AppFont.rounded(size: 13))
                            .foregroundStyle(AppPalette.softInk)
                    }
                }
            }
        }
    }

    private var fallbackContent: some View {
        AppText("Not logged", style: .body, color: AppColor.Text.secondary)
    }

    @ViewBuilder
    private var footerAction: some View {
        if appState.reapplyCheckInPresentation != nil {
            ViewThatFits(in: .horizontal) {
                VStack(spacing: 10) {
                    reapplyButtons
                }
            }
        } else {
            Button("Log sunscreen") {
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
            .sunGlassPrimaryButton()
            .accessibilityIdentifier("reapply.logTodayFallback")
        }
    }

    @ViewBuilder
    private var reapplyButtons: some View {
        Button("Log reapplication") {
            snoozeErrorMessage = nil
            let result = appState.recordReapplication()
            if result.succeeded {
                successFeedbackTrigger += 1
                router.goHome()
            }
        }
        .sunGlassPrimaryButton()
        .accessibilityIdentifier("reapply.log")

        if appState.settings.reapplyReminderEnabled {
            snoozeButton
        }

        Button("Dismiss") {
            router.goHome()
        }
        .buttonStyle(SunTextButtonStyle())
        .accessibilityIdentifier("reapply.skip")
    }

    private var snoozeButton: some View {
        Button(isSnoozing ? "Scheduling…" : "Snooze 15 min") {
            guard !isSnoozing else {
                return
            }
            isSnoozing = true
            snoozeErrorMessage = nil
            Task {
                let result = await appState.snoozeReapplyReminder(minutes: 15)
                isSnoozing = false
                if result.isSuccessful {
                    router.goHome()
                } else {
                    snoozeErrorMessage = result.message
                }
            }
        }
        .sunGlassSecondaryButton()
        .disabled(isSnoozing)
        .accessibilityHint("Schedules another reapply reminder in 15 minutes.")
        .accessibilityIdentifier("reapply.snooze")

    }

    private var reapplyDetail: String {
        guard let record = appState.record(for: appState.referenceDate) else {
            return "Not logged"
        }

        let time = Self.lastLoggedAt(for: record).formatted(date: .omitted, time: .shortened)
        let spf = record.spfLevel.map { " · SPF \($0)" } ?? ""
        return "Last logged \(time)\(spf)."
    }

    static func lastLoggedAt(for record: DailyRecord) -> Date {
        max(record.verifiedAt, record.lastReappliedAt ?? record.verifiedAt)
    }
}

#Preview {
    SunclubPreviewHost {
        ReapplyCheckInView()
    }
}
