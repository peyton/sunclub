import SwiftUI

private struct TimelineAttentionContent {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let actionTitle: String
    let identifier: String
}

@MainActor
private struct TimelineHomePresentation {
    let selectedDay: Date
    let today: Date
    let logSummary: TimelineDayLogSummary
    let homeDailyPlanPresentation: HomeDailyPlanPresentation
    let recordedDays: Set<Date>
    let currentStreakDays: Set<Date>
    let elevatedUVDays: Set<Date>
    let forecastUVLevels: [Date: UVLevel]
    let extrasDays: Set<Date>
    let logDetails: [Date: SunDayDetails]
    let visibleDays: [Date]
    let weekProgressDays: [SunWeekProgressDay]
    let allowsFuture: Bool
    let uvForecast: SunclubUVForecast?
    let weatherAttribution: SunclubWeatherAttribution?
    let currentStreak: Int
    let longestStreak: Int

    init(appState: AppState) {
        let selected = appState.selectedDay
        let referenceDate = appState.referenceDate
        let days = Self.timelineDays(centeredOn: referenceDate)

        selectedDay = selected
        today = referenceDate
        let recordSet = Set(appState.recordedDays)

        logSummary = appState.timelineDayLogSummary(for: selected)
        homeDailyPlanPresentation = appState.homeDailyPlanPresentation
        recordedDays = recordSet
        currentStreakDays = Set(appState.currentStreakDays)
        elevatedUVDays = appState.elevatedUVDays
        forecastUVLevels = Self.forecastUVLevels(
            for: days,
            today: referenceDate,
            dailyForecast: appState.dailyUVForecast
        )
        extrasDays = appState.daysWithExtras
        logDetails = appState.dailyDetailsForTimeline
        visibleDays = days
        weekProgressDays = Self.weekProgressDays(today: referenceDate, recordedDays: recordSet)
        allowsFuture = appState.timelineShowsFutureDays
        uvForecast = appState.uvForecast
        weatherAttribution = appState.weatherAttribution
        currentStreak = appState.currentStreak
        longestStreak = appState.longestStreak
    }

    private static func timelineDays(centeredOn today: Date) -> [Date] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let pastStart = calendar.date(byAdding: .day, value: -365, to: todayStart) ?? todayStart
        let futureEnd = calendar.date(byAdding: .day, value: 14, to: todayStart) ?? todayStart
        var days: [Date] = []
        var cursor = pastStart

        while cursor <= futureEnd {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? futureEnd.addingTimeInterval(86_400)
        }

