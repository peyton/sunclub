import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var report = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)
    @State private var insights = SunscreenUsageInsights.empty

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 28) {
                SunLightHeader(title: "Weekly Summary", showsBack: true, onBack: {
                    dismiss()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text(report.appliedSummaryText)
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(Color(red: 0.870, green: 0.482, blue: 0.000))
                        .accessibilityIdentifier("weekly.summaryValue")

                    Text("Days Applied This Week")
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.ink)

                    if appState.longestStreak > 0 {
                        Text("Longest streak: \(appState.longestStreak) days")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)
                            .accessibilityIdentifier("weekly.longestStreak")
                    }
                }

                weeklyChart
                    .frame(maxWidth: .infinity, alignment: .center)

                usageInsightsSection

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            refreshReport()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var weeklyChart: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(AppPalette.muted)
                .frame(width: 100, height: 100)
                .overlay {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 6), count: 3), spacing: 6) {
                        ForEach(Array(weekProgress.enumerated()), id: \.offset) { _, applied in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(applied ? AppPalette.sun : Color.white.opacity(0.9))
                                .frame(width: 18, height: 18)
                        }
                    }
                }

            Text(report.missedDays.isEmpty ? "Perfect week" : "Missed: \(report.missedDays.joined(separator: ", "))")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
                .multilineTextAlignment(.center)
        }
    }

    private var weekProgress: [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: report.endDate)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let records = Set(appState.recordStartsForTesting())

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            return records.contains(calendar.startOfDay(for: day))
        }
    }

    private var usageInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("From Your Logs")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            if let mostUsedSPF = insights.mostUsedSPF {
                WeeklyInsightCard(
                    eyebrow: "Most Used SPF",
                    value: mostUsedSPF.title,
                    detail: mostUsedSPF.detail,
                    valueAccessibilityIdentifier: "weekly.mostUsedSPFValue"
                )
            }

            if !insights.recentNotes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Notes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    VStack(spacing: 10) {
                        ForEach(Array(insights.recentNotes.enumerated()), id: \.offset) { index, note in
                            WeeklyRecentNoteRow(
                                note: note,
                                index: index
                            )
                        }
                    }
                }
                .accessibilityIdentifier("weekly.recentNotes")
            }

            if !insights.hasContent {
                Text("Add SPF or a note while logging to see what you use most often.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("weekly.usageInsightsPlaceholder")
            }
        }
        .accessibilityIdentifier("weekly.usageInsights")
    }

    private func refreshReport() {
        report = appState.last7DaysReport()
        insights = appState.sunscreenUsageInsights()
    }
}

private struct WeeklyInsightCard: View {
    let eyebrow: String
    let value: String
    let detail: String
    let valueAccessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier(valueAccessibilityIdentifier)

            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .accessibilityIdentifier("weekly.mostUsedSPFCard")
    }
}

private struct WeeklyRecentNoteRow: View {
    let note: RecentUsageNote
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.sun)

            Text(note.text)
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("weekly.recentNoteText.\(index)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

#Preview {
    SunclubPreviewHost {
        WeeklyReportView()
    }
}
