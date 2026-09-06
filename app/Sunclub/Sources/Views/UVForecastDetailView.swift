import SwiftUI

struct UVForecastDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var forecastDay: Date {
        Self.referenceDay(in: appState)
    }

    @MainActor
    static func referenceDay(in state: AppState) -> Date {
        Calendar.current.startOfDay(for: state.referenceDate)
    }

    var body: some View {
        TimelineView(.periodic(from: forecastDay, by: 60)) { _ in
            forecastContent
                .onChange(of: forecastDay) { _, _ in refreshForecast() }
        }
        .onAppear(perform: refreshForecast)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshForecast() }
        }
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
        .accessibilityIdentifier("uvForecast.detail")
    }

    private var forecastContent: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                forecastHeader

                if let currentUV {
                    UVForecastHeroCard(
                        index: currentUV.index,
                        level: currentUV.level,
                        context: currentUV.context,
                        recommendation: currentUV.recommendation
                    )
                } else {
                    SunStatusCard(
                        title: "UV data unavailable",
                        detail: appState.liveUVStatusPresentation.detail,
                        tint: AppPalette.sun,
                        symbol: "arrow.clockwise"
                    )
                    .accessibilityIdentifier("uvForecast.unavailable")
                }

                if !forecastHours.isEmpty {
                    hourlyForecastCard
                }

                if let window = appState.uvProtectionWindow,
                   Calendar.current.isDate(window.start, inSameDayAs: forecastDay) {
                    SunStatusCard(
                        title: "Protection window",
                        detail: "\(window.start.formatted(date: .omitted, time: .shortened))–\(window.end.formatted(date: .omitted, time: .shortened))",
                        tint: AppColor.sun,
                        symbol: "sun.max"
                    )
                    .accessibilityIdentifier("uvForecast.protectionWindow")
                }

                protectionTipsCard
                sourceFooter

                Spacer(minLength: 0)
            }
        }
    }

    private var forecastHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .top, spacing: AppSpacing.xs) {
                SunLightHeader(title: "UV Forecast", showsBack: true, onBack: { router.goBack() })
                if #unavailable(iOS 26.0) {
                    documentationButton
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(locationTitle)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.ink)
                Text(forecastDay.formatted(.dateTime.month(.wide).day().year()))
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    documentationButton
                }
            }
        }
    }

    private var documentationButton: some View {
        Button {
            openURL(SunclubWebLinks.docs)
        } label: {
            SunIcon.book.image.resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(AppPalette.ink)
                .accessibilityHidden(true)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("UV index documentation")
        .accessibilityIdentifier("uvForecast.docs")
    }

    private func refreshForecast() {
        appState.refreshUVForecastIfNeeded()
    }

    private var currentUV: UVForecastPresentationReading? {
        guard appState.uvStatus.availability == .available else {
            return nil
        }

        if let reading = appState.uvReading,
           Calendar.current.isDate(reading.timestamp, inSameDayAs: forecastDay) {
            return UVForecastPresentationReading(
                index: reading.index,
                level: reading.level,
                source: reading.source,
                context: "Current UV",
                recommendation: reading.level.shortAdvice
            )
        }

        if appState.uvForecast?.isAvailable == true,
           let peakHour = forecastHours.max(by: { $0.index < $1.index }) {
            return UVForecastPresentationReading(
                index: peakHour.index,
                level: peakHour.level,
                source: forecastReadingSource,
                context: "Today’s peak UV",
                recommendation: appState.uvForecast?.recommendation ?? peakHour.level.shortAdvice
            )
        }

        return nil
    }

    private var forecastReadingSource: UVReadingSource {
        switch appState.uvForecast?.sourceLabel {
        case UVReadingSource.cachedWeatherKit.forecastLabel:
            return .cachedWeatherKit
        case UVReadingSource.localEstimate.forecastLabel:
            return .localEstimate
        default:
            return .weatherKit
        }
    }

    private var locationTitle: String {
        appState.uvStatus.source?.displayName(for: activeReadingSource) ?? "Approximate UV"
    }

    @ViewBuilder
    private var sourceFooter: some View {
        if let currentUV {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(Self.freshnessDetail(for: currentUV.source, updatedAt: appState.uvStatus.updatedAt))
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppColor.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                WeatherKitAttributionFooter(
                    attribution: appState.weatherAttribution,
                    sourceLabel: Self.dataQualityPresentation(for: currentUV.source).title,
                    showAttributionLink: currentUV.source.shouldDisplayAttribution
                )
            }
            .accessibilityIdentifier("uvForecast.dataQuality")
        }
    }

    static func freshnessDetail(for source: UVReadingSource, updatedAt: Date?) -> String {
        let updated = updatedAt.map { "Updated \($0.formatted(date: .omitted, time: .shortened))." }
        switch source {
        case .weatherKit:
            return updated ?? "Latest available forecast."
        case .cachedWeatherKit:
            return ["Last available forecast.", updated].compactMap { $0 }.joined(separator: " ")
        case .localEstimate:
            return "Based on season and time of day."
        }
    }

    private var activeReadingSource: UVReadingSource {
        appState.uvReading?.source ?? forecastReadingSource
    }

    static func dataQualityPresentation(
        for source: UVReadingSource
    ) -> UVForecastDataQualityPresentation {
        switch source {
        case .weatherKit:
            return UVForecastDataQualityPresentation(
                title: "Apple Weather",
                symbol: "checkmark.seal.fill"
            )
        case .cachedWeatherKit:
            return UVForecastDataQualityPresentation(
                title: "Apple Weather",
                symbol: "clock.arrow.circlepath"
            )
        case .localEstimate:
            return UVForecastDataQualityPresentation(
                title: "Local UV estimate",
                symbol: "sun.haze.fill"
            )
        }
    }

    private var hourlyForecastCard: some View {
        AppCard(padding: AppSpacing.sm, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Hourly Forecast")
                    .font(AppTextStyle.sectionHeader.font)
                    .foregroundStyle(AppPalette.ink)

                if let peak = forecastHours.max(by: { $0.index < $1.index }) {
                    Text("Today’s peak: UV \(peak.index) at \(peak.date.formatted(.dateTime.hour())).")
                        .font(AppTextStyle.caption.font)
                        .foregroundStyle(AppColor.Text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("uvForecast.dailyPeak")
                }

                VStack(spacing: 0) {
                    ForEach(forecastHours) { hour in
                        hourlyForecastRow(hour)

                        if hour.id != forecastHours.last?.id {
                            Divider()
                                .overlay(AppPalette.hairlineStroke)
                        }
                    }
                }
                .accessibilityIdentifier("uvForecast.hourly")
            }
        }
    }

    private func hourlyForecastRow(_ hour: SunclubUVHourForecast) -> some View {
        let isCurrent = Self.isCurrentHour(hour.date, now: appState.referenceDate)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) {
                hourLabel(hour, isCurrent: isCurrent)
                Spacer(minLength: AppSpacing.xxs)
                hourValue(hour)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                hourLabel(hour, isCurrent: isCurrent)
                hourValue(hour)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hour.date.formatted(.dateTime.hour()))\(isCurrent ? ", current hour" : ""), UV \(hour.index), \(hour.level.displayName)")
        .accessibilityIdentifier(isCurrent ? "uvForecast.hour.current" : "uvForecast.hour.\(hour.date.timeIntervalSince1970)")
    }

    private func hourLabel(_ hour: SunclubUVHourForecast, isCurrent: Bool) -> some View {
        Text("\(hour.date.formatted(.dateTime.hour()))\(isCurrent ? " · Now" : "")")
            .font(AppTextStyle.captionMedium.font)
            .foregroundStyle(AppColor.Text.primary)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func hourValue(_ hour: SunclubUVHourForecast) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Text("\(hour.index)")
                .font(AppTextStyle.metric.font)
                .foregroundStyle(AppColor.Text.primary)
            Text(hour.level.displayName)
                .font(AppTextStyle.caption.font)
                .foregroundStyle(AppColor.Text.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    static func isCurrentHour(_ date: Date, now: Date, calendar: Calendar = .current) -> Bool {
        guard let hour = calendar.dateInterval(of: .hour, for: date) else { return false }
        return now >= hour.start && now < hour.end
    }

    private var protectionTipsCard: some View {
        AppCard(padding: AppSpacing.sm, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Sun Protection Tips")
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text("Seek shade, wear a hat, and cover up.")
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("uvForecast.tips")
    }

    private var forecastHours: [SunclubUVHourForecast] {
        Self.hoursForDay(appState.uvForecast?.hours ?? [], day: forecastDay)
    }

    static func hoursForDay(
        _ hours: [SunclubUVHourForecast], day: Date, calendar: Calendar = .current
    ) -> [SunclubUVHourForecast] {
        hours.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

}

private struct UVForecastPresentationReading {
    let index: Int
    let level: UVLevel
    let source: UVReadingSource
    let context: String
    let recommendation: String
}

struct UVForecastDataQualityPresentation: Equatable {
    let title: String
    let symbol: String
}

private struct UVForecastHeroCard: View {
    let index: Int
    let level: UVLevel
    let context: String
    let recommendation: String

    @ScaledMetric(relativeTo: .largeTitle) private var metricSize: CGFloat = 72

    var body: some View {
        AppCard(padding: AppSpacing.sm, cornerRadius: AppRadius.card, fill: AppColor.surfaceElevated) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(context)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppColor.Text.secondary)
                Text("\(index)")
                    .font(AppFont.heroMetric(size: metricSize))
                    .foregroundStyle(level.designTextTint)
                Text(level.displayName)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppColor.Text.primary)
                Text(recommendation)
                    .font(AppTextStyle.body.font)
                    .foregroundStyle(AppColor.Text.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("UV Index \(index), \(level.displayName). \(context). \(recommendation)")
        .accessibilityIdentifier("uvForecast.hero")
    }
}

#Preview {
    SunclubPreviewHost {
        UVForecastDetailView()
    }
}
