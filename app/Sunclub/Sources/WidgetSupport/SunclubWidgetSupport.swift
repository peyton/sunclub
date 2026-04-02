import Foundation

enum SunclubWidgetDefaults {
    static let appGroupID = "group.app.peyton.sunclub"
    static let snapshotKey = "sunclub.widget.snapshot"
    static let pendingRouteKey = "sunclub.widget.pending-route"
}

enum SunclubWidgetRoute: String, Codable, CaseIterable, Sendable {
    case summary
    case history
    case updateToday

    var appRoute: AppRoute {
        switch self {
        case .summary:
            return .weeklySummary
        case .history:
            return .history
        case .updateToday:
            return .manualLog
        }
    }

    var url: URL {
        URL(string: "sunclub://widget/open/\(rawValue)")!
    }
}

struct SunclubWidgetSnapshot: Codable, Equatable, Sendable {
    let isOnboardingComplete: Bool
    let lastLoggedDay: Date?
    let recordedDays: [Date]
    let currentStreak: Int
    let longestStreak: Int
    let weeklyAppliedCount: Int
    let monthlyAppliedCount: Int
    let monthlyDayCount: Int
    let mostUsedSPF: Int?

    static let empty = SunclubWidgetSnapshot(
        isOnboardingComplete: false,
        lastLoggedDay: nil,
        recordedDays: [],
        currentStreak: 0,
        longestStreak: 0,
        weeklyAppliedCount: 0,
        monthlyAppliedCount: 0,
        monthlyDayCount: 0,
        mostUsedSPF: nil
    )

    func hasLoggedToday(now: Date = Date(), calendar: Calendar = Calendar.current) -> Bool {
        let today = calendar.startOfDay(for: now)
        return recordedDaySet(calendar: calendar).contains(today)
    }

    func streakValue(now: Date = Date(), calendar: Calendar = Calendar.current) -> Int {
        CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar)
    }

    func weeklyValue(now: Date = Date(), calendar: Calendar = Calendar.current) -> Int {
        CalendarAnalytics.weeklyReport(records: recordedDays, now: now, calendar: calendar).appliedCount
    }

    func monthlyAppliedValue(now: Date = Date(), calendar: Calendar = Calendar.current) -> Int {
        let interval = monthInterval(now: now, calendar: calendar)
        return recordedDaySet(calendar: calendar).filter { interval.contains($0) }.count
    }

    func monthlyDayValue(now: Date = Date(), calendar: Calendar = Calendar.current) -> Int {
        let interval = monthInterval(now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        guard interval.start < interval.end else {
            return 0
        }
        return (calendar.dateComponents([.day], from: interval.start, to: min(interval.end, calendar.date(byAdding: .day, value: 1, to: today) ?? interval.end)).day ?? 0)
    }

    func monthGridDays(now: Date = Date(), calendar: Calendar = Calendar.current) -> [Date] {
        CalendarAnalytics.monthGridDays(for: now, calendar: calendar)
    }

    func dayStatus(for date: Date, now: Date = Date(), calendar: Calendar = Calendar.current) -> DayStatus {
        CalendarAnalytics.status(for: date, with: recordedDaySet(calendar: calendar), now: now, calendar: calendar)
    }

    func currentWeekDays(now: Date = Date(), calendar: Calendar = Calendar.current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -delta, to: today) ?? today
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    private func monthInterval(now: Date, calendar: Calendar) -> DateInterval {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return DateInterval(start: now, end: now)
        }
        return DateInterval(start: monthStart, end: monthEnd)
    }

    private func recordedDaySet(calendar: Calendar) -> Set<Date> {
        Set(recordedDays.map { calendar.startOfDay(for: $0) })
    }
}

enum SunclubWidgetSnapshotBuilder {
    static func make(
        settings: Settings,
        records: [DailyRecord],
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> SunclubWidgetSnapshot {
        let normalizedRecordedDays = Set(records.map { calendar.startOfDay(for: $0.startOfDay) }).sorted()
        let weeklyAppliedCount = CalendarAnalytics.weeklyReport(records: normalizedRecordedDays, now: now, calendar: calendar).appliedCount
        let currentStreak = CalendarAnalytics.currentStreak(records: normalizedRecordedDays, now: now, calendar: calendar)

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let today = calendar.startOfDay(for: now)
        let effectiveMonthEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: today) ?? monthEnd)
        let monthlyAppliedCount = normalizedRecordedDays.filter { $0 >= monthStart && $0 < effectiveMonthEnd }.count
        let monthlyDayCount = max(calendar.dateComponents([.day], from: monthStart, to: effectiveMonthEnd).day ?? 0, 0)

        return SunclubWidgetSnapshot(
            isOnboardingComplete: settings.hasCompletedOnboarding,
            lastLoggedDay: normalizedRecordedDays.last,
            recordedDays: normalizedRecordedDays,
            currentStreak: currentStreak,
            longestStreak: settings.longestStreak,
            weeklyAppliedCount: weeklyAppliedCount,
            monthlyAppliedCount: monthlyAppliedCount,
            monthlyDayCount: monthlyDayCount,
            mostUsedSPF: SunscreenUsageAnalytics.mostUsedSPFInsight(from: records)?.level
        )
    }
}

struct SunclubWidgetSnapshotStore {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: SunclubWidgetDefaults.appGroupID)) {
        self.userDefaults = userDefaults ?? .standard
    }

    func load() -> SunclubWidgetSnapshot {
        guard let data = userDefaults.data(forKey: SunclubWidgetDefaults.snapshotKey),
              let snapshot = try? decoder.decode(SunclubWidgetSnapshot.self, from: data) else {
            return .empty
        }

        return snapshot
    }

    func save(_ snapshot: SunclubWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }

        userDefaults.set(data, forKey: SunclubWidgetDefaults.snapshotKey)
    }

    func setPendingRoute(_ route: SunclubWidgetRoute?) {
        userDefaults.set(route?.rawValue, forKey: SunclubWidgetDefaults.pendingRouteKey)
    }

    func takePendingRoute() -> SunclubWidgetRoute? {
        guard let rawValue = userDefaults.string(forKey: SunclubWidgetDefaults.pendingRouteKey),
              let route = SunclubWidgetRoute(rawValue: rawValue) else {
            return nil
        }

        userDefaults.removeObject(forKey: SunclubWidgetDefaults.pendingRouteKey)
        return route
    }
}
