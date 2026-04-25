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

            streakHighlight
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

    private var streakHighlight: some View {
        let streak = appState.currentStreak
        let best = appState.longestStreak
        let detail: String
        if streak == 0 {
            detail = "Log once today to start a streak."
        } else {
            detail = "\(streak)-day streak. Personal best: \(best)."
        }

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
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
                showAttributionLink: forecast.sourceLabel == UVReadingSource.weatherKit.forecastLabel
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sunGlassCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timeline.highlights.uvForecast")
    }
}
