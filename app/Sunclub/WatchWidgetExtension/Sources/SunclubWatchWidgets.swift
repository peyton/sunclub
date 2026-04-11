import SwiftUI
import WidgetKit

private struct SunclubWatchEntry: TimelineEntry {
    let date: Date
    let snapshot: SunclubWidgetSnapshot
}

private struct SunclubWatchProvider: TimelineProvider {
    private let store = SunclubWidgetSnapshotStore()

    func placeholder(in context: Context) -> SunclubWatchEntry {
        SunclubWatchEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SunclubWatchEntry) -> Void) {
        completion(SunclubWatchEntry(date: Date(), snapshot: store.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunclubWatchEntry>) -> Void) {
        let snapshot = store.load()
        let now = Date()
        let refreshDate = snapshot.reapplyDeadline() ?? Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
        let entry = SunclubWatchEntry(date: now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(max(refreshDate, now.addingTimeInterval(900)))))
    }
}

private struct SunclubWatchStatusComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let entry: SunclubWatchEntry

    private var snapshot: SunclubWidgetSnapshot {
        entry.snapshot
    }

    private var statusURL: URL {
        let action = snapshot.hasLoggedToday() ? "open" : "log"
        return URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://watch/\(action)")!
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                accessoryCircular
            case .accessoryInline:
                accessoryInline
            default:
                accessoryRectangular
            }
        }
        .widgetURL(statusURL)
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.hasLoggedToday() ? "Protected Today" : "Tap to Log")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(snapshot.currentStreak)d streak")
                .font(.headline)
            if let currentUVIndex = snapshot.currentUVIndex {
                Text("UV \(currentUVIndex)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            Circle()
                .fill(snapshot.hasLoggedToday() ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))

            VStack(spacing: 1) {
                Image(systemName: snapshot.hasLoggedToday() ? "checkmark.circle.fill" : "sun.max.fill")
                    .font(.caption.weight(.semibold))
                Text("\(snapshot.currentStreak)")
                    .font(.caption2.weight(.bold))
            }
        }
    }

    private var accessoryInline: some View {
        Text(snapshot.hasLoggedToday() ? "Sunclub protected • \(snapshot.currentStreak)d" : "Sunclub log now • \(snapshot.currentStreak)d")
    }
}

struct SunclubWatchStatusComplication: Widget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubWatchStatusComplication")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubWatchProvider()) { entry in
            SunclubWatchStatusComplicationView(entry: entry)
        }
        .configurationDisplayName("Sunclub Status")
        .description("See today's sunscreen status and your current streak.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct SunclubWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SunclubWatchStatusComplication()
    }
}
