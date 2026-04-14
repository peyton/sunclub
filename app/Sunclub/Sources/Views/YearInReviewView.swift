import SwiftUI

struct YearInReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "Year in Review", showsBack: true, onBack: {
                    router.goBack()
                })

                if let summary = appState.yearInReviewSummary {
                    heroMetrics(summary)
                    mostUsedSPFCard(summary)
                    monthlyConsistencyChart(summary)
                } else {
                    emptyState
                }

                Spacer(minLength: 0)
            }
        } footer: {
            EmptyView()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private func heroMetrics(_ summary: SunclubSkinHealthReportSummary) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, spacing: 12) {
            bigNumberCard(
                value: "\(summary.totalProtectedDays)",
                label: "Protected Days",
                symbol: "shield.checkered"
            )

            bigNumberCard(
                value: "\(summary.longestStreak)",
                label: "Longest Streak",
                symbol: "flame.fill"
            )
        }
    }

    private func bigNumberCard(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .accessibilityHidden(true)

            Text(value)
                .font(.system(size: 42, weight: .heavy))
                .foregroundStyle(AppPalette.ink)

            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .sunGlassCard(cornerRadius: AppRadius.card)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func mostUsedSPFCard(_ summary: SunclubSkinHealthReportSummary) -> some View {
        if let spf = summary.mostUsedSPF {
            VStack(alignment: .leading, spacing: 6) {
                Text("Most Used SPF")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                Text(spf.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Text(spf.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppPalette.softInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .sunGlassCard(cornerRadius: AppRadius.card)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("yearInReview.mostUsedSPF")
        }
    }

    @ViewBuilder
    private func monthlyConsistencyChart(_ summary: SunclubSkinHealthReportSummary) -> some View {
        let entries = summary.monthlyConsistency
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Monthly Consistency")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(entries) { entry in
                        VStack(spacing: 4) {
                            barView(ratio: entry.ratio)
                                .accessibilityHidden(true)

                            Text(entry.monthLabel.prefix(1))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppPalette.softInk)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(entry.monthLabel): \(entry.protectedDays) of \(entry.totalDays) days")
                    }
                }
                .frame(height: 120)
            }
            .padding(22)
            .sunGlassCard(cornerRadius: AppRadius.card)
            .accessibilityIdentifier("yearInReview.monthlyChart")
        }
    }

    private func barView(ratio: Double) -> some View {
        GeometryReader { geo in
            let barHeight = max(geo.size.height * ratio, 4)
            VStack {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(AppPalette.sun)
                    .frame(height: barHeight)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityHidden(true)

            Text("Not enough data yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text("Log at least 30 days to unlock your Year in Review.")
                .font(AppTypography.body)
                .foregroundStyle(AppPalette.softInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}
