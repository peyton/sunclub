import SwiftUI

struct TimelineLogSection: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    let summary: TimelineDayLogSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            forecastBlockGroup
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("UV Forecast")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Spacer(minLength: 0)

            Button("Options") {
                router.open(.history)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.pool)
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.historyCard")
            .accessibilityHint("Opens history and calendar options.")
        }
    }

    private var forecastBlockGroup: some View {
        let blocks = forecastBlocks
        return VStack(spacing: 0) {
            ForEach(blocks) { block in
                forecastRow(for: block)
                if block.dayPart != DayPart.allCases.last {
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
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.76))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
    }

    private var forecastBlocks: [TimelineUVForecastBlock] {
        DayPart.allCases.map { forecastBlock(for: $0) }
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
        let liveOrCachedHours = appState.uvForecast?.hours.filter { hour in
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
        case .evening:
            return "12-5 PM"
        case .night:
            return "6-9 PM"
        }
    }

    private func forecastRow(for block: TimelineUVForecastBlock) -> some View {
        HStack(spacing: 12) {
            Image(systemName: block.level.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .frame(width: 24, height: 24)
                .background(AppPalette.warmGlow.opacity(0.45), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(block.dayPart.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(block.timeRange)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("UV \(block.uvIndex)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Text(block.level.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.dayPart.title) UV forecast")
        .accessibilityValue(
            "\(block.timeRange). UV \(block.uvIndex), \(block.level.displayName). \(block.sourceLabel)."
        )
        .accessibilityIdentifier("timeline.forecast.part.\(block.dayPart.rawValue)")
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
        case .evening:
            return Array(12...17)
        case .night:
            return Array(18...21)
        }
    }
}
