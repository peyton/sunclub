import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @State private var report: WeeklyReport = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)
    @State private var encouragement = ""

    var body: some View {
        SunScreen {
            heroCard
            metricsGrid
            missesCard
            encouragementCard

            Button("Generate another pep talk") {
                encouragement = appState.nextWeeklyPhrase()
            }
            .buttonStyle(SunSecondaryButtonStyle())
        }
        .navigationTitle("Weekly Report")
        .navigationBarTitleDisplayMode(.inline)
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
        ViewThatFits {
            HStack(spacing: 18) {
                progressRing
                reportCopy
            }

            VStack(alignment: .leading, spacing: 18) {
                progressRing
                reportCopy
            }
        }
        .sunCard()
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(value: "\(report.appliedCount)", title: "applied", tint: AppPalette.success)
            MetricTile(value: "\(report.missedDays.count)", title: "missed", tint: AppPalette.danger)
            MetricTile(value: "\(report.streak)", title: "streak", tint: AppPalette.coral)
        }
    }

    private var missesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SunSectionHeader(
                eyebrow: "Missed days",
                title: report.missedDays.isEmpty ? "Clean sheet" : "Spots to recover",
                detail: report.missedDays.isEmpty ? "This week stayed free of misses." : "These are the weekdays that fell through without a successful verification."
            )

            if report.missedDays.isEmpty {
                SunStatusCard(
                    title: "No misses this week",
                    detail: "A suspiciously competent performance, in the best way.",
                    tint: AppPalette.success,
                    symbol: "checkmark.circle.fill"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                    ForEach(report.missedDays, id: \.self) { day in
                        Text(day)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(AppPalette.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppPalette.danger.opacity(0.18), lineWidth: 1)
                            }
                    }
                }
            }
        }
        .sunCard()
    }

    private var encouragementCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SunSectionHeader(
                eyebrow: "Encouragement",
                title: "This week's local pep talk",
                detail: "Rotated from your weekly phrase bag so the app doesn't sound like a malfunctioning sticker."
            )

            Text(encouragement)
                .font(.title3.weight(.medium))
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.leading)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [AppPalette.sun.opacity(0.16), AppPalette.coral.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
        }
        .sunCard()
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.52), lineWidth: 16)

            Circle()
                .trim(from: 0, to: completionRatio)
                .stroke(
                    AngularGradient(
                        colors: [AppPalette.sun, AppPalette.coral, AppPalette.sea],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
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
        .frame(width: 138, height: 138)
    }

    private var reportCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            SunPill(title: "Last 7 days", systemImage: "chart.bar.fill", tint: AppPalette.sun)

            Text("Weekly report")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(AppPalette.ink)

            Text(periodLabel)
                .font(.subheadline)
                .foregroundStyle(AppPalette.softInk)

            Text(report.missedDays.isEmpty ? "No misses. The bottle would like a tiny ovation." : "You missed a few, but the trend line is still redeemable.")
                .font(.callout)
                .foregroundStyle(AppPalette.softInk)
        }
    }
}
