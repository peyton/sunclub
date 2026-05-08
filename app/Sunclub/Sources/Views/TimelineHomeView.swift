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
private struct TimelineHomeSharedPresentation {
    let today: Date
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
    let weatherAttribution: SunclubWeatherAttribution?
    let currentStreak: Int
    let longestStreak: Int

    init(appState: AppState) {
        let referenceDate = appState.referenceDate
        let days = appState.timelineVisibleDays
        let recordSet = Set(appState.recordedDays)

        today = referenceDate
        homeDailyPlanPresentation = appState.homeDailyPlanPresentation
        recordedDays = recordSet
        currentStreakDays = Set(appState.currentStreakDays)
        elevatedUVDays = appState.elevatedUVDays
        forecastUVLevels = appState.timelineForecastUVLevels
        extrasDays = appState.daysWithExtras
        logDetails = appState.dailyDetailsForTimeline
        visibleDays = days
        weekProgressDays = Self.weekProgressDays(today: referenceDate, recordedDays: recordSet)
        allowsFuture = appState.timelineShowsFutureDays
        uvReading = appState.uvReading
        weatherAttribution = appState.weatherAttribution
        currentStreak = appState.currentStreak
        longestStreak = appState.longestStreak
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

    init(
        appState: AppState,
        selectedDay requestedSelectedDay: Date? = nil,
        shared: TimelineHomeSharedPresentation? = nil
    ) {
        let sharedPresentation = shared ?? TimelineHomeSharedPresentation(appState: appState)
        let selected = appState.timelineClampedDay(requestedSelectedDay ?? appState.selectedDay)

        selectedDay = selected
        today = sharedPresentation.today
        logSummary = appState.timelineDayLogSummary(for: selected)
        homeDailyPlanPresentation = sharedPresentation.homeDailyPlanPresentation
        recordedDays = sharedPresentation.recordedDays
        currentStreakDays = sharedPresentation.currentStreakDays
        elevatedUVDays = sharedPresentation.elevatedUVDays
        forecastUVLevels = sharedPresentation.forecastUVLevels
        extrasDays = sharedPresentation.extrasDays
        logDetails = sharedPresentation.logDetails
        visibleDays = sharedPresentation.visibleDays
        weekProgressDays = sharedPresentation.weekProgressDays
        allowsFuture = sharedPresentation.allowsFuture
        uvReading = sharedPresentation.uvReading
        uvForecast = appState.timelineUVForecast(for: selected)
        weatherAttribution = sharedPresentation.weatherAttribution
        currentStreak = sharedPresentation.currentStreak
        longestStreak = sharedPresentation.longestStreak
    }
}

struct TimelineScrubCalculator: Equatable {
    static let defaultDayStride: CGFloat = 68

    let visibleDays: [Date]
    let calendar: Calendar
    let dayStride: CGFloat

    init(
        visibleDays: [Date],
        calendar: Calendar = .current,
        dayStride: CGFloat = Self.defaultDayStride
    ) {
        self.visibleDays = visibleDays.map { calendar.startOfDay(for: $0) }
        self.calendar = calendar
        self.dayStride = dayStride
    }

    func index(for day: Date) -> Int? {
        let normalized = calendar.startOfDay(for: day)
        return visibleDays.firstIndex(of: normalized)
    }

    func selectedDay(startDay: Date, translation: CGFloat) -> Date? {
        guard let startIndex = index(for: startDay) else {
            return nil
        }
        return visibleDays[selectedIndex(startIndex: startIndex, translation: translation)]
    }

    func selectedIndex(startIndex: Int, translation: CGFloat) -> Int {
        guard !visibleDays.isEmpty else {
            return 0
        }
        let projected = CGFloat(startIndex) - (translation / dayStride)
        let rounded = Int(projected.rounded())
        return min(max(rounded, visibleDays.startIndex), visibleDays.index(before: visibleDays.endIndex))
    }

