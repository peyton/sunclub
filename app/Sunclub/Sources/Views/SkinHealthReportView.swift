import SwiftUI

struct SkinHealthReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var startDate = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)) ?? Date()
    @State private var endDate = Date()
    @State private var shareSheetItem: ShareSheetItem?

    private var interval: DateInterval {
        DateInterval(start: min(startDate, endDate), end: max(startDate, endDate))
    }

    private var summary: SunclubSkinHealthReportSummary {
        appState.skinHealthReportSummary(for: interval)
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Skin Health Report", showsBack: true, onBack: {
                    router.goBack()
                })

                introCard
                dateRangeCard
                metricsCard
                monthlyConsistencyCard
                spfDistributionCard

                Spacer(minLength: 0)
            }
        } footer: {
            VStack(spacing: 12) {
                Button("Export PDF Report") {
                    exportPDFReport()
                }
                .buttonStyle(SunPrimaryButtonStyle())

                Button("Share Streak Card") {
                    shareStreakCard()
                }
                .buttonStyle(SunSecondaryButtonStyle())
            }
        }
        .sheet(item: $shareSheetItem) { item in
            ActivityShareSheet(items: item.items)
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your year in sun protection")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text("Generate a dermatologist-friendly PDF from any date range. The report stays on-device and summarizes streaks, coverage, SPF mix, and how often you were protected on higher-UV days.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Start", selection: $startDate, displayedComponents: .date)
            DatePicker("End", selection: $endDate, displayedComponents: .date)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            reportMetricRow(label: "Protected days", value: "\(summary.totalProtectedDays)")
            reportMetricRow(label: "Longest streak", value: "\(summary.longestStreak)")
            reportMetricRow(label: "Average streak", value: String(format: "%.1f", summary.averageStreakLength))
            reportMetricRow(label: "High-UV protected days", value: "\(summary.highUVProtectedDays)")
        }
        .padding(18)
        .background(cardBackground)
    }

    private var monthlyConsistencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly consistency")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(summary.monthlyConsistency) { month in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(month.monthLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)

                        Text("\(month.protectedDays)/\(month.totalDays)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)

                        ProgressView(value: month.ratio)
                            .tint(AppPalette.sun)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.9))
                    )
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var spfDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPF mix")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            if summary.spfDistribution.isEmpty {
                Text("Add SPF details to your logs to build this section.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            } else {
                ForEach(summary.spfDistribution) { entry in
                    reportMetricRow(label: "SPF \(entry.spf)", value: "\(entry.count)")
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private func reportMetricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
        }
    }

    private func exportPDFReport() {
        guard let artifact = try? appState.skinHealthReportArtifact(for: interval) else {
            return
        }
        appState.recordShareActionStarted()
        shareSheetItem = ShareSheetItem(items: [artifact.fileURL])
    }

    private func shareStreakCard() {
        guard let artifact = try? appState.streakCardArtifact() else {
            return
        }
        appState.recordShareActionStarted()
        shareSheetItem = ShareSheetItem(items: [artifact.fileURL])
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.72))
    }
}

#Preview {
    SunclubPreviewHost {
        SkinHealthReportView()
    }
}
