import AppIntents
import SwiftUI
import WidgetKit

private enum SunclubWidgetPalette {
    static let sun = Color(red: 0.980, green: 0.643, blue: 0.012)
    static let ink = Color(red: 0.129, green: 0.114, blue: 0.102)
    static let softInk = Color(red: 0.463, green: 0.404, blue: 0.369)
    static let warm = Color(red: 0.992, green: 0.965, blue: 0.914)
    static let warmStrong = Color(red: 1.000, green: 0.947, blue: 0.760)
    static let cool = Color(red: 0.955, green: 0.973, blue: 1.000)
    static let success = Color(red: 0.212, green: 0.565, blue: 0.341)
    static let muted = Color(red: 0.820, green: 0.789, blue: 0.748)
}

private struct SunclubSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: SunclubWidgetSnapshot
}

private struct SunclubSnapshotProvider: TimelineProvider {
    private let store = SunclubWidgetSnapshotStore()

    func placeholder(in context: Context) -> SunclubSnapshotEntry {
        SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
    }

    func getSnapshot(in context: Context, completion: @escaping (SunclubSnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? .previewLogged : store.load()
        completion(SunclubSnapshotEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunclubSnapshotEntry>) -> Void) {
        let now = Date()
        let entry = SunclubSnapshotEntry(date: now, snapshot: store.load())
        completion(Timeline(entries: [entry], policy: .after(nextRefreshDate(after: now))))
    }

    private func nextRefreshDate(after date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(3_600)
    }
}

struct SunclubLogTodayWidget: Widget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubLogTodayWidget")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubLogTodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .warm)
                }
        }
        .configurationDisplayName("Sunclub Log Today")
        .description("Sunclub quick log and today status.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct SunclubStreakWidget: Widget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubStreakWidget")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubStreakWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .warmStrong)
                }
        }
        .configurationDisplayName("Sunclub Streak")
        .description("Sunclub streak and recent momentum.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct SunclubStatsWidget: Widget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubStatsWidget")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubStatsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .cool)
                }
        }
        .configurationDisplayName("Sunclub Stats")
        .description("Sunclub weekly and monthly habit stats.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}

struct SunclubCalendarWidget: Widget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubCalendarWidget")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubCalendarWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .warm)
                }
        }
        .configurationDisplayName("Sunclub Calendar")
        .description("Sunclub month and week history at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}

struct SunclubAccountabilityWidget: Widget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubAccountabilityWidget")

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubAccountabilityWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .cool)
                }
        }
        .configurationDisplayName("Sunclub Accountability")
        .description("Friend sunscreen accountability and pokes.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct SunclubLogTodayControl: ControlWidget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubLogTodayControl")

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: LogSunscreenIntent()) {
                Label("Log Today", systemImage: "sun.max.fill")
            }
        }
        .displayName("Sunclub Log Today")
        .description("Log today from Sunclub in Control Center.")
    }
}

struct SunclubSummaryControl: ControlWidget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubSummaryControl")

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenSunclubRouteIntent(route: .summary)) {
                Label("Summary", systemImage: "flame.fill")
            }
        }
        .displayName("Sunclub Summary")
        .description("Open the Sunclub weekly summary.")
    }
}

struct SunclubHistoryControl: ControlWidget {
    private let kind = SunclubRuntimeConfiguration.widgetKind("SunclubHistoryControl")

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenSunclubRouteIntent(route: .history)) {
                Label("History", systemImage: "calendar")
            }
        }
        .displayName("Sunclub History")
        .description("Open Sunclub calendar history.")
    }
}