    func scrubOffset(startIndex: Int, translation: CGFloat) -> CGFloat {
        guard !visibleDays.isEmpty else {
            return 0
        }
        let minIndex = CGFloat(visibleDays.startIndex)
        let maxIndex = CGFloat(visibleDays.index(before: visibleDays.endIndex))
        let projected = CGFloat(startIndex) - (translation / dayStride)
        let bounded = min(max(projected, minIndex), maxIndex)
        let boundedTranslation = (CGFloat(startIndex) - bounded) * dayStride
        let overflow = translation - boundedTranslation

        guard overflow != 0 else {
            return translation
        }
        return boundedTranslation + Self.rubberBand(overflow, dimension: dayStride * 2.5)
    }

    static func rubberBand(_ overflow: CGFloat, dimension: CGFloat) -> CGFloat {
        guard overflow != 0, dimension > 0 else {
            return 0
        }
        let magnitude = abs(overflow)
        let banded = (dimension * magnitude) / (dimension + magnitude)
        return overflow < 0 ? -banded : banded
    }
}

enum TimelineScrubAxis: Equatable {
    case horizontal
    case vertical
}

struct TimelineScrubGestureClassifier: Equatable {
    let minimumDistance: CGFloat
    let horizontalDominance: CGFloat

    init(minimumDistance: CGFloat = 18, horizontalDominance: CGFloat = 1.35) {
        self.minimumDistance = minimumDistance
        self.horizontalDominance = horizontalDominance
    }

    func axis(current: TimelineScrubAxis?, translation: CGSize) -> TimelineScrubAxis? {
        if let current {
            return current
        }

        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)
        guard max(horizontal, vertical) >= minimumDistance else {
            return nil
        }

