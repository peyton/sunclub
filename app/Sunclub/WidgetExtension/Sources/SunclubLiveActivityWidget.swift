import ActivityKit
import SwiftUI
import WidgetKit

struct SunclubLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SunclubLiveActivityAttributes.self) { context in
            ZStack {
                Image("WidgetTextureNight")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.58)

                Image("MotifShieldGlow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .opacity(0.18)
                    .offset(x: 124, y: -58)

                VStack(alignment: .leading, spacing: 12) {
                    Text(context.attributes.headline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reapplyText(for: context.state.countdownLabel))
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)

                            Text(uvSummary(current: context.state.currentUVIndex, peak: context.state.peakUVIndex))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(uvTint(for: context.state.currentUVIndex).opacity(0.95))
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Last log")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                            Text("Logged \(context.state.lastAppliedLabel)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(context.state.lastLogDetail)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    Divider()
                        .overlay(.white.opacity(0.2))

                    HStack {
                        Label(reapplyText(for: context.state.countdownLabel), systemImage: "timer")
                        Spacer(minLength: 0)
                        Text("Logged \(context.state.lastAppliedLabel)")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .padding(18)
            }
            .activityBackgroundTint(Color(red: 0.20, green: 0.10, blue: 0.06))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(reapplyText(for: context.state.countdownLabel), systemImage: "timer")
                        .font(.system(size: 16, weight: .bold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Logged \(context.state.lastAppliedLabel)")
                        .font(.system(size: 16, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(uvSummary(current: context.state.currentUVIndex, peak: context.state.peakUVIndex))
                        Spacer(minLength: 0)
                        Text(context.state.lastLogDetail)
                    }
                    .font(.system(size: 14, weight: .medium))
                }
            } compactLeading: {
                Text(compactCountdown(context.state.countdownLabel))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(uvTint(for: context.state.currentUVIndex))
            } compactTrailing: {
                Image(systemName: "timer")
                    .foregroundStyle(uvTint(for: context.state.peakUVIndex))
            } minimal: {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(uvTint(for: context.state.currentUVIndex))
            }
            .keylineTint(uvTint(for: context.state.peakUVIndex))
        }
    }

    private func reapplyText(for countdownLabel: String) -> String {
        countdownLabel == "due" ? "Reapply due" : "Reapply \(countdownLabel)"
    }

    private func compactCountdown(_ countdownLabel: String) -> String {
        countdownLabel.replacingOccurrences(of: "in ", with: "")
    }

    private func uvSummary(current: Int, peak: Int) -> String {
        "UV \(current) \(UVLevel.from(index: current).displayName) · Peak \(peak)"
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
}