private struct SunclubLogTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SunclubSnapshotEntry

    var body: some View {
        switch family {
        case .systemSmall:
            tapSurface {
                SunclubLogSmallView(snapshot: entry.snapshot, now: entry.date)
            }
        case .systemMedium:
            tapSurface {
                SunclubLogMediumView(snapshot: entry.snapshot, now: entry.date)
            }
        case .systemLarge:
            tapSurface {
                SunclubLogLargeView(snapshot: entry.snapshot, now: entry.date)
            }
        case .systemExtraLarge:
            tapSurface {
                SunclubLogExtraLargeView(snapshot: entry.snapshot, now: entry.date)
            }
        case .accessoryInline:
            tapSurface {
                SunclubLogInlineView(snapshot: entry.snapshot, now: entry.date)
            }
        case .accessoryCircular:
            tapSurface {
                SunclubLogCircularView(snapshot: entry.snapshot, now: entry.date)
            }
        case .accessoryRectangular:
            tapSurface {
                SunclubLogRectangularView(snapshot: entry.snapshot, now: entry.date)
            }
        default:
            SunclubLogRectangularView(snapshot: entry.snapshot, now: entry.date)
        }
    }

    @ViewBuilder
    private func tapSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if entry.snapshot.isOnboardingComplete, !entry.snapshot.hasLoggedToday(now: entry.date) {
            Button(intent: LogSunscreenIntent()) {
                content()
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: loggedRouteURL) {
                content()
            }
        }
    }

    private var loggedRouteURL: URL {
        if entry.snapshot.isOnboardingComplete {
            return SunclubWidgetRoute.updateToday.url
        }

        return SunclubWidgetRoute.summary.url
    }
}

private struct SunclubStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SunclubSnapshotEntry

    var body: some View {
        Link(destination: SunclubWidgetRoute.summary.url) {
            switch family {
            case .systemSmall:
                SunclubStreakSmallView(snapshot: entry.snapshot, now: entry.date)
            case .systemMedium:
                SunclubStreakMediumView(snapshot: entry.snapshot, now: entry.date)
            case .accessoryCircular:
                SunclubStreakCircularView(snapshot: entry.snapshot, now: entry.date)
            case .accessoryRectangular:
                SunclubStreakRectangularView(snapshot: entry.snapshot, now: entry.date)
            default:
                SunclubStreakRectangularView(snapshot: entry.snapshot, now: entry.date)
            }
        }
    }
}

private struct SunclubStatsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SunclubSnapshotEntry

    var body: some View {
        Link(destination: SunclubWidgetRoute.summary.url) {
            switch family {
            case .systemMedium:
                SunclubStatsMediumView(snapshot: entry.snapshot, now: entry.date)
            case .systemLarge:
                SunclubStatsLargeView(snapshot: entry.snapshot, now: entry.date)
            case .accessoryInline:
                SunclubStatsInlineView(snapshot: entry.snapshot, now: entry.date)
            case .accessoryRectangular:
                SunclubStatsRectangularView(snapshot: entry.snapshot, now: entry.date)
            default:
                SunclubStatsRectangularView(snapshot: entry.snapshot, now: entry.date)
            }
        }
    }
}

private struct SunclubCalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SunclubSnapshotEntry

    var body: some View {
        Link(destination: SunclubWidgetRoute.history.url) {
            switch family {
            case .systemMedium:
                SunclubCalendarMediumView(snapshot: entry.snapshot, now: entry.date)
            case .systemLarge:
                SunclubCalendarLargeView(snapshot: entry.snapshot, now: entry.date)
            case .accessoryInline:
                SunclubCalendarInlineView(snapshot: entry.snapshot, now: entry.date)
            case .accessoryRectangular:
                SunclubCalendarRectangularView(snapshot: entry.snapshot, now: entry.date)
            default:
                SunclubCalendarRectangularView(snapshot: entry.snapshot, now: entry.date)
            }
        }
    }
}