        if horizontal >= vertical * horizontalDominance {
            return .horizontal
        }
        if vertical >= horizontal {
            return .vertical
        }
        return nil
    }
}

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

        SunLightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                topChrome

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
        bodyScrubSurface(for: presentation) {
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
        }
    }

    @ViewBuilder
    private func bodyScrubSurface<Content: View>(
        for presentation: TimelineHomePresentation,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let surface = ZStack(alignment: .topLeading) {
            content()
        }
        .contentShape(Rectangle())

        if isBodyScrubAvailable(for: presentation) {
            surface.highPriorityGesture(bodyScrubGesture(for: presentation), including: .all)
        } else {
            surface
        }
    }

    private func timelineContentPage(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if presentation.logSummary.category == .future {
                bodyScrubSurface(for: presentation) {
                    TimelineTodayStatusCard(
                        presentation: presentation,
                        accessibilityIdentifierSuffix: accessibilityIdentifierSuffix(
                            for: presentation,
                            isSelectedPage: isSelectedPage
                        )
                    )
                }

                bodyScrubSurface(for: presentation) {
                    futureDayActions(for: presentation, isSelectedPage: isSelectedPage)
                }
            } else {
                todayProductStack(for: presentation, isSelectedPage: isSelectedPage)
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

            attentionBanners(for: presentation, isSelectedPage: isSelectedPage)

            bodyScrubSurface(for: presentation) {
                TimelineLogSection(
                    summary: presentation.logSummary,
                    uvForecast: presentation.uvForecast,
                    weatherAttribution: presentation.weatherAttribution,
                    currentStreak: presentation.currentStreak,
                    longestStreak: presentation.longestStreak,
                    accessibilityIdentifierSuffix: accessibilityIdentifierSuffix(
                        for: presentation,
                        isSelectedPage: isSelectedPage
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 1)
    }

    private func bodyScrubGesture(for presentation: TimelineHomePresentation) -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                updateBodyScrub(value, presentation: presentation)
            }
            .onEnded { value in
                finishBodyScrub(value, presentation: presentation)
            }
    }

    private func updateBodyScrub(
        _ value: DragGesture.Value,
        presentation: TimelineHomePresentation
    ) {
        guard isBodyScrubAvailable(for: presentation) else {
            return
        }

        let axis = bodyScrubClassifier.axis(current: bodyScrubAxis, translation: value.translation)
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
        guard let startIndex = calculator.index(for: startDay),
              let selectedDay = calculator.selectedDay(
                startDay: startDay,
                translation: value.translation.width
              ) else {
            return
        }

        bodyScrubOffset = calculator.scrubOffset(
            startIndex: startIndex,
            translation: value.translation.width
        )

        guard !Calendar.current.isDate(selectedDay, inSameDayAs: appState.selectedDay) else {
            return
        }
        appState.selectTimelineDay(selectedDay)
    }

    private func finishBodyScrub(
        _ value: DragGesture.Value,
        presentation: TimelineHomePresentation
    ) {
        defer {
            settleBodyScrub()
        }
        guard isBodyScrubAvailable(for: presentation) else {
            return
        }

        let axis = bodyScrubClassifier.axis(current: bodyScrubAxis, translation: value.translation)
        bodyScrubAxis = axis
        guard axis == .horizontal else {
            return
        }

        let calculator = TimelineScrubCalculator(visibleDays: presentation.visibleDays)
        let startDay = bodyScrubStartDay ?? presentation.selectedDay
        guard let targetDay = calculator.selectedDay(
            startDay: startDay,
            translation: value.predictedEndTranslation.width
        ) else {
            return
        }
        appState.selectTimelineDay(targetDay)
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
            .sunGlassCard(cornerRadius: AppRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            pageIdentifier("timeline.backToToday", for: presentation, isSelectedPage: isSelectedPage)
        )
    }

    private var topChrome: some View {
        HStack(alignment: .center, spacing: 16) {
            SunBrandLockup(markSize: 30)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sunclub")

            Spacer(minLength: 0)

            Button {
                feedbackTrigger += 1
                router.open(.settings)
            } label: {
                Image(systemName: "bell")
                    .font(AppFont.rounded(size: 18, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppPalette.elevatedCardFill.opacity(0.92))
                            .appShadow(AppShadow.soft)
                    )
                    .overlay {
                        Circle()
                            .stroke(AppPalette.cardStroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications and settings")
            .accessibilityHint("Opens app settings.")
            .accessibilityIdentifier("home.settingsButton")
        }
    }

    private func todayProductStack(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            bodyScrubSurface(for: presentation) {
                uvContextCard(for: presentation, isSelectedPage: isSelectedPage)
            }

            bodyScrubSurface(for: presentation) {
                sunscreenLogSummaryButton(for: presentation, isSelectedPage: isSelectedPage)
            }

            bodyScrubSurface(for: presentation) {
                todayUVForecastCard(for: presentation, isSelectedPage: isSelectedPage)
            }
        }
    }

    private func uvContextCard(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        let reading = homeUVReading(for: presentation)
        return Button {
            feedbackTrigger += 1
            router.push(.uvForecast)
        } label: {
            SunUVIndexCard(
                index: reading.index,
                level: reading.level,
                sourceLabel: reading.sourceLabel,
                recommendation: reading.recommendation
            )
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

    private func todayUVForecastCard(
        for presentation: TimelineHomePresentation,
        isSelectedPage: Bool
    ) -> some View {
        let hours = forecastHours(for: presentation)
        return AppCard(padding: 13, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("UV Forecast")
                            .font(AppTextStyle.bodyMedium.font)
                            .foregroundStyle(AppPalette.ink)

                        Text(uvForecastSubtitle(for: presentation))
                            .font(AppTextStyle.caption.font)
                            .foregroundStyle(AppPalette.softInk)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(peakUVText(for: presentation))
                            .font(AppFont.rounded(size: 17, weight: .bold))
                            .foregroundStyle(AppPalette.sun)

                        Text(homeUVReading(for: presentation).sourceLabel)
                            .font(AppTextStyle.captionMedium.font)
                            .foregroundStyle(AppPalette.softInk)
                    }
                }

                SunMiniBarChart(bars: chartBars(for: hours))

                SunForecastStrip(hours: hours)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("UV forecast. \(peakUVText(for: presentation)). Hourly intensity for the selected day.")
        .accessibilityIdentifier(
            pageIdentifier("home.uvForecastExposureCard", for: presentation, isSelectedPage: isSelectedPage)
        )
    }

    private func logSummaryDetail(for presentation: TimelineHomePresentation) -> String {
        guard let record = presentation.logSummary.record else {
            return "Add a log to start your reminder."
        }

        let time = record.verifiedAt.formatted(date: .omitted, time: .shortened)
        let spf = record.spfLevel.map { "SPF \($0)" } ?? "SPF optional"
        let areas = coveredAreaSummary(for: record)
        let reapply = reapplySummary(for: record)
        return [time, spf, areas, reapply].compactMap(\.self).joined(separator: " • ")
    }

    private func coveredAreaSummary(for record: DailyRecord) -> String? {
        let areas = SunManualLogInput.coveredAreas(in: record.notes)
        guard !areas.isEmpty else {
            return "Areas not set"
        }
        return SunManualLogInput.coveredAreas.filter { areas.contains($0) }.joined(separator: " & ")
    }

    private func reapplySummary(for record: DailyRecord) -> String? {
        guard appState.settings.reapplyReminderEnabled else {
            return nil
        }

        let base = record.lastReappliedAt ?? record.verifiedAt
        guard let deadline = Calendar.current.date(
            byAdding: .minute,
            value: appState.settings.reapplyIntervalMinutes,
            to: base
        ) else {
            return nil
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
            let lateMorningHours = liveHours.filter {
                calendar.component(.hour, from: $0.date) >= 10
            }
            return Array((lateMorningHours.isEmpty ? liveHours : lateMorningHours).prefix(7))
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

    private func uvForecastSubtitle(for presentation: TimelineHomePresentation) -> String {
        switch presentation.logSummary.category {
        case .today:
            return "Hourly intensity for today"
        case .past:
            return "Hourly context for this day"
        case .future:
            return "Hourly plan for this day"
        }
    }

    private func chartBars(for hours: [SunclubUVHourForecast]) -> [SunChartBar] {
        hours.map { hour in
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
                allowsFuture: presentation.allowsFuture,
                scrubOffset: bodyScrubOffset,
                isExternalScrubbing: isBodyScrubbing
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
        let offset = calendar.dateComponents([.day], from: today, to: selected).day
        let dateText = formattedHeadlineDate(selected, relativeTo: today)

        switch offset {
        case 0:
            return "Today, \(dateText)"
        case 1:
            return "Tomorrow, \(dateText)"
        case -1:
            return "Yesterday, \(dateText)"
        case let days? where days > 1:
            return "In \(days) days, \(dateText)"
        case let days? where days < -1:
            return "\(abs(days)) days ago, \(dateText)"
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
    let accessibilityIdentifierSuffix: String?

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
                            .accessibilityIdentifier(identifier(statusAccessibilityIdentifier))

                        if let statusDetail {
                            AppText(statusDetail, style: .body, color: AppColor.Text.secondary)
                                .accessibilityIdentifier(identifier("timeline.statusDetail"))
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
                    .accessibilityIdentifier(identifier("timeline.weekProgress"))

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
            value: "\(weekLoggedCount)/7",
            label: "logged this week",
            systemImage: "checkmark.circle.fill",
            tint: AppPalette.streakAccent
        )
        .accessibilityIdentifier(identifier("timeline.status.weekLogged"))

        StatCard(
            value: reapplyStatusValue,
            label: "reapply",
            systemImage: "timer",
            tint: AppPalette.sun
        )
        .accessibilityIdentifier(identifier("timeline.status.reapply"))
    }

    private var dateText: String {
        presentation.selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var statusTitle: String {
        switch presentation.logSummary.category {
        case .today:
            return presentation.logSummary.record == nil ? "No sunscreen logged today" : "Sunscreen Logged"
        case .past:
            return presentation.logSummary.record == nil ? "No log" : "Logged"
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

    private func identifier(_ base: String) -> String {
        guard let accessibilityIdentifierSuffix else {
            return base
        }
        return "\(base).\(accessibilityIdentifierSuffix)"
    }

    private var statusDetail: String? {
        switch presentation.logSummary.category {
        case .today:
            if presentation.logSummary.record != nil {
                return "Add SPF, areas, or a note."
            }
            return "Add a log to start your reminder."
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
            return presentation.logSummary.record == nil ? "No log" : "Logged"
        case .past:
            return presentation.logSummary.record == nil ? "Open" : "Saved"
        case .future:
            return "Plan"
        }
    }

    private var reapplyStatusValue: String {
        guard presentation.logSummary.category == .today,
              presentation.logSummary.record != nil else {
            return "After log"
        }
        return "2h"
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
