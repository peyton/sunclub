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

                quickJumpStrip

                SunDayStrip(
                    selectedDay: $appState.selectedDay,
                    today: appState.referenceDate,
                    recordedDays: Set(appState.recordedDays),
                    currentStreakDays: Set(appState.currentStreakDays),
                    elevatedUVDays: appState.elevatedUVDays,
                    extrasDays: appState.daysWithExtras,
                    logDetails: appState.dailyDetailsForTimeline,
                    allowsFuture: appState.timelineShowsFutureDays
                )

                attentionBanners

                TimelineLogSection(summary: logSummary) { context in
                    openManualLog(context: context)
                }

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
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                Text(headlineText)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("timeline.headline")

                Text(headlineSubtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(headlineSubtitleTint)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("timeline.headlineSubtitle")
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityHeadlineLabel)

            sunConnector
        }
    }

    private var quickJumpStrip: some View {
        let calendar = Calendar.current
        let today = appState.startOfLocalDay(appState.referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let selected = appState.startOfLocalDay(appState.selectedDay)

        return HStack(spacing: 10) {
            quickJumpButton(
                title: "Today",
                isDisabled: selected == today
            ) {
                appState.selectDay(today)
            }
            .accessibilityIdentifier("timeline.jump.today")

            quickJumpButton(
                title: "Yesterday",
                isDisabled: selected == yesterday
            ) {
                appState.selectDay(yesterday)
            }
            .accessibilityIdentifier("timeline.jump.yesterday")
        }
    }

    private func quickJumpButton(title: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title) {
            feedbackTrigger += 1
            withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
                action()
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(isDisabled ? AppPalette.muted : AppPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppPalette.cardFill.opacity(isDisabled ? 0.45 : 0.76))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.cardStroke, lineWidth: 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var sunConnector: some View {
        VStack(spacing: 0) {
            SunburstMark(size: 14, tint: AppPalette.sun)
                .frame(width: 16, height: 10)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [AppPalette.sun.opacity(0.45), AppPalette.sun.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 1.5, height: 8)
        }
        .accessibilityHidden(true)
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

    private var headlineText: String {
        appState.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var headlineSubtitle: String {
        if logSummary.category == .future {
            return "Future date preview only"
        }
        if logSummary.record != nil {
            return "\(logSummary.dayPart.title) logged"
        }
        return "Next up: \(logSummary.dayPart.title)"
    }

    private var headlineSubtitleTint: Color {
        if logSummary.category == .future {
            return AppPalette.muted
        }
        if logSummary.record != nil {
            return AppPalette.success
        }
        return AppPalette.softInk
    }

    private var accessibilityHeadlineLabel: String {
        "\(headlineText). \(headlineSubtitle)."
    }

    private var isSelectedToday: Bool {
        Calendar.current.isDate(appState.selectedDay, inSameDayAs: appState.referenceDate)
    }

    private var primaryCTAText: String {
        let action = appState.homeDailyPlanPresentation.action
        switch action {
        case .logToday, .addDetails:
            return "Log \(logSummary.dayPart.title)"
        default:
            return appState.homeDailyPlanPresentation.actionTitle
        }
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
            openManualLog(
                context: AppLogContext(
                    date: appState.selectedDay,
                    dayPart: logSummary.dayPart,
                    source: .timeline
                )
            )
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

    private func openManualLog(context: AppLogContext) {
        appState.prepareManualLogRouteContext(
            targetDate: context.date,
            targetDayPart: context.dayPart,
            source: context.source
        )
        router.open(
            .manualLog,
            targetDate: context.date,
            targetDayPart: context.dayPart
        )
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

private struct SunburstMark: View {
    let size: CGFloat
    let tint: Color

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let coreRadius = size * 0.18
            let rayInner = size * 0.28
            let rayOuter = size * 0.48

            var core = Path()
            core.addEllipse(
                in: CGRect(
                    x: center.x - coreRadius,
                    y: center.y - coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                )
            )
            context.fill(core, with: .color(tint))

            let rayCount = 6
            for index in 0..<rayCount {
                let angle = (Double(index) / Double(rayCount)) * 2 * .pi
                let startX = center.x + CGFloat(cos(angle)) * rayInner
                let startY = center.y + CGFloat(sin(angle)) * rayInner
                let endX = center.x + CGFloat(cos(angle)) * rayOuter
                let endY = center.y + CGFloat(sin(angle)) * rayOuter
                var ray = Path()
                ray.move(to: CGPoint(x: startX, y: startY))
                ray.addLine(to: CGPoint(x: endX, y: endY))
                context.stroke(ray, with: .color(tint.opacity(0.75)), lineWidth: 1.2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    SunclubPreviewHost {
        TimelineHomeView()
    }
}
