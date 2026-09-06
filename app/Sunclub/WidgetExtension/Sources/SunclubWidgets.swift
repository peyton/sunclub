import AppIntents
import SwiftUI
import WidgetKit

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
        completion(SunclubSnapshotEntry(date: Date(), snapshot: context.isPreview ? .previewLogged : store.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SunclubSnapshotEntry>) -> Void) {
        let now = Date()
        let snapshot = store.load()
        var dates = [now]
        if let deadline = snapshot.reapplyDeadline(now: now), deadline > now { dates.append(deadline) }
        if let snooze = snapshot.pendingDepartureSnoozedUntil, snooze > now { dates.append(snooze) }
        if let midnight = Calendar.current.dateInterval(of: .day, for: now)?.end { dates.append(midnight) }
        // Pre-render transitions so a delayed reload cannot leave yesterday's timer visible.
        let entries = dates.sorted().map { SunclubSnapshotEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(snapshot.nextTimelineRefreshDate(after: now))))
    }
}

struct SunclubLogTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SunclubRuntimeConfiguration.widgetKind("SunclubLogTodayWidget"), provider: SunclubSnapshotProvider()) { entry in
            SunclubLogTodayWidgetView(entry: entry)
                .containerBackground(AppColor.surface, for: .widget)
        }
        .configurationDisplayName("Sunscreen")
        .description("Log sunscreen and see when to reapply.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryCircular, .accessoryRectangular])
    }
}

struct SunclubStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SunclubRuntimeConfiguration.widgetKind("SunclubStreakWidget"), provider: SunclubSnapshotProvider()) { entry in
            SunclubHistorySurface(entry: entry, style: .week)
                .containerBackground(AppColor.surface, for: .widget)
        }
        .configurationDisplayName("Logged Days")
        .description("This week's sunscreen logs.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct SunclubStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SunclubRuntimeConfiguration.widgetKind("SunclubStatsWidget"), provider: SunclubSnapshotProvider()) { entry in
            SunclubHistorySurface(entry: entry, style: .totals)
                .containerBackground(AppColor.surface, for: .widget)
        }
        .configurationDisplayName("Stats")
        .description("Weekly and monthly logged days.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}

struct SunclubCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SunclubRuntimeConfiguration.widgetKind("SunclubCalendarWidget"), provider: SunclubSnapshotProvider()) { entry in
            SunclubHistorySurface(entry: entry, style: .calendar)
                .containerBackground(AppColor.surface, for: .widget)
        }
        .configurationDisplayName("History")
        .description("Your sunscreen logs by date.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular])
    }
}

private struct SunclubLoggingControlProvider: ControlValueProvider {
    var previewValue: SunclubApplicationStatus {
        SunclubWidgetSnapshot.previewLogged.applicationStatus()
    }

    func currentValue() async throws -> SunclubApplicationStatus {
        SunclubWidgetSnapshotStore().load().applicationStatus()
    }
}

struct SunclubLogTodayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SunclubRuntimeConfiguration.widgetKind("SunclubLogTodayControl"), provider: SunclubLoggingControlProvider()) { status in
            ControlWidgetButton(action: LogSunscreenWidgetIntent()) {
                Label(status.actionTitle, systemImage: status.symbol)
            }
        }
        .displayName("Log sunscreen")
        .description("Log sunscreen or a reapplication.")
    }
}

struct SunclubSummaryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SunclubRuntimeConfiguration.widgetKind("SunclubSummaryControl")) {
            ControlWidgetButton(action: OpenSunclubRouteIntent(route: SunclubWidgetRoute.summary)) {
                Label("Stats", systemImage: "chart.bar")
            }
        }
        .displayName("Stats")
        .description("Open your sunscreen summary.")
    }
}

struct SunclubHistoryControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SunclubRuntimeConfiguration.widgetKind("SunclubHistoryControl")) {
            ControlWidgetButton(action: OpenSunclubRouteIntent(route: SunclubWidgetRoute.history)) {
                Label("History", systemImage: "calendar")
            }
        }
        .displayName("History")
        .description("Open your sunscreen history.")
    }
}