private struct SunclubAccountabilityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SunclubSnapshotEntry

    var body: some View {
        Link(destination: actionURL) {
            switch family {
            case .systemSmall:
                SunclubAccountabilitySmallView(snapshot: entry.snapshot)
            case .systemMedium:
                SunclubAccountabilityMediumView(snapshot: entry.snapshot)
            case .systemLarge:
                SunclubAccountabilityLargeView(snapshot: entry.snapshot, maxFriends: 3)
            case .systemExtraLarge:
                SunclubAccountabilityLargeView(snapshot: entry.snapshot, maxFriends: 4)
            case .accessoryInline:
                SunclubAccountabilityInlineView(snapshot: entry.snapshot)
            case .accessoryCircular:
                SunclubAccountabilityCircularView(snapshot: entry.snapshot)
            case .accessoryRectangular:
                SunclubAccountabilityRectangularView(snapshot: entry.snapshot)
            default:
                SunclubAccountabilityRectangularView(snapshot: entry.snapshot)
            }
        }
    }

    private var actionURL: URL {
        SunclubAccountabilityWidgetPresentation.make(
            summary: entry.snapshot.accountabilitySummary,
            family: presentationFamily
        ).actionURL
    }

    private var presentationFamily: SunclubAccountabilityWidgetFamily {
        switch family {
        case .systemSmall:
            return .systemSmall
        case .systemMedium:
            return .systemMedium
        case .systemLarge:
            return .systemLarge
        case .systemExtraLarge:
            return .systemExtraLarge
        case .accessoryInline:
            return .accessoryInline
        case .accessoryCircular:
            return .accessoryCircular
        case .accessoryRectangular:
            return .accessoryRectangular
        default:
            return .accessoryRectangular
        }
    }
}

private struct SunclubAccountabilitySmallView: View {
    let snapshot: SunclubWidgetSnapshot

    var body: some View {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: snapshot.accountabilitySummary,
            family: .systemSmall
        )

        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: presentation.iconName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.sun)

            Spacer(minLength: 0)

            Text(presentation.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(SunclubWidgetPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(presentation.subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)
                .lineLimit(1)

            Text(presentation.actionText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(SunclubWidgetPalette.sun))
        }
        .padding(16)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubAccountabilityMediumView: View {
    let snapshot: SunclubWidgetSnapshot

    var body: some View {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: snapshot.accountabilitySummary,
            family: .systemMedium
        )

        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.sun)

                Text(presentation.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SunclubWidgetPalette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Text(presentation.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 9) {
                SunclubAccountabilityMetric(value: presentation.openCountText, label: "open")
                SunclubAccountabilityMetric(value: presentation.loggedCountText, label: "logged")
                SunclubAccountabilityMetric(value: presentation.friendCountText, label: "friends")
            }
            .frame(width: 82, alignment: .leading)
        }
        .padding(18)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubAccountabilityLargeView: View {
    let snapshot: SunclubWidgetSnapshot
    let maxFriends: Int

    var body: some View {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: snapshot.accountabilitySummary,
            family: maxFriends > 3 ? .systemExtraLarge : .systemLarge
        )

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accountability")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SunclubWidgetPalette.softInk)

                    Text(presentation.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(SunclubWidgetPalette.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: presentation.iconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.sun)
            }

            HStack(spacing: 10) {
                SunclubAccountabilityMetric(value: presentation.openCountText, label: "open")
                SunclubAccountabilityMetric(value: presentation.loggedCountText, label: "logged")
                SunclubAccountabilityMetric(value: presentation.friendCountText, label: "friends")
            }

            VStack(spacing: 8) {
                ForEach(Array(presentation.friends.prefix(maxFriends))) { friend in
                    HStack {
                        Text(friend.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SunclubWidgetPalette.ink)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Text(friend.status)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(friend.status == "Coated" ? SunclubWidgetPalette.success : SunclubWidgetPalette.softInk)

                        Text(friend.streak)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SunclubWidgetPalette.sun)
                    }
                }

                if presentation.friends.isEmpty {
                    Text(presentation.detail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SunclubWidgetPalette.softInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !presentation.latestPokeText.isEmpty {
                Text(presentation.latestPokeText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubAccountabilityInlineView: View {
    let snapshot: SunclubWidgetSnapshot

    var body: some View {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: snapshot.accountabilitySummary,
            family: .accessoryInline
        )
        Label(presentation.inlineText, systemImage: presentation.iconName)
    }
}

private struct SunclubAccountabilityCircularView: View {
    let snapshot: SunclubWidgetSnapshot

    var body: some View {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: snapshot.accountabilitySummary,
            family: .accessoryCircular
        )
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 13, weight: .semibold))
                Text(presentation.circularText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubAccountabilityRectangularView: View {
    let snapshot: SunclubWidgetSnapshot

    var body: some View {
        let presentation = SunclubAccountabilityWidgetPresentation.make(
            summary: snapshot.accountabilitySummary,
            family: .accessoryRectangular
        )
        VStack(alignment: .leading, spacing: 2) {
            Label("Accountability", systemImage: presentation.iconName)
                .font(.system(size: 12, weight: .semibold))
            Text(presentation.inlineText)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)
            Text(presentation.detail)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubAccountabilityMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(SunclubWidgetPalette.ink)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SunclubLogSmallView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemSmall
        )

        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                SunclubLogIconBadge(presentation: presentation, size: 32)
                Spacer(minLength: 0)
                Text(presentation.eyebrow)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
            }

            Spacer(minLength: 0)

            Text(presentation.title)
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(SunclubWidgetPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Text(presentation.subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            SunclubLogActionPill(presentation: presentation, compact: true)
        }
        .padding(16)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubLogMediumView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemMedium
        )

        HStack(alignment: .top, spacing: 14) {
            SunclubLogHeroPanel(presentation: presentation, compact: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(presentation.metrics.prefix(2))) { metric in
                    SunclubLogMetricRow(metric: metric)
                }

                Spacer(minLength: 0)

                SunclubWeekStrip(snapshot: snapshot, now: now, cellSize: 9, spacing: 4)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 132)
        }
        .padding(18)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubLogLargeView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemLarge
        )

        VStack(alignment: .leading, spacing: 14) {
            SunclubLogHeader(presentation: presentation)

            HStack(alignment: .top, spacing: 14) {
                SunclubLogHeroPanel(presentation: presentation, compact: false)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SunclubLogMetricGrid(metrics: Array(presentation.metrics.prefix(4)), columns: 2)
                    .frame(width: 154)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("This week")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
                SunclubWeekStrip(snapshot: snapshot, now: now, cellSize: 13, spacing: 5, showsLabels: true)
            }
        }
        .padding(20)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubLogExtraLargeView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .systemExtraLarge
        )

        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 18) {
                SunclubLogHeader(presentation: presentation)
                SunclubLogHeroPanel(presentation: presentation, compact: false)
                SunclubLogMetricGrid(metrics: presentation.metrics, columns: 2)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 12) {
                Text(now.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)

                SunclubMonthGrid(snapshot: snapshot, now: now, columns: 7, cellSize: 18, spacing: 5)

                SunclubWeekStrip(snapshot: snapshot, now: now, cellSize: 12, spacing: 5, showsLabels: true)
            }
            .frame(width: 250, alignment: .topLeading)
        }
        .padding(22)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubLogInlineView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .accessoryInline
        )

        Text(presentation.inlineText)
    }
}

