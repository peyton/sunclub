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
        let refreshDate = snapshot.reapplyDeadline(now: now).flatMap { deadline in
            deadline > now ? deadline : nil
        } ?? Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
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

    private var hasLoggedToday: Bool {
        snapshot.hasLoggedToday(now: entry.date)
    }

    private var statusURL: URL {
        let action = hasLoggedToday ? "open" : "log"
        return URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://watch/\(action)")!
    }

    private var statusText: String {
        hasLoggedToday ? "Logged" : "Log sunscreen"
    }

    private var secondaryText: String {
        if let reapplyText {
            return reapplyText
        }
        if let uvText {
            return uvText
        }
        return hasLoggedToday ? "Logged today" : "Not logged"
    }

    private var uvText: String? {
        guard let currentUVIndex = snapshot.currentUVIndex else {
            return nil
        }

        return "UV \(currentUVIndex) \(UVLevel.from(index: currentUVIndex).displayName)"
    }

    private var reapplyText: String? {
        guard let deadline = snapshot.reapplyDeadline(now: entry.date) else {
            return nil
        }
        if deadline <= entry.date {
            return "Reapply due"
        }

        return "Reapply in \(durationLabel(until: deadline))"
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
            Text(statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(secondaryText)
                .font(.headline)
            if reapplyText != nil, let uvText {
                Text(uvText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accessoryCircular: some View {
        ZStack {
            Circle()
                .fill(hasLoggedToday ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))

            VStack(spacing: 1) {
                Image(systemName: hasLoggedToday ? "checkmark.circle.fill" : "sun.max.fill")
                    .font(.caption.weight(.semibold))
                Text(snapshot.currentUVIndex.map { "UV\($0)" } ?? (hasLoggedToday ? "OK" : "Log"))
                    .font(.caption2.weight(.bold))
            }
        }
    }

    private var accessoryInline: some View {
        Text("\(statusText) • \(secondaryText)")
    }

    private func durationLabel(until deadline: Date) -> String {
        let minutesUntilDeadline = max(1, Int(ceil(deadline.timeIntervalSince(entry.date) / 60)))
        let hours = minutesUntilDeadline / 60
        let minutes = minutesUntilDeadline % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(minutes)m"
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
