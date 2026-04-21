import SwiftUI

struct SunDayStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selectedDay: Date
    let today: Date
    let recordedDays: Set<Date>
    let currentStreakDays: Set<Date>
    let allowsFuture: Bool

    private let calendar = Calendar.current
    private let pastDays = 365
    private let futureDays = 60
    private let chipWidth: CGFloat = 44
    private let chipHeight: CGFloat = 44
    private let columnSpacing: CGFloat = 8

    @State private var scrollTargetDay: Date?

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibleList
        } else {
            stripScrollView
        }
    }

    private var stripScrollView: some View {
        let days = visibleDays

        return VStack(spacing: 6) {
            pointerHeader

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: columnSpacing) {
                    ForEach(days, id: \.self) { day in
                        dayColumn(for: day)
                            .id(day)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, stripHorizontalInset)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollTargetDay, anchor: .center)
            .frame(height: chipHeight + 26)
            .onAppear {
                scrollTargetDay = calendar.startOfDay(for: selectedDay)
            }
            .onChange(of: selectedDay) { _, newValue in
                let normalized = calendar.startOfDay(for: newValue)
                if scrollTargetDay != normalized {
                    withAnimation(SunMotion.easeInOut(duration: 0.25, reduceMotion: reduceMotion)) {
                        scrollTargetDay = normalized
                    }
                }
            }
            .onChange(of: scrollTargetDay) { _, newValue in
                guard let newValue else {
                    return
                }
                let normalized = calendar.startOfDay(for: newValue)
                if selectedDay != normalized {
                    selectedDay = normalized
                }
            }
            .accessibilityIdentifier("timeline.dayStrip")
        }
    }

    private var pointerHeader: some View {
        HStack {
            Spacer(minLength: 0)
            pointerChip
            Spacer(minLength: 0)
        }
        .frame(height: 20)
    }

    private var pointerChip: some View {
        let letter = selectedDayWeekdayLetter
        return ZStack {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .offset(y: 14)

            Text(letter)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppPalette.onAccent)
                .frame(width: 22, height: 22)
                .background(AppPalette.ink, in: Circle())
        }
        .accessibilityHidden(true)
    }

    private var selectedDayWeekdayLetter: String {
        let symbols = calendar.veryShortWeekdaySymbols
        let weekday = calendar.component(.weekday, from: selectedDay)
        let index = (weekday - 1 + symbols.count) % symbols.count
        return symbols[index]
    }

    private var accessibleList: some View {
        VStack(spacing: 8) {
            ForEach(visibleDays.reversed(), id: \.self) { day in
                Button {
                    selectDay(day)
                } label: {
                    accessibleRow(for: day)
                }
                .buttonStyle(.plain)
                .disabled(!canSelect(day))
            }
        }
    }

    private func accessibleRow(for day: Date) -> some View {
        let state = chipState(for: day)
        return HStack(spacing: 12) {
            Image(systemName: state.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(state.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(state.statusLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer(minLength: 0)

            if state.isSelected {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(AppPalette.sun)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(state.isSelected ? AppPalette.warmGlow.opacity(0.5) : AppPalette.cardFill.opacity(0.62))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppPalette.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
    }

    private func dayColumn(for day: Date) -> some View {
        let state = chipState(for: day)
        return Button {
            selectDay(day)
        } label: {
            VStack(spacing: 6) {
                Text(weekdayLetter(for: day))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(state.weekdayColor)
                    .frame(height: 14)

                chip(for: state)

                dotIndicator(for: state)
                    .frame(height: 6)
            }
            .frame(width: chipWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSelect(day))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityHint(accessibilityHint(for: state))
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
        .accessibilityIdentifier("timeline.day.\(Self.dayIdentifierFormatter.string(from: day))")
    }

    private func chip(for state: ChipState) -> some View {
        ZStack {
            Circle()
                .fill(state.fillColor)
                .frame(width: chipWidth, height: chipHeight)

            Circle()
                .strokeBorder(state.borderColor, lineWidth: state.borderWidth)
                .frame(width: chipWidth, height: chipHeight)

            Image(systemName: state.symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(state.symbolColor)
        }
    }

    @ViewBuilder
    private func dotIndicator(for state: ChipState) -> some View {
        if state.hasSecondaryActivity {
            Circle()
                .fill(AppPalette.pool)
                .frame(width: 5, height: 5)
        } else {
            EmptyView()
        }
    }

    private func weekdayLetter(for day: Date) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let weekday = calendar.component(.weekday, from: day)
        let index = (weekday - 1 + symbols.count) % symbols.count
        return symbols[index]
    }

    private func selectDay(_ day: Date) {
        let normalized = calendar.startOfDay(for: day)
        guard canSelect(normalized) else {
            return
        }
        withAnimation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion)) {
            selectedDay = normalized
        }
    }

    private func canSelect(_ day: Date) -> Bool {
        if allowsFuture {
            return true
        }
        return calendar.startOfDay(for: day) <= calendar.startOfDay(for: today)
    }

    private var stripHorizontalInset: CGFloat {
        max(0, (UIScreen.main.bounds.width - chipWidth) / 2)
    }

    private var visibleDays: [Date] {
        let todayStart = calendar.startOfDay(for: today)
        let pastStart = calendar.date(byAdding: .day, value: -pastDays, to: todayStart) ?? todayStart
        let futureEnd = allowsFuture
            ? (calendar.date(byAdding: .day, value: futureDays, to: todayStart) ?? todayStart)
            : todayStart
        var days: [Date] = []
        var cursor = pastStart
        while cursor <= futureEnd {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? futureEnd.addingTimeInterval(86400)
        }
        return days
    }

    private func chipState(for day: Date) -> ChipState {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: today)
        let isToday = dayStart == todayStart
        let isFuture = dayStart > todayStart
        let hasRecord = recordedDays.contains(dayStart)
        let isCurrentStreak = currentStreakDays.contains(dayStart)
        let isSelected = calendar.isDate(dayStart, inSameDayAs: selectedDay)

        let status: DayStatus
        if hasRecord {
            status = .applied
        } else if isToday {
            status = .todayPending
        } else if isFuture {
            status = .future
        } else {
            status = .missed
        }

        return ChipState(
            day: dayStart,
            status: status,
            isToday: isToday,
            isFuture: isFuture,
            isSelected: isSelected,
            isCurrentStreak: isCurrentStreak,
            hasSecondaryActivity: hasRecord && isCurrentStreak
        )
    }

    private func accessibilityHint(for state: ChipState) -> String {
        if state.isFuture {
            return allowsFuture ? "Views the forecast for this day." : "Future days cannot be viewed."
        }
        if state.status == .applied {
            return "Opens this day's log for edits."
        }
        if state.isToday {
            return "Selects today so you can log sunscreen."
        }
        return "Selects this missed day so you can backfill it."
    }

    private static let dayIdentifierFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct ChipState {
    let day: Date
    let status: DayStatus
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let isCurrentStreak: Bool
    let hasSecondaryActivity: Bool

    var symbol: String {
        switch status {
        case .applied: return "checkmark"
        case .todayPending: return "circle.dashed"
        case .missed: return "xmark"
        case .future: return "circle"
        }
    }

    var fillColor: Color {
        if isSelected {
            switch status {
            case .applied: return AppPalette.sun
            case .todayPending: return AppPalette.warmGlow.opacity(0.9)
            case .missed: return AppPalette.coral.opacity(0.22)
            case .future: return AppPalette.controlFill.opacity(0.85)
            }
        }
        switch status {
        case .applied: return AppPalette.sun.opacity(0.85)
        case .todayPending: return AppPalette.warmGlow.opacity(0.6)
        case .missed: return AppPalette.controlFill.opacity(0.7)
        case .future: return AppPalette.controlFill.opacity(0.55)
        }
    }

    var borderColor: Color {
        if isSelected {
            return AppPalette.ink
        }
        if isCurrentStreak {
            return AppPalette.streakAccent.opacity(0.5)
        }
        return AppPalette.cardStroke
    }

    var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }

    var symbolColor: Color {
        switch status {
        case .applied: return AppPalette.onAccent
        case .todayPending: return AppPalette.ink
        case .missed: return AppPalette.coral
        case .future: return AppPalette.softInk
        }
    }

    var accent: Color {
        switch status {
        case .applied: return AppPalette.sun
        case .todayPending: return AppPalette.warmGlow
        case .missed: return AppPalette.coral
        case .future: return AppPalette.softInk
        }
    }

    var weekdayColor: Color {
        if isSelected {
            return AppPalette.ink
        }
        return AppPalette.softInk
    }

    var statusLabel: String {
        switch status {
        case .applied: return "Logged"
        case .todayPending: return "Pending — today"
        case .missed: return "Not logged"
        case .future: return "Forecast ahead"
        }
    }

    var accessibilityLabel: String {
        let dateLabel = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        var parts = [dateLabel, statusLabel]
        if isCurrentStreak {
            parts.append("part of current streak")
        }
        if isSelected {
            parts.append("selected")
        }
        return parts.joined(separator: ", ")
    }
}
