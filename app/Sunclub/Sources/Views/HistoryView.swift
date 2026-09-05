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
    @State private var didFailUndo = false
    @State private var isShowingMonthlyInsights = false
    @State private var isCalendarExpanded = false
    @State private var hasInitializedSelection = false
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .caption) private var smallIconSize: CGFloat = 16

    let preselectedDay: Date?
    let showsBackButton: Bool

    private let calendar = Calendar.current

    init(preselectedDay: Date? = nil, showsBackButton: Bool = true) {
        self.preselectedDay = preselectedDay
        self.showsBackButton = showsBackButton
        let initialMonth = preselectedDay ?? Date()
        _displayedMonth = State(initialValue: initialMonth)
        _selectedDay = State(initialValue: preselectedDay)
    }

    var body: some View {
        let presentation = historyPresentation

        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.readable,
            contentFrameAlignment: .center,
            scrollAccessibilityIdentifier: "history.scroll"
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                historyHeader

                if isCalendarExpanded {
                    VStack(spacing: AppSpacing.sm) {
                        monthNavigator
                        calendarMonthCard(presentation: presentation)
                        historyLegend(presentation: presentation)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("history.calendarExpansion")
                } else {
                    weekStrip(presentation: presentation)
                }

                deleteUndoBanner

                deletionErrorBanner

                dayDetailCard(for: selectedDay ?? presentation.today, presentation: presentation)

                weeklySummary(presentation: presentation)

                if isCalendarExpanded {
                    statsSection(stats: presentation.monthStats)
                }

                Spacer(minLength: 0)
            }
        }
        .sunNavigationBarCompatibility()
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
        .onAppear {
            guard !hasInitializedSelection else { return }
            applyPreselectedDay(preselectedDay)
            hasInitializedSelection = true
        }
        .onChange(of: preselectedDay) { _, day in
            applyPreselectedDay(day)
        }
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

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if showsBackButton {
                Button {
                    router.goBack()
                } label: {
                    HStack(spacing: AppSpacing.xxs) {
                        SunIcon.chevronLeft.image.resizable().scaledToFit()
                            .frame(width: smallIconSize, height: smallIconSize)
                            .accessibilityHidden(true)
                        AppText("Back", style: .captionMedium, color: AppColor.accent)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("screen.back")
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    historyHeading
                    Spacer(minLength: 0)
                    calendarDisclosure
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    historyHeading
                    calendarDisclosure
                }
            }
        }
    }

    private var historyHeading: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            AppText("History", style: .largeTitle)
                .accessibilityAddTraits(.isHeader)
            AppText(displayedMonth.formatted(.dateTime.month(.wide).year()), style: .caption, color: AppColor.Text.secondary)
                .accessibilityIdentifier("history.monthTitle")
        }
    }

    private var calendarDisclosure: some View {
        Button {
            withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
                isCalendarExpanded.toggle()
            }
        } label: {
            SunIcon.calendar.image.resizable().scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)
        }
        .sunGlassIconButton(
            legacyStyle: HistoryMonthNavigationButtonStyle(isEnabled: true, cornerRadius: AppRadius.pill)
        )
        .buttonBorderShape(.circle)
        .controlSize(.regular)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(isCalendarExpanded ? "Show week" : "Show calendar")
        .accessibilityValue(isCalendarExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isCalendarExpanded
            ? "Returns to the compact selected week."
            : "Shows the full calendar, month navigation, and monthly patterns.")
        .accessibilityIdentifier("history.calendarToggle")
    }

    @ViewBuilder
    private var deleteUndoBanner: some View {
        if let lastDeletedBatchID,
           let lastDeletedDay,
           appState.canUndoChangeIfCurrent(batchID: lastDeletedBatchID) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Log deleted")
                        .font(AppTextStyle.bodyMedium.font)
                        .foregroundStyle(AppPalette.ink)

                    Text(lastDeletedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(AppTextStyle.captionMedium.font)
                        .foregroundStyle(AppPalette.softInk)
                }

                Button("Undo Delete") {
                    switch appState.undoChangeIfCurrent(batchID: lastDeletedBatchID) {
                    case .success:
                        didFailUndo = false
                        selectedDay = lastDeletedDay
                        displayedMonth = lastDeletedDay
                        self.lastDeletedBatchID = nil
                        self.lastDeletedDay = nil
                    case .failure:
                        didFailUndo = true
                    }
                }
                .font(AppTextStyle.bodyMedium.font)
                .foregroundStyle(AppPalette.ink)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.undoDelete")

                if didFailUndo {
                    AppText("Couldn’t undo. Try again or open Recovery & Changes.", style: .caption)
                        .accessibilityIdentifier("history.undoError")
                    Button("Review Recovery & Changes") {
                        router.push(.recovery)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("history.undoRecovery")
                }
            }
            .padding(14)
            .sunGlassCard(
                cornerRadius: AppRadius.medium,
                fillOpacity: 0.76,
                legacyShadow: nil
            )
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
        PrimaryButton(
            "Try Again",
            systemImage: "arrow.clockwise",
            identifier: "history.deleteRetry",
            usesGlass: false
        ) {
            if deleteRecordAndPreserveSelection(for: day) {
                failedDeletionDay = nil
            }
        }

        SecondaryPillButton("Keep Entry", identifier: "history.deleteCancel", usesGlass: false) {
            failedDeletionDay = nil
            appState.clearLogActionError()
        }
    }

    private func weekStrip(presentation: HistoryPresentation) -> some View {
        let week = weekPresentation(presentation)
        return ScrollViewReader { proxy in
            ViewThatFits(in: .horizontal) {
                weekDays(week.days, presentation: presentation)
                ScrollView(.horizontal, showsIndicators: false) {
                    weekDays(week.days, presentation: presentation)
                }
                .onAppear {
                    proxy.scrollTo(selectedDay ?? presentation.today, anchor: .center)
                }
                .onChange(of: selectedDay) { _, day in
                    proxy.scrollTo(day ?? presentation.today, anchor: .center)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Week containing \((selectedDay ?? presentation.today).formatted(.dateTime.month(.wide).day()))")
        .accessibilityIdentifier("history.weekStrip")
    }

    private func weekDays(_ days: [Date], presentation: HistoryPresentation) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(days, id: \.self) { day in
                let state = dayCellState(for: day, presentation: presentation)
                Button {
                    selectDay(day, state: state, allowsAdjacentMonth: true)
                } label: {
                    VStack(spacing: AppSpacing.xs) {
                        Text(calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: day) - 1])
                            .font(AppTextStyle.caption.font)
                            .foregroundStyle(AppColor.Text.secondary)
                        VStack(spacing: AppSpacing.xxs) {
                            Text("\(calendar.component(.day, from: day))")
                                .font(AppFont.rounded(size: 20, weight: state.isSelected ? .semibold : .medium))
                                .foregroundStyle(state.isFuture ? AppColor.Text.secondary : AppColor.Text.primary)
                            weekDayMarker(state)
                                .frame(width: smallIconSize, height: smallIconSize)
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, AppSpacing.xs)
                        .frame(maxWidth: .infinity)
                        .background {
                            if state.isSelected {
                                Capsule()
                                    .fill(AppColor.surfaceElevated)
                                    .overlay { Capsule().stroke(AppColor.stroke, lineWidth: 1) }
                                    .appShadow(AppShadow.soft)
                            }
                        }
                    }
                    .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 76 : 44, maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(state.isFuture)
                .accessibilityLabel(dayAccessibilityLabel(for: day, state: state))
                .accessibilityHint(dayAccessibilityHint(hasRecord: state.hasRecord, isToday: state.isToday, isFuture: state.isFuture))
                .accessibilityAddTraits(state.isSelected ? .isSelected : [])
                .accessibilityIdentifier(dayAccessibilityIdentifier(for: day))
                .contextMenu { calendarDayContextMenu(for: state, allowsAdjacentMonth: true) }
                .id(day)
            }
        }
    }

    @ViewBuilder
    private func weekDayMarker(_ state: HistoryDayCellState) -> some View {
        switch state.status {
        case .applied:
            SunIcon.check.image.resizable().scaledToFit()
                .foregroundStyle(state.isSelected ? AppColor.accent : AppColor.Text.secondary)
        case .todayPending:
            SunIcon.clock.image.resizable().scaledToFit()
                .foregroundStyle(AppColor.accent)
        case .missed:
            Capsule().fill(AppColor.Text.secondary).frame(width: smallIconSize * 0.6, height: 2)
        case .untracked:
            Circle().stroke(AppColor.Text.secondary, lineWidth: 1).padding(smallIconSize * 0.3)
        case .future:
            Circle().fill(AppColor.muted).padding(smallIconSize * 0.3)
        }
    }

    private func weekPresentation(_ presentation: HistoryPresentation) -> HistoryWeekPresentation {
        HistoryWeekPresentation(
            selectedDay: selectedDay ?? presentation.today,
            recordDays: presentation.recordDateSet,
            today: presentation.today,
            eligibleFrom: presentation.eligibilityStart,
            calendar: calendar
        )
    }

    private func weeklySummary(presentation: HistoryPresentation) -> some View {
        let week = weekPresentation(presentation)
        let isCurrentWeek = week.days.contains(presentation.today)
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            AppText(isCurrentWeek ? "This week" : "Selected week", style: .sectionHeader)
                .accessibilityAddTraits(.isHeader)
            AppCard(padding: AppSpacing.sm, showsShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.sm) {
                        SunIcon.calendar.image.resizable().scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundStyle(AppColor.Text.primary)
                            .accessibilityHidden(true)
                        AppText(
                            week.eligibleDayCount > 0
                                ? "\(week.loggedDayCount) of \(week.eligibleDayCount) days logged"
                                : "No tracked days this week",
                            style: .bodyMedium
                        )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("history.selectedWeekCounts")

                    Divider().overlay(AppColor.stroke)

                    weeklyInsightsButton
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.weekSummary")
    }

    private var weeklyInsightsButton: some View {
        Button {
            router.push(.weeklySummary)
        } label: {
            HStack(spacing: AppSpacing.xxs) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.xxs) {
                        weeklyInsightsLabel
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        weeklyInsightsLabel
                    }
                }
                Spacer(minLength: 0)
                SunIcon.chevronRight.image.resizable().scaledToFit()
                    .frame(width: smallIconSize, height: smallIconSize)
                    .foregroundStyle(AppColor.Text.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Weekly insights")
        .accessibilityValue("Last 7 days")
        .accessibilityHint("Opens your report for the last seven days.")
        .accessibilityIdentifier("home.streakCard")
    }

    @ViewBuilder
    private var weeklyInsightsLabel: some View {
        AppText("Weekly insights", style: .captionMedium, color: AppColor.accent)
        AppText("Last 7 days", style: .caption, color: AppColor.Text.secondary)
    }

    private var monthNavigator: some View {
        SunGlassEffectContainer(spacing: 12) {
            HStack {
                monthNavigationButton(icon: .chevronLeft) {
                    changeMonth(by: -1)
                }
                .accessibilityLabel("Previous month")
                .accessibilityHint("Shows the previous month in history.")
                .accessibilityIdentifier("history.previousMonth")

                Spacer()

                Button("Today", action: jumpToToday)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppColor.accent)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityHint("Returns to the current month and selects today.")
                    .accessibilityIdentifier("history.today")

                Spacer()

                monthNavigationButton(icon: .chevronRight, isEnabled: canGoForward) {
                    changeMonth(by: 1)
                }
                .accessibilityLabel("Next month")
                .accessibilityHint(canGoForward ? "Shows the next month in history." : "The next month is in the future.")
                .accessibilityIdentifier("history.nextMonth")
            }
        }
    }

    private func monthNavigationButton(
        icon: SunIcon,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            icon.image.resizable().scaledToFit()
                .frame(width: smallIconSize, height: smallIconSize)
                .foregroundStyle(isEnabled ? AppPalette.ink : AppPalette.muted)
                .frame(width: 44, height: 44)
        }
        .sunGlassIconButton(legacyStyle: HistoryMonthNavigationButtonStyle(isEnabled: isEnabled))
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
        return (0..<7).map { offset in
            let index = (calendar.firstWeekday - 1 + offset) % 7
            return (visible: visibleSymbols[index], spoken: calendar.standaloneWeekdaySymbols[index])
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
        .accessibilityElement(children: .contain)
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
        ViewThatFits(in: .horizontal) {
            calendarMonthContent(presentation: presentation, allowsMonthSwipe: true)
            ScrollView(.horizontal, showsIndicators: true) {
                calendarMonthContent(presentation: presentation, allowsMonthSwipe: false)
            }
        }
        .padding(AppSpacing.xxs)
        .sunGlassCard(cornerRadius: AppRadius.card)
    }

    private func calendarMonthContent(presentation: HistoryPresentation, allowsMonthSwipe: Bool) -> some View {
        VStack(spacing: AppSpacing.xs) {
            weekdayHeader
            calendarGrid(presentation: presentation, allowsMonthSwipe: allowsMonthSwipe)
                .id(displayedMonth)
        }
        .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 532 : 308)
    }

    private func calendarGrid(presentation: HistoryPresentation, allowsMonthSwipe: Bool) -> some View {
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
            including: allowsMonthSwipe ? .all : .none
        )
        .accessibilityElement(children: .contain)
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
            hasNotes: !SunManualLogInput.notesRemovingCoveredAreas(record?.notes).isEmpty,
            isToday: isToday,
            isFuture: isFuture,
            isSelected: isSelected,
            isCurrentMonth: isCurrentMonth
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
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
        .contextMenu {
            calendarDayContextMenu(for: state)
        }
        .accessibilityAction(named: state.hasRecord ? "Edit log" : "Log sunscreen") {
            guard state.isCurrentMonth, !state.isFuture else { return }
            editorPresentation = HistoryEditorPresentation(day: state.dayStart)
        }
        .accessibilityAction(named: "Delete Entry") {
            guard state.isCurrentMonth, !state.isFuture, state.hasRecord else { return }
            dayPendingDeletion = state.dayStart
        }
    }

    @ViewBuilder
    private func calendarDayContextMenu(for state: HistoryDayCellState, allowsAdjacentMonth: Bool = false) -> some View {
        if !state.isFuture, state.isCurrentMonth || allowsAdjacentMonth {
            if state.hasRecord {
                Button("Edit log") {
                    editorPresentation = HistoryEditorPresentation(day: state.dayStart)
                }

                Button("Delete Entry", role: .destructive) {
                    dayPendingDeletion = state.dayStart
                }
            } else {
                Button("Log sunscreen") {
                    editorPresentation = HistoryEditorPresentation(day: state.dayStart)
                }
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
                        isFuture: state.isFuture
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
                .fill(state.isSelected ? AppColor.accentSoft : Color.clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .stroke(
                    state.isSelected ? AppColor.accent : Color.clear,
                    lineWidth: state.isSelected ? 1.5 : 1
                )
        }
    }

    private func selectDay(_ day: Date, state: HistoryDayCellState, allowsAdjacentMonth: Bool = false) {
        guard (state.isCurrentMonth || allowsAdjacentMonth) && !state.isFuture else { return }

        withAnimation(SunMotion.easeInOut(duration: 0.15, reduceMotion: reduceMotion)) {
            selectedDay = state.dayStart
            if !state.isCurrentMonth {
                displayedMonth = state.dayStart
            }
        }
    }

    private func dayTextColor(isCurrentMonth: Bool, isFuture: Bool) -> Color {
        if !isCurrentMonth { return AppPalette.muted }
        if isFuture { return AppPalette.muted }
        return AppPalette.ink
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
            eligibleFrom: presentation.eligibilityStart,
            calendar: calendar
        )
        let conflict = appState.conflict(for: dayStart)

        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                    selectedDayHeading(day)
                    Spacer(minLength: 0)
                    selectedDayTodayLabel(day)
                }
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    selectedDayHeading(day)
                    selectedDayTodayLabel(day)
                }
            }

            AppCard(padding: AppSpacing.sm, showsShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if let record {
                        dayApplicationRows(record)
                    } else {
                        AppText(statusTitle(for: status), style: .bodyMedium)
                            .accessibilityIdentifier("history.statusTitle")
                    }

                    dayRecordDetails(record)
                    conflictBanner(conflict)

                    if record == nil, status != .future {
                        logButton(for: dayStart)
                    }
                }
            }

            if record != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) { selectedRecordActions(dayStart) }
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) { selectedRecordActions(dayStart) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.dayDetail")
    }

    private func selectedDayHeading(_ day: Date) -> some View {
        AppText(day.formatted(.dateTime.weekday(.wide).month(.wide).day()), style: .bodyMedium)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("history.selectedDate")
    }

    @ViewBuilder
    private func selectedDayTodayLabel(_ day: Date) -> some View {
        if isToday(day) {
            AppText("Today", style: .caption, color: AppColor.accent)
        }
    }

    private func dayApplicationRows(_ record: DailyRecord) -> some View {
        let applications = HistoryApplicationPresentation(
            verifiedAt: record.verifiedAt,
            reapplyCount: record.reapplyCount,
            lastReappliedAt: record.lastReappliedAt
        )
        return VStack(alignment: .leading, spacing: 0) {
            AppText(
                "\(applications.applicationCount) \(applications.applicationCount == 1 ? "application" : "applications")",
                style: .caption,
                color: AppColor.Text.secondary
            )
            .accessibilityLabel("Logged, \(applications.applicationCount) \(applications.applicationCount == 1 ? "application" : "applications")")
            .accessibilityIdentifier("history.statusTitle")

            ForEach(applications.timestamps) { timestamp in
                if timestamp.id != applications.timestamps.first?.id {
                    Divider().overlay(AppColor.stroke)
                }
                applicationRow(timestamp, record: record)
            }

            if applications.untimedReapplicationCount > 0 {
                AppText(
                    "\(applications.untimedReapplicationCount) more \(applications.untimedReapplicationCount == 1 ? "reapplication" : "reapplications") · times not saved",
                    style: .caption,
                    color: AppColor.Text.secondary
                )
                .accessibilityIdentifier("history.earlierReapplications")
            }
        }
    }

    private func applicationRow(_ timestamp: HistoryApplicationPresentation.Timestamp, record: DailyRecord) -> some View {
        HStack(spacing: AppSpacing.sm) {
            SunIcon.check.image.resizable().scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(AppPalette.aloe)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                AppText(timestamp.date.formatted(date: .omitted, time: .shortened), style: .bodyMedium)
                AppText(
                    applicationDetail(timestamp, record: record),
                    style: .caption,
                    color: AppColor.Text.secondary
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.application.\(timestamp.id)")
    }

    private func applicationDetail(_ timestamp: HistoryApplicationPresentation.Timestamp, record: DailyRecord) -> String {
        var parts: [String] = []
        if timestamp.kind == .reapplication {
            parts.append("Reapplied")
        } else {
            parts.append("First application")
        }
        if let spf = record.spfLevel { parts.append("SPF \(spf)") }
        let areas = SunManualLogInput.coveredAreas(in: record.notes)
        let orderedAreas = SunManualLogInput.coveredAreas.filter { areas.contains($0) }
        if !orderedAreas.isEmpty { parts.append(orderedAreas.joined(separator: " & ")) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func selectedRecordActions(_ day: Date) -> some View {
        Button("Edit log") {
            editorPresentation = HistoryEditorPresentation(day: day)
        }
        .accessibilityIdentifier("history.editRecord")
        .font(AppTextStyle.captionMedium.font)
        .foregroundStyle(AppColor.accent)
        .frame(minHeight: 44)
        .buttonStyle(.plain)

        Button("Delete", role: .destructive) {
            dayPendingDeletion = day
        }
        .accessibilityIdentifier("history.deleteRecord")
        .font(AppTextStyle.captionMedium.font)
        .foregroundStyle(AppPalette.warning)
        .frame(minHeight: 44)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dayRecordDetails(_ record: DailyRecord?) -> some View {
        let notes = SunManualLogInput.notesRemovingCoveredAreas(record?.notes)
        if !notes.isEmpty {
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
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("history.conflictBanner")
        }
    }

    private func statsSection(stats: HistoryMonthStats) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            AppText("Month summary", style: .sectionHeader)
                .accessibilityAddTraits(.isHeader)
            AppText(
                "\(stats.appliedCount) of \(stats.totalDays) active days logged · \(stats.rate)",
                style: .caption,
                color: AppColor.Text.secondary
            )
                .accessibilityIdentifier("history.monthSummary")
            if stats.bestStreak > 0 {
                AppText("Longest run: \(stats.bestStreak) days", style: .caption, color: AppColor.Text.secondary)
            }

            if stats.appliedCount > 0 {
                monthlyInsightDisclosure(stats.insights)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.monthStats")
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

    private func logButton(for day: Date) -> some View {
        Button {
            editorPresentation = HistoryEditorPresentation(day: day)
        } label: {
            HStack(spacing: AppSpacing.xxs) {
                SunIcon.plus.image.resizable().scaledToFit()
                    .frame(width: smallIconSize, height: smallIconSize)
                    .accessibilityHidden(true)
                AppText("Log sunscreen", style: .bodyMedium, color: AppColor.primaryActionForeground)
            }
        }
        .buttonStyle(SunPrimaryButtonStyle())
        .accessibilityIdentifier("history.backfillRecord")
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
        if !SunManualLogInput.notesRemovingCoveredAreas(record.notes).isEmpty {
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
            displayedMonth = calendar.startOfDay(for: day)
            lastDeletedDay = calendar.startOfDay(for: day)
            lastDeletedBatchID = receipt.batchID
            failedDeletionDay = nil
            didFailUndo = false
            return true
        case .failure:
            return false
        }
    }

    private func changeMonth(by offset: Int) {
        guard let day = HistoryWeekPresentation.selectionAfterMovingMonth(
            from: displayedMonth,
            by: offset,
            referenceDate: appState.referenceDate,
            calendar: calendar
        ) else { return }

        withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
            displayedMonth = day
            selectedDay = day
            isShowingMonthlyInsights = false
        }
    }

    private func applyPreselectedDay(_ day: Date?) {
        let selection = HistoryWeekPresentation.initialSelection(
            preselectedDay: day,
            referenceDate: appState.referenceDate,
            calendar: calendar
        )
        displayedMonth = selection
        selectedDay = selection
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

        return "Selects this day so you can add a log."
    }

    private func dayAccessibilityIdentifier(for day: Date) -> String {
        "history.day.\(Self.dayIdentifierFormatter.string(from: day))"
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
        .sunGlassCard(
            cornerRadius: AppRadius.button,
            fillOpacity: 0.72,
            legacyStroke: .clear,
            legacyShadow: nil
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
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
    var cornerRadius: CGFloat = AppRadius.small

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(controlFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
