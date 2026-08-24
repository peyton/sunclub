import SwiftUI

struct TimelineHighlightsSection: View {
    @Environment(AppState.self) private var appState

    let summary: TimelineDayLogSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Highlights")
                .font(AppFont.rounded(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            ForEach(summary.partStatuses) { status in
                partHighlight(status)
            }

            if summary.category != .past, let forecast = appState.uvForecast {
                uvForecastCard(forecast: forecast)
            }

            weekHighlight
        }
    }

    private func partHighlight(_ status: TimelineDayPartStatus) -> some View {
        let badgeTitle = status.isCompleted ? "Complete" : (summary.canLog ? "Open" : "Future")
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(status.dayPart.title)
                    .font(AppFont.rounded(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(status.statusText)
                    .font(AppFont.rounded(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer(minLength: 0)

            Text(badgeTitle)
                .font(AppFont.rounded(size: 12, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(status.isCompleted ? AppPalette.success.opacity(0.25) : AppPalette.warmGlow.opacity(0.6))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .sunGlassCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.dayPart.title). \(status.statusText).")
        .accessibilityValue(badgeTitle)
        .accessibilityIdentifier("timeline.highlights.part.\(status.dayPart.rawValue)")
    }

    private var weekHighlight: some View {
        let loggedParts = summary.partStatuses.filter(\.isCompleted).count
        let detail = loggedParts == 0
            ? "No sunscreen logged for this day yet."
            : "\(loggedParts) part\(loggedParts == 1 ? "" : "s") logged for this day."

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: loggedParts > 0 ? "checkmark.circle.fill" : "circle")
                .font(AppFont.rounded(size: 16, weight: .semibold))
                .foregroundStyle(loggedParts > 0 ? AppPalette.success : AppPalette.softInk)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Daily log")
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
        .accessibilityLabel("Daily log")
        .accessibilityValue(detail)
        .accessibilityIdentifier("timeline.highlights.dailyLog")
    }

    private func uvForecastCard(forecast: SunclubUVForecast) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UV Forecast")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
            Text(forecast.headline)
                .font(AppFont.rounded(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)
            Text(forecast.recommendation)
                .font(AppFont.rounded(size: 14))
                .foregroundStyle(AppPalette.softInk)
            WeatherKitAttributionFooter(
                attribution: appState.weatherAttribution,
                sourceLabel: forecast.sourceLabel,
                showAttributionLink: UVReadingSource.shouldDisplayAttribution(for: forecast.sourceLabel)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sunGlassCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timeline.highlights.uvForecast")
    }
}
