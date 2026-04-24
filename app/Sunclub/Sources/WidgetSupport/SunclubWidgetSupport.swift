import Foundation

enum SunclubWidgetDefaults {
    static let appGroupID = SunclubRuntimeConfiguration.appGroupID
    static let snapshotKey = "sunclub.widget.snapshot"
    static let pendingRouteKey = "sunclub.widget.pending-route"
}

enum SunclubWidgetRoute: String, Codable, CaseIterable, Sendable {
    case summary
    case history
    case updateToday
    case accountability

    var appRoute: AppRoute {
        switch self {
        case .summary:
            return .weeklySummary
        case .history:
            return .history
        case .updateToday:
            return .manualLog
        case .accountability:
            return .friends
        }
    }

    var url: URL {
        URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://widget/open/\(rawValue)")!
    }
}

struct SunclubWidgetSnapshot: Codable, Equatable, Sendable {
    let isOnboardingComplete: Bool
    let lastLoggedDay: Date?
    let lastVerifiedAt: Date?
    let lastReappliedAt: Date?
    let recordedDays: [Date]
    let currentStreak: Int
    let longestStreak: Int
    let weeklyAppliedCount: Int
    let monthlyAppliedCount: Int
    let monthlyDayCount: Int
    let todaySPFLevel: Int?
    let mostUsedSPF: Int?
    let currentUVIndex: Int?
    let peakUVIndex: Int?
    let peakUVHour: Date?
    let reapplyReminderEnabled: Bool
    let reapplyIntervalMinutes: Int
    let accountabilitySummary: SunclubAccountabilitySummary

    static let empty = SunclubWidgetSnapshot(
        isOnboardingComplete: false,
        lastLoggedDay: nil,
        lastVerifiedAt: nil,
        lastReappliedAt: nil,
        recordedDays: [],
        currentStreak: 0,
        longestStreak: 0,
        weeklyAppliedCount: 0,
        monthlyAppliedCount: 0,
        monthlyDayCount: 0,
        todaySPFLevel: nil,
        mostUsedSPF: nil,
        currentUVIndex: nil,
        peakUVIndex: nil,
        peakUVHour: nil,
        reapplyReminderEnabled: false,
        reapplyIntervalMinutes: 120,
        accountabilitySummary: .empty
    )

    private enum CodingKeys: String, CodingKey {
        case isOnboardingComplete
        case lastLoggedDay
        case lastVerifiedAt
        case lastReappliedAt
        case recordedDays
        case currentStreak
        case longestStreak
        case weeklyAppliedCount
        case monthlyAppliedCount
        case monthlyDayCount
        case todaySPFLevel
        case mostUsedSPF
        case currentUVIndex
        case peakUVIndex
        case peakUVHour
        case reapplyReminderEnabled
        case reapplyIntervalMinutes
        case accountabilitySummary
    }

