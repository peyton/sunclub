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
    @State private var failedDeletionDay: Date?
    @State private var isShowingMonthlyInsights = true

    let showsBackButton: Bool

    private let calendar = Calendar.current

    init(preselectedDay: Date? = nil, showsBackButton: Bool = true) {
        self.showsBackButton = showsBackButton
        let initialMonth = preselectedDay ?? Date()
        _displayedMonth = State(initialValue: initialMonth)
        _selectedDay = State(initialValue: preselectedDay)
    }

    var body: some View {
        let presentation = historyPresentation

        SunLightScreen {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "History", showsBack: showsBackButton, onBack: {
                    router.goBack()
                })

                monthNavigator

                calendarMonthCard(presentation: presentation)

                statsSection(stats: presentation.monthStats)

                deleteUndoBanner

                deletionErrorBanner

                if let selectedDay = selectedDay {
                    dayDetailCard(for: selectedDay, presentation: presentation)
                }

                historyOverviewCard(presentation: presentation)

                historyLegend(presentation: presentation)

                if selectedDay == nil {
                    historyEmptyHint(presentation: presentation)
                }

                Spacer(minLength: 0)
            }
        }
        .sunNavigationBarCompatibility()
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
                    if deleteRecordAndPreserveSelection(for: day) {
                        dayPendingDeletion = nil
                    } else {
                        failedDeletionDay = day
                    }
                }
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

    private func historyOverviewCard(presentation: HistoryPresentation) -> some View {
        AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 14) {
                SunInfoRow(
                    title: "iCloud History",
                    detail: "Your sunscreen history stays private and follows your devices when iCloud sync is on.",
                    systemImage: "icloud.fill",
                    tint: AppPalette.pool
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        historyOverviewMetric(
                            value: "\(presentation.monthStats.appliedCount)",
                            label: "logged days"
                        )
                        historyOverviewMetric(
                            value: "\(max(0, presentation.monthStats.totalDays - presentation.monthStats.appliedCount))",
                            label: "open days"
                        )
                    }

                    VStack(spacing: 10) {
                        historyOverviewMetric(
                            value: "\(presentation.monthStats.appliedCount)",
                            label: "logged days"
                        )
                        historyOverviewMetric(
                            value: "\(max(0, presentation.monthStats.totalDays - presentation.monthStats.appliedCount))",
                            label: "open days"
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("history.overview")
    }

    private func historyOverviewMetric(value: String, label: String) -> some View {
        StatCard(
            value: value,
            label: label,
            systemImage: label.contains("open") ? "calendar" : "checkmark.circle.fill",
            tint: label.contains("open") ? AppPalette.sun : AppPalette.success
        )
    }

    @ViewBuilder
    private var deleteUndoBanner: some View {
        if let lastDeletedBatchID,
           let lastDeletedDay {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Entry deleted")
                        .font(AppTextStyle.bodyMedium.font)
                        .foregroundStyle(AppPalette.ink)

                    Text(lastDeletedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(AppTextStyle.captionMedium.font)
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 0)

                Button("Undo Delete") {
                    appState.undoChange(lastDeletedBatchID)
                    selectedDay = lastDeletedDay
                    self.lastDeletedBatchID = nil
                    self.lastDeletedDay = nil
                }
                .font(AppTextStyle.bodyMedium.font)
                .foregroundStyle(AppPalette.ink)
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.undoDelete")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(AppPalette.cardFill.opacity(0.76))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("history.deleteUndoBanner")
        }
    }

    @ViewBuilder
    private var deletionErrorBanner: some View {
        if let failedDeletionDay,
           let errorMessage = appState.logActionErrorMessage {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                SunInfoRow(
                    title: "Entry not deleted",
                    detail: "\(failedDeletionDay.formatted(.dateTime.weekday(.wide).month(.wide).day())) is unchanged. \(errorMessage)",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: AppColor.warning
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.xs) {
                        deletionErrorActions(for: failedDeletionDay)
                    }

                    VStack(spacing: AppSpacing.xs) {
                        deletionErrorActions(for: failedDeletionDay)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .sunGlassCard(cornerRadius: AppRadius.card)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("history.deleteError")
        }
    }

    @ViewBuilder
    private func deletionErrorActions(for day: Date) -> some View {
        PrimaryButton("Try Again", systemImage: "arrow.clockwise", identifier: "history.deleteRetry") {
            if deleteRecordAndPreserveSelection(for: day) {
                failedDeletionDay = nil
            }
        }

        SecondaryPillButton("Keep Entry", identifier: "history.deleteCancel") {
            failedDeletionDay = nil
            appState.clearLogActionError()
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
                .font(AppTextStyle.title.font)
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
                .font(AppFont.rounded(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? AppPalette.ink : AppPalette.muted)
        }
        .buttonStyle(HistoryMonthNavigationButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }

    private var canGoForward: Bool {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        let nextMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: nextMonth)) ?? nextMonth
        let today = calendar.startOfDay(for: appState.referenceDate)
        return nextMonthStart <= today
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(Array(weekdayHeaderSymbols.enumerated()), id: \.offset) { index, symbol in
                Text(symbol.visible)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.softInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(symbol.spoken)
                    .accessibilityIdentifier("history.weekday.\(index)")
            }
        }
    }

    private var weekdayHeaderSymbols: [(visible: String, spoken: String)] {
        let visibleSymbols = dynamicTypeSize.isAccessibilitySize
            ? calendar.veryShortStandaloneWeekdaySymbols
            : calendar.shortStandaloneWeekdaySymbols
        return Array(zip(visibleSymbols, calendar.standaloneWeekdaySymbols)).map {
            (visible: $0.0, spoken: $0.1)
        }
    }

    private func historyLegend(presentation: HistoryPresentation) -> some View {
        LazyVGrid(columns: historyLegendColumns, spacing: 8) {
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
                color: AppPalette.softInk.opacity(0.58),
                symbol: "xmark.circle",
                accessibilityIdentifier: "history.legend.notLogged"
            )
            historyLegendItem(
                title: "Not tracking yet",
                color: AppPalette.muted,
                symbol: "ellipsis.circle",
                accessibilityIdentifier: "history.legend.untracked"
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
                .font(AppFont.rounded(size: 10, weight: .semibold))
                .foregroundStyle(color)

            Text(title)
                .font(AppTextStyle.caption.font)
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

    private func calendarMonthCard(presentation: HistoryPresentation) -> some View {
        VStack(spacing: 12) {
            weekdayHeader

            calendarGrid(presentation: presentation)
                .id(displayedMonth)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        }
        .padding(14)
        .sunGlassCard(cornerRadius: AppRadius.card)
    }

    private func historyEmptyHint(presentation: HistoryPresentation) -> some View {
        let hasLogs = presentation.monthStats.appliedCount > 0
        let text = hasLogs
            ? "Tap a logged day to edit, or a blank past day to backfill."
            : "Tap any past day to add a sunscreen log."

        return HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(AppFont.rounded(size: 15, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .accessibilityHidden(true)

            Text(text)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(AppPalette.warmGlow.opacity(0.32))
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
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 24)
                .onEnded(handleCalendarSwipe),
            including: .all
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
                eligibleFrom: presentation.eligibilityStart,
                calendar: calendar
            ),
            hasRecord: hasRecord,
            spfLevel: record?.spfLevel,
            hasNotes: record?.trimmedNotes != nil,
            isToday: isToday,
            isFuture: isFuture,
            isSelected: isSelected,
            isCurrentMonth: isCurrentMonth,
            isCurrentStreak: false
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
                .font(state.isToday ? AppTextStyle.bodyMedium.font : AppTextStyle.body.font)
                .foregroundStyle(
                    dayTextColor(
                        isCurrentMonth: state.isCurrentMonth,
                        isFuture: state.isFuture,
                        isSelected: state.isSelected
                    )
                )

            Image(systemName: dayMarkerSymbol(for: state.status))
                .font(AppFont.rounded(size: 7, weight: .semibold))
                .foregroundStyle(state.isCurrentMonth ? dayMarkerColor(for: state.status) : Color.clear)
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(dayBackgroundColor(isSelected: state.isSelected, isCurrentStreak: state.isCurrentStreak))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
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
        if isSelected { return AppPalette.onAccent }
        return AppPalette.ink
    }

    private func dayBackgroundColor(isSelected: Bool, isCurrentStreak: Bool) -> Color {
        if isSelected {
            return AppPalette.ink
        }

        if isCurrentStreak {
            return AppPalette.sun.opacity(0.12)
        }

        return Color.clear
    }

    private func dayBorderColor(isSelected: Bool, isCurrentStreak: Bool) -> Color {
        if isSelected {
            return AppPalette.sun
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
        case .untracked: return "ellipsis.circle"
        case .future: return "circle"
        }
    }

    private func dayMarkerColor(for status: DayStatus) -> Color {
        switch status {
        case .applied: return AppPalette.sun
        case .todayPending: return AppPalette.sun.opacity(0.55)
        case .missed: return AppPalette.softInk.opacity(0.58)
        case .untracked: return AppPalette.muted
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

        VStack(alignment: .leading, spacing: 10) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)

            dayDetailBody(record: record, status: status, conflict: conflict)

            actionButtons(for: dayStart, record: record, status: status)
                .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
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
                .font(AppFont.rounded(size: 18, weight: .semibold))
                .foregroundStyle(statusColor(for: status))

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle(for: status))
                    .font(AppTextStyle.sectionHeader.font)
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
            Text("\(record.method.displayName) log at \(record.verifiedAt.formatted(date: .omitted, time: .shortened))")
                .font(AppTextStyle.caption.font)
                .foregroundStyle(AppPalette.softInk)
        } else {
            Text("No entry for this day yet.")
                .font(AppTextStyle.caption.font)
                .foregroundStyle(AppPalette.softInk)
        }
    }

    @ViewBuilder
    private func dayRecordDetails(_ record: DailyRecord?) -> some View {
        if let spf = record?.spfLevel {
            Text("SPF \(spf)")
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.sun)
        }

        if let notes = record?.trimmedNotes {
            Text(notes)
                .font(AppTextStyle.caption.font)
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
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text(conflict.summary)
                    .font(AppTextStyle.caption.font)
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

    private func statsSection(stats: HistoryMonthStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Month summary")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppPalette.softInk)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    monthMetricPills(stats: stats)
                }

                VStack(spacing: 10) {
                    monthMetricPills(stats: stats)
                }
            }

            if isShowingMonthlyInsights, stats.appliedCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(stats.appliedCount) of \(stats.totalDays) active days logged")
                        .font(AppTypography.metric)
                        .foregroundStyle(AppPalette.ink)

                    Text("Log rate: \(stats.rate)")
                        .font(AppTypography.metric)
                        .foregroundStyle(AppPalette.ink)

                    if stats.bestStreak > 0 {
                        Text("Longest run: \(stats.bestStreak) days")
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

            if stats.appliedCount > 0 {
                monthlyInsightDisclosure(stats.insights)
            }
        }
        .padding(16)
        .sunGlassCard(cornerRadius: AppRadius.card)
        .accessibilityIdentifier("history.monthStats")
    }

    @ViewBuilder
    private func monthMetricPills(stats: HistoryMonthStats) -> some View {
        SunMetricPill(
            value: "\(stats.appliedCount)",
            label: "logged days",
            symbolName: "checkmark.circle.fill",
            tint: AppPalette.success,
            accessibilityIdentifier: "history.month.applied"
        )

        SunMetricPill(
            value: "\(stats.totalDays)",
            label: "active days",
            symbolName: "calendar",
            tint: AppPalette.sun,
            accessibilityIdentifier: "history.month.active"
        )

        SunMetricPill(
            value: stats.rate,
            label: "month",
            symbolName: "chart.bar.fill",
            tint: AppPalette.pool,
            accessibilityIdentifier: "history.month.rate"
        )
    }

    private var historyPresentation: HistoryPresentation {
        let records = appState.records
        let recordDates = records.map { calendar.startOfDay(for: $0.startOfDay) }
        let recordDateSet = Set(recordDates)
        let today = calendar.startOfDay(for: appState.referenceDate)
        let eligibilityStart = CalendarAnalytics.eligibilityStart(
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
            today: today,
            eligibilityStart: eligibilityStart,
            monthDays: CalendarAnalytics.monthGridDays(for: displayedMonth, calendar: calendar),
            monthStats: monthStats(
                recordDates: recordDates,
                records: records,
                today: today,
                eligibilityStart: eligibilityStart
            )
        )
    }

    private func monthStats(
        recordDates: [Date],
        records: [DailyRecord],
        today: Date,
        eligibilityStart: Date
    ) -> HistoryMonthStats {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let effectiveEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        let effectiveStart = max(monthStart, calendar.startOfDay(for: eligibilityStart))
        let monthRecords = recordDates.filter { $0 >= effectiveStart && $0 < effectiveEnd }
        let daysInRange = effectiveStart < effectiveEnd
            ? calendar.dateComponents([.day], from: effectiveStart, to: effectiveEnd).day ?? 0
            : 0
        let rate = daysInRange > 0
            ? "\(Int(Double(monthRecords.count) / Double(daysInRange) * 100))%"
            : "—"
        let monthRecordSet = Set(monthRecords.map { calendar.startOfDay(for: $0) })
        let bestStreak = CalendarAnalytics.longestStreak(records: Array(monthRecordSet), calendar: calendar)

        return HistoryMonthStats(
            appliedCount: monthRecords.count,
            openCount: max(daysInRange - monthRecords.count, 0),
            rate: rate,
            insights: MonthlyReviewAnalytics.insights(
                from: records,
                month: displayedMonth,
                now: today,
                eligibleFrom: eligibilityStart,
                calendar: calendar
            ),
            bestStreak: bestStreak
        )
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
            PrimaryButton(
                isToday(day) ? "Log Today" : "Backfill Day",
                systemImage: isToday(day) ? "sun.max" : "calendar.badge.plus",
                identifier: "history.backfillRecord"
            ) {
                editorPresentation = HistoryEditorPresentation(day: day)
            }
        }
    }

    @ViewBuilder
    private func loggedDayActions(for day: Date) -> some View {
        PrimaryButton("Edit Entry", systemImage: "pencil", identifier: "history.editRecord") {
            editorPresentation = HistoryEditorPresentation(day: day)
        }

        SecondaryPillButton("Delete", systemImage: "trash", identifier: "history.deleteRecord") {
            dayPendingDeletion = day
        }
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

    private func deleteRecordAndPreserveSelection(for day: Date) -> Bool {
        switch appState.deleteRecord(for: day) {
        case let .success(receipt):
            selectedDay = calendar.startOfDay(for: day)
            lastDeletedDay = calendar.startOfDay(for: day)
            lastDeletedBatchID = receipt.batchID
            failedDeletionDay = nil
            return true
        case .failure:
            return false
        }
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
        let status = statusTitle(for: state.status)
        var parts = [dateLabel, status]

        if let spfLevel = state.spfLevel {
            parts.append("SPF \(spfLevel)")
        }

        if state.hasNotes {
            parts.append("note saved")
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
                .font(AppTextStyle.title.font)
                .foregroundStyle(AppPalette.ink)
            Text(label)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
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

    private func statusSymbol(for status: DayStatus) -> String {
        switch status {
        case .applied: return "checkmark.circle.fill"
        case .todayPending: return "circle.dashed"
        case .missed: return "xmark.circle"
        case .untracked: return "ellipsis.circle"
        case .future: return "circle"
        }
    }

    private func statusColor(for status: DayStatus) -> Color {
        switch status {
        case .applied: return AppPalette.success
        case .todayPending: return AppPalette.sun
        case .missed: return AppPalette.softInk
        case .untracked: return AppPalette.muted
        case .future: return AppPalette.muted
        }
    }

    private func statusTitle(for status: DayStatus) -> String {
        switch status {
        case .applied: return "Logged"
        case .todayPending: return "Open today"
        case .missed: return "Not logged"
        case .untracked: return "Not tracking yet"
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
    @State private var selectedAreas: Set<String>
    @State private var notes: String
    @State private var selectedTimestamp: Date
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
        let existingAreas = SunManualLogInput.coveredAreas(in: existingRecord?.notes)
        _selectedAreas = State(initialValue: existingAreas.isEmpty ? SunManualLogInput.defaultCoveredAreas : existingAreas)
        _notes = State(initialValue: SunManualLogInput.notesRemovingCoveredAreas(existingRecord?.notes))
        _selectedTimestamp = State(initialValue: existingRecord?.verifiedAt ?? day)
    }

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: editorTitle, showsBack: true, onBack: {
                    closeEditor()
                })

                SunScreenTitleBlock(
                    eyebrow: day.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                    title: existingRecord == nil ? "No sunscreen logged" : "Completed",
                    detail: editorMessage,
                    symbolName: existingRecord == nil ? "calendar.badge.plus" : "checkmark.circle.fill",
                    tint: existingRecord == nil ? AppPalette.sun : AppPalette.success
                )
                .accessibilityIdentifier("historyEditor.title")

                SunclubCard(cornerRadius: AppRadius.card, padding: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        AppText("Application time", style: .bodyMedium)
                        DatePicker(
                            "Application time",
                            selection: $selectedTimestamp,
                            in: allowedTimestampRange,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("historyEditor.timePicker")

                        AppText(
                            "Saved for \(selectedTimestamp.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())).",
                            style: .caption,
                            color: AppColor.Text.secondary
                        )
                    }
                }

                SunclubCard(cornerRadius: 20, padding: 16) {
                    SunManualLogFields(
                        selectedSPF: $selectedSPF,
                        notes: $notes,
                        selectedAreas: $selectedAreas,
                        accessibilityPrefix: "historyEditor",
                        suggestions: appState.manualLogSuggestionState(for: day),
                        showsOptionalDisclosure: false
                    )
                }

                if let errorMessage = appState.logActionErrorMessage {
                    SunInfoRow(
                        title: "Couldn’t save",
                        detail: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: AppColor.warning
                    )
                    .padding(AppSpacing.sm)
                    .sunGlassCard(cornerRadius: AppRadius.card)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Save error. \(errorMessage)")
                    .accessibilityIdentifier("historyEditor.error")
                }
            }
        } footer: {
            Button(primaryActionTitle) {
                let result = appState.saveManualRecord(
                    for: targetContext?.date ?? day,
                    dayPart: targetContext?.dayPart,
                    verifiedAt: selectedTimestamp,
                    spfLevel: selectedSPF,
                    notes: SunManualLogInput.notesWithCoveredAreas(notes, areas: selectedAreas)
                )
                if case .success = result {
                    closeEditor()
                }
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("historyEditor.save")
        }
        .onAppear {
            appState.clearLogActionError()
            syncInitialStateIfNeeded()
        }
        .onDisappear {
            appState.clearLogActionError()
        }
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
    }

    private var editorTitle: String {
        existingRecord == nil ? "Backfill Day" : "Edit Entry"
    }

    private var editorMessage: String {
        if existingRecord == nil {
            return "Add a log for this day so your history stays complete."
        }

        return "Update the time, SPF, covered areas, or note for this day."
    }

    private var primaryActionTitle: String {
        if appState.logActionErrorMessage != nil {
            return "Try Again"
        }
        return existingRecord == nil ? "Save Backfill" : "Save Changes"
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
        selectedTimestamp = defaultTimestamp
    }

    private var allowedTimestampRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: targetContext?.date ?? day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let endOfDay = nextDay.addingTimeInterval(-1)
        let upperBound = max(start, min(endOfDay, appState.referenceDate))
        return start...upperBound
    }

    private var defaultTimestamp: Date {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: targetContext?.date ?? day)
        if calendar.isDate(targetDay, inSameDayAs: appState.referenceDate) {
            return appState.referenceDate
        }

        let hour = switch targetContext?.dayPart ?? .morning {
        case .morning: 9
        case .afternoon: 13
        case .evening: 18
        case .night: 21
        }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: targetDay) ?? targetDay
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
                    .font(AppTextStyle.title.font)
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("historyHarness.day")

                Text(spfSummary)
                    .font(AppTextStyle.bodyMedium.font)
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
    let today: Date
    let eligibilityStart: Date
    let monthDays: [Date]
    let monthStats: HistoryMonthStats

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
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(controlFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
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
