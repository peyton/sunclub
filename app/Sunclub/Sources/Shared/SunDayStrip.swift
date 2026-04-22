import SwiftUI

struct SunDayStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selectedDay: Date
    let today: Date
    let recordedDays: Set<Date>
    let currentStreakDays: Set<Date>
    let elevatedUVDays: Set<Date>
    let extrasDays: Set<Date>
    let logDetails: [Date: SunDayDetails]
    let allowsFuture: Bool

    private let calendar = Calendar.current
    private let pastDays = 365
    private let futureDays = 14
    private let chipWidth: CGFloat = 44
    private let chipHeight: CGFloat = 44
    private let columnSpacing: CGFloat = 16
    private let letterRowHeight: CGFloat = 14
    private let pointerRowHeight: CGFloat = 22

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
                .padding(.vertical, 6)
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
                guard canSelect(normalized) else {
                    scrollTargetDay = calendar.startOfDay(for: selectedDay)
                    return
                }
                if selectedDay != normalized {
                    selectedDay = normalized
                }
            }
        }
        .frame(height: letterRowHeight + pointerRowHeight + chipHeight + 22)
        .accessibilityIdentifier("timeline.dayStrip")
    }

    private func dayColumn(for day: Date) -> some View {
        let state = chipState(for: day)
        return Button {
            selectDay(day)
        } label: {
            VStack(spacing: 4) {
                Text(state.weekdayLetter)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(state.isSelected ? AppPalette.ink : AppPalette.softInk)
                    .frame(height: letterRowHeight)

                pointerSlot(for: state)
                    .frame(height: pointerRowHeight)

                chip(for: state)
                    .frame(width: chipWidth, height: chipHeight)
                    .overlay {
                        if state.isCurrentStreak, state.status == .applied {
                            Capsule()
                                .stroke(AppPalette.streakAccent.opacity(0.8), lineWidth: 1.3)
                                .frame(width: chipWidth + 6, height: chipHeight + 6)
                                .allowsHitTesting(false)
                        }
                    }

                footerDot(for: state)
                    .frame(height: 8)
            }
            .frame(width: chipWidth, height: 96)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSelect(day))
        .opacity(state.isFuture && !canSelect(day) ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityHint(accessibilityHint(for: state))
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
        .accessibilityAddTraits(!canSelect(day) ? .isDisabled : [])
        .accessibilityIdentifier("timeline.day.\(Self.dayIdentifierFormatter.string(from: day))")
    }

    @ViewBuilder
    private func pointerSlot(for state: ChipState) -> some View {
        if state.isSelected {
            SelectedDayPointer(letter: state.weekdayLetter)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func chip(for state: ChipState) -> some View {
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

    private func filledChip(for state: ChipState) -> some View {
        Capsule(style: .continuous)
            .fill(filledGradient(for: state))
            .overlay {
                if state.isHighProtection {
                    highProtectionOverlay
                }
            }
            .overlay {
                if state.isReapplyDense {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                        .padding(3)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        state.isSelected ? AppPalette.ink.opacity(0.4) : AppPalette.sun.opacity(0.18),
                        lineWidth: state.isSelected ? 1.6 : 0.5
                    )
            }
            .shadow(
                color: shadowColor(for: state),
                radius: state.isHighProtection ? 7 : (state.isSelected ? 4 : 2),
                x: 0,
                y: 2
            )
    }

    private func filledGradient(for state: ChipState) -> LinearGradient {
        let colors: [Color]
        switch state.protectionTier {
        case .light:
            colors = [AppPalette.warmGlow, AppPalette.sun.opacity(0.85)]
        case .standard:
            colors = [AppPalette.sun, AppPalette.coral.opacity(0.85)]
        case .peak:
            colors = [AppPalette.sun, AppPalette.coral, AppPalette.uvExtreme.opacity(0.55)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private func shadowColor(for state: ChipState) -> Color {
        switch state.protectionTier {
        case .light: return AppPalette.sun.opacity(0.10)
        case .standard: return AppPalette.sun.opacity(0.18)
        case .peak: return AppPalette.coral.opacity(0.28)
        }
    }

    private var highProtectionOverlay: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: chipWidth * 0.55
                )
            )
            .frame(width: chipWidth * 0.75, height: chipWidth * 0.75)
            .allowsHitTesting(false)
    }

    private func outlineChip(for state: ChipState, dashed: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(AppPalette.warmGlow.opacity(0.32))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        AppPalette.sun.opacity(state.isSelected ? 1 : 0.65),
                        style: StrokeStyle(
                            lineWidth: state.isSelected ? 2 : 1.5,
                            dash: dashed ? [3, 3] : []
                        )
                    )
            }
    }

    private func hatchedChip(for state: ChipState) -> some View {
        Capsule(style: .continuous)
            .fill(AppPalette.coral.opacity(0.14))
            .overlay {
                SunDiagonalHatch(color: AppPalette.coral.opacity(0.62))
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
                        state.isSelected
                            ? AppPalette.ink.opacity(0.45)
                            : AppPalette.muted.opacity(0.5),
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
            scrollTargetDay = calendar.startOfDay(for: selectedDay)
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
        let futureEnd = calendar.date(byAdding: .day, value: futureDays, to: todayStart) ?? todayStart
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
        let details = logDetails[dayStart]

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
            spfLevel: details?.spfLevel,
            isHighProtection: details?.isHighProtection ?? false,
            isReapplyDense: details?.isReapplyDense ?? false,
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
            return allowsFuture ? "Views the forecast for this future day." : "Future days are view only."
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

private enum ProtectionTier: Equatable {
    case light
    case standard
    case peak
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
    let spfLevel: Int?
    let isHighProtection: Bool
    let isReapplyDense: Bool
    let weekdayLetter: String

    var protectionTier: ProtectionTier {
        guard let spfLevel else {
            return .standard
        }
        if spfLevel >= 50 {
            return .peak
        }
        if spfLevel < 30 {
            return .light
        }
        return .standard
    }

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
            var parts = ["Logged"]
            if isHighProtection {
                parts.append("high SPF")
            }
            if isReapplyDense {
                parts.append("reapplied")
            }
            if isCurrentStreak {
                parts.append("current streak")
            }
            return parts.joined(separator: " · ")
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
        if isFuture {
            parts.append("future date")
        }
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
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppPalette.onAccent)
                .frame(width: 24, height: 18)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppPalette.ink)
                )

            Triangle()
                .fill(AppPalette.ink)
                .frame(width: 7, height: 4)
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