        return days
    }

    private static func weekProgressDays(today: Date, recordedDays: Set<Date>) -> [SunWeekProgressDay] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let dayStart = calendar.startOfDay(for: day)
            return SunWeekProgressDay(
                date: dayStart,
                isLogged: recordedDays.contains(dayStart),
                isToday: dayStart == todayStart,
                isFuture: dayStart > todayStart
            )
        }
    }

    private static func forecastUVLevels(
        for visibleDays: [Date],
        today: Date,
        dailyForecast: [SunclubUVDayForecast]
    ) -> [Date: UVLevel] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        var levels: [Date: UVLevel] = [:]

        for forecast in dailyForecast {
            let dayStart = calendar.startOfDay(for: forecast.day)
            guard dayStart > todayStart else {
                continue
            }
            levels[dayStart] = forecast.level
        }

        for day in visibleDays {
            let dayStart = calendar.startOfDay(for: day)
            guard dayStart > todayStart, levels[dayStart] == nil else {
                continue
            }
            let midday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart
            levels[dayStart] = UVLevel.from(index: UVIndexService.estimatedUVIndex(at: midday, calendar: calendar))
        }

        return levels
    }
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
        let presentation = TimelineHomePresentation(appState: appState)

        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                headerBar

                timelineSelector(for: presentation, selectedDay: $appState.selectedDay)

                TimelineTodayStatusCard(presentation: presentation)

                attentionBanners

                TimelineLogSection(
                    summary: presentation.logSummary,
                    uvForecast: presentation.uvForecast,
                    weatherAttribution: presentation.weatherAttribution,
                    currentStreak: presentation.currentStreak,
                    longestStreak: presentation.longestStreak
                )

                Spacer(minLength: 0)
            }
        } footer: {
            TimelineFooterBar(
                primaryTitle: primaryCTAText(for: presentation),
                primaryIdentifier: primaryCTAIdentifier(for: presentation),
                onPrimaryTap: {
                    feedbackTrigger += 1
                    performPrimaryAction(using: presentation)
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

    private func timelineSelector(
        for presentation: TimelineHomePresentation,
        selectedDay: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Timeline")
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppPalette.softInk)

                Spacer(minLength: 0)

                dateHeadline(for: presentation)
            }

            SunDayStrip(
                selectedDay: selectedDay,
                today: presentation.today,
                visibleDays: presentation.visibleDays,
                recordedDays: presentation.recordedDays,
                currentStreakDays: presentation.currentStreakDays,
                elevatedUVDays: presentation.elevatedUVDays,
                forecastUVLevels: presentation.forecastUVLevels,
                extrasDays: presentation.extrasDays,
                logDetails: presentation.logDetails,
                allowsFuture: presentation.allowsFuture
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateHeadline(for presentation: TimelineHomePresentation) -> some View {
        let isToday = Calendar.current.isDate(presentation.selectedDay, inSameDayAs: presentation.today)

        return VStack(spacing: 0) {
            HStack(spacing: 7) {
                headlineLabel(for: presentation, isToday: isToday)

                if !isToday {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppPalette.pool)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isToday else {
                    return
                }
                feedbackTrigger += 1
                jumpToToday()
            }
        }
    }

    @ViewBuilder
    private func headlineLabel(for presentation: TimelineHomePresentation, isToday: Bool) -> some View {
        let text = Text(headlineText(for: presentation))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.ink)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("timeline.headline")
            .accessibilityLabel(accessibilityHeadlineLabel(for: presentation))

        if isToday {
            text
        } else {
            text
                .accessibilityHint("Returns to today's date.")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    feedbackTrigger += 1
                    jumpToToday()
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

    private func headlineText(for presentation: TimelineHomePresentation) -> String {
        relativeHeadline(for: presentation.selectedDay)
    }

    private func accessibilityHeadlineLabel(for presentation: TimelineHomePresentation) -> String {
        headlineText(for: presentation)
    }

    private func primaryCTAText(for presentation: TimelineHomePresentation) -> String {
        if presentation.logSummary.category == .future {
            return "Back to Today"
        }

        let action = presentation.homeDailyPlanPresentation.action
        switch action {
        case .logToday, .addDetails:
            return "Log \(presentation.logSummary.dayPart.title)"
        default:
            return presentation.homeDailyPlanPresentation.actionTitle
        }
    }

    private func primaryCTAIdentifier(for presentation: TimelineHomePresentation) -> String {
        if presentation.logSummary.category == .future {
            return "timeline.backToToday"
        }

        switch presentation.homeDailyPlanPresentation.action {
        case .logToday:
            return "home.logManually"
        case .backfillYesterday, .logReapply, .addDetails, .viewProgress, .reviewRecovery, .repairReminders, .openSettings:
            return "home.loggedPrimaryAction"
        }
    }

    private func performPrimaryAction(using presentation: TimelineHomePresentation) {
        if presentation.logSummary.category == .future {
            jumpToToday()
            return
        }

        let action = presentation.homeDailyPlanPresentation.action
        switch action {
        case .logToday, .addDetails:
            openManualLog(
                context: AppLogContext(
                    date: presentation.selectedDay,
                    dayPart: presentation.logSummary.dayPart,
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
        guard !Calendar.current.isDate(appState.selectedDay, inSameDayAs: appState.referenceDate) else {
            return
        }
        withAnimation(SunMotion.easeInOut(duration: 0.25, reduceMotion: reduceMotion)) {
            appState.selectDay(appState.referenceDate)
        }
    }

    private func relativeHeadline(for day: Date) -> String {
        let calendar = Calendar.current
        let selected = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: appState.referenceDate)
        let offset = calendar.dateComponents([.day], from: today, to: selected).day
        let dateText = formattedHeadlineDate(selected, relativeTo: today)

        switch offset {
        case 0:
            return "Today, \(dateText)"
        default:
            return formattedWeekdayHeadlineDate(selected, relativeTo: today)
        }
    }

    private func formattedWeekdayHeadlineDate(_ day: Date, relativeTo referenceDay: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, equalTo: referenceDay, toGranularity: .year) {
            return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    private func formattedHeadlineDate(_ day: Date, relativeTo referenceDay: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, equalTo: referenceDay, toGranularity: .year) {
            return day.formatted(.dateTime.month(.wide).day())
        }
        return day.formatted(.dateTime.month(.wide).day().year())
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

private struct TimelineTodayStatusCard: View {
    let presentation: TimelineHomePresentation

    private var isToday: Bool {
        Calendar.current.isDate(presentation.selectedDay, inSameDayAs: presentation.today)
    }

    private var weekLoggedCount: Int {
        presentation.weekProgressDays.filter(\.isLogged).count
    }

    var body: some View {
        SunclubCard(cornerRadius: 20, padding: 18, fillOpacity: 0.90) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dateText)
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(AppPalette.softInk)
                            .accessibilityIdentifier("timeline.statusDate")

                        Text(statusTitle)
                            .font(.system(size: 29, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(statusAccessibilityIdentifier)

                        Label(statusDetail, systemImage: statusSymbolName)
                            .font(AppTypography.body)
                            .foregroundStyle(statusTint)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("timeline.statusDetail")
                    }

                    Spacer(minLength: 0)

                    statusRing
                        .frame(width: 112, height: 112)
                }

                SunWeekProgressRow(days: presentation.weekProgressDays)
                    .accessibilityIdentifier("timeline.weekProgress")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        statusMetricPills
                    }

                    VStack(spacing: 10) {
                        statusMetricPills
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusMetricPills: some View {
        SunMetricPill(
            value: "\(presentation.currentStreak)",
            label: presentation.currentStreak == 1 ? "day streak" : "day streak",
            symbolName: "flame.fill",
            tint: AppPalette.streakAccent,
            accessibilityIdentifier: "timeline.status.currentStreak"
        )

        SunMetricPill(
            value: "\(weekLoggedCount)/7",
            label: "this week",
            symbolName: "calendar",
            tint: AppPalette.sun,
            accessibilityIdentifier: "timeline.status.week"
        )
    }

    private var statusRing: some View {
        ZStack {
            if presentation.logSummary.record != nil {
                SunSuccessBurst(size: 108, milestone: SunSuccessBurst.milestoneLevel(for: presentation.currentStreak))
            } else {
                SunclubVisualAsset.motifSunRing.image
                    .resizable()
                    .scaledToFit()
                    .opacity(0.48)

                Circle()
                    .stroke(
                        AppPalette.sun.opacity(0.62),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6])
                    )
                    .padding(12)
            }

            VStack(spacing: 3) {
                Image(systemName: statusSymbolName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(statusTint)
                    .accessibilityHidden(true)

                Text(ringLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
        }
        .accessibilityHidden(true)
    }

    private var dateText: String {
        presentation.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var statusTitle: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "Not yet logged" : "Protected today"
        case .past:
            return presentation.logSummary.record == nil ? "No sunscreen logged" : "Day logged"
        case .future:
            return "Forecast only"
        }
    }

    private var statusAccessibilityIdentifier: String {
        if presentation.logSummary.category == .today, presentation.logSummary.record != nil {
            return "home.todayStatus"
        }
        return "timeline.todayStatus"
    }

    private var statusDetail: String {
        switch presentation.logSummary.category {
        case .today:
            if presentation.logSummary.record != nil {
                return presentation.homeDailyPlanPresentation.detail
            }
            return "Log once before outdoor time to keep today covered."
        case .past:
            return presentation.logSummary.record == nil
                ? "Backfill this day if you applied sunscreen."
                : presentation.logSummary.sunscreenStatusText
        case .future:
            return presentation.logSummary.futurePreview?.suggestionText
                ?? "Use the forecast to plan SPF before the day starts."
        }
    }

    private var statusSymbolName: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "sun.max" : "checkmark.shield.fill"
        case .past:
            return presentation.logSummary.record == nil ? "calendar.badge.plus" : "checkmark.circle.fill"
        case .future:
            return "sparkles"
        }
    }

    private var ringLabel: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "Open" : "Done"
        case .past:
            return presentation.logSummary.record == nil ? "Open" : "Saved"
        case .future:
            return "Plan"
        }
    }

    private var statusTint: Color {
        if presentation.logSummary.record != nil {
            return AppPalette.success
        }
        return presentation.logSummary.category == .future ? AppPalette.pool : AppPalette.sun
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
