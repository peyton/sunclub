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
            VStack(alignment: .leading, spacing: 18) {
                forecastHeader

                if let currentUV {
                    UVForecastHeroCard(
                        index: currentUV.index,
                        level: currentUV.level,
                        sourceLabel: currentUV.sourceLabel,
                        recommendation: currentUV.recommendation
                    )

                    let quality = Self.dataQualityPresentation(for: currentUV.source)
                    SunStatusCard(
                        title: quality.title,
                        detail: dataQualityDetail,
                        tint: currentUV.source == .localEstimate ? AppPalette.sun : AppPalette.pool,
                        symbol: quality.symbol
                    )
                    .accessibilityIdentifier("uvForecast.dataQuality")

                    if currentUV.source.shouldDisplayAttribution {
                        WeatherKitAttributionFooter(
                            attribution: appState.weatherAttribution,
                            sourceLabel: currentUV.sourceLabel,
                            showAttributionLink: true
                        )
                    }
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

                protectionTipsCard

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
                sourceLabel: reading.source.statusLabel,
                recommendation: reading.level.shortAdvice
            )
        }

        if appState.uvForecast?.isAvailable == true,
           let peakHour = forecastHours.max(by: { $0.index < $1.index }) {
            return UVForecastPresentationReading(
                index: peakHour.index,
                level: peakHour.level,
                source: forecastReadingSource,
                sourceLabel: appState.uvForecast?.sourceLabel ?? peakHour.sourceLabel,
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

    private var dataQualityDetail: String {
        let dataSource = appState.uvReading?.source.statusLabel
            ?? appState.uvForecast?.sourceLabel
            ?? UVReadingSource.localEstimate.statusLabel
        let source = appState.uvStatus.source?.displayName(for: activeReadingSource) ?? "season and time of day"
        let updated = appState.uvStatus.updatedAt?.formatted(date: .omitted, time: .shortened) ?? "recently"
        if let window = appState.uvProtectionWindow {
            return "\(dataSource) · \(source) · Updated \(updated). Protection recommended \(window.start.formatted(date: .omitted, time: .shortened))–\(window.end.formatted(date: .omitted, time: .shortened))."
        }
        return "\(dataSource) · \(source) · Updated \(updated)."
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
                title: "Verified Apple Weather UV",
                symbol: "checkmark.seal.fill"
            )
        case .cachedWeatherKit:
            return UVForecastDataQualityPresentation(
                title: "Cached Apple Weather",
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
        AppCard(padding: 16, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Hourly Forecast")
                    .font(AppTextStyle.sectionHeader.font)
                    .foregroundStyle(AppPalette.ink)

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
        HStack(spacing: 14) {
            Text(hour.date.formatted(.dateTime.hour()))
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.ink)
                .frame(width: 48, alignment: .leading)

            Image(systemName: hour.level.symbolName)
                .font(AppTextStyle.bodyMedium.font)
                .foregroundStyle(AppPalette.sun)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text("\(hour.index)")
                .font(AppTextStyle.metric.font)
                .foregroundStyle(AppPalette.ink)
                .frame(width: 28, alignment: .leading)

            Spacer(minLength: 0)

            Text(hour.level.displayName)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hour.date.formatted(.dateTime.hour())), UV \(hour.index), \(hour.level.displayName)")
    }

    private var protectionTipsCard: some View {
        AppCard(padding: 16, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Sun Protection Tips")
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text("Seek shade during peak sun hours, wear a hat, and use UV-protective clothing.")
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("uvForecast.tips")
    }

    private var forecastHours: [SunclubUVHourForecast] {
        let calendar = Calendar.current
        let day = forecastDay
        let liveHours = appState.uvForecast?.hours.filter {
            calendar.isDate($0.date, inSameDayAs: day)
        } ?? []

        if !liveHours.isEmpty {
            let lateMorningHours = liveHours.filter {
                let hour = calendar.component(.hour, from: $0.date)
                return hour >= 10 && hour <= 15
            }
            return Array((lateMorningHours.isEmpty ? liveHours : lateMorningHours).prefix(6))
        }

        return []
    }
}

private struct UVForecastPresentationReading {
    let index: Int
    let level: UVLevel
    let source: UVReadingSource
    let sourceLabel: String
    let recommendation: String
}

struct UVForecastDataQualityPresentation: Equatable {
    let title: String
    let symbol: String
}

private struct UVForecastHeroCard: View {
    let index: Int
    let level: UVLevel
    let sourceLabel: String
    let recommendation: String

    var body: some View {
        AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Text("\(index)")
                        .font(AppTypography.streakNumber)
                        .foregroundStyle(AppPalette.sun)
                        .frame(minWidth: 88, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("UV Index")
                            .font(AppTextStyle.captionMedium.font)
                            .foregroundStyle(AppPalette.sun)

                        Text(level.displayName)
                            .font(AppTypography.screenTitle)
                            .foregroundStyle(AppPalette.sun)

                        Text(sourceLabel)
                            .font(AppTextStyle.caption.font)
                            .foregroundStyle(AppPalette.softInk)
                    }
                }

                Text(recommendation)
                    .font(AppTextStyle.body.font)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("UV Index \(index), \(level.displayName). \(sourceLabel). \(recommendation)")
        .accessibilityIdentifier("uvForecast.hero")
    }
}

#Preview {
    SunclubPreviewHost {
        UVForecastDetailView()
    }
}
