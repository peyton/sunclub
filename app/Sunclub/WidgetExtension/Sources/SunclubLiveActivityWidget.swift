import ActivityKit
import SwiftUI
import WidgetKit

struct SunclubLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunclubLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text(context.attributes.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current UV \(context.state.currentUVIndex)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Peak UV \(context.state.peakUVIndex)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last applied")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(context.state.lastAppliedLabel)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.2))

                HStack {
                    Label(context.state.countdownLabel, systemImage: "timer")
                    Spacer(minLength: 0)
                    Text(context.state.streakLabel)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            }
            .padding(18)
            .activityBackgroundTint(Color(red: 0.93, green: 0.48, blue: 0.16))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("UV \(context.state.currentUVIndex)", systemImage: "sun.max.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.streakLabel)
                        .font(.system(size: 16, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Reapply by \(context.state.countdownLabel)")
                        Spacer(minLength: 0)
                        Text("Peak \(context.state.peakUVIndex)")
                    }
                    .font(.system(size: 14, weight: .medium))
                }
            } compactLeading: {
                Text("UV\(context.state.currentUVIndex)")
                    .font(.system(size: 12, weight: .bold))
            } compactTrailing: {
                Image(systemName: "timer")
            } minimal: {
                Image(systemName: "sun.max.fill")
            }
            .keylineTint(.white)
        }
    }
}
