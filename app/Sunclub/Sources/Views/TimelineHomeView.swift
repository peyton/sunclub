import SwiftUI
import UIKit

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

                if presentation.logSummary.category == .today {
                    dailyPlanCard(for: presentation)
                }

                timelineSelector(for: presentation, selectedDay: selectedTimelineDayBinding)

                timelineContent(for: presentation)
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
        timelineContentPage(
            for: presentation,
            isSelectedPage: true
        )
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

    private func timelineContentPage(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if presentation.logSummary.category == .future {
                TimelineTodayStatusCard(
                    presentation: presentation,
                    accessibilityIdentifierSuffix: accessibilityIdentifierSuffix(
                        for: presentation,
                        isSelectedPage: isSelectedPage
                    )
                )

                futureDayActions(for: presentation, isSelectedPage: isSelectedPage)
            } else {
                todayProductStack(for: presentation, isSelectedPage: isSelectedPage)
            }

            if presentation.logSummary.category == .today,
               let forecast = presentation.uvForecast,
               UVReadingSource.shouldDisplayAttribution(for: forecast.sourceLabel) {
                WeatherKitAttributionFooter(
                    attribution: presentation.weatherAttribution,
                    sourceLabel: forecast.sourceLabel,
                    showAttributionLink: true
                )
                .padding(.horizontal, AppSpacing.sm)
            }

            refreshErrorBanner(for: presentation, isSelectedPage: isSelectedPage)

            if presentation.logSummary.category != .today {
                attentionBanners(for: presentation, isSelectedPage: isSelectedPage)
            }

            if presentation.logSummary.category == .future {
                TimelineLogSection(
                    summary: presentation.logSummary,
                    uvForecast: presentation.uvForecast,
                    weatherAttribution: presentation.weatherAttribution,
                    currentStreak: presentation.currentStreak,
                    longestStreak: presentation.longestStreak,
                    accessibilityIdentifierSuffix: accessibilityIdentifierSuffix(
                        for: presentation,
                        isSelectedPage: isSelectedPage
                    ),
                    now: presentation.today
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 1)
    }

    @ViewBuilder
    private func refreshErrorBanner(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        if let refreshError = appState.lastRefreshError,
           appState.logActionErrorMessage == nil {
            timelineAttentionBanner(
                TimelineAttentionContent(
                    title: "Your data needs another try",
                    detail: refreshError,
                    symbol: "arrow.clockwise.circle.fill",
                    tint: AppColor.warning,
                    actionTitle: "Try Again",
                    identifier: pageIdentifier(
                        "timeline.refreshError.retry",
                        for: presentation,
                        isSelectedPage: isSelectedPage
                    )
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

    private func accessibilityIdentifierSuffix(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> String? {
        guard !isSelectedPage else {
            return nil
        }
        let dayID = Int(Calendar.current.startOfDay(for: presentation.selectedDay).timeIntervalSinceReferenceDate)
        return "offscreen.\(dayID)"
    }

    private func pageIdentifier(
        _ identifier: String,
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> String {
        guard let suffix = accessibilityIdentifierSuffix(
            for: presentation,
            isSelectedPage: isSelectedPage
        ) else {
            return identifier
        }
        return "\(identifier).\(suffix)"
    }

    private func futureDayActions(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
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
        .accessibilityIdentifier(
            pageIdentifier("timeline.backToToday", for: presentation, isSelectedPage: isSelectedPage)
        )
    }

    private func timelineHeader(for presentation: TimelineHomePresentation) -> some View {
        let isToday = Calendar.current.isDate(presentation.selectedDay, inSameDayAs: presentation.today)

        return HStack(alignment: .top, spacing: 14) {
            headlineLabel(for: presentation, isToday: isToday)

            Spacer(minLength: 8)

            Image(systemName: "sun.max.fill")
                .font(AppFont.rounded(size: 24, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .frame(width: 46, height: 46)
                .background(AppPalette.warmGlow.opacity(0.48), in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppPalette.sun.opacity(0.30), lineWidth: 1)
                }
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todayProductStack(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sunscreenLogSummaryButton(for: presentation, isSelectedPage: isSelectedPage)

            bodyScrubSurface(for: presentation, onTap: openUVForecast) {
                uvContextCard(for: presentation, isSelectedPage: isSelectedPage)
            }
        }
    }

    private func dailyPlanCard(for presentation: TimelineHomePresentation) -> some View {
        let plan = presentation.homeDailyPlanPresentation
        return AppCard(padding: AppSpacing.sm, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: plan.symbolName)
                        .font(AppTextStyle.sectionHeader.font)
                        .foregroundStyle(dailyPlanTint(plan.tone))
                        .frame(width: 40, height: 40)
                        .background(dailyPlanTint(plan.tone).opacity(0.14), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        AppText(plan.title, style: .sectionHeader)
                        if !dynamicTypeSize.isAccessibilitySize {
                            AppText(plan.detail, style: .body, color: AppColor.Text.secondary)
                        }
                    }
                }

                PrimaryButton(
                    plan.actionTitle,
                    systemImage: plan.symbolName,
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

    private func uvContextCard(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        return Button {
            openUVForecast()
        } label: {
            uvContextCardLabel(for: presentation)
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
                    .padding(.trailing, 14)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the hourly UV forecast.")
        .accessibilityIdentifier(
            pageIdentifier("home.uvIndexCard", for: presentation, isSelectedPage: isSelectedPage)
        )
    }

    private func openUVForecast() {
        feedbackTrigger += 1
        router.push(.uvForecast)
    }

    @ViewBuilder
    private func uvContextCardLabel(for presentation: TimelineHomePresentation) -> some View {
        if let reading = homeUVReading(for: presentation) {
            SunUVIndexCard(
                index: reading.index,
                level: reading.level,
                sourceLabel: reading.sourceLabel,
                recommendation: reading.recommendation
            )
        } else {
            AppCard(padding: AppSpacing.sm, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: "sun.haze.fill")
                        .font(AppTextStyle.title.font)
                        .foregroundStyle(AppPalette.muted)
                        .frame(width: 44, height: 44)
                        .background(AppPalette.muted.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        AppText("UV unavailable", style: .sectionHeader)
                        AppText(
                            unavailableUVDetail(for: presentation),
                            style: .caption,
                            color: AppColor.Text.secondary
                        )
                    }

                    Spacer(minLength: AppSpacing.sm)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("UV unavailable. \(unavailableUVDetail(for: presentation))")
        }
    }

    private func sunscreenLogSummaryButton(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
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
            sunscreenLogSummaryLabel(for: presentation, isSelectedPage: isSelectedPage)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            pageIdentifier("home.sunscreenLogCard", for: presentation, isSelectedPage: isSelectedPage)
        )
        .accessibilityHint("Opens the sunscreen log.")
    }

    private func sunscreenLogSummaryLabel(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: presentation.logSummary.record == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                .font(AppFont.rounded(size: 32, weight: .semibold))
                .foregroundStyle(presentation.logSummary.record == nil ? AppPalette.pool : AppPalette.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                sunscreenLogStatusText(for: presentation, isSelectedPage: isSelectedPage)
                sunscreenLogDetailText(for: presentation, isSelectedPage: isSelectedPage)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(AppFont.rounded(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityHidden(true)
        }
        .padding(13)
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 1,
            interactive: true,
            legacyFill: AppPalette.elevatedCardFill
        )
    }

    private func sunscreenLogStatusText(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        Text(sunscreenLogStatusTitle(for: presentation))
            .font(AppTextStyle.bodyMedium.font)
            .foregroundStyle(AppPalette.ink)
            .accessibilityIdentifier(
                pageIdentifier(
                    sunscreenLogStatusIdentifier(for: presentation),
                    for: presentation,
                    isSelectedPage: isSelectedPage
                )
            )
    }

    private func sunscreenLogStatusTitle(for presentation: TimelineHomePresentation) -> String {
        if presentation.logSummary.record != nil {
            return "Sunscreen Logged"
        }

        switch presentation.logSummary.category {
        case .today:
            return "No sunscreen logged today"
        case .past:
            return "No sunscreen logged"
        case .future:
            return "Forecast only"
        }
    }

    private func sunscreenLogStatusIdentifier(for presentation: TimelineHomePresentation) -> String {
        guard presentation.logSummary.category == .today else {
            return "timeline.dayStatus"
        }
        return presentation.logSummary.record == nil ? "timeline.todayStatus" : "home.todayStatus"
    }

    private func sunscreenLogDetailText(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        Text(logSummaryDetail(for: presentation))
            .font(AppTextStyle.caption.font)
            .foregroundStyle(AppPalette.softInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(
                pageIdentifier("timeline.statusDetail", for: presentation, isSelectedPage: isSelectedPage)
            )
    }

    private func logSummaryDetail(for presentation: TimelineHomePresentation) -> String {
        guard let record = presentation.logSummary.record else {
            return "Add a log to start your reminder."
        }

        let time = record.verifiedAt.formatted(date: .omitted, time: .shortened)
        let spf = record.spfLevel.map { "SPF \($0)" } ?? "SPF optional"
        let areas = coveredAreaSummary(for: record)
        return [
            "Logged \(time)",
            "\(spf)  •  \(areas)",
            reapplySummary(for: record)
        ].joined(separator: "\n")
    }

    private func coveredAreaSummary(for record: DailyRecord) -> String {
        let areas = SunManualLogInput.coveredAreas(in: record.notes)
        guard !areas.isEmpty else {
            return "Areas not set"
        }
        return SunManualLogInput.coveredAreas.filter { areas.contains($0) }.joined(separator: " & ")
    }

    private func reapplySummary(for record: DailyRecord) -> String {
        guard appState.settings.reapplyReminderEnabled else {
            return "No reapply needed"
        }

        let base = record.lastReappliedAt ?? record.verifiedAt
        guard let deadline = Calendar.current.date(
            byAdding: .minute,
            value: appState.settings.reapplyIntervalMinutes,
            to: base
        ) else {
            return "No reapply needed"
        }

        if deadline <= appState.referenceDate {
            return "Reapply due"
        }

        let minutes = max(1, Int(deadline.timeIntervalSince(appState.referenceDate) / 60))
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes == 0
                ? "Reapply in \(hours)h"
                : "Reapply in \(hours)h \(remainingMinutes)m"
        }
        return "Reapply in \(minutes)m"
    }

    private struct HomeUVReading {
        let index: Int
        let level: UVLevel
        let sourceLabel: String
        let recommendation: String
    }

    private func homeUVReading(for presentation: TimelineHomePresentation) -> HomeUVReading? {
        guard Calendar.current.isDate(presentation.selectedDay, inSameDayAs: presentation.today),
              presentation.uvStatus.availability == .available else {
            return nil
        }

        if let uvReading = presentation.uvReading {
            return HomeUVReading(
                index: uvReading.index,
                level: uvReading.level,
                sourceLabel: uvSourceLabel(for: presentation),
                recommendation: uvRecommendation(for: presentation, level: uvReading.level)
            )
        }

        if presentation.uvForecast?.isAvailable == true,
           let peakHour = presentation.uvForecast?.peakHour {
            return HomeUVReading(
                index: peakHour.index,
                level: peakHour.level,
                sourceLabel: uvSourceLabel(for: presentation),
                recommendation: uvRecommendation(for: presentation, level: peakHour.level)
            )
        }

        return nil
    }

    private func uvSourceLabel(for presentation: TimelineHomePresentation) -> String {
        let readingSource = presentation.uvReading?.source.statusLabel
            ?? presentation.uvForecast?.sourceLabel
            ?? UVReadingSource.localEstimate.statusLabel
        let location = presentation.uvStatus.source?.displayName(for: presentation.uvReading?.source)
        let source = location.map { "\(readingSource) · \($0)" } ?? readingSource
        guard let updatedAt = presentation.uvStatus.updatedAt else {
            return source
        }
        return "\(source) · Updated \(updatedAt.formatted(date: .omitted, time: .shortened))"
    }

    private func uvRecommendation(for presentation: TimelineHomePresentation, level: UVLevel) -> String {
        guard let protectionWindow = presentation.uvProtectionWindow else {
            return level.shortAdvice
        }
        let start = protectionWindow.start.formatted(date: .omitted, time: .shortened)
        let end = protectionWindow.end.formatted(date: .omitted, time: .shortened)
        return "Protection recommended \(start)–\(end). \(level.shortAdvice)"
    }

    private func unavailableUVDetail(for presentation: TimelineHomePresentation) -> String {
        if presentation.uvStatus.freshness == .stale,
           let source = presentation.uvStatus.source?.displayName {
            let updateDetail = presentation.uvStatus.updatedAt.map {
                " Last updated \($0.formatted(date: .omitted, time: .shortened))."
            } ?? ""
            return "The cached reading for \(source) is more than 24 hours old.\(updateDetail) Sunclub will use a local estimate while it refreshes."
        }
        if let source = presentation.uvStatus.source?.displayName {
            return "No Apple Weather or local UV value is available for \(source). Refresh to try again."
        }
        return "Sunclub could not calculate a local UV estimate."
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
        let text = VStack(alignment: .leading, spacing: 3) {
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
    private func attentionBanners(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        if let notificationHealth = appState.notificationHealthPresentation {
            timelineAttentionBanner(
                TimelineAttentionContent(
                    title: notificationHealth.title,
                    detail: notificationHealth.detail,
                    symbol: "bell.badge.fill",
                    tint: AppColor.warning.opacity(0.75),
                    actionTitle: notificationHealth.actionTitle,
                    identifier: pageIdentifier(
                        "timeline.notificationHealthAction",
                        for: presentation,
                        isSelectedPage: isSelectedPage
                    )
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
                    identifier: pageIdentifier(
                        "timeline.syncRecoveryCard",
                        for: presentation,
                        isSelectedPage: isSelectedPage
                    )
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
