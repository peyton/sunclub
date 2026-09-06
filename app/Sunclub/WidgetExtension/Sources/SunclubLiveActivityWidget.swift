import ActivityKit
import SwiftUI
import WidgetKit

struct SunclubLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunclubLiveActivityAttributes.self) { context in
            SunclubLiveActivityLockScreenView(state: context.state)
                .id(context.isStale)
                .activityBackgroundTint(AppColor.surface)
                .activitySystemActionForegroundColor(AppColor.Text.primary)
                .widgetURL(SunclubWidgetRoute.today.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.statusTitle())
                            .font(.footnote.weight(.medium))
                            .fontDesign(.rounded)
                        SunclubLiveActivityTimerValue(state: context.state, size: 24)
                    }
                    .id(context.isStale)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isReapplyDue() ? "arrow.clockwise" : "timer")
                        .foregroundStyle(AppColor.sun)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.state.hasCurrentApplication() ? context.state.appliedLabel : "Open Sunclub to log today")
                            .font(.footnote)
                            .fontDesign(.rounded)
                            .foregroundStyle(.secondary)
                        SunclubLiveActivityLogButton(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isReapplyDue() ? "arrow.clockwise" : "timer")
                    .foregroundStyle(AppColor.sun)
                    .accessibilityLabel(context.state.statusTitle())
            } compactTrailing: {
                SunclubLiveActivityTimerValue(state: context.state, size: 11, isCompact: true)
                    .id(context.isStale)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: context.state.isReapplyDue() ? "arrow.clockwise" : "timer")
                    .foregroundStyle(AppColor.sun)
                    .accessibilityLabel(context.state.statusTitle())
            }
            .widgetURL(SunclubWidgetRoute.today.url)
            .keylineTint(AppColor.sun)
        }
    }
}

private struct SunclubLiveActivityLockScreenView: View {
    let state: SunclubLiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.statusTitle())
                .font(.headline)
                .fontDesign(.rounded)
                .fixedSize(horizontal: false, vertical: true)
            SunclubLiveActivityTimerValue(state: state, size: 34)
            Text(state.hasCurrentApplication() ? state.appliedLabel : "Open Sunclub to log today")
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(AppColor.Text.secondary)
            SunclubLiveActivityLogButton(state: state)
        }
        .foregroundStyle(AppColor.Text.primary)
        .padding(16)
    }
}

private struct SunclubLiveActivityLogButton: View {
    let state: SunclubLiveActivityAttributes.ContentState

    var body: some View {
        if state.hasCurrentApplication() {
            Button(intent: LogReapplicationLiveActivityIntent()) {
                Label("Log reapplication", systemImage: "arrow.clockwise")
                    .font(.callout.weight(.semibold))
                    .fontDesign(.rounded)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.primaryAction)
            .accessibilityHint("Records another sunscreen application.")
        } else {
            Link("Open Sunclub", destination: SunclubWidgetRoute.today.url)
                .font(.callout.weight(.semibold))
                    .fontDesign(.rounded)
        }
    }
}

private struct SunclubLiveActivityTimerValue: View {
    let state: SunclubLiveActivityAttributes.ContentState
    let isCompact: Bool
    @ScaledMetric private var timerSize: CGFloat

    init(state: SunclubLiveActivityAttributes.ContentState, size: CGFloat, isCompact: Bool = false) {
        self.state = state
        self.isCompact = isCompact
        _timerSize = ScaledMetric(wrappedValue: size, relativeTo: isCompact ? .caption2 : .largeTitle)
    }

    var body: some View {
        let now = Date()
        Group {
            if !state.hasCurrentApplication(now: now) {
                if isCompact {
                    Image(systemName: "sun.max")
                        .accessibilityLabel("Open Sunclub to log today")
                } else {
                    Text("Open Sunclub")
                        .font(.headline)
                }
            } else if state.isReapplyDue(now: now) {
                Text("Due")
                    .font(isCompact ? .caption2.weight(.semibold) : .title2.weight(.semibold))
            } else if let deadline = state.reapplyDeadline {
                Text(timerInterval: now...max(now, deadline), countsDown: true)
                    .font(AppFont.heroMetric(size: isCompact ? 11 : timerSize))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(isCompact ? 0.7 : 1)
            } else {
                Text(state.fallbackTimerText(now: now))
                    .font(isCompact ? .caption2 : .title2)
            }
        }
        .fontDesign(.rounded)
        .fixedSize(horizontal: false, vertical: true)
    }
}
