import SwiftUI

struct TimelineHighlightsSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let summary: TimelineDayLogSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            VStack(spacing: 12) {
                switch summary.category {
                case .today:
                    todayHighlights
                case .future:
                    futureHighlights
                case .past:
                    pastHighlights
                }

                streakHighlight
            }
        }
    }

    private var sectionHeader: some View {
        Text("Highlights")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(AppPalette.ink)
    }

    @ViewBuilder
    private var todayHighlights: some View {
        if let forecast = appState.uvForecast {
            uvForecastCard(forecast: forecast)
        }

        reapplyCard
    }

    @ViewBuilder
    private var futureHighlights: some View {
        if let preview = summary.futurePreview {
            highlightCard(
                symbol: "sun.max.fill",
                title: "Plan Ahead",
                detail: preview.suggestionText,
                tint: AppPalette.sun,
                identifier: "timeline.highlights.futurePlan"
            )
        }

        if let forecast = appState.uvForecast,
           isForecastRelevantForDay(summary.day, forecast: forecast) {
            uvForecastCard(forecast: forecast)
        }
    }

    @ViewBuilder
    private var pastHighlights: some View {
        if let record = summary.record {
            let verifiedText = "Logged at \(record.verifiedAt.formatted(date: .omitted, time: .shortened))"
            highlightCard(
                symbol: "checkmark.seal.fill",
                title: "Logged",
                detail: verifiedText,
                tint: AppPalette.success,
                identifier: "timeline.highlights.pastLog"
            )

            if record.reapplyCount > 0 {
                let detail = record.reapplyCount == 1
                    ? "1 reapply check-in saved."
                    : "\(record.reapplyCount) reapply check-ins saved."
                highlightCard(
                    symbol: "timer",
                    title: "Reapplications",
                    detail: detail,
                    tint: AppPalette.pool,
                    identifier: "timeline.highlights.pastReapply"
                )
            }
        } else {
            highlightCard(
                symbol: "calendar.badge.exclamationmark",
                title: "Missed Day",
                detail: "Tap the Sunscreen row above to backfill this day.",
                tint: AppPalette.coral,
                identifier: "timeline.highlights.pastMissed"
            )
        }
    }

    @ViewBuilder
    private var reapplyCard: some View {
        let plan = ReapplyReminderPlan(
            baseIntervalMinutes: appState.settings.reapplyIntervalMinutes,
            uvReading: appState.uvReading,
            now: appState.referenceDate
        )

        if plan.shouldScheduleNotification {
            highlightCard(
                symbol: plan.confirmationSymbolName,
                title: "Reapply Plan",
                detail: plan.confirmationText,
                tint: AppPalette.sun,
                identifier: "timeline.highlights.reapply"
            )
        }
    }

    private var streakHighlight: some View {
        let streak = appState.currentStreak
        let best = appState.longestStreak
        let milestone = nextMilestone(for: streak)
        let detail: String
        if streak == 0 {
            detail = "Log today to start a streak."
        } else if let milestone {
            let remaining = milestone - streak
            let unit = remaining == 1 ? "day" : "days"
            detail = "\(streak)-day streak — \(remaining) \(unit) to \(milestone)."
        } else {
            detail = "\(streak)-day streak. Personal best: \(best)."
        }

        return highlightCard(
            symbol: streak > 0 ? "flame.fill" : "flame",
            title: "Streak",
            detail: detail,
            tint: AppPalette.streakAccent,
            identifier: "timeline.highlights.streak"
        )
    }

    private func nextMilestone(for streak: Int) -> Int? {
        let milestones = [7, 30, 100, 365]
        return milestones.first { $0 > streak }
    }

    private func isForecastRelevantForDay(_ day: Date, forecast: SunclubUVForecast) -> Bool {
        let calendar = Calendar.current
        guard let first = forecast.hours.first else {
            return false
        }
        return calendar.isDate(first.date, inSameDayAs: day)
    }

    private func uvForecastCard(forecast: SunclubUVForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("UV Forecast", systemImage: "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
                    .labelStyle(.titleAndIcon)

                Spacer(minLength: 0)

                if let peakHour = forecast.peakHour {
                    Text("Peak UV \(peakHour.index)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.sun)
                }
            }

            Text(forecast.headline)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            if !forecast.hours.isEmpty {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(forecast.hours.prefix(8))) { hour in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(barColor(for: hour.level))
                                .frame(width: 14, height: max(CGFloat(hour.index) * 7, 8))

                            Text("\(hour.index)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppPalette.ink)

                            Text(hour.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppPalette.softInk)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            }

            Text(forecast.recommendation)
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.softInk)

            WeatherKitAttributionFooter(
                attribution: appState.weatherAttribution,
                sourceLabel: forecast.sourceLabel
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .sunGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("timeline.highlights.uvForecast")
    }

    private func highlightCard(
        symbol: String,
        title: String,
        detail: String,
        tint: Color,
        identifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppPalette.onAccent)
                .frame(width: 32, height: 32)
                .background(tint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sunGlassCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityIdentifier(identifier)
    }

    private func barColor(for level: UVLevel) -> Color {
        switch level {
        case .low: return AppPalette.aloe
        case .moderate: return AppPalette.sun
        case .high: return AppPalette.coral
        case .veryHigh: return Color.red.opacity(0.78)
        case .extreme: return AppPalette.uvExtreme
        case .unknown: return AppPalette.muted
        }
    }
}
