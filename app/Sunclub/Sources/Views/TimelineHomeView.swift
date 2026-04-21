import SwiftUI

private struct TimelineAttentionContent {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let actionTitle: String
    let identifier: String
}

struct TimelineHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var feedbackTrigger = 0
    @State private var midnightTimer: Timer?

    var body: some View {
        @Bindable var appState = appState

        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                headerBar

                dateHeadline

                SunDayStrip(
                    selectedDay: $appState.selectedDay,
                    today: appState.referenceDate,
                    recordedDays: Set(appState.recordedDays),
                    currentStreakDays: Set(appState.currentStreakDays),
                    allowsFuture: true
                )

                attentionBanners

                TimelineLogSection(summary: logSummary)

                TimelineHighlightsSection(summary: logSummary)

                Spacer(minLength: 0)
            }
        } footer: {
            TimelineFooterBar(
                primaryTitle: primaryCTAText,
                primaryIdentifier: primaryCTAIdentifier,
                onPrimaryTap: {
                    feedbackTrigger += 1
                    performPrimaryAction()
                }
            )
        }
        .onAppear {
            refresh()
            scheduleMidnightRefresh()
        }
        .onDisappear {
            midnightTimer?.invalidate()
        }
        .refreshable {
            await refreshAsync()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            refresh()
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            SunBrandLockup(layout: .inline, markSize: 28)

            Spacer(minLength: 0)

            Button {
                feedbackTrigger += 1
                router.open(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppPalette.cardFill.opacity(0.72))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens app settings.")
            .accessibilityIdentifier("home.settingsButton")
        }
    }

    private var dateHeadline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                feedbackTrigger += 1
                jumpToToday()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headlinePrefix)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(headlineDate)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(AppPalette.ink)

                        if !isSelectedToday {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppPalette.sun)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityHeadlineLabel)
            .accessibilityHint(isSelectedToday ? "Already viewing today." : "Jumps the day strip back to today.")
            .accessibilityIdentifier("timeline.headline")

            if isSelectedToday, appState.record(for: appState.referenceDate) != nil {
                Text("Today's log is in")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.success)
                    .accessibilityIdentifier("home.todayStatus")
            }
        }
    }

    @ViewBuilder
    private var attentionBanners: some View {
        if let notificationHealth = appState.notificationHealthPresentation {
            timelineAttentionBanner(
                TimelineAttentionContent(
                    title: notificationHealth.title,
                    detail: notificationHealth.detail,
                    symbol: "bell.badge.fill",
                    tint: Color.red.opacity(0.75),
                    actionTitle: notificationHealth.actionTitle,
                    identifier: "timeline.notificationHealthAction"
                )
            ) {
                switch notificationHealth.state {
                case .denied:
                    router.open(.settings)
                case .stale:
                    appState.repairReminderSchedule()
                case .healthy:
                    break
                }
            }
        }

        if appState.pendingImportedBatchCount > 0 || !appState.conflicts.isEmpty {
            timelineAttentionBanner(
                TimelineAttentionContent(
                    title: appState.syncRecoveryTitle,
                    detail: appState.syncRecoveryDetail,
                    symbol: !appState.conflicts.isEmpty
                        ? "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
                        : "icloud.and.arrow.up",
                    tint: !appState.conflicts.isEmpty ? Color.red.opacity(0.75) : AppPalette.sun,
                    actionTitle: "Review",
                    identifier: "timeline.syncRecoveryCard"
                )
            ) {
                router.open(.recovery)
            }
        }
    }

    private func timelineAttentionBanner(
        _ content: TimelineAttentionContent,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: content.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.onAccent)
                    .frame(width: 30, height: 30)
                    .background(content.tint, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(content.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(content.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(content.actionTitle, action: action)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppPalette.warmGlow.opacity(0.5)))
                .buttonStyle(.plain)
                .accessibilityIdentifier(content.identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .sunGlassCard(cornerRadius: 18)
    }

    private var logSummary: TimelineDayLogSummary {
        appState.timelineDayLogSummary(for: appState.selectedDay)
    }

    private var headlinePrefix: String {
        isSelectedToday ? "Today" : relativeSelectedDayLabel
    }

    private var headlineDate: String {
        appState.selectedDay.formatted(.dateTime.month(.wide).day())
    }

    private var relativeSelectedDayLabel: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: appState.referenceDate)
        let selected = calendar.startOfDay(for: appState.selectedDay)
        let dayComponents = calendar.dateComponents([.day], from: today, to: selected)
        guard let dayDiff = dayComponents.day else {
            return appState.selectedDay.formatted(.dateTime.weekday(.wide))
        }
        switch dayDiff {
        case -1: return "Yesterday"
        case 1: return "Tomorrow"
        default:
            if dayDiff < 0 {
                return "\(-dayDiff) days ago"
            }
            return "In \(dayDiff) days"
        }
    }

    private var accessibilityHeadlineLabel: String {
        let dateLabel = appState.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "\(headlinePrefix), \(dateLabel)"
    }

    private var isSelectedToday: Bool {
        Calendar.current.isDate(appState.selectedDay, inSameDayAs: appState.referenceDate)
    }

    private var primaryCTAText: String {
        appState.homeDailyPlanPresentation.actionTitle
    }

    private var primaryCTAIdentifier: String {
        switch appState.homeDailyPlanPresentation.action {
        case .logToday:
            return "home.logManually"
        case .backfillYesterday, .logReapply, .addDetails, .viewProgress, .reviewRecovery, .repairReminders, .openSettings:
            return "home.loggedPrimaryAction"
        }
    }

    private func performPrimaryAction() {
        let action = appState.homeDailyPlanPresentation.action
        switch action {
        case .logToday, .addDetails:
            router.open(.manualLog)
        case .backfillYesterday:
            router.open(.backfillYesterday)
        case .logReapply:
            router.open(.reapplyCheckIn)
        case .viewProgress:
            router.open(.weeklySummary)
        case .reviewRecovery:
            router.open(.recovery)
        case .repairReminders:
            appState.repairReminderSchedule()
        case .openSettings:
            router.open(.settings)
        }
    }

    private func jumpToToday() {
        guard !isSelectedToday else {
            return
        }
        withAnimation(SunMotion.easeInOut(duration: 0.25, reduceMotion: reduceMotion)) {
            appState.selectDay(appState.referenceDate)
        }
    }

    private func refresh() {
        appState.advanceSelectedDayIfStale()
        appState.refreshUVReadingIfNeeded()
        appState.refreshUVForecastIfNeeded()
        appState.refreshNotificationHealth()
    }

    private func refreshAsync() async {
        appState.refresh()
        refresh()
        try? await Task.sleep(for: .milliseconds(300))
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        let calendar = Calendar.current
        let now = appState.referenceDate
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return
        }
        let interval = tomorrow.timeIntervalSinceNow
        guard interval > 0 else {
            return
        }
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval + 1, repeats: false) { _ in
            Task { @MainActor in
                refresh()
                scheduleMidnightRefresh()
            }
        }
    }
}

#Preview {
    SunclubPreviewHost {
        TimelineHomeView()
    }
}
