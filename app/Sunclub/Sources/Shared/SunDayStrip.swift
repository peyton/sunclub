import SwiftUI

enum SunDayLogEmphasis: Equatable {
    case none
    case elevatedUV
    case hasExtras
}

struct SunDayStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selectedDay: Date
    let today: Date
    let recordedDays: Set<Date>
    let currentStreakDays: Set<Date>
    let elevatedUVDays: Set<Date>
    let extrasDays: Set<Date>
    let allowsFuture: Bool

    private let calendar = Calendar.current
    private let pastDays = 365
    private let futureDays = 60
    private let chipWidth: CGFloat = 26
    private let chipHeight: CGFloat = 38
    private let columnSpacing: CGFloat = 14

    @State private var scrollTargetDay: Date?

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibleList
        } else {
            stripScrollView
        }
    }

    private var stripScrollView: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: columnSpacing) {
                    ForEach(visibleDays, id: \.self) { day in
                        dayColumn(for: day)
                            .id(day)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 4)
            }
            .contentMargins(
                .horizontal,
                max(0, (proxy.size.width - chipWidth) / 2),
                for: .scrollContent
            )
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollTargetDay, anchor: .center)
            .scrollClipDisabled()
            .onAppear {
                scrollTargetDay = calendar.startOfDay(for: selectedDay)
            }
            .onChange(of: selectedDay) { _, newValue in
                let normalized = calendar.startOfDay(for: newValue)
                if scrollTargetDay != normalized {
                    withAnimation(SunMotion.easeInOut(duration: 0.3, reduceMotion: reduceMotion)) {
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
        }
        .frame(height: chipHeight + 44)
        .accessibilityIdentifier("timeline.dayStrip")
    }

    private func dayColumn(for day: Date) -> some View {
        let state = chipState(for: day)
        return Button {
            selectDay(day)
        } label: {
            VStack(spacing: 4) {
                header(for: state)

                chip(for: state)

                footerDot(for: state)
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

    @ViewBuilder
    private func header(for state: ChipState) -> some View {
        if state.isSelected {
            SelectedDayPointer(letter: state.weekdayLetter)
        } else {
            Text(state.weekdayLetter)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
                .frame(height: 22)
        }
    }

    @ViewBuilder
    private func chip(for state: ChipState) -> some View {
        Group {
            switch state.visualStyle {
            case .filled:
                filledChip(for: state)
            case .outline(let dashed):
                outlineChip(for: state, dashed: dashed)
            case .hatched:
                hatchedChip(for: state)
            case .ghost:
                ghostChip(for: state)
            }
        }
        .frame(width: chipWidth, height: chipHeight)
        .overlay(alignment: .center) {
            if state.isCurrentStreak, state.status == .applied {
                Capsule()
                    .stroke(AppPalette.streakAccent.opacity(0.7), lineWidth: 1.5)
                    .padding(-3)
                    .allowsHitTesting(false)
            }
        }
    }

    private func filledChip(for state: ChipState) -> some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [AppPalette.sun, AppPalette.coral.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(AppPalette.sun.opacity(state.isSelected ? 1 : 0.2), lineWidth: state.isSelected ? 2 : 0.5)
            }
    }

    private func outlineChip(for state: ChipState, dashed: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(AppPalette.warmGlow.opacity(0.28))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        AppPalette.sun.opacity(state.isSelected ? 1 : 0.6),
                        style: StrokeStyle(
                            lineWidth: state.isSelected ? 2 : 1.4,
                            dash: dashed ? [3, 3] : []
                        )
                    )
            }
    }

    private func hatchedChip(for state: ChipState) -> some View {
        Capsule(style: .continuous)
            .fill(AppPalette.coral.opacity(0.12))
            .overlay {
                SunDiagonalHatch(color: AppPalette.coral.opacity(0.65))
                    .clipShape(Capsule(style: .continuous))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        AppPalette.coral.opacity(state.isSelected ? 0.9 : 0.5),
                        lineWidth: state.isSelected ? 1.8 : 1
                    )
            }
    }

    private func ghostChip(for state: ChipState) -> some View {
        Capsule(style: .continuous)
            .fill(Color.clear)
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        state.isSelected ? AppPalette.ink.opacity(0.55) : AppPalette.muted.opacity(0.55),
                        lineWidth: state.isSelected ? 1.6 : 1
                    )
            }
    }

    @ViewBuilder
    private func footerDot(for state: ChipState) -> some View {
        if state.hasSecondaryActivity {
            Circle()
                .fill(AppPalette.pool)
                .frame(width: 5, height: 5)
        } else {
            Color.clear.frame(width: 5, height: 5)
        }
    }

    private func selectDay(_ day: Date) {
        let normalized = calendar.startOfDay(for: day)
        guard canSelect(normalized) else {
            return
        }
        withAnimation(SunMotion.easeInOut(duration: 0.22, reduceMotion: reduceMotion)) {
            selectedDay = normalized
        }
    }

    private func canSelect(_ day: Date) -> Bool {
        if allowsFuture {
            return true
        }
        return calendar.startOfDay(for: day) <= calendar.startOfDay(for: today)
    }

    private var accessibleList: some View {
        VStack(spacing: 8) {
            ForEach(visibleDays.reversed().prefix(14), id: \.self) { day in
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
            chip(for: state)
                .frame(width: chipWidth, height: chipHeight)

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
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.sun)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
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
        let hasExtras = extrasDays.contains(dayStart)
        let isElevatedUV = elevatedUVDays.contains(dayStart)
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
            isElevatedUV: isElevatedUV,
            hasSecondaryActivity: hasExtras,
            weekdayLetter: weekdayLetter(for: dayStart)
        )
    }

    private func weekdayLetter(for day: Date) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let weekday = calendar.component(.weekday, from: day)
        let index = (weekday - 1 + symbols.count) % symbols.count
        return symbols[index]
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

