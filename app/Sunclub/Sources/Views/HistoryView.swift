import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var displayedMonth: Date
    @State private var selectedDay: Date?
    @State private var editorPresentation: HistoryEditorPresentation?
    @State private var dayPendingDeletion: Date?
    @State private var lastDeletedBatchID: UUID?
    @State private var lastDeletedDay: Date?
    @State private var isShowingMonthlyInsights = true

    private let calendar = Calendar.current
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    init(preselectedDay: Date? = nil) {
        let initialMonth = preselectedDay ?? Date()
        _displayedMonth = State(initialValue: initialMonth)
        _selectedDay = State(initialValue: preselectedDay)
    }

    var body: some View {
        let presentation = historyPresentation

        SunLightScreen {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "History", showsBack: true, onBack: {
                    router.goBack()
                })

                monthNavigator

                deleteUndoBanner

                if let selectedDay = selectedDay {
                    dayDetailCard(for: selectedDay, presentation: presentation)
                }

                weekdayHeader

                calendarGrid(presentation: presentation)
                    .id(displayedMonth)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))

                historyLegend(presentation: presentation)

                if selectedDay == nil {
                    historyEmptyHint(presentation: presentation)
                }

                statsSection(stats: presentation.monthStats)

                streakContextCard(presentation: presentation)

                SunAssetHero(
                    asset: .illustrationHistoryCalendar,
                    height: 112,
                    glowColor: AppPalette.sun
                )

                Spacer(minLength: 0)
            }
        } footer: {
            historyActionFooter(presentation: presentation)
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { dayPendingDeletion != nil },
                set: { if !$0 { dayPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let day = dayPendingDeletion {
                    let existingBatchIDs = Set(appState.changeBatches.map(\.id))
                    appState.deleteRecord(for: day)
                    selectedDay = calendar.startOfDay(for: day)
                    lastDeletedDay = calendar.startOfDay(for: day)
                    lastDeletedBatchID = appState.changeBatches.first {
                        $0.kind == .deleteRecord && !existingBatchIDs.contains($0.id)
                    }?.id
                }
                dayPendingDeletion = nil
            }
        } message: {
            Text(deleteDialogMessage)
        }
        .sheet(item: $editorPresentation) { presentation in
            HistoryRecordEditorView(
                day: presentation.day,
                existingRecord: appState.record(for: presentation.day)
            )
        }
    }

    @ViewBuilder
    private var deleteUndoBanner: some View {
        if let lastDeletedBatchID,
           let lastDeletedDay {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Entry deleted")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(lastDeletedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 0)

                Button("Undo Delete") {
                    appState.undoChange(lastDeletedBatchID)
                    selectedDay = lastDeletedDay
                    self.lastDeletedBatchID = nil
                    self.lastDeletedDay = nil
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.undoDelete")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.cardFill.opacity(0.76))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("history.deleteUndoBanner")
        }
    }

    private var monthNavigator: some View {
        HStack {
            monthNavigationButton(systemName: "chevron.left") {
                changeMonth(by: -1)
            }
            .accessibilityLabel("Previous month")
            .accessibilityHint("Shows the previous month in history.")
            .accessibilityIdentifier("history.previousMonth")

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("history.monthTitle")

            Spacer()

            monthNavigationButton(systemName: "chevron.right", isEnabled: canGoForward) {
                changeMonth(by: 1)
            }
            .accessibilityLabel("Next month")
            .accessibilityHint(canGoForward ? "Shows the next month in history." : "The next month is in the future.")
            .accessibilityIdentifier("history.nextMonth")
        }
    }

    private func monthNavigationButton(
        systemName: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? AppPalette.ink : AppPalette.muted)
        }
        .buttonStyle(HistoryMonthNavigationButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }

    private func streakContextCard(presentation: HistoryPresentation) -> some View {
        let streakDays = presentation.currentStreakDays
        let currentStreak = streakDays.count
        let startText = streakDays.first.map {
            "Started \($0.formatted(.dateTime.month(.abbreviated).day()))"
        } ?? "Start by logging today"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)
                    .frame(width: 30, height: 30)
                    .background(AppPalette.warmGlow.opacity(0.5), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(currentStreak > 0 ? "Current Streak" : "No Current Streak")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    Text(currentStreak == 1 ? "1 day" : "\(currentStreak) days")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("history.currentStreakValue")

                    Text(startText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .accessibilityIdentifier("history.currentStreakStart")
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                streakMetricPill(
                    value: "\(presentation.longestStreak)",
                    label: presentation.longestStreak == 1 ? "Best day" : "Best days",
                    accessibilityIdentifier: "history.bestStreak"
                )

                Button("Jump to Today") {
                    jumpToToday()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppPalette.warmGlow.opacity(0.5))
                )
                .buttonStyle(.plain)
                .accessibilityHint("Shows and selects today in the calendar.")
                .accessibilityIdentifier("history.todayMonth")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.72))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.streakContext")
    }

    private func streakMetricPill(
        value: String,
        label: String,
        accessibilityIdentifier: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.76))
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var canGoForward: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) ?? nextMonth
        let today = calendar.startOfDay(for: appState.referenceDate)
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

    private func historyLegend(presentation: HistoryPresentation) -> some View {
        LazyVGrid(columns: historyLegendColumns, spacing: 8) {
            if !presentation.currentStreakDays.isEmpty {
                historyLegendItem(
                    title: "Streak",
                    color: AppPalette.streakAccent,
                    symbol: "flame.fill",
                    accessibilityIdentifier: "history.legend.streak"
                )
            }
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
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var historyLegendColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    private func historyEmptyHint(presentation: HistoryPresentation) -> some View {
        let hasLogs = presentation.monthStats.appliedCount > 0
        return SunStatusCard(
            title: hasLogs ? "Tap a day" : "No logs this month",
            detail: hasLogs
                ? "Logged days open for editing. Blank past days can be backfilled."
                : "Tap any past day to add a sunscreen log.",
            tint: AppPalette.sun,
            symbol: "calendar.badge.plus"
        )
        .accessibilityIdentifier("history.emptyHint")
    }

    private func calendarGrid(presentation: HistoryPresentation) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(Array(presentation.monthDays.enumerated()), id: \.offset) { _, day in
                calendarDayButton(
                    day: day,
                    state: dayCellState(
                        for: day,
                        presentation: presentation
                    )
                )
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded(handleCalendarSwipe)
        )
        .accessibilityAction(named: "Previous Month") {
            changeMonth(by: -1)
        }
        .accessibilityAction(named: "Next Month") {
            changeMonth(by: 1)
        }
        .accessibilityIdentifier("history.calendarGrid")
    }

    private func dayCellState(
        for day: Date,
        presentation: HistoryPresentation
    ) -> HistoryDayCellState {
        let isCurrentMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let dayStart = calendar.startOfDay(for: day)
        let record = presentation.record(for: dayStart, calendar: calendar)
        let hasRecord = record != nil
        let isToday = dayStart == presentation.today
        let isFuture = dayStart > presentation.today
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        return HistoryDayCellState(
            dayStart: dayStart,
            status: CalendarAnalytics.status(
                for: dayStart,
                with: presentation.recordDateSet,
                now: presentation.today,
                calendar: calendar
            ),
            hasRecord: hasRecord,
            spfLevel: record?.spfLevel,
            hasNotes: record?.trimmedNotes != nil,
            isToday: isToday,
            isFuture: isFuture,
            isSelected: isSelected,
            isCurrentMonth: isCurrentMonth,
            isCurrentStreak: isCurrentMonth && presentation.currentStreakDaySet.contains(dayStart)
        )
    }

    private func calendarDayButton(day: Date, state: HistoryDayCellState) -> some View {
        Button {
            selectDay(day, state: state)
        } label: {
            calendarDayContent(day: day, state: state)
        }
        .buttonStyle(.plain)
        .disabled(!state.isCurrentMonth || state.isFuture)
        .accessibilityLabel(
            dayAccessibilityLabel(
                for: day,
                state: state
            )
        )
        .accessibilityHint(
            dayAccessibilityHint(hasRecord: state.hasRecord, isToday: state.isToday, isFuture: state.isFuture)
        )
        .accessibilityIdentifier(dayAccessibilityIdentifier(for: state.dayStart))
        .contextMenu {
            calendarDayContextMenu(for: state)
        }
        .accessibilityAction(named: state.hasRecord ? "Edit Entry" : (state.isToday ? "Log Today" : "Backfill Day")) {
            guard state.isCurrentMonth, !state.isFuture else { return }
            editorPresentation = HistoryEditorPresentation(day: state.dayStart)
        }
        .accessibilityAction(named: "Delete Entry") {
            guard state.hasRecord else { return }
            dayPendingDeletion = state.dayStart
        }
    }

    @ViewBuilder
    private func calendarDayContextMenu(for state: HistoryDayCellState) -> some View {
        if state.hasRecord {
            Button("Edit Entry") {
                editorPresentation = HistoryEditorPresentation(day: state.dayStart)
            }

            Button("Delete Entry", role: .destructive) {
                dayPendingDeletion = state.dayStart
            }
        } else if state.isCurrentMonth, !state.isFuture {
            Button(state.isToday ? "Log Today" : "Backfill Day") {
                editorPresentation = HistoryEditorPresentation(day: state.dayStart)
            }
        }
    }

    private func calendarDayContent(day: Date, state: HistoryDayCellState) -> some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 15, weight: state.isToday ? .bold : .regular))
                .foregroundStyle(
                    dayTextColor(
                        isCurrentMonth: state.isCurrentMonth,
                        isFuture: state.isFuture,
                        isSelected: state.isSelected
                    )
                )

            Image(systemName: dayMarkerSymbol(for: state.status))
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(state.isCurrentMonth ? dayMarkerColor(for: state.status) : Color.clear)
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(dayBackgroundColor(isSelected: state.isSelected, isCurrentStreak: state.isCurrentStreak))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    dayBorderColor(isSelected: state.isSelected, isCurrentStreak: state.isCurrentStreak),
                    lineWidth: state.isSelected ? 1.5 : 1
                )
        }
    }

    private func selectDay(_ day: Date, state: HistoryDayCellState) {
        guard state.isCurrentMonth && !state.isFuture else { return }

        withAnimation(SunMotion.easeInOut(duration: 0.15, reduceMotion: reduceMotion)) {
            selectedDay = day
        }
    }

    private func dayTextColor(isCurrentMonth: Bool, isFuture: Bool, isSelected: Bool) -> Color {
        if !isCurrentMonth { return AppPalette.muted }
        if isFuture { return AppPalette.muted }
        if isSelected { return AppPalette.ink }
        return AppPalette.ink
    }

    private func dayBackgroundColor(isSelected: Bool, isCurrentStreak: Bool) -> Color {
        if isSelected {
            return AppPalette.warmGlow.opacity(0.58)
        }

        if isCurrentStreak {
            return AppPalette.sun.opacity(0.12)
        }

        return Color.clear
    }

    private func dayBorderColor(isSelected: Bool, isCurrentStreak: Bool) -> Color {
        if isSelected {
            return AppPalette.ink.opacity(0.28)
        }

        if isCurrentStreak {
            return AppPalette.streakAccent.opacity(0.32)
        }

        return Color.clear
    }

    private func dayMarkerSymbol(for status: DayStatus) -> String {
        switch status {
        case .applied: return "checkmark.circle.fill"
        case .todayPending: return "circle.dashed"
        case .missed: return "xmark.circle"
        case .future: return "circle"
        }
    }

    private func dayMarkerColor(for status: DayStatus) -> Color {
        switch status {
        case .applied: return AppPalette.sun
        case .todayPending: return AppPalette.sun.opacity(0.55)
        case .missed: return Color.red.opacity(0.45)
        case .future: return AppPalette.muted
        }
    }

    @ViewBuilder
    private func dayDetailCard(for day: Date, presentation: HistoryPresentation) -> some View {
        let dayStart = calendar.startOfDay(for: day)
        let record = presentation.record(for: dayStart, calendar: calendar)
        let status = CalendarAnalytics.status(
            for: dayStart,
            with: presentation.recordDateSet,
            now: presentation.today,
            calendar: calendar
        )
        let conflict = appState.conflict(for: dayStart)
        let isCurrentStreak = presentation.currentStreakDaySet.contains(dayStart)

        VStack(alignment: .leading, spacing: 10) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            if isCurrentStreak {
                Label("Part of your current streak", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.streakAccent)
                    .accessibilityIdentifier("history.currentStreakBadge")
            }

            dayDetailBody(record: record, status: status, conflict: conflict)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.cardStroke, lineWidth: 1)
        }
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
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("history.dayNote")
        }
    }

    @ViewBuilder
    private func conflictBanner(_ conflict: SunclubConflictItem?) -> some View {
        if let conflict {
            VStack(alignment: .leading, spacing: 8) {
                Text("Merged for review")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

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
    private func historyActionFooter(presentation: HistoryPresentation) -> some View {
        if let selectedDay = selectedDay {
            let dayStart = calendar.startOfDay(for: selectedDay)
            let record = presentation.record(for: dayStart, calendar: calendar)
            let status = CalendarAnalytics.status(
                for: dayStart,
                with: presentation.recordDateSet,
                now: presentation.today,
                calendar: calendar
            )

            actionButtons(for: dayStart, record: record, status: status)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statsSection(stats: HistoryMonthStats) -> some View {
        if stats.appliedCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Month Stats")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                HStack(spacing: 20) {
                    statBubble(value: "\(stats.appliedCount)", label: "Applied")
                    statBubble(value: "\(stats.openCount)", label: "Open")
                    statBubble(value: "\(stats.rate)", label: "Rate")
                }

                if isShowingMonthlyInsights {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Text("\(stats.appliedCount) of \(stats.totalDays) days logged")
                                .font(AppTypography.metric)
                                .foregroundStyle(AppPalette.ink)
                        }

                        Text("Consistency: \(stats.rate)")
                            .font(AppTypography.metric)
                            .foregroundStyle(AppPalette.ink)

                        if stats.bestStreak > 0 {
                            Text("Best streak: \(stats.bestStreak) days")
                                .font(AppTypography.metric)
                                .foregroundStyle(AppPalette.ink)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.insetCard, style: .continuous)
                            .fill(AppPalette.warmGlow.opacity(0.3))
                    )
                    .accessibilityIdentifier("history.monthSummary")
                }

                monthlyInsightDisclosure(stats.insights)
            }
            .accessibilityIdentifier("history.monthStats")
        }
    }

    private var historyPresentation: HistoryPresentation {
        let records = appState.records
        let recordDates = records.map { calendar.startOfDay(for: $0.startOfDay) }
        let recordDateSet = Set(recordDates)
        let today = calendar.startOfDay(for: appState.referenceDate)
        let currentStreakDays = CalendarAnalytics.currentStreakDays(
            records: recordDates,
            now: today,
            calendar: calendar
        )
        var recordsByDay: [Date: DailyRecord] = [:]
        for record in records {
            recordsByDay[calendar.startOfDay(for: record.startOfDay)] = record
        }

        return HistoryPresentation(
            recordsByDay: recordsByDay,
            recordDateSet: recordDateSet,
            currentStreakDays: currentStreakDays,
            currentStreakDaySet: Set(currentStreakDays),
            today: today,
            monthDays: CalendarAnalytics.monthGridDays(for: displayedMonth, calendar: calendar),
            monthStats: monthStats(recordDates: recordDates, records: records, today: today),
            longestStreak: appState.longestStreak
        )
    }

    private func monthStats(recordDates: [Date], records: [DailyRecord], today: Date) -> HistoryMonthStats {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let effectiveEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        let monthRecords = recordDates.filter { $0 >= monthStart && $0 < effectiveEnd }
        let daysInRange = daysInCurrentMonthRange(
            monthEnd: monthEnd,
            monthStart: monthStart,
            effectiveEnd: effectiveEnd,
            today: today
        )
        let rate = daysInRange > 0 ? Int(Double(monthRecords.count) / Double(daysInRange) * 100) : 0
        let monthRecordSet = Set(monthRecords.map { calendar.startOfDay(for: $0) })
        let bestStreak = CalendarAnalytics.longestStreak(records: Array(monthRecordSet), calendar: calendar)

        return HistoryMonthStats(
            appliedCount: monthRecords.count,
            openCount: max(daysInRange - monthRecords.count, 0),
            rate: "\(rate)%",
            insights: MonthlyReviewAnalytics.insights(
                from: records,
                month: displayedMonth,
                now: today,
                calendar: calendar
            ),
            bestStreak: bestStreak
        )
    }

    private func daysInCurrentMonthRange(monthEnd: Date, monthStart: Date, effectiveEnd: Date, today: Date) -> Int {
        if monthEnd <= today {
            return calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        }

        return calendar.dateComponents([.day], from: monthStart, to: effectiveEnd).day ?? 0
    }

    @ViewBuilder
    private func monthlyInsightDisclosure(_ insights: MonthlyReviewInsights) -> some View {
        if insights.hasContent {
            Button(isShowingMonthlyInsights ? "Hide Patterns" : "Show Patterns") {
                withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
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
    private func actionButtons(for day: Date, record: DailyRecord?, status: DayStatus) -> some View {
        if record != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    loggedDayActions(for: day)
                }

                VStack(spacing: 10) {
                    loggedDayActions(for: day)
                }
            }
            .accessibilityLabel("\(statusTitle(for: status)) entry actions")
        } else {
            Button(isToday(day) ? "Log Today" : "Backfill Day") {
                editorPresentation = HistoryEditorPresentation(day: day)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("history.backfillRecord")
        }
    }

    @ViewBuilder
    private func loggedDayActions(for day: Date) -> some View {
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

    private func isToday(_ day: Date) -> Bool {
        calendar.isDate(day, inSameDayAs: appState.referenceDate)
    }

    private var deleteDialogTitle: String {
        guard let day = dayPendingDeletion else {
            return "Delete Entry"
        }

        return "Delete \(day.formatted(.dateTime.month(.wide).day()))?"
    }

    private var deleteDialogMessage: String {
        guard let day = dayPendingDeletion else {
            return "This removes the visible entry. You can undo recent changes in Recovery & Changes."
        }

        let dateLabel = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "This removes \(deleteRecordSummary(for: day)) for \(dateLabel). You can undo this from the History banner or Recovery & Changes."
    }

    private func deleteRecordSummary(for day: Date) -> String {
        guard let record = appState.record(for: day) else {
            return "the visible entry"
        }

        var parts: [String] = []
        if let spfLevel = record.spfLevel {
            parts.append("SPF \(spfLevel)")
        }
        if record.trimmedNotes != nil {
            parts.append("a saved note")
        }
        if record.reapplyCount > 0 {
            let checkInLabel = record.reapplyCount == 1 ? "reapply check-in" : "reapply check-ins"
            parts.append("\(record.reapplyCount) \(checkInLabel)")
        }

        return parts.isEmpty ? "the visible entry" : parts.joined(separator: ", ")
    }

    private func changeMonth(by offset: Int) {
        guard offset != 0 else { return }
        guard offset < 0 || canGoForward else { return }

        withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
            displayedMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) ?? displayedMonth
            selectedDay = nil
            isShowingMonthlyInsights = false
        }
    }

    private func jumpToToday() {
        let today = calendar.startOfDay(for: appState.referenceDate)
        withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
            displayedMonth = today
            selectedDay = today
        }
    }

    private func handleCalendarSwipe(_ value: DragGesture.Value) {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        guard abs(horizontalDistance) > 44,
              abs(horizontalDistance) > abs(verticalDistance) * 1.35 else {
            return
        }

        if horizontalDistance < 0 {
            changeMonth(by: 1)
        } else {
            changeMonth(by: -1)
        }
    }

    private func dayAccessibilityLabel(
        for day: Date,
        state: HistoryDayCellState
    ) -> String {
        let dateLabel = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let status = state.hasRecord ? "Applied" : (state.isToday ? "Pending" : "No entry")
        var parts = [dateLabel, status]

        if let spfLevel = state.spfLevel {
            parts.append("SPF \(spfLevel)")
        }

        if state.hasNotes {
            parts.append("note saved")
        }

        if state.isCurrentStreak {
            parts.append("part of current streak")
        }

        if state.isSelected {
            parts.append("selected")
        }

        return parts.joined(separator: ", ")
    }

    private func dayAccessibilityHint(hasRecord: Bool, isToday: Bool, isFuture: Bool) -> String {
        if isFuture {
            return "Future days cannot be edited."
        }

        if hasRecord {
            return "Selects this day so you can edit or delete the entry."
        }

        if isToday {
            return "Selects today so you can add a log."
        }

        return "Selects this missed day so you can backfill it."
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
                .fill(AppPalette.cardFill.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.cardStroke, lineWidth: 1)
        }
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
                .fill(AppPalette.cardFill.opacity(0.72))
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

