import SwiftUI
import WidgetKit

private enum SunclubWidgetDeepLink {
    static let logTodayURL = URL(string: "sunclub://widget/log-today")!
}

private struct SunclubLogTodayEntry: TimelineEntry {
    let date: Date
}

private struct SunclubLogTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunclubLogTodayEntry {
        SunclubLogTodayEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SunclubLogTodayEntry) -> Void) {
        completion(SunclubLogTodayEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunclubLogTodayEntry>) -> Void) {
        completion(Timeline(entries: [SunclubLogTodayEntry(date: Date())], policy: .never))
    }
}

struct SunclubLogTodayWidget: Widget {
    private let kind = "SunclubLogTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubLogTodayProvider()) { entry in
            SunclubLogTodayWidgetView(entry: entry)
                .widgetURL(SunclubWidgetDeepLink.logTodayURL)
                .containerBackground(for: .widget) {
                    widgetBackground
                }
        }
        .configurationDisplayName("Log Today")
        .description("Log today's sunscreen in one tap from Home Screen or Lock Screen.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }

    private var widgetBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.992, green: 0.965, blue: 0.914),
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SunclubLogTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SunclubLogTodayEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .accessoryRectangular:
            lockScreenView
        default:
            lockScreenView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.980, green: 0.643, blue: 0.012))

                Text("Sunclub")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.220, green: 0.180, blue: 0.120))
            }

            Spacer(minLength: 0)

            Text("Log Today")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(red: 0.129, green: 0.114, blue: 0.102))

            Text("One tap to keep your streak moving.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.463, green: 0.404, blue: 0.369))

            HStack(spacing: 6) {
                Text("Tap to log")
                    .font(.system(size: 13, weight: .semibold))

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.980, green: 0.643, blue: 0.012))
            )
        }
        .padding(18)
    }

    private var lockScreenView: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.980, green: 0.643, blue: 0.012))

            VStack(alignment: .leading, spacing: 2) {
                Text("Log Today")
                    .font(.system(size: 15, weight: .semibold))

                Text("Keep your streak moving")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(red: 0.980, green: 0.643, blue: 0.012))
        }
    }
}

#Preview(as: .systemSmall) {
    SunclubLogTodayWidget()
} timeline: {
    SunclubLogTodayEntry(date: Date())
}

#Preview(as: .accessoryRectangular) {
    SunclubLogTodayWidget()
} timeline: {
    SunclubLogTodayEntry(date: Date())
}
