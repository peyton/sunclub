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
                SunLightHeader(title: "Reapply Check-In", showsBack: true, onBack: {
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
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
        .sensoryFeedback(.success, trigger: successFeedbackTrigger)
    }

    private func reapplyContent(presentation: ReapplyCheckInPresentation) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            SunScreenTitleBlock(
                eyebrow: "Reapply",
                title: "Reapply sunscreen",
                detail: reapplyDetail,
                symbolName: "timer",
                tint: AppPalette.sun
            )

            if let record = appState.record(for: appState.referenceDate) {
                ReapplyTimelineCard(
                    record: record,
                    plan: appState.reapplyReminderPlan
                )
            }

            if let record = appState.record(for: appState.referenceDate), record.hasReapplied {
                HStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(AppFont.rounded(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.sun)

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
            .sunGlassPrimaryButton()
            .accessibilityIdentifier("reapply.logTodayFallback")
        }
    }

    @ViewBuilder
    private func reapplyButtons(presentation: ReapplyCheckInPresentation) -> some View {
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

        Button("Dismiss") {
            router.goHome()
        }
        .buttonStyle(SunTextButtonStyle())
        .accessibilityIdentifier("reapply.skip")
    }

    private var reapplyDetail: String {
        guard let record = appState.record(for: appState.referenceDate) else {
            return "Log sunscreen first, then use reapply reminders when you add more."
        }

        let time = record.verifiedAt.formatted(date: .omitted, time: .shortened)
        let spf = record.spfLevel.map { " · SPF \($0)" } ?? ""
        return "Last logged \(time)\(spf)."
    }
}

private struct ReapplyTimelineCard: View {
    let record: DailyRecord
    let plan: ReapplyReminderPlan

    var body: some View {
        SunclubCard(cornerRadius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today's timeline")
                    .font(AppFont.rounded(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                VStack(alignment: .leading, spacing: 0) {
                    ReapplyTimelineStep(
                        title: "First log",
                        detail: "Logged at \(record.verifiedAt.formatted(date: .omitted, time: .shortened))",
                        symbolName: "checkmark",
                        tint: AppPalette.success
                    )

                    ReapplyTimelineConnector()

                    ReapplyTimelineStep(
                        title: "Reapply now",
                        detail: "Log the reapplication after you put more sunscreen on.",
                        symbolName: "timer",
                        tint: AppPalette.sun,
                        isCurrent: true
                    )

                    ReapplyTimelineConnector()

                    ReapplyTimelineStep(
                        title: nextStepTitle,
                        detail: nextStepDetail,
                        symbolName: plan.shouldScheduleNotification ? "bell.fill" : "moon.stars.fill",
                        tint: plan.shouldScheduleNotification ? AppPalette.sun : AppPalette.softInk
                    )
                }

                Text("Reapply check-ins update the same day instead of creating a second sunscreen log.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reapply.timeline")
    }

    private var nextStepTitle: String {
        plan.shouldScheduleNotification ? "Next reminder" : "After sunset"
    }

    private var nextStepDetail: String {
        if let fireDate = plan.fireDate {
            return "Sunclub can remind you again around \(fireDate.formatted(date: .omitted, time: .shortened))."
        }

        return "Sunclub will stay quiet for the rest of today."
    }
}

private struct ReapplyTimelineStep: View {
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color
    var isCurrent = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(isCurrent ? 0.18 : 0.12))
                    .frame(width: 34, height: 34)

                Circle()
                    .stroke(tint.opacity(isCurrent ? 0.85 : 0.30), lineWidth: isCurrent ? 2 : 1)
                    .frame(width: 34, height: 34)

                Image(systemName: symbolName)
                    .font(AppFont.rounded(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.rounded(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(AppFont.rounded(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}

private struct ReapplyTimelineConnector: View {
    var body: some View {
        Rectangle()
            .fill(AppPalette.hairlineStroke)
            .frame(width: 2, height: 22)
            .padding(.leading, 16)
            .accessibilityHidden(true)
    }
}

#Preview {
    SunclubPreviewHost {
        ReapplyCheckInView()
    }
}