private enum ChipVisualStyle: Equatable {
    case filled
    case outline(dashed: Bool)
    case hatched
    case ghost
}

private struct ChipState {
    let day: Date
    let status: DayStatus
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let isCurrentStreak: Bool
    let isElevatedUV: Bool
    let hasSecondaryActivity: Bool
    let weekdayLetter: String

    var visualStyle: ChipVisualStyle {
        switch status {
        case .applied:
            return .filled
        case .todayPending:
            return .outline(dashed: true)
        case .future:
            return isElevatedUV ? .hatched : .ghost
        case .missed:
            return .ghost
        }
    }

    var statusLabel: String {
        switch status {
        case .applied:
            return isCurrentStreak ? "Logged — current streak" : "Logged"
        case .todayPending:
            return "Pending — today"
        case .missed:
            return "Not logged"
        case .future:
            return isElevatedUV ? "Elevated UV forecast" : "Forecast"
        }
    }

    var accessibilityLabel: String {
        let dateLabel = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        var parts = [dateLabel, statusLabel]
        if isElevatedUV {
            parts.append("high UV expected")
        }
        if hasSecondaryActivity {
            parts.append("has notes")
        }
        if isSelected {
            parts.append("selected")
        }
        return parts.joined(separator: ", ")
    }
}

private struct SelectedDayPointer: View {
    let letter: String

    var body: some View {
        VStack(spacing: 0) {
            Text(letter)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppPalette.onAccent)
                .frame(width: 20, height: 18)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppPalette.ink)
                )

            Triangle()
                .fill(AppPalette.ink)
                .frame(width: 6, height: 4)
        }
        .accessibilityHidden(true)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct SunDiagonalHatch: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 4
            let diagonal = size.width + size.height
            var offset: CGFloat = -size.height
            while offset < diagonal {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(color), lineWidth: 1.5)
                offset += step
            }
        }
    }
}
