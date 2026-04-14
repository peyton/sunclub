import SwiftUI

struct WeeklyReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var report = WeeklyReport(startDate: Date(), endDate: Date(), appliedCount: 0, totalDays: 7, missedDays: [], streak: 0)
    @State private var insights = SunscreenUsageInsights.empty
    @State private var editorPresentation: WeeklyEditorPresentation?

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 28) {
                SunLightHeader(title: "Weekly Summary", showsBack: true, onBack: {
                    router.goBack()
                })

                weeklyPostcard

                weeklyChart
                    .frame(maxWidth: .infinity, alignment: .center)

                streakContextRow

                usageInsightsSection

                Spacer(minLength: 0)
            }
        } footer: {
            Button("View Full History") {
                router.push(.history)
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityHint("Opens your full calendar history with your current streak highlighted.")
            .accessibilityIdentifier("weekly.viewFullHistory")
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

    private var streakContextRow: some View {
        HStack(spacing: 12) {
                WeeklyMetricPill(
                    value: "\(appState.currentStreak)",
                    label: "Current streak",
                    accessibilityIdentifier: "weekly.currentStreak"
                )

                WeeklyMetricPill(
                    value: "\(appState.longestStreak)",
                    label: "Best streak",
                    accessibilityIdentifier: "weekly.bestStreak"
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak \(appState.currentStreak) days, best streak \(appState.longestStreak) days")
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This week")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            LazyVGrid(columns: weekEntryColumns, spacing: 10) {
                ForEach(weekEntries) { entry in
                    Button {
                        handleWeekEntryTap(entry)
                    } label: {
                        VStack(spacing: 8) {
                            Text(entry.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppPalette.softInk)

                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(entry.applied ? AppPalette.sun : AppPalette.cardFill.opacity(0.9))
                                .overlay {
                                    if entry.applied {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(AppPalette.onAccent)
                                    }
                                }
                                .overlay {
                                    if isToday(entry.date) {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppPalette.ink.opacity(0.18), lineWidth: 1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)

                            Text(entry.date.formatted(.dateTime.day()))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppPalette.softInk)

                            Text(entry.applied ? "Logged" : "Open")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(entry.applied ? AppPalette.success : AppPalette.softInk)
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

            Text(report.missedDays.isEmpty ? "All 7 days are logged." : "Backfill missing days")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(report.missedDays.isEmpty ? AppPalette.softInk : AppPalette.ink)
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
                                    .fill(AppPalette.cardFill.opacity(0.72))
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
                applied: records.contains(calendar.startOfDay(for: day)),
                isFuture: calendar.startOfDay(for: day) > today
            )
        }
    }

    private var notLoggedEntries: [WeeklyEntry] {
        weekEntries.filter { !$0.applied && !$0.isFuture }
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

    private var weekEntryColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.adaptive(minimum: 76), spacing: 10)]
        }

        return Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    }

    private func refreshReport() {
        report = appState.last7DaysReport()
        insights = appState.sunscreenUsageInsights()
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
            router.open(.manualLog)
        } else {
            editorPresentation = WeeklyEditorPresentation(day: day)
        }
    }

    private func backfillTitle(for day: Date) -> String {
        if isToday(day) {
            return "Log Today"
        }

        return "Backfill \(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
    }

    private func weekEntryAccessibilityLabel(_ entry: WeeklyEntry) -> String {
        let dateLabel = entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let status = entry.applied ? "logged" : "not logged"
        return "\(dateLabel), \(status)"
    }

    private func weekEntryAccessibilityHint(_ entry: WeeklyEntry) -> String {
        if entry.applied {
            return "Opens this entry for editing."
        }

        if isToday(entry.date) {
            return "Opens today's log."
        }

        return "Opens this missed day for backfill."
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
                .fill(AppPalette.cardFill.opacity(0.72))
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
                .fill(AppPalette.cardFill.opacity(0.72))
        )
    }
}

private struct WeeklyMetricPill: View {
    let value: String
    let label: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.72))
        )
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
    let isFuture: Bool

    var id: Date { date }
}

private struct WeeklyEditorPresentation: Identifiable {
    let day: Date

    var id: Date { day }
}