private struct SunclubLogCircularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .accessoryCircular
        )

        ZStack {
            Circle()
                .fill(SunclubWidgetPalette.warm.opacity(0.85))
            VStack(spacing: 2) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 16, weight: .bold))
                Text(presentation.circularText)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(presentation.accentColor)
        }
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubLogRectangularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        let presentation = SunclubLogTodayWidgetPresentation.make(
            snapshot: snapshot,
            now: now,
            family: .accessoryRectangular
        )

        HStack(spacing: 10) {
            SunclubLogIconBadge(presentation: presentation, size: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.state == .open ? "Log SPF" : presentation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(presentation.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)

            Text(presentation.actionText)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(presentation.accentColor)
        }
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}

private struct SunclubLogHeader: View {
    let presentation: SunclubLogTodayWidgetPresentation

    var body: some View {
        HStack(spacing: 8) {
            SunclubLogIconBadge(presentation: presentation, size: 28)
            Text(presentation.eyebrow)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)
            Spacer(minLength: 0)
            Text(presentation.actionText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(presentation.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(presentation.accentColor.opacity(0.14), in: Capsule())
        }
    }
}

private struct SunclubLogHeroPanel: View {
    let presentation: SunclubLogTodayWidgetPresentation
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 12) {
            SunclubLogIconBadge(presentation: presentation, size: compact ? 40 : 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(.system(size: compact ? 21 : 27, weight: .black, design: .rounded))
                    .foregroundStyle(SunclubWidgetPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(presentation.subtitle)
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(presentation.detail)
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .foregroundStyle(SunclubWidgetPalette.softInk)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            if compact {
                SunclubLogActionPill(presentation: presentation, compact: false)
            }
        }
    }
}

private struct SunclubLogIconBadge: View {
    let presentation: SunclubLogTodayWidgetPresentation
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(8, size * 0.28), style: .continuous)
                .fill(presentation.accentColor.opacity(presentation.state == .logged ? 0.18 : 0.22))
            Image(systemName: presentation.iconName)
                .font(.system(size: max(size * 0.46, 12), weight: .black))
                .foregroundStyle(presentation.accentColor)
        }
        .frame(width: size, height: size)
    }
}

