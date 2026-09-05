import SwiftUI

struct TimelineHomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @State private var feedbackTrigger = 0
    @State private var midnightTimer: Timer?
    @State private var bodyScrubStartDay: Date?
    @State private var bodyScrubAxis: TimelineScrubAxis?
    @State private var bodyScrubOffset: CGFloat = 0
    @State private var isBodyScrubbing = false

    private let bodyScrubClassifier = TimelineScrubGestureClassifier()

    var body: some View {
        let sharedPresentation = TimelineHomeSharedPresentation(appState: appState)
        let presentation = TimelineHomePresentation(appState: appState, shared: sharedPresentation)

        SunLightScreen(scrollAccessibilityIdentifier: "timeline.scroll") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                timelineHeader(for: presentation)

                if presentation.logSummary.category != .today {
                    timelineSelector(for: presentation, selectedDay: selectedTimelineDayBinding)
                }

                timelineContent(for: presentation)

                if presentation.logSummary.category == .today {
                    timelineSelector(for: presentation, selectedDay: selectedTimelineDayBinding)
                        .padding(.top, AppSpacing.lg)
                }
            }
            .contentShape(Rectangle())
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
        .sunNavigationBarCompatibility()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var selectedTimelineDayBinding: Binding<Date> {
        Binding(
            get: { appState.selectedDay },
            set: { newValue in
                appState.selectTimelineDay(newValue)
            }
        )
    }

    private func timelineContent(for presentation: TimelineHomePresentation) -> some View {
        selectedDayContent(for: presentation)
        .overlay {
            if RuntimeEnvironment.isUITesting {
                Color.clear
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Timeline content scrub area")
                    .accessibilityIdentifier("timeline.contentPager")
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if presentation.logSummary.category == .future {
                bodyScrubGestureLayer(for: presentation)
                    .frame(height: 240)
            }
        }
    }

    @ViewBuilder
    private func bodyScrubSurface<Content: View>(
        for presentation: TimelineHomePresentation,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let surface = ZStack(alignment: .topLeading) {
            content()
        }
        .contentShape(Rectangle())

        if isBodyScrubAvailable(for: presentation) {
            surface.overlay {
                bodyScrubGestureLayer(for: presentation, onTap: onTap)
            }
        } else {
            surface
        }
    }

    @ViewBuilder
    private func bodyScrubGestureLayer(
        for presentation: TimelineHomePresentation,
        onTap: (() -> Void)? = nil
    ) -> some View {
        if isBodyScrubAvailable(for: presentation) {
            TimelineBodyScrubGestureLayer(
                onChanged: { translation in
                    updateBodyScrub(translation, presentation: presentation)
                },
                onEnded: { translation, predictedEndTranslation in
                    finishBodyScrub(
                        translation,
                        predictedEndTranslation: predictedEndTranslation,
                        presentation: presentation
                    )
                },
                onTap: onTap
            )
            .accessibilityHidden(true)
        }
    }

    private func selectedDayContent(for presentation: TimelineHomePresentation) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if presentation.logSummary.category == .future {
                TimelineTodayStatusCard(presentation: presentation, accessibilityIdentifierSuffix: nil)
                futureDayActions()
            } else {
                todayProductStack(for: presentation)
            }

            if presentation.logSummary.category == .today {
                dailyPlanCardIfNeeded(for: presentation)
            }

            refreshErrorBanner()
            attentionBanners(for: presentation)

            if presentation.logSummary.category == .future {
                TimelineLogSection(
                    summary: presentation.logSummary,
                    uvForecast: presentation.uvForecast,
                    weatherAttribution: presentation.weatherAttribution,
                    currentStreak: presentation.currentStreak,
                    longestStreak: presentation.longestStreak,
                    accessibilityIdentifierSuffix: nil,
                    now: presentation.today
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func refreshErrorBanner() -> some View {
        if let refreshError = appState.lastRefreshError,
           appState.logActionErrorMessage == nil {
            timelineAttentionBanner(
                TimelineAttentionContent(
                    title: "Your data needs another try",
                    detail: refreshError,
                    symbol: "arrow.clockwise.circle.fill",
                    tint: AppColor.warning,
                    actionTitle: "Try Again",
                    identifier: "timeline.refreshError.retry"
                )
            ) {
                appState.refresh()
                refresh()
            }
        }
    }

    private func updateBodyScrub(
        _ translation: CGSize,
        presentation: TimelineHomePresentation
    ) {
        guard isBodyScrubAvailable(for: presentation) else {
            return
        }

        let axis = bodyScrubClassifier.axis(current: bodyScrubAxis, translation: translation)
        bodyScrubAxis = axis
        guard axis == .horizontal else {
            return
        }

        if bodyScrubStartDay == nil {
            bodyScrubStartDay = presentation.selectedDay
        }
        isBodyScrubbing = true

        let calculator = TimelineScrubCalculator(visibleDays: presentation.visibleDays)
        let startDay = bodyScrubStartDay ?? presentation.selectedDay
        let scrubTranslation = bodyScrubTranslation(for: translation.width)
        guard let startIndex = calculator.index(for: startDay) else {
            return
        }

        bodyScrubOffset = calculator.scrubOffset(
            startIndex: startIndex,
            translation: scrubTranslation
        )
    }

    private func finishBodyScrub(
        _ translation: CGSize,
        predictedEndTranslation: CGSize,
        presentation: TimelineHomePresentation
    ) {
        defer {
            settleBodyScrub()
        }
        guard isBodyScrubAvailable(for: presentation) else {
            return
        }

        let axis = bodyScrubClassifier.axis(current: bodyScrubAxis, translation: translation)
        bodyScrubAxis = axis
        guard axis == .horizontal else {
            return
        }

        let calculator = TimelineScrubCalculator(visibleDays: presentation.visibleDays)
        let startDay = bodyScrubStartDay ?? presentation.selectedDay
        guard let targetDay = calculator.selectedDay(
            startDay: startDay,
            translation: bodyScrubTranslation(for: predictedEndTranslation.width)
        ) else {
            return
        }
        appState.selectTimelineDay(targetDay)
    }

    private func bodyScrubTranslation(for translation: CGFloat) -> CGFloat {
        min(
            max(translation, -TimelineScrubCalculator.defaultDayStride),
            TimelineScrubCalculator.defaultDayStride
        )
    }

    private func isBodyScrubAvailable(for presentation: TimelineHomePresentation) -> Bool {
        !dynamicTypeSize.isAccessibilitySize && presentation.visibleDays.count > 1
    }

    private func settleBodyScrub() {
        bodyScrubStartDay = nil
        bodyScrubAxis = nil
        isBodyScrubbing = false
        withAnimation(SunMotion.easeInOut(duration: 0.24, reduceMotion: reduceMotion)) {
            bodyScrubOffset = 0
        }
    }

    private func futureDayActions() -> some View {
        Button {
            feedbackTrigger += 1
            jumpToToday()
        } label: {
            SunInfoRow(
                title: "Back to Today",
                detail: "Return to today's log and UV context.",
                systemImage: "arrow.uturn.backward.circle.fill",
                tint: AppPalette.pool,
                showsChevron: false
            )
            .padding(14)
            .sunGlassCard(cornerRadius: AppRadius.card, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("timeline.backToToday")
    }

    private func timelineHeader(for presentation: TimelineHomePresentation) -> some View {
        let isToday = Calendar.current.isDate(presentation.selectedDay, inSameDayAs: presentation.today)

        return HStack(alignment: .top, spacing: AppSpacing.sm) {
            headlineLabel(for: presentation, isToday: isToday)

            SunIcon.sun.image
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColor.sun)
                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                .padding(AppSpacing.xs)
                .sunGlassCard(cornerRadius: AppSpacing.xl)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todayProductStack(for presentation: TimelineHomePresentation) -> some View {
        let log = TodayQuietGlassLogPresentation(
            record: presentation.logSummary.record,
            category: presentation.logSummary.category,
            now: presentation.today,
            remindersEnabled: appState.settings.reapplyReminderEnabled,
            reapplyPlan: appState.reapplyReminderPlan
        )
        let uvPresentation = TodayQuietGlassUVPresentation(
            reading: presentation.uvReading,
            forecast: presentation.uvForecast,
            status: presentation.uvStatus,
            protectionWindow: presentation.uvProtectionWindow,
            selectedDay: presentation.selectedDay,
            now: presentation.today
        )

        return todayProductContent(for: presentation, log: log, uvPresentation: uvPresentation)
    }

    private func primaryLogTitle(for presentation: TimelineHomePresentation) -> String {
        guard presentation.logSummary.record != nil else { return "Log sunscreen" }
        return presentation.logSummary.category == .today ? "Log reapplication" : "Edit sunscreen log"
    }

    private func todayProductContent(
        for presentation: TimelineHomePresentation,
        log: TodayQuietGlassLogPresentation,
        uvPresentation: TodayQuietGlassUVPresentation
    ) -> some View {
        VStack(spacing: AppSpacing.sm) {
            if presentation.logSummary.category == .today {
                bodyScrubSurface(for: presentation, onTap: openUVForecast) {
                    uvContextButton(uvPresentation, showsGauge: true)
                }
                .padding(.top, AppSpacing.xs)
            }

            Button {
                openSelectedDayLog(for: presentation)
            } label: {
                TodayQuietGlassLogSummary(presentation: log)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.sunscreenLogCard")
            .accessibilityHint("Opens the sunscreen log to edit SPF, areas, and notes.")

            if let reminderText = log.reminderText {
                Divider()
                    .overlay(AppColor.stroke)
                    .accessibilityHidden(true)
                reminderRow(text: reminderText, detail: log.reminderDetail, canLogReapply: log.canLogReapply)
            }

            TodayQuietGlassLogButton(
                title: primaryLogTitle(for: presentation)
            ) {
                if presentation.logSummary.category == .today, presentation.logSummary.record != nil {
                    router.push(.reapplyCheckIn)
                } else {
                    openSelectedDayLog(for: presentation)
                }
            }

            if let lastLogDetail = log.lastLogDetail {
                AppText(lastLogDetail, style: .caption, color: AppColor.Text.secondary, alignment: .center)
                    .accessibilityIdentifier("home.lastLogged")
            }

            if presentation.logSummary.category == .today {
                uvSupportingDetail(uvPresentation, presentation: presentation)
            } else {
                bodyScrubSurface(for: presentation, onTap: openUVForecast) {
                    uvContextButton(uvPresentation, showsGauge: false)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func openSelectedDayLog(for presentation: TimelineHomePresentation) {
        feedbackTrigger += 1
        openManualLog(context: presentation.logSummary.loggingContext)
    }

    @ViewBuilder
    private func reminderRow(text: String, detail: String?, canLogReapply: Bool) -> some View {
        if canLogReapply {
            Button {
                dispatchDailyPlanAction(.logReapply)
            } label: {
                TodayQuietGlassReminder(text: text, detail: detail, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.reapplyReminder")
            .accessibilityHint("Opens reapply check-in to log another application or snooze the reminder.")
        } else {
            TodayQuietGlassReminder(text: text, detail: detail)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.reapplyReminder")
        }
    }

    private func uvContextButton(_ uvPresentation: TodayQuietGlassUVPresentation, showsGauge: Bool) -> some View {
        Button(action: openUVForecast) {
            if showsGauge {
                TodayQuietGlassGauge(presentation: uvPresentation)
            } else {
                HStack(spacing: AppSpacing.xs) {
                    SunIcon.sun.image
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(AppColor.sun)
                        .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                        .accessibilityHidden(true)
                    AppText(uvPresentation.detail, style: .caption, color: AppColor.Text.secondary)
                    SunIcon.chevronRight.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: AppSpacing.sm, height: AppSpacing.sm)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, AppSpacing.sm)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(uvPresentation.accessibilityLabel)
        .accessibilityHint("Opens the hourly UV forecast.")
        .accessibilityIdentifier("home.uvIndexCard")
    }

    private func uvSupportingDetail(
        _ uvPresentation: TodayQuietGlassUVPresentation,
        presentation: TimelineHomePresentation
    ) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            if let sourceLabel = uvPresentation.sourceLabel {
                AppText(sourceLabel, style: .caption, color: AppColor.Text.secondary, alignment: .center)
                    .accessibilityIdentifier("home.uvSource")
            }
            AppText(uvPresentation.detail, style: .caption, color: AppColor.Text.secondary, alignment: .center)
                .accessibilityIdentifier("home.uvAdvice")

            if let sourceLabel = displayedAttributionSource(for: presentation, uvPresentation: uvPresentation) {
                WeatherKitAttributionFooter(
                    attribution: presentation.weatherAttribution,
                    sourceLabel: sourceLabel,
                    showAttributionLink: true
                )
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    private func displayedAttributionSource(
        for presentation: TimelineHomePresentation,
        uvPresentation: TodayQuietGlassUVPresentation
    ) -> String? {
        guard uvPresentation.index != nil else { return nil }
        if let reading = presentation.uvReading, reading.index >= 0 {
            return reading.source.shouldDisplayAttribution ? reading.source.statusLabel : nil
        }
        return presentation.uvForecast.map(\.sourceLabel)
            .flatMap { UVReadingSource.shouldDisplayAttribution(for: $0) ? $0 : nil }
    }

    @ViewBuilder
    private func dailyPlanCardIfNeeded(for presentation: TimelineHomePresentation) -> some View {
        if TodayQuietGlassLogPresentation.showsDailyPlan(presentation.homeDailyPlanPresentation.action) {
            dailyPlanCard(for: presentation)
        }
    }

    private func dailyPlanCard(for presentation: TimelineHomePresentation) -> some View {
        let plan = presentation.homeDailyPlanPresentation
        return AppCard(padding: AppSpacing.sm, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    dailyPlanIcon(plan.action).image
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(dailyPlanTint(plan.tone))
                        .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                        .padding(AppSpacing.xxs)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        AppText(plan.title, style: .sectionHeader)
                        if !dynamicTypeSize.isAccessibilitySize {
                            AppText(plan.detail, style: .body, color: AppColor.Text.secondary)
                        }
                    }
                }

                SecondaryPillButton(
                    plan.actionTitle,
                    identifier: "home.dailyPlan.action",
                    usesGlass: false
                ) {
                    dispatchDailyPlanAction(plan.action)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    AppText(plan.detail, style: .body, color: AppColor.Text.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today’s next step")
        .accessibilityValue(plan.accessibilityValue)
        .accessibilityIdentifier("home.dailyPlan")
    }

    private func dailyPlanIcon(_ action: HomeDailyPlanAction) -> SunIcon {
        switch action {
        case .backfillYesterday: return .calendar
        case .reviewRecovery: return .shield
        case .repairReminders, .logReapply: return .clock
        case .openSettings: return .settings
        case .logToday, .addDetails: return .plus
        case .viewProgress: return .chart
        }
    }

    private func dailyPlanTint(_ tone: HomeDailyPlanTone) -> Color {
        switch tone {
        case .calm:
            return AppPalette.pool
        case .action:
            return AppPalette.sun
        case .warning:
            return AppColor.warning
        case .complete:
            return AppPalette.success
        }
    }

    private func dispatchDailyPlanAction(_ action: HomeDailyPlanAction) {
        feedbackTrigger += 1
        switch action {
        case .logToday, .addDetails:
            let today = appState.startOfLocalDay(appState.referenceDate)
            openManualLog(
                context: appState.currentLogContext(for: today, source: .timeline)
            )
        case .backfillYesterday:
            router.push(.backfillYesterday)
        case .logReapply:
            router.push(.reapplyCheckIn)
        case .viewProgress:
            router.open(.weeklySummary)
        case .reviewRecovery:
            router.push(.recovery)
        case .repairReminders:
            appState.repairReminderSchedule()
        case .openSettings:
            router.open(.settingsNotifications)
        }
    }

    private func openUVForecast() {
        feedbackTrigger += 1
        router.push(.uvForecast)
    }

    private func timelineSelector(
        for presentation: TimelineHomePresentation,
        selectedDay: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
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
                eligibilityStart: presentation.eligibilityStart,
                allowsFuture: presentation.allowsFuture,
                scrubOffset: bodyScrubOffset,
                isExternalScrubbing: isBodyScrubbing
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func headlineLabel(for presentation: TimelineHomePresentation, isToday: Bool) -> some View {
        let text = VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(relativeHeadlineTitle(for: presentation.selectedDay))
                .font(AppTypography.screenTitle)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(formattedHeadlineDate(
                Calendar.current.startOfDay(for: presentation.selectedDay),
                relativeTo: Calendar.current.startOfDay(for: appState.referenceDate)
            ))
            .font(AppTextStyle.captionMedium.font)
            .foregroundStyle(AppPalette.softInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("timeline.headline")
        .accessibilityLabel(accessibilityHeadlineLabel(for: presentation))

        if isToday {
            text
        } else {
            text
                .onTapGesture {
                    feedbackTrigger += 1
                    jumpToToday()
                }
                .accessibilityHint("Returns to today's date.")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    feedbackTrigger += 1
                    jumpToToday()
                }
        }
    }

    @ViewBuilder
    private func attentionBanners(for presentation: TimelineHomePresentation) -> some View {
        let planAction = presentation.logSummary.category == .today
            ? presentation.homeDailyPlanPresentation.action : nil
        if let notificationHealth = appState.notificationHealthPresentation,
           planAction != .repairReminders, planAction != .openSettings {
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

        if appState.pendingImportedBatchCount > 0 || !appState.conflicts.isEmpty, planAction != .reviewRecovery {
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
                        .font(AppTextStyle.bodyMedium.font)
                        .foregroundStyle(AppPalette.ink)

                    Text(content.detail)
                        .font(AppTextStyle.caption.font)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(content.actionTitle, action: action)
                .font(AppTextStyle.captionMedium.font)
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

    private func jumpToToday() {
        guard !Calendar.current.isDate(appState.selectedDay, inSameDayAs: appState.referenceDate) else {
            return
        }
        withAnimation(SunMotion.easeInOut(duration: 0.25, reduceMotion: reduceMotion)) {
            appState.selectTimelineDay(appState.referenceDate)
        }
    }

    private func relativeHeadline(for day: Date) -> String {
        let calendar = Calendar.current
        let selected = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: appState.referenceDate)
        let title = relativeHeadlineTitle(for: selected)
        let dateText = formattedHeadlineDate(selected, relativeTo: today)
        return "\(title), \(dateText)"
    }

    private func relativeHeadlineTitle(for day: Date) -> String {
        let calendar = Calendar.current
        let selected = calendar.startOfDay(for: day)
        let today = calendar.startOfDay(for: appState.referenceDate)
        let offset = calendar.dateComponents([.day], from: today, to: selected).day

        switch offset {
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        case -1:
            return "Yesterday"
        case let days? where days > 1:
            return "In \(days) days"
        case let days? where days < -1:
            return "\(abs(days)) days ago"
        default:
            return selected.formatted(.dateTime.weekday(.wide))
        }
    }

    private func formattedHeadlineDate(_ day: Date, relativeTo referenceDay: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, equalTo: referenceDay, toGranularity: .year) {
            return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
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
