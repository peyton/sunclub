import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @State private var report: WeeklyReport = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)
    @State private var encouragement = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Weekly Report")
                .font(.largeTitle)
                .bold()

            let period = "\(report.startDate.formatted(.dateTime.month(.abbreviated).day())) - \(report.endDate.formatted(.dateTime.month(.abbreviated).day()))"
            Text("Last 7 days: \(period)")
                .foregroundStyle(.secondary)

            Text("Applied: \(report.appliedCount)/\(report.totalDays)")
            Text("Missed: \(report.missedCount)")
            Text("Current streak: \(report.streak)")

            if !report.missedDays.isEmpty {
                VStack(alignment: .leading) {
                    Text("Missed days:")
                        .font(.headline)
                    ForEach(report.missedDays, id: \.self) { day in
                        Text("• \(day)")
                            .font(.caption)
                    }
                }
            } else {
                Text("No misses this week!")
                    .foregroundStyle(.green)
            }

            if !encouragement.isEmpty {
                Text(encouragement)
                    .padding()
                    .multilineTextAlignment(.center)
                    .background(.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Regenerate encouragement") {
                encouragement = appState.nextWeeklyPhrase()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .onAppear {
            report = appState.last7DaysReport()
            encouragement = appState.nextWeeklyPhrase()
        }
    }
}