    init(
        isOnboardingComplete: Bool,
        lastLoggedDay: Date?,
        lastVerifiedAt: Date?,
        lastReappliedAt: Date?,
        recordedDays: [Date],
        currentStreak: Int,
        longestStreak: Int,
        weeklyAppliedCount: Int,
        monthlyAppliedCount: Int,
        monthlyDayCount: Int,
        todaySPFLevel: Int? = nil,
        mostUsedSPF: Int?,
        currentUVIndex: Int?,
        peakUVIndex: Int?,
        peakUVHour: Date?,
        reapplyReminderEnabled: Bool,
        reapplyIntervalMinutes: Int,
        accountabilitySummary: SunclubAccountabilitySummary = .empty
    ) {
        self.isOnboardingComplete = isOnboardingComplete
        self.lastLoggedDay = lastLoggedDay
        self.lastVerifiedAt = lastVerifiedAt
        self.lastReappliedAt = lastReappliedAt
        self.recordedDays = recordedDays
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.weeklyAppliedCount = weeklyAppliedCount
        self.monthlyAppliedCount = monthlyAppliedCount
        self.monthlyDayCount = monthlyDayCount
        self.todaySPFLevel = todaySPFLevel
        self.mostUsedSPF = mostUsedSPF
        self.currentUVIndex = currentUVIndex
        self.peakUVIndex = peakUVIndex
        self.peakUVHour = peakUVHour
        self.reapplyReminderEnabled = reapplyReminderEnabled
        self.reapplyIntervalMinutes = reapplyIntervalMinutes
        self.accountabilitySummary = accountabilitySummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isOnboardingComplete = try container.decode(Bool.self, forKey: .isOnboardingComplete)
        lastLoggedDay = try container.decodeIfPresent(Date.self, forKey: .lastLoggedDay)
        lastVerifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastVerifiedAt)
        lastReappliedAt = try container.decodeIfPresent(Date.self, forKey: .lastReappliedAt)
        recordedDays = try container.decode([Date].self, forKey: .recordedDays)
        currentStreak = try container.decode(Int.self, forKey: .currentStreak)
        longestStreak = try container.decode(Int.self, forKey: .longestStreak)
        weeklyAppliedCount = try container.decode(Int.self, forKey: .weeklyAppliedCount)
        monthlyAppliedCount = try container.decode(Int.self, forKey: .monthlyAppliedCount)
        monthlyDayCount = try container.decode(Int.self, forKey: .monthlyDayCount)
        todaySPFLevel = try container.decodeIfPresent(Int.self, forKey: .todaySPFLevel)
        mostUsedSPF = try container.decodeIfPresent(Int.self, forKey: .mostUsedSPF)
        currentUVIndex = try container.decodeIfPresent(Int.self, forKey: .currentUVIndex)
        peakUVIndex = try container.decodeIfPresent(Int.self, forKey: .peakUVIndex)
        peakUVHour = try container.decodeIfPresent(Date.self, forKey: .peakUVHour)
        reapplyReminderEnabled = try container.decode(Bool.self, forKey: .reapplyReminderEnabled)
        reapplyIntervalMinutes = try container.decode(Int.self, forKey: .reapplyIntervalMinutes)
        accountabilitySummary = try container.decodeIfPresent(SunclubAccountabilitySummary.self, forKey: .accountabilitySummary) ?? .empty
    }

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

    func currentWeekAppliedValue(now: Date = Date(), calendar: Calendar = Calendar.current) -> Int {
        let appliedDays = recordedDaySet(calendar: calendar)
        return currentWeekDays(now: now, calendar: calendar).filter { day in
            appliedDays.contains(calendar.startOfDay(for: day))
        }.count
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

    func reapplyDeadline(now: Date = Date(), calendar: Calendar = Calendar.current) -> Date? {
        guard reapplyReminderEnabled,
              let baseDate = lastReappliedAt ?? lastVerifiedAt else {
            return nil
        }

        return calendar.date(byAdding: .minute, value: reapplyIntervalMinutes, to: baseDate)
    }

    func nextTimelineRefreshDate(after now: Date = Date(), calendar: Calendar = Calendar.current) -> Date {
        let nextMidnightRefresh = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3_600)

        guard let reapplyDeadline = reapplyDeadline(now: now, calendar: calendar),
              reapplyDeadline > now else {
            return nextMidnightRefresh
        }

        return min(reapplyDeadline, nextMidnightRefresh)
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
        growthSettings: SunclubGrowthSettings = SunclubGrowthSettings(),
        uvReading: UVReading? = nil,
        uvForecast: SunclubUVForecast? = nil,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> SunclubWidgetSnapshot {
        let normalizedRecordedDays = Set(records.map { calendar.startOfDay(for: $0.startOfDay) }).sorted()
        let weeklyAppliedCount = CalendarAnalytics.weeklyReport(records: normalizedRecordedDays, now: now, calendar: calendar).appliedCount
        let currentStreak = CalendarAnalytics.currentStreak(records: normalizedRecordedDays, now: now, calendar: calendar)
        let latestRecord = records.max { lhs, rhs in
            lhs.verifiedAt < rhs.verifiedAt
        }
        let today = calendar.startOfDay(for: now)
        let todayRecord = records.first { record in
            calendar.isDate(record.startOfDay, inSameDayAs: today)
        }

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let effectiveMonthEnd = min(monthEnd, calendar.date(byAdding: .day, value: 1, to: today) ?? monthEnd)
        let monthlyAppliedCount = normalizedRecordedDays.filter { $0 >= monthStart && $0 < effectiveMonthEnd }.count
        let monthlyDayCount = max(calendar.dateComponents([.day], from: monthStart, to: effectiveMonthEnd).day ?? 0, 0)
        let compactUVReading = compactSurfaceReading(from: uvReading, now: now, calendar: calendar)
        let compactUVPeakHour = compactSurfacePeakHour(from: uvForecast, now: now, calendar: calendar)

        return SunclubWidgetSnapshot(
            isOnboardingComplete: settings.hasCompletedOnboarding,
            lastLoggedDay: normalizedRecordedDays.last,
            lastVerifiedAt: latestRecord?.verifiedAt,
            lastReappliedAt: latestRecord?.lastReappliedAt,
            recordedDays: normalizedRecordedDays,
            currentStreak: currentStreak,
            longestStreak: settings.longestStreak,
            weeklyAppliedCount: weeklyAppliedCount,
            monthlyAppliedCount: monthlyAppliedCount,
            monthlyDayCount: monthlyDayCount,
            todaySPFLevel: todayRecord?.spfLevel,
            mostUsedSPF: SunscreenUsageAnalytics.mostUsedSPFInsight(from: records)?.level,
            currentUVIndex: compactUVReading?.index,
            peakUVIndex: compactUVPeakHour?.index,
            peakUVHour: compactUVPeakHour?.date,
            reapplyReminderEnabled: settings.reapplyReminderEnabled,
            reapplyIntervalMinutes: settings.reapplyIntervalMinutes,
            accountabilitySummary: accountabilitySummary(from: growthSettings)
        )
    }

    private static func compactSurfaceReading(
        from reading: UVReading?,
        now: Date,
        calendar: Calendar
    ) -> UVReading? {
        guard let reading else {
            return nil
        }

        guard reading.source == .weatherKit else {
            return reading
        }

        return UVReading(
            index: SunclubUVEstimator.estimatedIndex(at: now, calendar: calendar),
            timestamp: now,
            source: .heuristic
        )
    }

    private static func compactSurfacePeakHour(
        from forecast: SunclubUVForecast?,
        now: Date,
        calendar: Calendar
    ) -> SunclubUVHourForecast? {
        guard let forecast else {
            return nil
        }

        guard forecast.sourceLabel == UVReadingSource.weatherKit.forecastLabel else {
            return forecast.peakHour
        }

        return heuristicPeakHour(now: now, calendar: calendar)
    }

    private static func heuristicPeakHour(now: Date, calendar: Calendar) -> SunclubUVHourForecast? {
        let dayStart = calendar.startOfDay(for: now)
        return (6...18)
            .compactMap { hour in
                calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayStart)
            }
            .map { hourDate in
                SunclubUVHourForecast(
                    date: hourDate,
                    index: SunclubUVEstimator.estimatedIndex(at: hourDate, calendar: calendar),
                    sourceLabel: UVReadingSource.heuristic.hourlySourceLabel
                )
            }
            .max(by: { $0.index < $1.index })
    }

    private static func accountabilitySummary(from settings: SunclubGrowthSettings) -> SunclubAccountabilitySummary {
        let friends = settings.friends.sorted { lhs, rhs in
            if lhs.hasLoggedToday != rhs.hasLoggedToday {
                return !lhs.hasLoggedToday && rhs.hasLoggedToday
            }
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            return lhs.lastSharedAt > rhs.lastSharedAt
        }
        let latestPoke = settings.accountability.pokeHistory.sorted { $0.createdAt > $1.createdAt }.first
        let primaryPokeFriendID: UUID?
        if SunclubRuntimeConfiguration.isPublicAccountabilityTransportEnabled {
            primaryPokeFriendID = friends.first { friend in
                !friend.hasLoggedToday
                    && settings.accountability.connections.contains { connection in
                        connection.friendSnapshotID == friend.id && connection.canDirectPoke
                    }
            }?.id
        } else {
            primaryPokeFriendID = nil
        }
        return SunclubAccountabilitySummary(
            isActive: settings.accountability.isActive,
            friendCount: friends.count,
            loggedCount: friends.filter(\.hasLoggedToday).count,
            openCount: friends.filter { !$0.hasLoggedToday }.count,
            topFriends: Array(friends.prefix(4)),
            latestPoke: latestPoke,
            primaryPokeFriendID: primaryPokeFriendID,
            latestPokeText: accountabilityLatestPokeText(latestPoke)
        )
    }

    private static func accountabilityLatestPokeText(_ poke: SunclubAccountabilityPoke?) -> String {
        guard let poke else { return "" }
        switch (poke.direction, poke.status) {
        case (.sent, .sent):
            return "You poked \(poke.friendName)."
        case (.sent, .failed):
            return "Message \(poke.friendName) if direct poke failed."
        case (.received, .received):
            return "\(poke.friendName) poked you."
        default:
            return ""
        }
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

    func setPendingRoute(_ route: AppRoute?) {
        userDefaults.set(route?.rawValue, forKey: SunclubWidgetDefaults.pendingRouteKey)
    }

    func setPendingRoute(_ route: SunclubWidgetRoute?) {
        setPendingRoute(route?.appRoute)
    }

    func takePendingRoute() -> AppRoute? {
        guard let rawValue = userDefaults.string(forKey: SunclubWidgetDefaults.pendingRouteKey) else {
            return nil
        }

        userDefaults.removeObject(forKey: SunclubWidgetDefaults.pendingRouteKey)
        if let route = AppRoute(rawValue: rawValue) {
            return route
        }

        return SunclubWidgetRoute(rawValue: rawValue)?.appRoute
    }
}
