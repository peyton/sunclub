import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date
    @State private var selectedDay: Date?
    @State private var editorPresentation: HistoryEditorPresentation?

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
                    dismiss()
                })

                monthNavigator

                weekdayHeader

                calendarGrid

                if let selectedDay = selectedDay {
                    dayDetailCard(for: selectedDay)
                }

                statsSection

                Spacer(minLength: 0)
            }
        } footer: {
            historyActionFooter
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
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

    private var calendarGrid: some View {
        let days = appState.monthGrid(for: displayedMonth)
        let recordDates = Set(appState.recordStartsForTesting())

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                let isCurrentMonth = appState.isCurrentMonth(day, month: displayedMonth)
                let dayStart = calendar.startOfDay(for: day)
                let today = calendar.startOfDay(for: Date())
                let hasRecord = recordDates.contains(dayStart)
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

        VStack(alignment: .leading, spacing: 10) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 10) {
                Image(systemName: statusSymbol(for: status))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(statusColor(for: status))

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle(for: status))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("history.statusTitle")

                    if let record {
                        Text("Verified via \(record.method.displayName) at \(record.verifiedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                    } else {
                        Text("No entry for this day yet.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                    }

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

                Spacer()
            }

        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .accessibilityIdentifier("history.dayDetail")
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

    private var statsSection: some View {
        let recordDates = appState.recordStartsForTesting()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
        let today = calendar.startOfDay(for: Date())
        let effectiveEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: today)!)
        let monthRecords = recordDates.filter { $0 >= monthStart && $0 < effectiveEnd }

        let daysInRange: Int = {
            if monthEnd <= today {
                return calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
            } else {
                return calendar.dateComponents([.day], from: monthStart, to: effectiveEnd).day ?? 0
            }
        }()

        let rate = daysInRange > 0 ? Int(Double(monthRecords.count) / Double(daysInRange) * 100) : 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Month Stats")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            HStack(spacing: 20) {
                statBubble(value: "\(monthRecords.count)", label: "Applied")
                statBubble(value: "\(max(daysInRange - monthRecords.count, 0))", label: "Missed")
                statBubble(value: "\(rate)%", label: "Rate")
            }
        }
        .accessibilityIdentifier("history.monthStats")
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
                    appState.deleteRecord(for: day)
                    selectedDay = nil
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
        case .missed: return "Missed"
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
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let existingRecord: DailyRecord?

    @State private var selectedSPF: Int?
    @State private var notes: String

    init(day: Date, existingRecord: DailyRecord?) {
        self.day = day
        self.existingRecord = existingRecord
        _selectedSPF = State(initialValue: existingRecord?.spfLevel)
        _notes = State(initialValue: existingRecord?.notes ?? "")
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: editorTitle, showsBack: true, onBack: {
                    dismiss()
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
                    accessibilityPrefix: "historyEditor"
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
                dismiss()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("historyEditor.save")
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var editorTitle: String {
        existingRecord == nil ? "Backfill Day" : "Edit Entry"
    }

    private var editorMessage: String {
        if existingRecord == nil {
            return "Add a manual log for this day so your history reflects what actually happened."
        }

        return "Update SPF or notes without changing the selected day."
    }

    private var primaryActionTitle: String {
        existingRecord == nil ? "Save Backfill" : "Save Changes"
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

#Preview {
    SunclubPreviewHost {
        HistoryView()
    }
}