private struct SunclubLogActionPill: View {
    let presentation: SunclubLogTodayWidgetPresentation
    let compact: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: presentation.state == .logged ? "pencil" : "hand.tap.fill")
                .font(.system(size: compact ? 9 : 10, weight: .bold))
            Text(presentation.actionText)
                .font(.system(size: compact ? 10 : 11, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(presentation.accentColor)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 5 : 6)
        .background(presentation.accentColor.opacity(0.14), in: Capsule())
    }
}

private struct SunclubLogMetricRow: View {
    let metric: SunclubLogTodayWidgetMetric

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metric.systemImageName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SunclubWidgetPalette.sun)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(metric.value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SunclubWidgetPalette.ink)
                    .lineLimit(1)
                Text(metric.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
                    .lineLimit(1)
            }
        }
    }
}

private struct SunclubLogMetricGrid: View {
    let metrics: [SunclubLogTodayWidgetMetric]
    let columns: Int

    var body: some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: metric.systemImageName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SunclubWidgetPalette.sun)
                    Text(metric.value)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(SunclubWidgetPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(metric.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(SunclubWidgetPalette.softInk)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)
    }
}

private extension SunclubLogTodayWidgetPresentation {
    var accentColor: Color {
        switch state {
        case .needsSetup:
            return SunclubWidgetPalette.softInk
        case .open:
            return SunclubWidgetPalette.sun
        case .logged:
            return SunclubWidgetPalette.success
        }
    }
}

private struct SunclubStreakSmallView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sunclub Streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)

            Spacer(minLength: 0)

            Text("\(snapshot.streakValue(now: now))d")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(SunclubWidgetPalette.ink)

            Text("Best \(max(snapshot.longestStreak, snapshot.streakValue(now: now)))d")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)
        }
        .padding(18)
    }
}

private struct SunclubStreakMediumView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sunclub Streak")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)

            HStack(alignment: .firstTextBaseline) {
                Text("\(snapshot.streakValue(now: now))d")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(SunclubWidgetPalette.ink)
                Text("Best \(max(snapshot.longestStreak, snapshot.streakValue(now: now)))d")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
                Spacer(minLength: 0)
            }

            SunclubWeekStrip(snapshot: snapshot, now: now)
        }
        .padding(18)
    }
}

private struct SunclubStreakCircularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        ZStack {
            Circle().fill(SunclubWidgetPalette.warmStrong.opacity(0.9))
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("\(snapshot.streakValue(now: now))d")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(SunclubWidgetPalette.ink)
        }
    }
}

private struct SunclubStreakRectangularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sunclub")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(snapshot.streakValue(now: now))d streak")
                    .font(.system(size: 15, weight: .semibold))
                Text("Best \(max(snapshot.longestStreak, snapshot.streakValue(now: now)))d")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            SunclubWeekStrip(snapshot: snapshot, now: now, cellSize: 8, spacing: 3)
                .frame(width: 84)
        }
    }
}

private struct SunclubStatsMediumView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sunclub Stats")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)

            HStack(spacing: 14) {
                SunclubMetricBlock(primary: "\(snapshot.weeklyValue(now: now))/7", secondary: "week")
                SunclubMetricBlock(primary: snapshot.monthlyPercent(now: now), secondary: "month")
            }
        }
        .padding(18)
    }
}

