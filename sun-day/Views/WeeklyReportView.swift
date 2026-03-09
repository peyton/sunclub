import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @State private var report: WeeklyReport = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)
    @State private var encouragement = ""

    var body: some View {
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroCard
                    metricsRow
                    missedDaysCard
                    encouragementCard

                    Button("Spin a new pep talk") {
                        encouragement = appState.nextWeeklyPhrase()
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            report = appState.last7DaysReport()
            encouragement = appState.nextWeeklyPhrase()
        }
    }

    private var completionRatio: Double {
        guard report.totalDays > 0 else { return 0 }
        return Double(report.appliedCount) / Double(report.totalDays)
    }

    private var periodLabel: String {
        "\(report.startDate.formatted(.dateTime.month(.abbreviated).day())) - \(report.endDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var heroCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: completionRatio)
                    .stroke(
                        AngularGradient(
                            colors: [AppPalette.sun, AppPalette.coral, AppPalette.sea],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(report.appliedCount)/\(report.totalDays)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                    Text("days")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppPalette.softInk)
                }
            }
            .frame(width: 140, height: 140)

            VStack(alignment: .leading, spacing: 10) {
                SunPill(title: "Last 7 days", systemImage: "chart.bar.fill", tint: AppPalette.sun)

                Text("Weekly report")
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(AppPalette.ink)

                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.softInk)

                Text(report.missedDays.isEmpty ? "Clean sheet. Extremely suspicious in a good way." : "A few misses, but the trend is still salvageable.")
                    .font(.callout)
                    .foregroundStyle(AppPalette.softInk)
            }
        }
        .sunCard()
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(report.appliedCount)", title: "applied", tint: AppPalette.success)
            MetricTile(value: "\(report.missedDays.count)", title: "missed", tint: AppPalette.danger)
            MetricTile(value: "\(report.streak)", title: "streak", tint: AppPalette.coral)
        }
    }

    private var missedDaysCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Missed days")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)

            if report.missedDays.isEmpty {
                Text("No misses this week. The bottle would like a modest round of applause.")
                    .font(.callout)
                    .foregroundStyle(AppPalette.success)
            } else {
                FlowLayout(spacing: 10, items: report.missedDays) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppPalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppPalette.danger.opacity(0.12), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(AppPalette.danger.opacity(0.2), lineWidth: 1)
                        }
                }
            }
        }
        .sunCard()
    }

    private var encouragementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week's encouragement")
                .font(.headline)
                .foregroundStyle(AppPalette.ink)

            Text(encouragement.isEmpty ? "No pep talk loaded." : encouragement)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.leading)

            Text("Rotated locally from your weekly phrase bag.")
                .font(.footnote)
                .foregroundStyle(AppPalette.softInk)
        }
        .sunCard()
    }
}

private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let spacing: CGFloat
    let items: Data
    let content: (Data.Element) -> Content

    init(spacing: CGFloat, items: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.spacing = spacing
        self.items = items
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            let rows = Array(items).chunked(into: 3)
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: spacing) {
                    ForEach(rows[rowIndex], id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
