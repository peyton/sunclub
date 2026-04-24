import SwiftUI

struct SkinHealthReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var startDate = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)) ?? Date()
    @State private var endDate = Date()
    @State private var shareSheetItem: ShareSheetItem?

    private var interval: DateInterval {
        DateInterval(start: min(startDate, endDate), end: max(startDate, endDate))
    }

    var body: some View {
        let reportInterval = interval
        let summary = appState.skinHealthReportSummary(for: reportInterval)

        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Skin Health Report", showsBack: true, onBack: {
                    router.goBack()
                })

                introCard
                dateRangeCard
                metricsCard(summary: summary)
                monthlyConsistencyCard(summary: summary)
                spfDistributionCard(summary: summary)

                SunAssetHero(
                    asset: .illustrationSkinReport,
                    height: 104,
                    glowColor: AppPalette.aloe
                )

                Spacer(minLength: 0)
            }
        } footer: {
            footerActions
        }
        .sheet(item: $shareSheetItem) { item in
            ActivityShareSheet(items: item.items)
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Skin Health Report")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text("Choose a date range, review your key metrics, then export or share the summary.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date range")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            DatePicker("Start", selection: $startDate, displayedComponents: .date)
            DatePicker("End", selection: $endDate, displayedComponents: .date)
        }
        .padding(18)
        .background(cardBackground)
    }

    private func metricsCard(summary: SunclubSkinHealthReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            reportMetricRow(label: "Protected days in range", value: "\(summary.totalProtectedDays)")
            reportMetricRow(label: "Longest streak", value: "\(summary.longestStreak)")
            reportMetricRow(label: "Average streak length", value: String(format: "%.1f", summary.averageStreakLength))
            reportMetricRow(label: "High-UV protected days", value: "\(summary.highUVProtectedDays)")
        }
        .padding(18)
        .background(cardBackground)
    }

    private func monthlyConsistencyCard(summary: SunclubSkinHealthReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly consistency")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            LazyVGrid(columns: monthlyConsistencyColumns, spacing: 10) {
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
                            .accessibilityHidden(true)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppPalette.cardFill.opacity(0.9))
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(month.monthLabel)
                    .accessibilityValue("\(month.protectedDays) of \(month.totalDays) protected days")
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private func spfDistributionCard(summary: SunclubSkinHealthReportSummary) -> some View {
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
        .accessibilityElement(children: .combine)
    }

    private var monthlyConsistencyColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 10)]
        }

        return Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    }

    @ViewBuilder
    private var footerActions: some View {
        if appState.records.isEmpty {
            Text("Log at least one day before exporting or sharing a report.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 12) {
                Button("Export report") {
                    exportPDFReport()
                }
                .buttonStyle(SunPrimaryButtonStyle())

                Button("Share summary") {
                    shareStreakCard()
                }
                .buttonStyle(SunSecondaryButtonStyle())
            }
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
            .fill(AppPalette.cardFill.opacity(0.72))
            .shadow(color: AppPalette.ink.opacity(0.055), radius: 18, x: 0, y: 10)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
    }
}

#Preview {
    SunclubPreviewHost {
        SkinHealthReportView()
    }
}
