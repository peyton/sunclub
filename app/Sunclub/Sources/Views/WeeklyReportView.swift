import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var report = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)
    @State private var editorPresentation: WeeklyEditorPresentation?

    let showsBackButton: Bool

    init(showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
    }

    var body: some View {
        SunLightScreen(showsFooter: showsBackButton) {
            VStack(alignment: .leading, spacing: 28) {
                SunLightHeader(title: "Insights", showsBack: showsBackButton, onBack: {
                    router.goBack()
                })

                weeklyPostcard

                weeklyChart
                    .frame(maxWidth: .infinity, alignment: .center)

                weeklySummaryRow

                if !showsBackButton {
                    viewFullHistoryButton
                }

                usageInsightsSection

                Spacer(minLength: 0)
            }
        } footer: {
            viewFullHistoryButton
        }
        .sheet(item: $editorPresentation, onDismiss: refreshReport) { presentation in
            HistoryRecordEditorView(
                day: presentation.day,
                existingRecord: appState.record(for: presentation.day)
            )
        }
        .onAppear {
            refreshReport()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var viewFullHistoryButton: some View {
        SecondaryPillButton("View Full History", systemImage: "calendar", identifier: "weekly.viewFullHistory") {
            router.open(.history)
        }
        .accessibilityHint("Opens your full calendar history.")
    }

    private var weeklySummaryRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                weeklyMetricPills
            }

            VStack(spacing: 10) {
                weeklyMetricPills
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current run \(report.streak) days. Typical first log \(progressInsights.typicalApplicationTimeText() ?? "not available")"
        )
    }

    @ViewBuilder
    private var weeklyMetricPills: some View {
        WeeklyMetricPill(
            value: "\(report.streak)",
            label: report.streak == 1 ? "day current run" : "days current run",
            accessibilityIdentifier: "weekly.currentStreak"
        )

        WeeklyMetricPill(
            value: progressInsights.typicalApplicationTimeText() ?? "—",
            label: "typical first log",
            accessibilityIdentifier: "weekly.typicalTime"
        )
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This week")
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)

            LazyVGrid(columns: weekEntryColumns, spacing: 10) {
                ForEach(weekEntries) { entry in
                    Button {
                        handleWeekEntryTap(entry)
                    } label: {
                        VStack(spacing: 8) {
                            Text(entry.date.formatted(.dateTime.weekday(.narrow)))
                                .font(AppTextStyle.captionMedium.font)
                                .foregroundStyle(AppPalette.softInk)

                            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                .fill(weekEntryFill(entry))
                                .overlay {
                                    if entry.applied {
                                        Image(systemName: "checkmark")
                                            .font(AppTextStyle.captionMedium.font)
                                            .foregroundStyle(AppPalette.onAccent)
                                    } else if !entry.isEligible {
                                        Image(systemName: "ellipsis")
                                            .font(AppTextStyle.captionMedium.font)
                                            .foregroundStyle(AppPalette.muted)
                                    }
                                }
                                .overlay {
                                    if isToday(entry.date) {
                                        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                            .stroke(AppPalette.ink.opacity(0.18), lineWidth: 1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)

                            Text(entry.date.formatted(.dateTime.day()))
                                .font(AppTextStyle.captionMedium.font)
                                .foregroundStyle(AppPalette.softInk)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.isFuture)
                    .accessibilityLabel(weekEntryAccessibilityLabel(entry))
                    .accessibilityHint(weekEntryAccessibilityHint(entry))
                    .accessibilityIdentifier("weekly.day.\(Self.dayIdentifierFormatter.string(from: entry.date))")
                }
            }

            Text(weeklyChartHint)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(report.missedDays.isEmpty ? AppPalette.softInk : AppPalette.ink)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.86))
                .appShadow(AppShadow.soft)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppPalette.cardStroke, lineWidth: 1)
        }
    }

    private var weeklyPostcard: some View {
        ZStack(alignment: .bottomTrailing) {
            SunclubVisualAsset.motifSunRing.image
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 190)
                .opacity(0.24)
                .offset(x: 40, y: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("\(progressInsights.consistencyPercent)%")
                    .font(AppTextStyle.largeTitle.font)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppPalette.streakAccent, AppPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityIdentifier("weekly.summaryValue")

                Text("30-day consistency")
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text(progressInsights.consistencyDetail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: weeklyPostcardBackgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    SunclubVisualAsset.shareCardBackdropWarm.image
                        .resizable()
                        .scaledToFill()
                        .opacity(colorScheme == .dark ? 0.16 : 0.24)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                }
        }
        .sunGlassCard(cornerRadius: 24, fillOpacity: 0.52)
    }

    private var weeklyPostcardBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                AppPalette.elevatedCardFill,
                AppPalette.nightAmber.opacity(0.62),
                AppPalette.darkSurface
            ]
        }

        return [
            AppPalette.cardFill,
            AppPalette.warmGlow.opacity(0.40),
            AppPalette.cardFill
        ]
    }

    private var weekEntries: [WeeklyEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: report.endDate)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let records = Set(appState.recordedDays)

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            return WeeklyEntry(
                date: day,
                applied: records.contains(calendar.startOfDay(for: day)),
                isEligible: calendar.startOfDay(for: day) >= eligibilityStart,
                isFuture: calendar.startOfDay(for: day) > today
            )
        }
    }

    private var usageInsightsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("From your routine")
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
                .accessibilityIdentifier("weekly.usageInsights")

            if let highUVRateText = progressInsights.highUVRateText,
               let highUVDetail = progressInsights.highUVDetail {
                WeeklyInsightCard(
                    eyebrow: "UV 3+ days",
                    value: highUVRateText,
                    detail: highUVDetail,
                    accessibilityIdentifier: "weekly.highUVRate"
                )
            }

            WeeklyInsightCard(
                eyebrow: "Next step",
                value: "Keep it simple",
                detail: progressInsights.nextStep,
                accessibilityIdentifier: "weekly.nextStep"
            )
        }
    }

    private var eligibilityStart: Date {
        CalendarAnalytics.eligibilityStart(
            records: appState.recordedDays,
            now: appState.referenceDate
        )
    }

    private var progressInsights: RoutineProgressInsights {
        let highUVDays = Set(
            appState.dailyUVForecast
                .filter { $0.maxIndex >= 3 }
                .map { Calendar.current.startOfDay(for: $0.day) }
        )
        return CalendarAnalytics.routineProgress(
            recordDays: appState.recordedDays,
            verifiedAtDates: appState.records.map(\.verifiedAt),
            highUVDays: highUVDays,
            now: appState.referenceDate,
            eligibleFrom: eligibilityStart
        )
    }

    private var weeklyChartHint: String {
        if report.totalDays == 0 {
            return "Earlier days are not counted."
        }
        return report.missedDays.isEmpty ? "Every active day is logged." : "Tap an open day to backfill."
    }

    private func weekEntryFill(_ entry: WeeklyEntry) -> Color {
        if entry.applied {
            return AppPalette.sun
        }
        if !entry.isEligible {
            return AppPalette.muted.opacity(0.10)
        }
        return AppPalette.cardFill.opacity(0.9)
    }

    private var weekEntryColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.adaptive(minimum: 76), spacing: 10)]
        }

        return Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    }

    private func refreshReport() {
        report = CalendarAnalytics.weeklyReport(
            records: appState.recordedDays,
            now: appState.referenceDate,
            eligibleFrom: eligibilityStart
        )
    }

    private func handleWeekEntryTap(_ entry: WeeklyEntry) {
        if entry.applied {
            editorPresentation = WeeklyEditorPresentation(day: entry.date)
        } else {
            openBackfill(for: entry.date)
        }
    }

    private func openBackfill(for day: Date) {
        if isToday(day) {
            appState.prepareManualLogRouteContext(
                targetDate: day,
                targetDayPart: appState.dayPart(for: appState.referenceDate),
                source: .manualLog
            )
            router.open(
                .manualLog,
                targetDate: day,
                targetDayPart: appState.dayPart(for: appState.referenceDate)
            )
        } else {
            editorPresentation = WeeklyEditorPresentation(day: day)
        }
    }

    private func weekEntryAccessibilityLabel(_ entry: WeeklyEntry) -> String {
        let dateLabel = entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let status = entry.applied ? "logged" : (entry.isEligible ? "open" : "not tracking yet")
        return "\(dateLabel), \(status)"
    }

    private func weekEntryAccessibilityHint(_ entry: WeeklyEntry) -> String {
        if entry.applied {
            return "Opens this entry for editing."
        }

        if isToday(entry.date) {
            return "Opens today's log."
        }

        if !entry.isEligible {
            return "This day is not counted, but you can add a backfilled log if needed."
        }

        return "Opens this open day for backfill."
    }

    private func isToday(_ day: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: appState.referenceDate)
    }

    private static let dayIdentifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct WeeklyInsightCard: View {
    let eyebrow: String
    let value: String
    let detail: String
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)

            Text(value)
                .font(AppTextStyle.title.font)
                .foregroundStyle(AppPalette.ink)

            Text(detail)
                .font(AppTextStyle.caption.font)
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.72))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct WeeklyMetricPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let value: String
    let label: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(AppTextStyle.title.font)
                .foregroundStyle(AppPalette.ink)

            Text(label)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            if colorScheme == .light {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppPalette.cardFill.opacity(0.72))
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

#Preview {
    SunclubPreviewHost {
        WeeklyReportView()
    }
}

private struct WeeklyEntry: Identifiable {
    let date: Date
    let applied: Bool
    let isEligible: Bool
    let isFuture: Bool

    var id: Date { date }
}

private struct WeeklyEditorPresentation: Identifiable {
    let day: Date

    var id: Date { day }
}
