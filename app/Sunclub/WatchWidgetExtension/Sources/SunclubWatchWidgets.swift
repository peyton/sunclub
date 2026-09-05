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
        let refreshDate = snapshot.nextTimelineRefreshDate(after: now)
        let entry = SunclubWatchEntry(date: now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

private struct SunclubWatchStatusComplicationView: View {
    @Environment(\.widgetFamily) private var family

    let entry: SunclubWatchEntry

    private var snapshot: SunclubWidgetSnapshot {
        entry.snapshot
    }

    private var status: SunclubApplicationStatus {
        snapshot.applicationStatus(now: entry.date)
    }

    private var statusURL: URL {
        let action = status.isSetupComplete && (!status.hasLoggedToday || status.isReapplyDue) ? "log" : "open"
        return URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://watch/\(action)")!
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: status.symbol)
                        .accessibilityHidden(true)
                    statusValue
                        .font(AppFont.rounded(size: 10, weight: .semibold))
                }
            case .accessoryInline:
                if status.isReapplyDue {
                    Text("Reapply due")
                } else if let lastAppliedAt = status.lastAppliedAt {
                    Text("Applied \(lastAppliedAt, style: .time)")
                } else {
                    Text(status.actionTitle)
                }
            default:
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.title)
                        .font(AppFont.rounded(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    statusValue
                        .font(AppFont.rounded(size: 17, weight: .semibold))
                    if status.reapplyDeadline != nil, let lastAppliedAt = status.lastAppliedAt {
                        Text("Applied \(lastAppliedAt, style: .time)")
                            .font(AppFont.rounded(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .widgetURL(statusURL)
        .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder
    private var statusValue: some View {
        if !status.isSetupComplete {
            Text("Open")
        } else if status.isReapplyDue {
            Text("Due")
        } else if let deadline = status.reapplyDeadline {
            Text(timerInterval: entry.date...max(entry.date, deadline), countsDown: true)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else if let lastAppliedAt = status.lastAppliedAt {
            Text(lastAppliedAt, style: .time)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else {
            Text("Log")
        }
    }
}

struct SunclubWatchStatusComplication: Widget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubWatchStatusComplication")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubWatchProvider()) { entry in
            SunclubWatchStatusComplicationView(entry: entry)
        }
        .configurationDisplayName("Sunclub Status")
        .description("See today's sunscreen status and reapply timing.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct SunclubWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SunclubWatchStatusComplication()
    }
}