private struct SunclubLogTodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: SunclubSnapshotEntry

    private var status: SunclubApplicationStatus { entry.snapshot.applicationStatus(now: entry.date) }

    private var pendingID: UUID? {
        guard !status.hasLoggedToday, let departure = entry.snapshot.pendingDepartureDate,
              Calendar.current.isDate(departure, inSameDayAs: entry.date), departure <= entry.date,
              entry.snapshot.pendingDepartureSnoozedUntil.map({ $0 <= entry.date }) ?? true else { return nil }
        return entry.snapshot.pendingDepartureCheckInID
    }

    var body: some View {
        Group {
            if let pendingID {
                pendingCheckIn(id: pendingID)
            } else {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Button(intent: LogSunscreenWidgetIntent()) {
                        VStack(spacing: 2) {
                            Image(systemName: status.symbol)
                            Text(!status.isSetupComplete ? "Open" : (status.hasLoggedToday ? "Reapply" : "Log"))
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(status.actionTitle)
                }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    statusContent
                    Spacer(minLength: 0)
                    Button(intent: LogSunscreenWidgetIntent()) {
                        Image(systemName: status.symbol)
                            .frame(minWidth: 32, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(status.actionTitle)
                }
                .font(.caption)
            default:
                VStack(alignment: .leading, spacing: 12) {
                    Link(destination: SunclubWidgetRoute.today.url) { statusContent }
                        .buttonStyle(.plain)
                    if family != .systemSmall, status.reapplyDeadline != nil, let applied = status.lastAppliedAt {
                        HStack(spacing: 4) {
                            Text("Last applied")
                            Text(applied, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if family == .systemLarge || family == .systemExtraLarge {
                        SunclubRecordedDays(snapshot: entry.snapshot, now: entry.date, month: false)
                    }
                    Button(intent: LogSunscreenWidgetIntent()) {
                        ViewThatFits(in: .horizontal) {
                            if family == .systemSmall {
                                Text(status.hasLoggedToday && status.isSetupComplete ? "Log again" : status.actionTitle)
                                    .fixedSize()
                            } else {
                                Label(status.actionTitle, systemImage: status.symbol)
                                    .fixedSize()
                            }
                            Text(!status.isSetupComplete ? "Open" : (status.hasLoggedToday ? "Again" : "Log"))
                                .fixedSize()
                        }
                        .padding(.horizontal, AppSpacing.xxs)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(renderingMode == .fullColor ? AppColor.primaryActionForeground : .primary)
                        .background {
                            if renderingMode == .fullColor {
                                Capsule().fill(AppColor.primaryAction)
                            }
                        }
                        .overlay {
                            if renderingMode != .fullColor {
                                Capsule().stroke(.primary, lineWidth: 1)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(status.actionTitle)
                }
                .font(.callout)
                .fontDesign(.rounded)
            }
            }
        }
        .widgetURL(SunclubWidgetRoute.today.url)
    }

    @ViewBuilder
    private func pendingCheckIn(id: UUID) -> some View {
        if family == .accessoryCircular {
            Link(destination: SunclubWidgetRoute.departureCheckIn.url) {
                Label("Check in", systemImage: "questionmark.circle")
            }
            .accessibilityLabel("Did you apply sunscreen? Check in")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Did you apply sunscreen?").font(.headline)
                if family != .accessoryRectangular { Text("Unconfirmed").font(.caption).foregroundStyle(.secondary) }
                Link("Already applied", destination: SunclubWidgetRoute.departureCheckIn.url).frame(minHeight: 32)
                if family == .systemMedium || family == .systemLarge || family == .systemExtraLarge {
                    HStack {
                        Button("Remind in 15 min", intent: SnoozeDepartureCheckInIntent(checkInID: id.uuidString))
                        Button("Dismiss", intent: DismissDepartureCheckInIntent(checkInID: id.uuidString))
                    }.font(.caption)
                }
            }.fontDesign(.rounded)
        }
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(status.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !status.isSetupComplete {
                Text("Finish setup").font(.headline)
            } else if status.isReapplyDue {
                Text("Now").font(.title2.bold())
            } else if let deadline = status.reapplyDeadline {
                Text(timerInterval: entry.date...max(entry.date, deadline), countsDown: true)
                    .monospacedDigit()
                    .font(.title2.bold())
            } else if let applied = status.lastAppliedAt {
                Text(applied, style: .time).font(.title2.bold())
            } else if !status.hasLoggedToday {
                Text("Sunscreen").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct SunclubHistorySurface: View {
    enum Style { case week, totals, calendar }
    @Environment(\.widgetFamily) private var family
    let entry: SunclubSnapshotEntry
    let style: Style

    private var weeklyCount: Int { entry.snapshot.currentWeekAppliedValue(now: entry.date) }
    private var monthlyCount: Int { entry.snapshot.monthlyAppliedValue(now: entry.date) }
    private var title: String {
        style == .calendar ? entry.date.formatted(.dateTime.month(.wide)) : "Logged days"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("\(weeklyCount) days logged this week")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack {
                        Image(systemName: "calendar")
                        Text("\(weeklyCount)/7")
                    }
                }
                .accessibilityLabel("\(weeklyCount) days logged this week")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(weeklyCount) days this week").font(.headline)
                    SunclubRecordedDays(snapshot: entry.snapshot, now: entry.date, month: false)
                }
            default:
                VStack(alignment: .leading, spacing: 12) {
                    Text(title).font(.headline)
                    if style == .totals {
                        HStack(alignment: .firstTextBaseline, spacing: 24) {
                            total(weeklyCount, label: "This week")
                            total(monthlyCount, label: "This month")
                        }
                    }
                    SunclubRecordedDays(snapshot: entry.snapshot, now: entry.date, month: style == .calendar)
                    if style == .week {
                        Text("\(weeklyCount) of 7 days").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .fontDesign(.rounded)
            }
        }
        .widgetURL(style == .totals ? SunclubWidgetRoute.summary.url : SunclubWidgetRoute.history.url)
    }

    private func total(_ count: Int, label: String) -> some View {
        VStack(alignment: .leading) {
            Text("\(count)").font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The same dated, non-color-only log marks serve week and month layouts.
private struct SunclubRecordedDays: View {
    let snapshot: SunclubWidgetSnapshot
    let now: Date
    let month: Bool

    var body: some View {
        let calendar = Calendar.current
        let days = month ? snapshot.monthGridDays(now: now) : snapshot.currentWeekDays(now: now)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in
                let applied = snapshot.dayStatus(for: day, now: now) == .applied
                Group {
                    if month {
                        HStack(spacing: 1) {
                            Text(day, format: .dateTime.day())
                            if applied { Image(systemName: "checkmark").font(.caption2) }
                        }
                        .font(.caption2)
                        .frame(minHeight: 14)
                    } else {
                        VStack(spacing: 2) {
                            Text(day, format: .dateTime.weekday(.narrow)).font(.caption2)
                            Image(systemName: applied ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(applied ? .primary : .secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(applied ? "logged" : (calendar.startOfDay(for: day) > calendar.startOfDay(for: now) ? "upcoming" : "not logged"))")
            }
        }
    }
}
private extension SunclubWidgetSnapshot {
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
            todaySPFLevel: 50,
            mostUsedSPF: 50,
            currentUVIndex: 6,
            peakUVIndex: 8,
            peakUVHour: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: today),
            uvValidUntil: Date().addingTimeInterval(2 * 60 * 60),
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
            uvValidUntil: Date().addingTimeInterval(2 * 60 * 60),
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
    SunclubLogTodayWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
}

#Preview(as: .systemLarge) {
    SunclubCalendarWidget()
} timeline: {
    SunclubSnapshotEntry(date: Date(), snapshot: .previewLogged)
}
