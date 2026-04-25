import SwiftUI

struct SunDayStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selectedDay: Date
    let today: Date
    let visibleDays: [Date]
    let recordedDays: Set<Date>
    let currentStreakDays: Set<Date>
    let elevatedUVDays: Set<Date>
    let forecastUVLevels: [Date: UVLevel]
    let extrasDays: Set<Date>
    let logDetails: [Date: SunDayDetails]
    let allowsFuture: Bool

    private let calendar = Calendar.current
    private let columnWidth: CGFloat = 60
    private let chipBaseWidth: CGFloat = 48
    private let chipBaseHeight: CGFloat = 56
    private let currentChipWidth: CGFloat = 50
    private let currentChipHeight: CGFloat = 58
    private let selectedChipWidth: CGFloat = 54
    private let selectedChipHeight: CGFloat = 64
    private let columnSpacing: CGFloat = 8
    private let weekdayRowHeight: CGFloat = 32

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
                max(0, (proxy.size.width - columnWidth) / 2),
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
        .frame(height: weekdayRowHeight + selectedChipHeight + 18)
        .accessibilityIdentifier("timeline.dayStrip")
    }

    private func dayColumn(for day: Date) -> some View {
        let state = chipState(for: day)
        return Button {
            selectDay(day)
        } label: {
            VStack(spacing: 4) {
                weekdayLabel(for: state)

                dayCapsule(for: state)
                    .animation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion), value: state.isSelected)
                    .animation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion), value: state.isToday)
            }
            .frame(width: columnWidth, height: weekdayRowHeight + selectedChipHeight + 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canSelect(day))
        .opacity(state.isFuture && !canSelect(day) ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityHint(accessibilityHint(for: state))
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
        .accessibilityIdentifier("timeline.day.\(Self.dayIdentifierFormatter.string(from: day))")
    }

    @ViewBuilder
    private func weekdayLabel(for state: ChipState) -> some View {
        if state.isSelected {
            VStack(spacing: 1) {
                SunSelectionTriangle()
                    .fill(selectedIndicatorFill)
                    .frame(width: 10, height: 7)
                    .accessibilityHidden(true)

                Text(state.weekdayLetter)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 24, height: 24)
            }
            .frame(width: columnWidth, height: weekdayRowHeight)
        } else {
            VStack(spacing: 1) {
                Color.clear
                    .frame(width: 10, height: 7)

                Text(state.weekdayLetter)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(state.isToday ? AppPalette.ink : AppPalette.softInk)
                    .frame(width: 24, height: 24)
            }
            .frame(width: columnWidth, height: weekdayRowHeight)
        }
    }

    private var selectedIndicatorFill: Color {
        colorScheme == .dark ? AppPalette.white.opacity(0.94) : AppPalette.ink
    }

    private var selectedIndicatorForeground: Color {
        colorScheme == .dark ? AppPalette.onAccent : AppPalette.white
    }

    private func dayCapsule(for state: ChipState) -> some View {
        DayCapsule(
            fill: dayCapsuleFill(for: state),
            stroke: dayCapsuleStroke(for: state),
            isSelected: state.isSelected,
            isFuture: state.status == .future,
            isComplete: state.status == .applied,
            showsSecondaryDot: state.hasSecondaryActivity,
            size: chipWidth(for: state)
        )
    }

    private func dayCapsuleFill(for state: ChipState) -> Color {
        switch state.status {
        case .applied:
            return filledColor(for: state)
        case .todayPending:
            return AppPalette.warmGlow.opacity(0.62)
        case .future:
            return AppPalette.cardFill.opacity(0.40)
        case .missed:
            return AppPalette.muted.opacity(0.10)
        }
    }

    private func dayCapsuleStroke(for state: ChipState) -> Color {
        if state.isSelected {
            return selectedIndicatorFill
        }

        switch state.status {
        case .applied:
            return filledColor(for: state).opacity(0.78)
        case .todayPending:
            return AppPalette.sun.opacity(0.66)
        case .future:
            return AppPalette.muted.opacity(0.26)
        case .missed:
            return AppPalette.hairlineStroke
        }
    }

    private func chipWidth(for state: ChipState) -> CGFloat {
        if state.isSelected {
            return selectedChipWidth
        }
        return state.isToday ? currentChipWidth : chipBaseWidth
    }

    private func chipHeight(for state: ChipState) -> CGFloat {
        if state.isSelected {
            return selectedChipHeight
        }
        return state.isToday ? currentChipHeight : chipBaseHeight
    }

    @ViewBuilder
    private func chip(for state: ChipState) -> some View {
        switch state.visualStyle {
        case .filled:
            filledChip(for: state)
        case .outline(let dashed):
            outlineChip(for: state, dashed: dashed)
        case .forecast:
            forecastChip(for: state)
        case .ghost:
            ghostChip(for: state)
        }
    }

    private func filledChip(for state: ChipState) -> some View {
        Capsule(style: .continuous)
            .fill(filledColor(for: state))
            .overlay {
                if state.isReapplyDense {
                    Capsule(style: .continuous)
                        .strokeBorder(AppPalette.pool.opacity(0.85), lineWidth: 2)
                        .padding(3)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        state.isSelected ? selectedIndicatorFill.opacity(0.85) : AppPalette.hairlineStroke,
                        lineWidth: state.isSelected ? 2 : 0.8
                    )
            }
            .appShadow(state.isSelected ? AppShadow.soft : nil)
    }

    private func filledColor(for state: ChipState) -> Color {
        switch state.protectionTier {
        case .light:
            return AppPalette.warmGlow.opacity(0.92)
        case .standard:
            return AppPalette.sun
        case .peak:
            return AppPalette.aloe
        }
    }

    private func outlineChip(for state: ChipState, dashed: Bool) -> some View {
        Capsule(style: .continuous)
            .fill(state.isSelected ? AppPalette.warmGlow.opacity(0.55) : AppPalette.cardFill.opacity(0.72))
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

    private func forecastChip(for state: ChipState) -> some View {
        let color = uvForecastColor(for: state.forecastUVLevel)
        return Capsule(style: .continuous)
            .fill(color.opacity(state.isSelected ? 0.18 : 0.11))
            .overlay {
                SunDiagonalHatch(color: color.opacity(state.isSelected ? 0.56 : 0.42))
                    .clipShape(Capsule(style: .continuous))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        color.opacity(state.isSelected ? 0.82 : 0.45),
                        lineWidth: state.isSelected ? 1.8 : 1
                    )
            }
    }

    private func uvForecastColor(for level: UVLevel?) -> Color {
        switch level {
        case .low:
            return AppColor.success
        case .moderate:
            return AppColor.accentSoft
        case .high:
            return AppColor.accent
        case .veryHigh:
            return AppColor.warning
        case .extreme:
            return AppPalette.pool
        case .unknown, nil:
            return AppPalette.muted
        }
    }

    private func ghostChip(for state: ChipState) -> some View {
        Capsule(style: .continuous)
            .fill(AppPalette.muted.opacity(state.isFuture ? 0.10 : 0.08))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        state.isSelected
                            ? selectedIndicatorFill.opacity(0.65)
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
                .frame(width: state.isSelected ? 7 : 5, height: state.isSelected ? 7 : 5)
                .animation(SunMotion.easeInOut(duration: 0.2, reduceMotion: reduceMotion), value: state.isSelected)
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
            dayCapsule(for: state)
                .frame(width: selectedChipWidth, height: selectedChipHeight)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text(state.statusLabel)
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer(minLength: 0)

            if state.isSelected {
                Image(systemName: "chevron.right.circle.fill")
                    .font(AppFont.rounded(size: 16))
                    .foregroundStyle(AppPalette.sun)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(state.isSelected ? AppPalette.warmGlow.opacity(0.5) : AppPalette.cardFill.opacity(0.62))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .stroke(AppPalette.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(state.isSelected ? .isSelected : [])
    }

    private func chipState(for day: Date) -> ChipState {
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: today)
        let isToday = dayStart == todayStart
        let isFuture = dayStart > todayStart
        let hasRecord = recordedDays.contains(dayStart)
        let isCurrentStreak = currentStreakDays.contains(dayStart)
        let hasExtras = extrasDays.contains(dayStart)
        let forecastUVLevel = forecastUVLevels[dayStart]
        let isElevatedUV = elevatedUVDays.contains(dayStart) || (forecastUVLevel?.shouldShowBanner ?? false)
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
            forecastUVLevel: forecastUVLevel,
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
    case forecast
    case ghost
}

private enum ProtectionTier: Equatable {
    case light
    case standard
    case peak
}

private struct SunSelectionTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ChipState {
    let day: Date
    let status: DayStatus
    let isToday: Bool
    let isFuture: Bool
    let isSelected: Bool
    let isCurrentStreak: Bool
    let isElevatedUV: Bool
    let forecastUVLevel: UVLevel?
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
            return forecastUVLevel == nil ? .ghost : .forecast
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
            return forecastUVLevel.map { "\($0.displayName) UV forecast" } ?? "Forecast"
        }
    }

    var accessibilityLabel: String {
        let dateLabel = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        var parts = [dateLabel, statusLabel]
        if isFuture {
            parts.append("future date")
        }
        if let forecastUVLevel {
            parts.append("\(forecastUVLevel.displayName) UV expected")
        } else if isElevatedUV {
            parts.append("Elevated UV expected")
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
