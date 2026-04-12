import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var report = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)
    @State private var insights = SunscreenUsageInsights.empty
    @State private var backfillPresentation: WeeklyBackfillPresentation?

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 28) {
                SunLightHeader(title: "Weekly Summary", showsBack: true, onBack: {
                    router.goBack()
                })

                weeklyPostcard

                weeklyChart
                    .frame(maxWidth: .infinity, alignment: .center)

                usageInsightsSection

                Spacer(minLength: 0)
            }
        }
        .sheet(item: $backfillPresentation) { presentation in
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

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This week")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                ForEach(weekEntries) { entry in
                    VStack(spacing: 8) {
                        Text(entry.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppPalette.softInk)

                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(entry.applied ? AppPalette.sun : Color.white.opacity(0.9))
                            .overlay {
                                if entry.applied {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                if Calendar.current.isDateInToday(entry.date) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppPalette.ink.opacity(0.18), lineWidth: 1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)

                        Text(entry.date.formatted(.dateTime.day()))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)
                    }
                }
            }

            Text(report.missedDays.isEmpty ? "All 7 days are logged." : "Not logged: \(report.missedDays.joined(separator: ", "))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(report.missedDays.isEmpty ? AppPalette.softInk : Color.red.opacity(0.78))
                .multilineTextAlignment(.leading)

            if !notLoggedEntries.isEmpty {
                VStack(spacing: 8) {
                    ForEach(notLoggedEntries) { entry in
                        Button {
                            openBackfill(for: entry.date)
                        } label: {
                            HStack {
                                Text(backfillTitle(for: entry.date))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppPalette.ink)

                                Spacer(minLength: 0)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppPalette.softInk)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.72))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("weekly.backfill.\(Self.dayIdentifierFormatter.string(from: entry.date))")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .sunGlassCard(cornerRadius: 20)
    }

    private var weeklyPostcard: some View {
        ZStack(alignment: .bottomTrailing) {
            SunclubVisualAsset.motifSunRing.image
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 190)
                .opacity(0.24)
                .offset(x: 40, y: 30)

            VStack(alignment: .leading, spacing: 10) {
                Text(report.appliedSummaryText)
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppPalette.streakAccent, AppPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityIdentifier("weekly.summaryValue")

                Text("Last 7 days")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                if appState.longestStreak > 0 {
                    Text("Longest streak: \(appState.longestStreak) days")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .accessibilityIdentifier("weekly.longestStreak")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .background {
            SunclubVisualAsset.shareCardBackdropWarm.image
                .resizable()
                .scaledToFill()
                .opacity(0.36)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .sunGlassCard(cornerRadius: 24, fillOpacity: 0.52)
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
                applied: records.contains(calendar.startOfDay(for: day))
            )
        }
    }

    private var notLoggedEntries: [WeeklyEntry] {
        weekEntries.filter { !$0.applied }
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

    private func openBackfill(for day: Date) {
        if Calendar.current.isDateInToday(day) {
            router.open(.manualLog)
        } else {
            backfillPresentation = WeeklyBackfillPresentation(day: day)
        }
    }

    private func backfillTitle(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) {
            return "Log Today"
        }

        return "Backfill \(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
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

private struct WeeklyEntry: Identifiable {
    let date: Date
    let applied: Bool

    var id: Date { date }
}

private struct WeeklyBackfillPresentation: Identifiable {
    let day: Date

    var id: Date { day }
}
