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
                        Text(context.state.hasPendingCheckIn() ? "Unconfirmed" : (context.state.hasCurrentApplication() ? context.state.appliedLabel : "Open Sunclub to log today"))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.statusTitle())
                        .font(.headline)
                        .lineLimit(2)
                    Text(state.hasPendingCheckIn() ? "Unconfirmed" :
                            (state.hasCurrentApplication() ? state.appliedLabel : "Open Sunclub to log today"))
                        .font(.caption)
                        .foregroundStyle(AppColor.Text.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if state.hasCurrentApplication() {
                    SunclubLiveActivityTimerValue(state: state, size: 28)
                        .frame(maxWidth: 140, alignment: .trailing)
                }
            }
            SunclubLiveActivityLogButton(state: state)
        }
        .fontDesign(.rounded)
        .foregroundStyle(AppColor.Text.primary)
        // The system caps Lock Screen activity height; keep larger text legible within that surface.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(12)
    }
}

private struct SunclubLiveActivityLogButton: View {
    let state: SunclubLiveActivityAttributes.ContentState

    var body: some View {
        if state.hasPendingCheckIn(), let checkInID = state.pendingDepartureCheckInID {
            HStack(spacing: 8) {
                Link(destination: SunclubWidgetRoute.departureCheckIn.url) {
                    Text("Already applied").lineLimit(1).minimumScaleFactor(0.75)
                }
                .buttonStyle(SunclubLiveActivityButtonStyle(isPrimary: true))
                .accessibilityHint("Choose when you applied sunscreen.")
                Button(intent: SnoozeDepartureCheckInIntent(checkInID: checkInID.uuidString)) {
                    Text("In 15 min").lineLimit(1).minimumScaleFactor(0.75)
                }
                .buttonStyle(SunclubLiveActivityButtonStyle())
                .accessibilityLabel("Remind me in 15 minutes")
                Button(intent: DismissDepartureCheckInIntent(checkInID: checkInID.uuidString)) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(SunclubLiveActivityButtonStyle())
                .frame(width: 44)
                .accessibilityLabel("Dismiss check-in")
            }
            .font(.callout.weight(.semibold))
            .fontDesign(.rounded)
        } else if state.hasCurrentApplication() {
            Button(intent: LogReapplicationLiveActivityIntent()) {
                Label("Log reapplication", systemImage: "arrow.clockwise")
                    .font(.callout.weight(.semibold))
                    .fontDesign(.rounded)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(SunclubLiveActivityButtonStyle(isPrimary: true))
            .accessibilityHint("Records another sunscreen application.")
        } else {
            Link("Open Sunclub", destination: SunclubWidgetRoute.today.url)
                .font(.callout.weight(.semibold))
                .fontDesign(.rounded)
                .buttonStyle(SunclubLiveActivityButtonStyle())
        }
    }
}

/// An explicit target height avoids the additional vertical padding of bordered button styles.
private struct SunclubLiveActivityButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isPrimary ? AppColor.primaryActionForeground : AppColor.Text.primary)
            .background(isPrimary ? AppColor.primaryAction : AppColor.control,
                        in: RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
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
            if state.hasPendingCheckIn(now: now) {
                if isCompact {
                    Image(systemName: "questionmark.circle")
                        .accessibilityLabel("Sunscreen application unconfirmed")
                } else {
                    Text("Unconfirmed").font(.title2.weight(.semibold))
                }
            } else if !state.hasCurrentApplication(now: now) {
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
                    .minimumScaleFactor(isCompact ? 0.7 : 0.8)
            } else {
                Text(state.fallbackTimerText(now: now))
                    .font(isCompact ? .caption2 : .title2)
            }
        }
        .fontDesign(.rounded)
        .fixedSize(horizontal: false, vertical: true)
    }
}
