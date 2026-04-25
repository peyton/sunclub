import SwiftUI

struct TimelineLogSection: View {
    @Environment(AppRouter.self) private var router

    let summary: TimelineDayLogSummary
    let uvForecast: SunclubUVForecast?
    let weatherAttribution: SunclubWeatherAttribution?
    let currentStreak: Int
    let longestStreak: Int

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
                streakHighlight
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text(sectionTitle)
                .font(AppFont.rounded(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Spacer(minLength: 0)

            Button("History") {
                router.open(.history)
            }
            .font(AppFont.rounded(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.pool)
            .buttonStyle(.plain)
            .accessibilityIdentifier("timeline.forecast.history")
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
        sourceLabels.first { $0 == UVReadingSource.weatherKit.forecastLabel }
    }

    private var forecastBlockGroup: some View {
        let blocks = forecastBlocks
        return VStack(spacing: 0) {
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
        .background(rowGroupBackground)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AppPalette.hairlineStroke)
            .frame(height: 1)
            .padding(.leading, 18)
    }

    private var rowGroupBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.76))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
    }

    private var forecastBlocks: [TimelineUVForecastBlock] {
        let hasNightLog = summary.record?.isLogged(in: .night) ?? false
        let dayParts = hasNightLog ? DayPart.standardLogParts + [.night] : DayPart.standardLogParts
        return dayParts.map { forecastBlock(for: $0) }
    }

    private func forecastBlock(for dayPart: DayPart) -> TimelineUVForecastBlock {
        let hours = forecastHours(for: dayPart)
        let peakHour = hours.max(by: { $0.index < $1.index }) ?? fallbackForecastHour(for: dayPart)
        return TimelineUVForecastBlock(
            dayPart: dayPart,
            timeRange: timeRange(for: dayPart),
            uvIndex: peakHour.index,
            level: peakHour.level,
            sourceLabel: peakHour.sourceLabel
        )
    }

    private func forecastHours(for dayPart: DayPart) -> [SunclubUVHourForecast] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: summary.day)
        let liveOrCachedHours = uvForecast?.hours.filter { hour in
            calendar.isDate(hour.date, inSameDayAs: selectedDay)
                && dayPart.forecastHours.contains(calendar.component(.hour, from: hour.date))
        } ?? []

        if !liveOrCachedHours.isEmpty {
            return liveOrCachedHours
        }

        return dayPart.forecastHours.compactMap { hour in
            estimatedForecastHour(on: selectedDay, hour: hour)
        }
    }

    private func fallbackForecastHour(for dayPart: DayPart) -> SunclubUVHourForecast {
        estimatedForecastHour(
            on: Calendar.current.startOfDay(for: summary.day),
            hour: dayPart.defaultHour
        ) ?? SunclubUVHourForecast(
            date: summary.day,
            index: 0,
            sourceLabel: UVReadingSource.heuristic.hourlySourceLabel
        )
    }

    private func estimatedForecastHour(on day: Date, hour: Int) -> SunclubUVHourForecast? {
        let calendar = Calendar.current
        guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else {
            return nil
        }
        return SunclubUVHourForecast(
            date: date,
            index: UVIndexService.estimatedUVIndex(at: date, calendar: calendar),
            sourceLabel: UVReadingSource.heuristic.hourlySourceLabel
        )
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
        HStack(spacing: 12) {
            Image(systemName: block.level.symbolName)
                .font(AppFont.rounded(size: 16, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .frame(width: 24, height: 24)
                .background(AppPalette.warmGlow.opacity(0.45), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.dayPart.title)
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(block.timeRange)
                    .font(AppFont.rounded(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)

                if let status {
                    Text(status.statusText)
                        .font(AppFont.rounded(size: 13, weight: .semibold))
                        .foregroundStyle(status.isCompleted ? AppPalette.success : AppPalette.softInk)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("UV \(block.uvIndex)")
                    .font(AppFont.rounded(size: 16, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Text(block.level.displayName)
                    .font(AppFont.rounded(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.dayPart.title) \(summary.category == .future ? "UV forecast" : "log and UV context")")
        .accessibilityValue(
            forecastAccessibilityValue(for: block, status: status)
        )
        .accessibilityIdentifier("timeline.forecast.part.\(block.dayPart.rawValue)")
    }

    private func forecastAccessibilityValue(
        for block: TimelineUVForecastBlock,
        status: TimelineDayPartStatus?
    ) -> String {
        var parts = [
            block.timeRange,
            "UV \(block.uvIndex), \(block.level.displayName)",
            block.sourceLabel
        ]
        if let status {
            parts.append(status.statusText)
        }
        return parts.joined(separator: ". ")
    }

    private func futurePlanCard(_ preview: FutureDayPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested routine")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text("SPF \(preview.suggestedSPF)+")
                .font(AppFont.rounded(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text(preview.suggestionText)
                .font(AppFont.rounded(size: 14))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sunGlassCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timeline.futurePlan")
    }

    private var streakHighlight: some View {
        let detail: String
        if currentStreak == 0 {
            detail = "Log once today to start a streak."
        } else {
            detail = "\(currentStreak)-day streak. Personal best: \(longestStreak)."
        }

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: currentStreak > 0 ? "flame.fill" : "flame")
                .font(AppFont.rounded(size: 16, weight: .semibold))
                .foregroundStyle(AppPalette.streakAccent)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Streak")
                    .font(AppFont.rounded(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(detail)
                    .font(AppFont.rounded(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sunGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak")
        .accessibilityValue(detail)
        .accessibilityIdentifier("timeline.highlights.streak")
    }
}

private struct TimelineUVForecastBlock: Identifiable {
    let dayPart: DayPart
    let timeRange: String
    let uvIndex: Int
    let level: UVLevel
    let sourceLabel: String

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
