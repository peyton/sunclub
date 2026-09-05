import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize: CGFloat = 72

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: appState.referenceDate), by: 60)) { _ in
            let report = appState.last7DaysReport()
            SunLightScreen {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SunLightHeader(title: "Insights", showsBack: true, onBack: { router.goBack() })

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        AppText("Last 7 days", style: .sectionHeader)
                        Text("\(report.appliedCount)")
                            .font(AppFont.heroMetric(size: metricSize))
                            .accessibilityIdentifier("weekly.summaryValue")
                        AppText(report.appliedCount == 1 ? "day logged" : "days logged",
                                style: .body, color: AppColor.Text.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(report.appliedCount) \(report.appliedCount == 1 ? "day" : "days") logged in the last 7 days")

                    weekStrip

                    Divider().accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        AppText("\(report.streak)", style: .title)
                            .accessibilityIdentifier("weekly.currentStreak")
                        AppText("day streak",
                                style: .body, color: AppColor.Text.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(report.streak)-day streak")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
    }

    @ViewBuilder
    private var weekStrip: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.sm) {
                ForEach(days, id: \.self) { day in
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        AppText(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), style: .body)
                        AppText(isLogged(day) ? "Logged" : "Not logged", style: .body,
                                color: AppColor.Text.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        } else {
            HStack(alignment: .top, spacing: AppSpacing.xxs) {
                ForEach(days, id: \.self) { day in
                    VStack(spacing: AppSpacing.sm) {
                        AppText(day.formatted(.dateTime.weekday(.narrow)), style: .caption,
                                color: AppColor.Text.secondary, alignment: .center)
                        AppText(day.formatted(.dateTime.day()), style: .bodyMedium, alignment: .center)
                        if isLogged(day) {
                            SunIcon.check.image
                                .resizable().scaledToFit()
                                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                                .foregroundStyle(AppPalette.ink)
                        } else {
                            Circle()
                                .strokeBorder(AppColor.Text.secondary, lineWidth: 1)
                                .frame(width: AppSpacing.xs, height: AppSpacing.xs)
                                .frame(height: AppSpacing.lg)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day())), \(isLogged(day) ? "logged" : "not logged")")
                }
            }
        }
    }

    private var days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: appState.referenceDate)
        return (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private func isLogged(_ day: Date) -> Bool {
        appState.record(for: day) != nil
    }
}