private struct SunclubStatsLargeView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sunclub Stats")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)

            HStack(spacing: 14) {
                SunclubMetricBlock(primary: "\(snapshot.weeklyValue(now: now))/7", secondary: "week")
                SunclubMetricBlock(primary: snapshot.monthlyPercent(now: now), secondary: "month")
                SunclubMetricBlock(primary: "\(max(snapshot.longestStreak, snapshot.streakValue(now: now)))d", secondary: "best")
            }

            if let mostUsedSPF = snapshot.mostUsedSPF {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max")
                        .foregroundStyle(SunclubWidgetPalette.sun)
                    Text("SPF \(mostUsedSPF)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SunclubWidgetPalette.ink)
                }
            }

            SunclubWeekStrip(snapshot: snapshot, now: now)
        }
        .padding(20)
    }
}

private struct SunclubStatsInlineView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        Text("Sunclub \(snapshot.weeklyValue(now: now))/7 • \(snapshot.monthlyPercent(now: now))")
    }
}

private struct SunclubStatsRectangularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sunclub")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                SunclubCompactStat(title: "Week", value: "\(snapshot.weeklyValue(now: now))/7")
                SunclubCompactStat(title: "Month", value: snapshot.monthlyPercent(now: now))
                Spacer(minLength: 0)
            }
        }
    }
}

private struct SunclubCalendarMediumView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sunclub \(now.formatted(.dateTime.month(.wide)))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)

            SunclubMonthGrid(snapshot: snapshot, now: now, columns: 7, cellSize: 18, spacing: 4)
        }
        .padding(18)
    }
}

private struct SunclubCalendarLargeView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sunclub \(now.formatted(.dateTime.month(.wide).year()))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)

            SunclubMonthGrid(snapshot: snapshot, now: now, columns: 7, cellSize: 24, spacing: 6)

            HStack(spacing: 14) {
                Text(snapshot.hasLoggedToday(now: now) ? "Logged" : "Today open")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(snapshot.streakValue(now: now))d streak")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
            }
        }
        .padding(20)
    }
}

private struct SunclubCalendarInlineView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        Text(snapshot.hasLoggedToday(now: now) ? "Sunclub Logged" : "Sunclub Open")
    }
}

private struct SunclubCalendarRectangularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sunclub Week")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            SunclubWeekStrip(snapshot: snapshot, now: now, cellSize: 10, spacing: 4, showsLabels: true)
        }
    }
}

private struct SunclubMetricBlock: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(primary)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(SunclubWidgetPalette.ink)
            Text(secondary)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SunclubWidgetPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SunclubCompactStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
        }
    }
}

private struct SunclubWeekStrip: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date
    var cellSize: CGFloat = 14
    var spacing: CGFloat = 6
    var showsLabels = false

    var body: some View {
        let days = snapshot.currentWeekDays(now: now)

        HStack(spacing: spacing) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: 4) {
                    if showsLabels {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill(for: day))
                        .frame(width: cellSize, height: cellSize)
                        .overlay {
                            if Calendar.current.isDate(day, inSameDayAs: now) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(SunclubWidgetPalette.ink, lineWidth: 1)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func fill(for day: Date) -> Color {
        switch snapshot.dayStatus(for: day, now: now) {
        case .applied:
            return SunclubWidgetPalette.sun
        case .todayPending:
            return SunclubWidgetPalette.warm
        case .missed:
            return SunclubWidgetPalette.muted.opacity(0.5)
        case .future:
            return Color.white.opacity(0.85)
        }
    }
}

private struct SunclubMonthGrid: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date
    let columns: Int
    let cellSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(snapshot.monthGridDays(now: now), id: \.self) { day in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fill(for: day))
                    .frame(height: cellSize)
                    .overlay {
                        if Calendar.current.isDate(day, inSameDayAs: now) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(SunclubWidgetPalette.ink, lineWidth: 1)
                        }
                    }
            }
        }
    }

    private func fill(for day: Date) -> Color {
        switch snapshot.dayStatus(for: day, now: now) {
        case .applied:
            return SunclubWidgetPalette.sun
        case .todayPending:
            return SunclubWidgetPalette.warmStrong
        case .missed:
            return SunclubWidgetPalette.muted.opacity(0.45)
        case .future:
            return Color.white.opacity(0.9)
        }
    }
}

