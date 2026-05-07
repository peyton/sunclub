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
    let uvReading: UVReading?
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
        uvReading = appState.uvReading
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
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                todayHeader(for: presentation)

                if presentation.logSummary.category == .future {
                    timelineSelector(for: presentation, selectedDay: $appState.selectedDay)

                    TimelineTodayStatusCard(presentation: presentation)
                } else {
                    todayProductStack(for: presentation)

                    timelineSelector(for: presentation, selectedDay: $appState.selectedDay)
                }

                if presentation.logSummary.category == .today,
                   let forecast = presentation.uvForecast,
                   forecast.sourceLabel == UVReadingSource.weatherKit.forecastLabel {
                    WeatherKitAttributionFooter(
                        attribution: presentation.weatherAttribution,
                        sourceLabel: forecast.sourceLabel,
                        showAttributionLink: true
                    )
                    .padding(.horizontal, AppSpacing.sm)
                }

                attentionBanners

                if presentation.logSummary.category == .future {
                    TimelineLogSection(
                        summary: presentation.logSummary,
                        uvForecast: presentation.uvForecast,
                        weatherAttribution: presentation.weatherAttribution,
                        currentStreak: presentation.currentStreak,
                        longestStreak: presentation.longestStreak
                    )
                }

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

    private func todayHeader(for presentation: TimelineHomePresentation) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle(for: presentation))
                    .font(AppFont.rounded(size: 28, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(headerDateText(for: presentation))
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer(minLength: 0)

            Button {
                feedbackTrigger += 1
                router.open(.settings)
            } label: {
                SunLogoMark(size: 38)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens app settings.")
            .accessibilityIdentifier("home.settingsButton")
        }
    }

    private func headerTitle(for presentation: TimelineHomePresentation) -> String {
        switch presentation.logSummary.category {
        case .today:
            return "Today"
        case .past:
            return presentation.selectedDay.formatted(.dateTime.weekday(.wide))
        case .future:
            return "Plan Ahead"
        }
    }

    private func headerDateText(for presentation: TimelineHomePresentation) -> String {
        presentation.selectedDay.formatted(.dateTime.month(.wide).day().year())
    }

    private func todayProductStack(for presentation: TimelineHomePresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            uvContextCard(for: presentation)

            sunscreenLogSummaryButton(for: presentation)

            todayExposureCard(for: presentation)

            todayForecastCard(for: presentation)
        }
    }

    private func uvContextCard(for presentation: TimelineHomePresentation) -> some View {
        let reading = homeUVReading(for: presentation)
        return SunUVIndexCard(
            index: reading.index,
            level: reading.level,
            sourceLabel: reading.sourceLabel,
            recommendation: reading.recommendation
        )
    }

    private func sunscreenLogSummaryButton(for presentation: TimelineHomePresentation) -> some View {
        Button {
            feedbackTrigger += 1
            openManualLog(
                context: AppLogContext(
                    date: presentation.selectedDay,
                    dayPart: presentation.logSummary.dayPart,
                    source: .timeline
                )
            )
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: presentation.logSummary.record == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(AppFont.rounded(size: 32, weight: .semibold))
                    .foregroundStyle(presentation.logSummary.record == nil ? AppPalette.pool : AppPalette.success)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.logSummary.record == nil ? "Log Sunscreen" : "Applied")
                        .font(AppTextStyle.bodyMedium.font)
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier(presentation.logSummary.record == nil ? "timeline.todayStatus" : "home.todayStatus")

                    Text(logSummaryDetail(for: presentation))
                        .font(AppTextStyle.caption.font)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("timeline.statusDetail")
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityHidden(true)
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(AppPalette.elevatedCardFill)
                    .appShadow(AppShadow.soft)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.sunscreenLogCard")
        .accessibilityHint("Opens the sunscreen log.")
    }

    private func todayExposureCard(for presentation: TimelineHomePresentation) -> some View {
        AppCard(padding: 13, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sun Exposure")
                            .font(AppTextStyle.bodyMedium.font)
                            .foregroundStyle(AppPalette.ink)

                        Text("Forecast intensity for the selected day")
                            .font(AppTextStyle.caption.font)
                            .foregroundStyle(AppPalette.softInk)
                    }

                    Spacer(minLength: 0)

                    Text(peakUVText(for: presentation))
                        .font(AppFont.rounded(size: 17, weight: .bold))
                        .foregroundStyle(AppPalette.sun)
                }

                SunMiniBarChart(bars: chartBars(for: presentation))
            }
        }
        .accessibilityIdentifier("home.sunExposureCard")
    }

    private func todayForecastCard(for presentation: TimelineHomePresentation) -> some View {
        AppCard(padding: 13, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today's Forecast")
                        .font(AppTextStyle.bodyMedium.font)
                        .foregroundStyle(AppPalette.ink)

                    Spacer(minLength: 0)

                    Text(homeUVReading(for: presentation).sourceLabel)
                        .font(AppTextStyle.captionMedium.font)
                        .foregroundStyle(AppPalette.softInk)
                }

                SunForecastStrip(hours: forecastHours(for: presentation))
            }
        }
    }

    private func logSummaryDetail(for presentation: TimelineHomePresentation) -> String {
        guard let record = presentation.logSummary.record else {
            return "Track SPF, timing, and covered areas."
        }

        let time = record.verifiedAt.formatted(date: .omitted, time: .shortened)
        let spf = record.spfLevel.map { "SPF \($0)" } ?? "SPF optional"
        let notes = record.trimmedNotes == nil ? "" : " • Note saved"
        return "\(time) • \(spf)\(notes)"
    }

    private struct HomeUVReading {
        let index: Int
        let level: UVLevel
        let sourceLabel: String
        let recommendation: String
    }

    private func homeUVReading(for presentation: TimelineHomePresentation) -> HomeUVReading {
        if let uvReading = presentation.uvReading,
           Calendar.current.isDate(uvReading.timestamp, inSameDayAs: presentation.today) {
            return HomeUVReading(
                index: uvReading.index,
                level: uvReading.level,
                sourceLabel: uvReading.source.statusLabel,
                recommendation: uvReading.level.shortAdvice
            )
        }

        if let peakHour = presentation.uvForecast?.peakHour {
            return HomeUVReading(
                index: peakHour.index,
                level: peakHour.level,
                sourceLabel: presentation.uvForecast?.sourceLabel ?? peakHour.sourceLabel,
                recommendation: peakHour.level.shortAdvice
            )
        }

        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: presentation.selectedDay)
            ?? presentation.selectedDay
        let estimated = UVIndexService.estimatedUVIndex(at: noon, calendar: calendar)
        let level = UVLevel.from(index: estimated)
        return HomeUVReading(
            index: estimated,
            level: level,
            sourceLabel: UVReadingSource.heuristic.statusLabel,
            recommendation: level.shortAdvice
        )
    }

    private func forecastHours(for presentation: TimelineHomePresentation) -> [SunclubUVHourForecast] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: presentation.selectedDay)
        let liveHours = presentation.uvForecast?.hours.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDay)
        } ?? []
        if !liveHours.isEmpty {
            return Array(liveHours.prefix(7))
        }

        return [10, 11, 12, 13, 14].compactMap { hour in
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDay) else {
                return nil
            }
            return SunclubUVHourForecast(
                date: date,
                index: UVIndexService.estimatedUVIndex(at: date, calendar: calendar),
                sourceLabel: UVReadingSource.heuristic.hourlySourceLabel
            )
        }
    }

    private func chartBars(for presentation: TimelineHomePresentation) -> [SunChartBar] {
        forecastHours(for: presentation).map { hour in
            SunChartBar(
                label: hour.date.formatted(.dateTime.hour()),
                value: hour.index,
                tint: tint(for: hour.level)
            )
        }
    }

    private func peakUVText(for presentation: TimelineHomePresentation) -> String {
        guard let peakHour = forecastHours(for: presentation).max(by: { $0.index < $1.index }) else {
            return "UV --"
        }
        return "Peak UV \(peakHour.index)"
    }

    private func tint(for level: UVLevel) -> Color {
        switch level {
        case .low:
            return AppPalette.aloe
        case .moderate:
            return AppPalette.sun.opacity(0.72)
        case .high:
            return AppPalette.sun
        case .veryHigh:
            return AppPalette.coral
        case .extreme:
            return AppPalette.uvExtreme
        case .unknown:
            return AppPalette.muted
        }
    }

    private func timelineSelector(
        for presentation: TimelineHomePresentation,
        selectedDay: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                AppText("Timeline", style: .sectionHeader)

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
                        .font(AppFont.rounded(size: 15, weight: .semibold))
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
            .font(AppTextStyle.sectionHeader.font)
            .foregroundStyle(AppPalette.ink)
            .tracking(AppTextStyle.sectionHeader.tracking)
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
                    tint: AppColor.warning.opacity(0.75),
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
                    tint: !appState.conflicts.isEmpty ? AppColor.warning.opacity(0.75) : AppPalette.sun,
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
                    .font(AppFont.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.onAccent)
                    .frame(width: 30, height: 30)
                    .background(content.tint, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(content.title)
                        .font(AppFont.rounded(size: 15, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(content.detail)
                        .font(AppFont.rounded(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(content.actionTitle, action: action)
                .font(AppFont.rounded(size: 13, weight: .semibold))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: TimelineHomePresentation

    private var isToday: Bool {
        Calendar.current.isDate(presentation.selectedDay, inSameDayAs: presentation.today)
    }

    private var weekLoggedCount: Int {
        presentation.weekProgressDays.filter(\.isLogged).count
    }

    var body: some View {
        AppCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        AppText(statusTitle, style: .largeTitle)
                            .accessibilityIdentifier(statusAccessibilityIdentifier)

                        if let statusDetail {
                            AppText(statusDetail, style: .body, color: AppColor.Text.secondary)
                                .accessibilityIdentifier("timeline.statusDetail")
                        }
                    }

                    Spacer(minLength: 0)

                    StatusBadge(
                        title: ringLabel,
                        systemImage: statusSymbolName,
                        tint: statusTint
                    )
                }

                Rectangle()
                    .fill(AppPalette.hairlineStroke)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                SunWeekProgressRow(days: presentation.weekProgressDays)
                    .accessibilityIdentifier("timeline.weekProgress")

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        statusMetricCards
                    }
                } else {
                    HStack(spacing: 10) {
                        statusMetricCards
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusMetricCards: some View {
        StatCard(
            value: "\(presentation.currentStreak)",
            label: presentation.currentStreak == 1 ? "day streak" : "day streak",
            systemImage: "flame.fill",
            tint: AppPalette.streakAccent
        )
        .accessibilityIdentifier("timeline.status.currentStreak")

        StatCard(
            value: "\(weekLoggedCount)/7",
            label: "this week",
            systemImage: "calendar",
            tint: AppPalette.sun
        )
        .accessibilityIdentifier("timeline.status.week")
    }

    private var dateText: String {
        presentation.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var statusTitle: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "Not applied" : "Applied"
        case .past:
            return presentation.logSummary.record == nil ? "No log" : "Applied"
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

    private var statusDetail: String? {
        switch presentation.logSummary.category {
        case .today:
            if presentation.logSummary.record != nil {
                return "Optional: add SPF or a note"
            }
            return nil
        case .past:
            return presentation.logSummary.record == nil
                ? "Backfill this day if you applied sunscreen."
                : "SPF and notes are saved for this day."
        case .future:
            return presentation.logSummary.futurePreview?.suggestionText
                ?? "Use the forecast to plan SPF before the day starts."
        }
    }

    private var statusSymbolName: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "sun.max.fill" : "checkmark.shield.fill"
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
