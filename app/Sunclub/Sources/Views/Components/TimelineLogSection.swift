import SwiftUI

struct TimelineLogSection: View {
    @Environment(AppRouter.self) private var router

    let summary: TimelineDayLogSummary
    let uvForecast: SunclubUVForecast?
    let weatherAttribution: SunclubWeatherAttribution?
    let currentStreak: Int
    let longestStreak: Int
    let accessibilityIdentifierSuffix: String?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            forecastBlockGroup

            if let weatherKitAttributionSourceLabel {
                WeatherKitAttributionFooter(
                    attribution: weatherAttribution,
                    sourceLabel: weatherKitAttributionSourceLabel,
                    showAttributionLink: true
                )
                .padding(.horizontal, 2)
            }

            if summary.category == .future, let futurePreview = summary.futurePreview {
                futurePlanCard(futurePreview)
            }

            if summary.category != .future {
                weekHighlight
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text(sectionTitle)
                .font(AppTextStyle.title.font)
                .foregroundStyle(AppPalette.ink)

            Spacer(minLength: 0)

            Button("History") {
                router.open(.history)
            }
            .font(AppTextStyle.bodyMedium.font)
            .foregroundStyle(AppPalette.pool)
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier("timeline.forecast.history"))
            .accessibilityHint("Opens your full calendar history.")
        }
    }

    private var sectionTitle: String {
        summary.category == .future ? "UV Forecast" : "Log"
    }

    private var weatherKitAttributionSourceLabel: String? {
        Self.attributionSourceLabel(forDisplayedSourceLabels: forecastBlocks.map(\.sourceLabel))
    }

    static func attributionSourceLabel(forDisplayedSourceLabels sourceLabels: [String]) -> String? {
        sourceLabels.first(where: UVReadingSource.shouldDisplayAttribution(for:))
    }

    @ViewBuilder
    private var forecastBlockGroup: some View {
        let blocks = forecastBlocks
        if blocks.isEmpty {
            AppCard(padding: AppSpacing.sm, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
                SunInfoRow(
                    title: "UV unavailable",
                    detail: "No fresh Apple Weather forecast is available for this day.",
                    systemImage: "sun.haze.fill",
                    tint: AppPalette.muted
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("UV unavailable. No fresh Apple Weather forecast is available for this day.")
            .accessibilityIdentifier(identifier("timeline.forecast.unavailable"))
        } else {
            VStack(spacing: 0) {
                ForEach(blocks) { block in
                    forecastRow(
                        for: block,
                        status: summary.category == .future ? nil : status(for: block.dayPart)
                    )
                    if block.id != blocks.last?.id {
                        rowDivider
                    }
                }
            }
            .sunGlassCard(
                cornerRadius: AppRadius.button,
                fillOpacity: 0.76,
                legacyShadow: nil
            )
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppPalette.hairlineStroke)
            .frame(height: 1)
            .padding(.leading, 18)
    }

    private var forecastBlocks: [TimelineUVForecastBlock] {
        let hasNightLog = summary.record?.isLogged(in: .night) ?? false
        let dayParts = hasNightLog ? DayPart.standardLogParts + [.night] : DayPart.standardLogParts
        return dayParts.compactMap { forecastBlock(for: $0) }
    }

    private func forecastBlock(for dayPart: DayPart) -> TimelineUVForecastBlock? {
        let hours = forecastHours(for: dayPart)
        guard let peakHour = hours.max(by: { $0.index < $1.index }),
              let generatedAt = uvForecast?.generatedAt else {
            return nil
        }
        return TimelineUVForecastBlock(
            dayPart: dayPart,
            timeRange: timeRange(for: dayPart),
            uvIndex: peakHour.index,
            level: peakHour.level,
            sourceLabel: peakHour.sourceLabel,
            sourceDetail: Self.sourceDetail(
                sourceLabel: peakHour.sourceLabel,
                generatedAt: generatedAt,
                now: now
            )
        )
    }

    static func sourceDetail(sourceLabel: String, generatedAt: Date, now: Date) -> String {
        guard sourceLabel == UVReadingSource.cachedWeatherKit.hourlySourceLabel else {
            return sourceLabel
        }
        let elapsedSeconds = max(0, now.timeIntervalSince(generatedAt))
        guard elapsedSeconds >= 3_600 else {
            return "\(sourceLabel) · less than 1 hour old"
        }
        let elapsedHours = Int(elapsedSeconds / 3_600)
        let unit = elapsedHours == 1 ? "hour" : "hours"
        return "\(sourceLabel) · \(elapsedHours) \(unit) old"
    }

    private func forecastHours(for dayPart: DayPart) -> [SunclubUVHourForecast] {
        Self.verifiedForecastHours(
            in: uvForecast,
            for: summary.day,
            dayPart: dayPart
        )
    }

    static func verifiedForecastHours(
        in forecast: SunclubUVForecast?,
        for day: Date,
        dayPart: DayPart,
        calendar: Calendar = .current
    ) -> [SunclubUVHourForecast] {
        guard let forecast, forecast.isAvailable else {
            return []
        }
        let selectedDay = calendar.startOfDay(for: day)
        return forecast.hours.filter { hour in
            calendar.isDate(hour.date, inSameDayAs: selectedDay)
                && dayPart.forecastHours.contains(calendar.component(.hour, from: hour.date))
        }
    }

    private func timeRange(for dayPart: DayPart) -> String {
        switch dayPart {
        case .morning:
            return "6-11 AM"
        case .afternoon:
            return "12-5 PM"
        case .evening:
            return "6-9 PM"
        case .night:
            return "9 PM-5 AM"
        }
    }

    private func status(for dayPart: DayPart) -> TimelineDayPartStatus? {
        summary.partStatuses.first { $0.dayPart == dayPart }
    }

    private func forecastRow(for block: TimelineUVForecastBlock, status: TimelineDayPartStatus?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) {
                forecastIdentity(for: block, status: status)

                Spacer(minLength: AppSpacing.xs)

                forecastValue(for: block)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                forecastIdentity(for: block, status: status)
                forecastValue(for: block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.dayPart.title) \(summary.category == .future ? "UV forecast" : "log and UV context")")
        .accessibilityValue(
            forecastAccessibilityValue(for: block, status: status)
        )
        .accessibilityIdentifier(identifier("timeline.forecast.part.\(block.dayPart.rawValue)"))
    }

    private func forecastIdentity(
        for block: TimelineUVForecastBlock,
        status: TimelineDayPartStatus?
    ) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: block.level.symbolName)
                .font(AppFont.rounded(size: 16, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .frame(width: 24, height: 24)
                .background(AppPalette.warmGlow.opacity(0.45), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.dayPart.title)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text(block.timeRange)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.softInk)

                if let status {
                    Text(status.statusText)
                        .font(AppTextStyle.captionMedium.font)
                        .foregroundStyle(status.isCompleted ? AppPalette.success : AppPalette.softInk)
                }
            }
        }
    }

    private func forecastValue(for block: TimelineUVForecastBlock) -> some View {
        VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
            Text("UV \(block.uvIndex)")
                .font(AppTextStyle.bodyMedium.font)
                .foregroundStyle(AppPalette.ink)

            Text(block.level.displayName)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)

            Text(block.sourceDetail)
                .font(AppTextStyle.caption.font)
                .foregroundStyle(AppPalette.softInk)
        }
    }

    private func forecastAccessibilityValue(
        for block: TimelineUVForecastBlock,
        status: TimelineDayPartStatus?
    ) -> String {
        var parts = [
            block.timeRange,
            "UV \(block.uvIndex), \(block.level.displayName)",
            block.sourceDetail
        ]
        if let status {
            parts.append(status.statusText)
        }
        return parts.joined(separator: ". ")
    }

    private func futurePlanCard(_ preview: FutureDayPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested routine")
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)

            Text("SPF \(preview.suggestedSPF)+")
                .font(AppTextStyle.title.font)
                .foregroundStyle(AppPalette.ink)

            Text(preview.suggestionText)
                .font(AppTextStyle.body.font)
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sunGlassCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier("timeline.futurePlan"))
    }

    private var weekHighlight: some View {
        let loggedCount = summary.partStatuses.filter(\.isCompleted).count
        let detail = loggedCount == 0
            ? "No sunscreen logged for this day yet."
            : "\(loggedCount) part\(loggedCount == 1 ? "" : "s") logged for this day."

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: loggedCount > 0 ? "checkmark.circle.fill" : "circle")
                .font(AppFont.rounded(size: 16, weight: .semibold))
                .foregroundStyle(loggedCount > 0 ? AppPalette.success : AppPalette.softInk)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily log")
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)
                Text(detail)
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sunGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily log")
        .accessibilityValue(detail)
        .accessibilityIdentifier(identifier("timeline.highlights.dailyLog"))
    }

    private func identifier(_ base: String) -> String {
        guard let accessibilityIdentifierSuffix else {
            return base
        }
        return "\(base).\(accessibilityIdentifierSuffix)"
    }
}

private struct TimelineUVForecastBlock: Identifiable {
    let dayPart: DayPart
    let timeRange: String
    let uvIndex: Int
    let level: UVLevel
    let sourceLabel: String
    let sourceDetail: String

    var id: DayPart { dayPart }
}

private extension DayPart {
    var forecastHours: [Int] {
        switch self {
        case .morning:
            return Array(6...11)
        case .afternoon:
            return Array(12...17)
        case .evening:
            return Array(18...20)
        case .night:
            return [21, 22, 23, 0, 1, 2, 3, 4]
        }
    }
}
