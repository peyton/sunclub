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
    private let kind = "SunclubLogTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubLogTodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .warm)
                }
        }
        .configurationDisplayName("Log Today")
        .description("Log today or see today at a glance.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct SunclubStreakWidget: Widget {
    private let kind = "SunclubStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubStreakWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .warmStrong)
                }
        }
        .configurationDisplayName("Streak")
        .description("Current streak and recent momentum.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct SunclubStatsWidget: Widget {
    private let kind = "SunclubStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubStatsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .cool)
                }
        }
        .configurationDisplayName("Stats")
        .description("Weekly and monthly habit stats.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}

struct SunclubCalendarWidget: Widget {
    private let kind = "SunclubCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunclubSnapshotProvider()) { entry in
            SunclubCalendarWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    SunclubWidgetBackground(style: .warm)
                }
        }
        .configurationDisplayName("Calendar")
        .description("This month and this week at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}

struct SunclubLogTodayControl: ControlWidget {
    private let kind = "SunclubLogTodayControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: LogSunscreenIntent()) {
                Label("Log Today", systemImage: "sun.max.fill")
            }
        }
        .displayName("Log Today")
        .description("Log today from Control Center.")
    }
}

struct SunclubSummaryControl: ControlWidget {
    private let kind = "SunclubSummaryControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenSunclubRouteIntent(route: .summary)) {
                Label("Summary", systemImage: "flame.fill")
            }
        }
        .displayName("Summary")
        .description("Open the weekly summary.")
    }
}

struct SunclubHistoryControl: ControlWidget {
    private let kind = "SunclubHistoryControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenSunclubRouteIntent(route: .history)) {
                Label("History", systemImage: "calendar")
            }
        }
        .displayName("History")
        .description("Open your calendar history.")
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

private struct SunclubLogSmallView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Sunclub", systemImage: snapshot.hasLoggedToday(now: now) ? "checkmark.circle.fill" : "sun.max.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(snapshot.hasLoggedToday(now: now) ? SunclubWidgetPalette.success : SunclubWidgetPalette.sun)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if !snapshot.isOnboardingComplete {
                Text("Open App")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(SunclubWidgetPalette.ink)
            } else if snapshot.hasLoggedToday(now: now) {
                Text("Logged")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(SunclubWidgetPalette.ink)
                Text("\(snapshot.streakValue(now: now))d streak")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
            } else {
                Text("Log Today")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(SunclubWidgetPalette.ink)
                Text("Today open")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SunclubWidgetPalette.softInk)
            }
        }
        .padding(18)
    }
}

private struct SunclubLogInlineView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        Text(snapshot.isOnboardingComplete ? (snapshot.hasLoggedToday(now: now) ? "Logged \(snapshot.streakValue(now: now))d" : "Log Today") : "Open Sunclub")
    }
}

private struct SunclubLogCircularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        ZStack {
            Circle()
                .fill(SunclubWidgetPalette.warm.opacity(0.85))
            VStack(spacing: 2) {
                Image(systemName: snapshot.hasLoggedToday(now: now) ? "checkmark" : "sun.max.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(snapshot.hasLoggedToday(now: now) ? "\(snapshot.streakValue(now: now))d" : "Log")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(snapshot.hasLoggedToday(now: now) ? SunclubWidgetPalette.success : SunclubWidgetPalette.sun)
        }
    }
}

private struct SunclubLogRectangularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: snapshot.hasLoggedToday(now: now) ? "checkmark.circle.fill" : "sun.max.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(snapshot.hasLoggedToday(now: now) ? SunclubWidgetPalette.success : SunclubWidgetPalette.sun)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.hasLoggedToday(now: now) ? "Logged" : "Log Today")
                    .font(.system(size: 15, weight: .semibold))
                Text(snapshot.hasLoggedToday(now: now) ? "\(snapshot.streakValue(now: now))d streak" : "Today open")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct SunclubStreakSmallView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Streak")
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
            Text("Stats")
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
        Text("\(snapshot.weeklyValue(now: now))/7 • \(snapshot.monthlyPercent(now: now))")
    }
}

private struct SunclubStatsRectangularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        HStack(spacing: 16) {
            SunclubCompactStat(title: "Week", value: "\(snapshot.weeklyValue(now: now))/7")
            SunclubCompactStat(title: "Month", value: snapshot.monthlyPercent(now: now))
            Spacer(minLength: 0)
        }
    }
}

private struct SunclubCalendarMediumView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(now.formatted(.dateTime.month(.wide)))
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
            Text(now.formatted(.dateTime.month(.wide).year()))
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
        Text(snapshot.hasLoggedToday(now: now) ? "Logged today" : "Today open")
    }
}

private struct SunclubCalendarRectangularView: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
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

    static var previewLogged: SunclubWidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records = [0, 1, 2, 3, 5, 7, 8].compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        return SunclubWidgetSnapshot(
            isOnboardingComplete: true,
            lastLoggedDay: today,
            recordedDays: records.sorted(),
            currentStreak: 4,
            longestStreak: 8,
            weeklyAppliedCount: 5,
            monthlyAppliedCount: 8,
            monthlyDayCount: max(calendar.component(.day, from: today), 1),
            mostUsedSPF: 50
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
            recordedDays: records.sorted(),
            currentStreak: 4,
            longestStreak: 9,
            weeklyAppliedCount: 4,
            monthlyAppliedCount: 6,
            monthlyDayCount: max(calendar.component(.day, from: today), 1),
            mostUsedSPF: 30
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