private struct SunclubWidgetBackground: View {
    enum Style {
        case warm
        case warmStrong
        case cool
    }

    let style: Style

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colors: [Color] {
        switch style {
        case .warm:
            return [SunclubWidgetPalette.warm, .white]
        case .warmStrong:
            return [SunclubWidgetPalette.warmStrong, SunclubWidgetPalette.warm]
        case .cool:
            return [SunclubWidgetPalette.cool, .white]
        }
    }
}

private extension SunclubWidgetSnapshot {
    var monthlyPercentFallback: String {
        guard monthlyDayCount > 0 else {
            return "0%"
        }
        return "\(Int((Double(monthlyAppliedCount) / Double(monthlyDayCount)) * 100))%"
    }

    func monthlyPercent(now: Date, calendar: Calendar = Calendar.current) -> String {
        let applied = monthlyAppliedValue(now: now, calendar: calendar)
        let total = monthlyDayValue(now: now, calendar: calendar)
        guard total > 0 else {
            return monthlyPercentFallback
        }
        return "\(Int((Double(applied) / Double(total)) * 100))%"
    }

    var uvSummary: String {
        if let peakUVIndex {
            return "Peak UV \(peakUVIndex)"
        }
        if let currentUVIndex {
            return "UV \(currentUVIndex)"
        }
        return "Today open"
    }

    func reapplyInlineLabel(now: Date) -> String? {
        guard let reapplyDeadline = reapplyDeadline(now: now) else {
            return nil
        }
        return "Reapply \(reapplyDeadline.formatted(date: .omitted, time: .shortened))"
    }

    static var previewLogged: SunclubWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records = [0, 1, 2, 3, 5, 7, 8].compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        return SunclubWidgetSnapshot(
            isOnboardingComplete: true,
            lastLoggedDay: today,
            lastVerifiedAt: calendar.date(byAdding: .hour, value: 9, to: today),
            lastReappliedAt: calendar.date(byAdding: .hour, value: 11, to: today),
            recordedDays: records.sorted(),
            currentStreak: 4,
            longestStreak: 8,
            weeklyAppliedCount: 5,
            monthlyAppliedCount: 8,
            monthlyDayCount: max(calendar.component(.day, from: today), 1),
            mostUsedSPF: 50,
            currentUVIndex: 6,
            peakUVIndex: 8,
            peakUVHour: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today),
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 120
        )
    }

    static var previewOpen: SunclubWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records = [1, 2, 3, 5].compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        return SunclubWidgetSnapshot(
            isOnboardingComplete: true,
            lastLoggedDay: calendar.date(byAdding: .day, value: -1, to: today),
            lastVerifiedAt: calendar.date(byAdding: .day, value: -1, to: today),
            lastReappliedAt: nil,
            recordedDays: records.sorted(),
            currentStreak: 4,
            longestStreak: 9,
            weeklyAppliedCount: 4,
            monthlyAppliedCount: 6,
            monthlyDayCount: max(calendar.component(.day, from: today), 1),
            mostUsedSPF: 30,
            currentUVIndex: 7,
            peakUVIndex: 9,
            peakUVHour: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today),
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )
    }
}

#Preview(as: .systemSmall) {
    SunclubLogTodayWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewOpen)
    SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
}

#Preview(as: .systemMedium) {
    SunclubStreakWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
}

#Preview(as: .systemLarge) {
    SunclubCalendarWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
}

#Preview(as: .accessoryInline) {
    SunclubStatsWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
}

#Preview(as: .accessoryCircular) {
    SunclubStreakWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
}

#Preview(as: .accessoryRectangular) {
    SunclubCalendarWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewOpen)
}