private struct HistoryDayCellState {
    let dayStart: Date
    let status: DayStatus
    let hasRecord: Bool
    let spfLevel: Int?
    let hasNotes: Bool
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let isCurrentMonth: Bool
    let isCurrentStreak: Bool
}

struct HistoryRecordEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let existingRecord: DailyRecord?
    let route: AppRoute?
    let targetContext: AppLogContext?

    @State private var selectedSPF: Int?
    @State private var notes: String
    @State private var hasLoadedInitialState = false

    init(
        day: Date,
        existingRecord: DailyRecord?,
        route: AppRoute? = nil,
        targetContext: AppLogContext? = nil
    ) {
        self.day = day
        self.existingRecord = existingRecord
        self.route = route
        self.targetContext = targetContext
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
                    for: targetContext?.date ?? day,
                    dayPart: targetContext?.dayPart,
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

private struct HistoryPresentation {
    let recordsByDay: [Date: DailyRecord]
    let recordDateSet: Set<Date>
    let currentStreakDays: [Date]
    let currentStreakDaySet: Set<Date>
    let today: Date
    let monthDays: [Date]
    let monthStats: HistoryMonthStats
    let longestStreak: Int

    func record(for day: Date, calendar: Calendar) -> DailyRecord? {
        recordsByDay[calendar.startOfDay(for: day)]
    }
}

private struct HistoryMonthStats {
    let appliedCount: Int
    let openCount: Int
    let rate: String
    let insights: MonthlyReviewInsights
    let bestStreak: Int

    var totalDays: Int { appliedCount + openCount }
}

private struct HistoryMonthNavigationButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(controlFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.96 : 1))
            .animation(
                SunMotion.easeOut(duration: 0.12, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }

    private var controlFill: Color {
        switch colorScheme {
        case .dark:
            return AppPalette.controlFill.opacity(isEnabled ? 0.88 : 0.72)
        default:
            return AppPalette.muted.opacity(isEnabled ? 0.22 : 0.18)
        }
    }
}

#Preview {
    SunclubPreviewHost {
        HistoryView()
    }
}
