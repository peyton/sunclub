import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var report = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)

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

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            report = appState.last7DaysReport()
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
}

#Preview {
    SunclubPreviewHost {
        WeeklyReportView()
    }
}
