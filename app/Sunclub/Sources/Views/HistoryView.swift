import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var displayedMonth: Date
    @State private var selectedDay: Date?
    @State private var editorPresentation: HistoryEditorPresentation?
    @State private var dayPendingDeletion: Date?
    @State private var isShowingMonthlyInsights = false

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    init(preselectedDay: Date? = nil) {
        let initialMonth = preselectedDay ?? Date()
        _displayedMonth = State(initialValue: initialMonth)
        _selectedDay = State(initialValue: preselectedDay)
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "History", showsBack: true, onBack: {
                    router.goBack()
                })

                monthNavigator

                weekdayHeader
                historyLegend

                let recordDates = appState.recordedDays

                statsSection(recordDates: recordDates)

                calendarGrid(recordDates: recordDates)

                if let selectedDay = selectedDay {
                    dayDetailCard(for: selectedDay)
                } else {
                    historyEmptyHint
                }

                Spacer(minLength: 0)
            }
        } footer: {
            historyActionFooter
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
        .confirmationDialog(
            "Delete Entry",
            isPresented: Binding(
                get: { dayPendingDeletion != nil },
                set: { if !$0 { dayPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let day = dayPendingDeletion {
                    appState.deleteRecord(for: day)
                    selectedDay = nil
                }
                dayPendingDeletion = nil
            }
        } message: {
            Text("This removes the visible entry for the selected day. You can undo recent changes in Recovery & Changes.")
        }
        .sheet(item: $editorPresentation) { presentation in
            HistoryRecordEditorView(
                day: presentation.day,
                existingRecord: appState.record(for: presentation.day)
            )
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    selectedDay = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history.previousMonth")

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("history.monthTitle")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    selectedDay = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canGoForward ? AppPalette.ink : AppPalette.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .accessibilityIdentifier("history.nextMonth")
        }
    }

    private var canGoForward: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) ?? nextMonth
        let today = calendar.startOfDay(for: Date())
        return nextMonthStart <= today
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var historyLegend: some View {
        HStack(spacing: 10) {
            historyLegendItem(
                title: "Logged",
                color: AppPalette.sun,
                symbol: "checkmark.circle.fill",
                accessibilityIdentifier: "history.legend.logged"
            )
            historyLegendItem(
                title: "Today",
                color: AppPalette.sun.opacity(0.45),
                symbol: "circle.dashed",
                accessibilityIdentifier: "history.legend.today"
            )
            historyLegendItem(
                title: "Not logged",
                color: Color.red.opacity(0.45),
                symbol: "xmark.circle",
                accessibilityIdentifier: "history.legend.notLogged"
            )
            historyLegendItem(
                title: "Future",
                color: AppPalette.muted,
                symbol: "circle",
                accessibilityIdentifier: "history.legend.future"
            )
        }
        .accessibilityIdentifier("history.legend")
    }

    private func historyLegendItem(
        title: String,
        color: Color,
        symbol: String,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .frame(maxWidth: .infinity)
    }

    private var historyEmptyHint: some View {
        SunStatusCard(
            title: "Pick a day",
            detail: "Tap a past day to edit an entry or backfill a log. Future days stay locked.",
            tint: AppPalette.sun,
            symbol: "calendar.badge.plus"
        )
        .accessibilityIdentifier("history.emptyHint")
    }

    private func calendarGrid(recordDates: [Date]) -> some View {
        let days = appState.monthGrid(for: displayedMonth)
        let recordDateSet = Set(recordDates)
        let today = calendar.startOfDay(for: Date())

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let isCurrentMonth = appState.isCurrentMonth(day, month: displayedMonth)
                let dayStart = calendar.startOfDay(for: day)
                let hasRecord = recordDateSet.contains(dayStart)
                let isToday = dayStart == today
                let isFuture = dayStart > today
                let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

                Button {
                    if isCurrentMonth && !isFuture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDay = day
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 15, weight: isToday ? .bold : .regular))
                            .foregroundStyle(dayTextColor(isCurrentMonth: isCurrentMonth, isFuture: isFuture, isSelected: isSelected))

                        Circle()
                            .fill(hasRecord && isCurrentMonth ? AppPalette.sun : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? AppPalette.warmGlow.opacity(0.5) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isCurrentMonth || isFuture)
                .accessibilityLabel(dayAccessibilityLabel(for: day, hasRecord: hasRecord, isToday: isToday))
                .accessibilityIdentifier(dayAccessibilityIdentifier(for: dayStart))
            }
        }
        .accessibilityIdentifier("history.calendarGrid")
    }

    private func dayTextColor(isCurrentMonth: Bool, isFuture: Bool, isSelected: Bool) -> Color {
        if !isCurrentMonth { return AppPalette.muted }
        if isFuture { return AppPalette.muted }
        if isSelected { return AppPalette.ink }
        return AppPalette.ink
    }

    @ViewBuilder
    private func dayDetailCard(for day: Date) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let record = appState.record(for: dayStart)
        let status = appState.dayStatus(for: dayStart)
        let conflict = appState.conflict(for: dayStart)

        VStack(alignment: .leading, spacing: 10) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            dayDetailBody(record: record, status: status, conflict: conflict)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .accessibilityIdentifier("history.dayDetail")
    }

    private func dayDetailBody(
        record: DailyRecord?,
        status: DayStatus,
        conflict: SunclubConflictItem?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: statusSymbol(for: status))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(statusColor(for: status))

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle(for: status))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("history.statusTitle")

                dayRecordMetadata(record)
                dayRecordDetails(record)
                conflictBanner(conflict)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func dayRecordMetadata(_ record: DailyRecord?) -> some View {
        if let record {
            Text("Verified via \(record.method.displayName) at \(record.verifiedAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
        } else {
            Text("No entry for this day yet.")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
        }
    }

    @ViewBuilder
    private func dayRecordDetails(_ record: DailyRecord?) -> some View {
        if let spf = record?.spfLevel {
            Text("SPF \(spf)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppPalette.sun)
        }

        if let notes = record?.trimmedNotes {
            Text(notes)
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.softInk)
                .lineLimit(3)
                .accessibilityIdentifier("history.dayNote")
        }
    }

    @ViewBuilder
    private func conflictBanner(_ conflict: SunclubConflictItem?) -> some View {
        if let conflict {
            VStack(alignment: .leading, spacing: 8) {
                Text("Merged for review")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.8))

                Text(conflict.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Review Recovery & Changes") {
                    router.push(.recovery)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("history.conflict.review")
            }
            .padding(.top, 6)
            .accessibilityIdentifier("history.conflictBanner")
        }
    }

    @ViewBuilder
    private var historyActionFooter: some View {
        if let selectedDay = selectedDay {
            let dayStart = calendar.startOfDay(for: selectedDay)
            let record = appState.record(for: dayStart)

            actionButtons(for: dayStart, record: record)
                .accessibilityIdentifier("history.actionFooter")
        }
    }

    private func statsSection(recordDates: [Date]) -> some View {
        let stats = monthStats(recordDates: recordDates)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Month Stats")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 20) {
                statBubble(value: "\(stats.appliedCount)", label: "Applied")
                statBubble(value: "\(stats.openCount)", label: "Open")
                statBubble(value: "\(stats.rate)", label: "Rate")
            }

            monthlyInsightDisclosure(stats.insights)
        }
        .accessibilityIdentifier("history.monthStats")
    }

    private func monthStats(recordDates: [Date]) -> HistoryMonthStats {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let today = calendar.startOfDay(for: Date())
        let effectiveEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        let monthRecords = recordDates.filter { $0 >= monthStart && $0 < effectiveEnd }
        let daysInRange = daysInCurrentMonthRange(monthEnd: monthEnd, monthStart: monthStart, effectiveEnd: effectiveEnd)
        let rate = daysInRange > 0 ? Int(Double(monthRecords.count) / Double(daysInRange) * 100) : 0

        return HistoryMonthStats(
            appliedCount: monthRecords.count,
            openCount: max(daysInRange - monthRecords.count, 0),
            rate: "\(rate)%",
            insights: appState.monthlyReviewInsights(for: displayedMonth)
        )
    }

    private func daysInCurrentMonthRange(monthEnd: Date, monthStart: Date, effectiveEnd: Date) -> Int {
        let today = calendar.startOfDay(for: Date())
        if monthEnd <= today {
            return calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        }

        return calendar.dateComponents([.day], from: monthStart, to: effectiveEnd).day ?? 0
    }

    @ViewBuilder
    private func monthlyInsightDisclosure(_ insights: MonthlyReviewInsights) -> some View {
        if insights.hasContent {
            Button(isShowingMonthlyInsights ? "Hide Patterns" : "Show Patterns") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingMonthlyInsights.toggle()
                }
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityIdentifier("history.monthPatternsToggle")

            if isShowingMonthlyInsights {
                monthlyInsightCards(insights)
            }
        }
    }

    private func monthlyInsightCards(_ insights: MonthlyReviewInsights) -> some View {
        VStack(spacing: 12) {
            if let bestWeekday = insights.bestWeekday {
                monthInsightCard(
                    title: "Best Day",
                    value: bestWeekday.title,
                    detail: bestWeekday.detail,
                    accessibilityIdentifier: "history.bestWeekday"
                )
            }

            if let hardestWeekday = insights.hardestWeekday {
                monthInsightCard(
                    title: "Hardest Day",
                    value: hardestWeekday.title,
                    detail: hardestWeekday.detail,
                    accessibilityIdentifier: "history.hardestWeekday"
                )
            }

            if let mostCommonSPF = insights.mostCommonSPF {
                monthInsightCard(
                    title: "Most Used SPF",
                    value: mostCommonSPF.title,
                    detail: mostCommonSPF.detail,
                    accessibilityIdentifier: "history.mostCommonSPF"
                )
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for day: Date, record: DailyRecord?) -> some View {
        if record != nil {
            HStack(spacing: 12) {
                Button("Edit Entry") {
                    editorPresentation = HistoryEditorPresentation(day: day)
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("history.editRecord")

                Button("Delete") {
                    dayPendingDeletion = day
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("history.deleteRecord")
            }
        } else {
            Button("Backfill Day") {
                editorPresentation = HistoryEditorPresentation(day: day)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("history.backfillRecord")
        }
    }

    private func dayAccessibilityLabel(for day: Date, hasRecord: Bool, isToday: Bool) -> String {
        let dateLabel = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let status = hasRecord ? "Applied" : (isToday ? "Pending" : "No entry")
        return "\(dateLabel), \(status)"
    }

    private func dayAccessibilityIdentifier(for day: Date) -> String {
        "history.day.\(Self.dayIdentifierFormatter.string(from: day))"
    }

    private func statBubble(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private func monthInsightCard(
        title: String,
        value: String,
        detail: String,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)

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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func statusSymbol(for status: DayStatus) -> String {
        switch status {
        case .applied: return "checkmark.circle.fill"
        case .todayPending: return "circle.dashed"
        case .missed: return "xmark.circle"
        case .future: return "circle"
        }
    }

    private func statusColor(for status: DayStatus) -> Color {
        switch status {
        case .applied: return AppPalette.success
        case .todayPending: return AppPalette.sun
        case .missed: return Color.red.opacity(0.6)
        case .future: return AppPalette.muted
        }
    }

    private func statusTitle(for status: DayStatus) -> String {
        switch status {
        case .applied: return "Applied"
        case .todayPending: return "Pending"
        case .missed: return "Not logged"
        case .future: return "Future"
        }
    }

    private static let dayIdentifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct HistoryEditorPresentation: Identifiable {
    let day: Date

    var id: Date { day }
}

struct HistoryRecordEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let existingRecord: DailyRecord?
    let route: AppRoute?

    @State private var selectedSPF: Int?
    @State private var notes: String
    @State private var hasLoadedInitialState = false

    init(day: Date, existingRecord: DailyRecord?, route: AppRoute? = nil) {
        self.day = day
        self.existingRecord = existingRecord
        self.route = route
        _selectedSPF = State(initialValue: existingRecord?.spfLevel)
        _notes = State(initialValue: existingRecord?.notes ?? "")
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: editorTitle, showsBack: true, onBack: {
                    closeEditor()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(editorMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }
                .accessibilityIdentifier("historyEditor.title")

                SunManualLogFields(
                    selectedSPF: $selectedSPF,
                    notes: $notes,
                    accessibilityPrefix: "historyEditor",
                    suggestions: appState.manualLogSuggestionState(for: day),
                    showsOptionalDisclosure: false
                )
            }
        } footer: {
            Button(primaryActionTitle) {
                appState.saveManualRecord(
                    for: day,
                    verifiedAt: existingRecord?.verifiedAt,
                    spfLevel: selectedSPF,
                    notes: notes
                )
                closeEditor()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("historyEditor.save")
        }
        .onAppear(perform: syncInitialStateIfNeeded)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var editorTitle: String {
        existingRecord == nil ? "Backfill Day" : "Edit Entry"
    }

    private var editorMessage: String {
        if existingRecord == nil {
            return "Add a log for this day so your history stays complete."
        }

        return "Update the SPF or note for this day."
    }

    private var primaryActionTitle: String {
        existingRecord == nil ? "Save Backfill" : "Save Changes"
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else {
            return
        }

        hasLoadedInitialState = true

        guard existingRecord == nil else {
            return
        }

        let suggestions = appState.manualLogSuggestionState(for: day)
        selectedSPF = suggestions.defaultSPF
    }

    private func closeEditor() {
        if route != nil {
            router.goBack()
        } else {
            dismiss()
        }
    }
}

struct HistoryEditorTestHarnessView: View {
    @Environment(AppState.self) private var appState

    let day: Date
    @State private var isPresentingEditor = true

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 12) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("historyHarness.day")

                Text(spfSummary)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("historyHarness.spf")
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            HistoryRecordEditorView(
                day: day,
                existingRecord: appState.record(for: day)
            )
        }
    }

    private var spfSummary: String {
        guard let spf = currentRecord?.spfLevel else {
            return "No SPF logged"
        }

        return "SPF \(spf)"
    }

    private var currentRecord: DailyRecord? {
        let dayStart = Calendar.current.startOfDay(for: day)
        return appState.records.first { Calendar.current.isDate($0.startOfDay, inSameDayAs: dayStart) }
    }
}

private struct HistoryMonthStats {
    let appliedCount: Int
    let openCount: Int
    let rate: String
    let insights: MonthlyReviewInsights
}

#Preview {
    SunclubPreviewHost {
        HistoryView()
    }
}
