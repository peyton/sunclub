import ActivityKit
import SwiftUI
import WidgetKit

struct SunclubLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunclubLiveActivityAttributes.self) { context in
            SunclubLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(SunclubLiveActivityPalette.surface)
                .activitySystemActionForegroundColor(SunclubLiveActivityPalette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SunclubDynamicIslandTimer(state: context.state)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    SunclubLiveActivityUVPill(state: context.state, colorScheme: .dark)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        SunclubLiveActivityProgressBar(state: context.state, height: 3)

                        Text(context.state.appliedLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.74))
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                let now = Date()
                if context.state.hasFreshUV(now: now) {
                    HStack(spacing: 3) {
                        Image(systemName: "sun.max.fill")
                        Text("\(context.state.currentUVIndex)")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(uvTint(for: context.state.currentUVIndex))
                    .accessibilityLabel(context.state.uvPillLabel(now: now))
                } else {
                    Image(systemName: "sun.haze.fill")
                        .foregroundStyle(.white.opacity(0.7))
                        .accessibilityLabel("UV unavailable")
                }
            } compactTrailing: {
                SunclubCompactTimer(state: context.state)
            } minimal: {
                let now = Date()
                Image(systemName: context.state.hasFreshUV(now: now) ? "sun.max.fill" : "sun.haze.fill")
                    .foregroundStyle(
                        context.state.hasFreshUV(now: now)
                            ? uvTint(for: context.state.currentUVIndex)
                            : .white.opacity(0.7)
                    )
                    .accessibilityLabel(context.state.uvPillLabel(now: now))
            }
            .keylineTint(
                context.state.hasFreshUV()
                    ? uvTint(for: context.state.currentUVIndex)
                    : .white.opacity(0.7)
            )
        }
    }
}

private struct SunclubLiveActivityLockScreenView: View {
    let state: SunclubLiveActivityAttributes.ContentState

    var body: some View {
        let now = Date()

        ZStack {
            LinearGradient(
                colors: [
                    SunclubLiveActivityPalette.surface,
                    SunclubLiveActivityPalette.surfaceDepth
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label(state.statusTitle(now: now), systemImage: "sun.max.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SunclubLiveActivityPalette.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    SunclubLiveActivityUVPill(state: state, colorScheme: .light)
                }

                SunclubLiveActivityTimerValue(state: state, now: now, size: 34)
                    .foregroundStyle(SunclubLiveActivityPalette.ink)

                SunclubLiveActivityProgressBar(state: state, height: 4)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(state.appliedLabel)
                    Spacer(minLength: 8)
                    if let nextReapplyLabel = state.nextReapplyLabel(now: now) {
                        Text(nextReapplyLabel)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SunclubLiveActivityPalette.mutedInk)
                .lineLimit(1)
            }
            .padding(18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary(now: now))
    }
}

private struct SunclubDynamicIslandTimer: View {
    let state: SunclubLiveActivityAttributes.ContentState

    var body: some View {
        let now = Date()

        VStack(alignment: .leading, spacing: 2) {
            Text(state.statusTitle(now: now))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            SunclubLiveActivityTimerValue(state: state, now: now, size: 20)
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary(now: now))
    }
}

private struct SunclubLiveActivityTimerValue: View {
    let state: SunclubLiveActivityAttributes.ContentState
    let now: Date
    let size: CGFloat

    var body: some View {
        Group {
            if state.isReapplyDue(now: now) {
                Text("Now")
            } else if let reapplyDeadline = state.reapplyDeadline {
                Text(reapplyDeadline, style: .timer)
            } else {
                Text(state.fallbackTimerText(now: now))
            }
        }
        .font(.system(size: size, weight: .bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
}

private struct SunclubCompactTimer: View {
    let state: SunclubLiveActivityAttributes.ContentState

    var body: some View {
        let now = Date()

        Group {
            if state.isReapplyDue(now: now) {
                Text("due")
            } else if let reapplyDeadline = state.reapplyDeadline {
                Text(reapplyDeadline, style: .timer)
            } else {
                Text(state.fallbackTimerText(now: now))
            }
        }
        .font(.system(size: 11, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityLabel(state.statusTitle(now: now))
    }
}

private struct SunclubLiveActivityProgressBar: View {
    let state: SunclubLiveActivityAttributes.ContentState
    let height: CGFloat

    var body: some View {
        let now = Date()

        Group {
            if state.isReapplyDue(now: now) {
                ProgressView(value: 1)
            } else if let interval = state.reapplyInterval {
                ProgressView(timerInterval: interval, countsDown: false)
            } else {
                ProgressView(value: 0)
            }
        }
        .progressViewStyle(.linear)
        .tint(SunclubLiveActivityPalette.amber)
        .labelsHidden()
        .frame(height: height)
        .scaleEffect(x: 1, y: max(1, height / 2), anchor: .center)
        .clipShape(Capsule())
    }
}

private struct SunclubLiveActivityUVPill: View {
    enum ColorScheme {
        case light
        case dark
    }

    let state: SunclubLiveActivityAttributes.ContentState
    let colorScheme: ColorScheme

    var body: some View {
        let now = Date()

        Text(state.uvPillLabel(now: now))
            .font(.system(size: colorScheme == .light ? 12 : 11, weight: .bold))
            .foregroundStyle(foregroundColor(now: now))
            .lineLimit(1)
            .padding(.horizontal, colorScheme == .light ? 8 : 7)
            .padding(.vertical, colorScheme == .light ? 5 : 4)
            .background(backgroundColor(now: now), in: Capsule())
            .accessibilityLabel(state.uvPillLabel(now: now))
    }

    private func foregroundColor(now: Date) -> Color {
        guard state.hasFreshUV(now: now) else {
            return colorScheme == .light ? SunclubLiveActivityPalette.mutedInk : .white.opacity(0.75)
        }
        switch colorScheme {
        case .light:
            return SunclubLiveActivityPalette.ink
        case .dark:
            return SunclubLiveActivityPalette.ink
        }
    }

    private func backgroundColor(now: Date) -> Color {
        guard state.hasFreshUV(now: now) else {
            return colorScheme == .light ? .white.opacity(0.55) : .white.opacity(0.18)
        }
        switch colorScheme {
        case .light:
            return SunclubLiveActivityPalette.amber.opacity(0.24)
        case .dark:
            return SunclubLiveActivityPalette.amber
        }
    }
}

private enum SunclubLiveActivityPalette {
    static let surface = Color(red: 1.000, green: 0.956, blue: 0.854)
    static let surfaceDepth = Color(red: 0.965, green: 0.900, blue: 0.760)
    static let ink = Color(red: 0.075, green: 0.110, blue: 0.145)
    static let mutedInk = Color(red: 0.290, green: 0.260, blue: 0.220)
    static let amber = Color(red: 0.965, green: 0.620, blue: 0.120)
}

private func uvTint(for index: Int) -> Color {
    switch index {
    case ..<3:
        return Color(red: 0.365, green: 0.720, blue: 0.510)
    case 3..<6:
        return Color(red: 0.980, green: 0.643, blue: 0.012)
    case 6..<8:
        return Color(red: 0.960, green: 0.365, blue: 0.255)
    default:
        return Color(red: 0.780, green: 0.255, blue: 0.560)
    }
}
