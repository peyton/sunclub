import Foundation

enum DayStatus: Equatable {
    case applied
    case todayPending
    case missed
    case untracked
    case future
}

struct WeeklyReport: Equatable {
    let startDate: Date
    let endDate: Date
    let appliedCount: Int
    let totalDays: Int
    let missedDays: [String]
    let streak: Int

    var missedCount: Int { max(totalDays - appliedCount, 0) }
    var appliedSummaryText: String { "\(appliedCount) / \(totalDays)" }
}

struct RoutineProgressInsights: Equatable {
    let startDate: Date
    let endDate: Date
    let loggedCount: Int
    let eligibleDayCount: Int
    let consistencyPercent: Int
    let typicalApplicationMinute: Int?
    let highUVLoggedCount: Int?
    let highUVEligibleDayCount: Int?
    let nextStep: String

    var consistencyDetail: String {
        "\(loggedCount) of \(eligibleDayCount) active days logged"
    }

    var highUVRateText: String? {
        guard let highUVLoggedCount, let highUVEligibleDayCount, highUVEligibleDayCount > 0 else {
            return nil
        }
        return "\(Int((Double(highUVLoggedCount) / Double(highUVEligibleDayCount) * 100).rounded()))%"
    }

    var highUVDetail: String? {
        guard let highUVLoggedCount, let highUVEligibleDayCount, highUVEligibleDayCount > 0 else {
            return nil
        }
        return "\(highUVLoggedCount) of \(highUVEligibleDayCount) forecast days at UV 3 or higher"
    }

    func typicalApplicationTimeText(calendar: Calendar = .current) -> String? {
        guard let typicalApplicationMinute,
              let date = calendar.date(
                  from: DateComponents(
                      calendar: calendar,
                      year: 2001,
                      month: 1,
                      day: 1,
                      hour: typicalApplicationMinute / 60,
                      minute: typicalApplicationMinute % 60
                  )
              ) else {
            return nil
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

enum CalendarAnalytics {
    private static func normalizedDays(_ dates: [Date], calendar: Calendar) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    static func monthGridDays(for month: Date, calendar: Calendar = Calendar.current) -> [Date] {
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let days = range.count
        let startDate = calendar.date(byAdding: .day, value: -leading, to: start) ?? start

        let totalCells = Int(ceil(Double(leading + days) / 7.0) * 7)
        return (0..<totalCells).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate)
        }
    }

    static func eligibilityStart(
        records: [Date],
        onboardingCompletedAt: Date? = nil,
        now: Date,
        calendar: Calendar = Calendar.current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        let firstRecord = normalizedDays(records, calendar: calendar).min()
        let onboardingDay = onboardingCompletedAt.map { calendar.startOfDay(for: $0) }
        let candidates = [firstRecord, onboardingDay].compactMap { $0 }
        return min(candidates.min() ?? today, today)
    }

    static func status(
        for date: Date,
        with records: Set<Date>,
        now: Date,
        eligibleFrom: Date? = nil,
        calendar: Calendar = Calendar.current
    ) -> DayStatus {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let normalizedRecords = normalizedDays(Array(records), calendar: calendar)
        let eligibilityStart = calendar.startOfDay(
            for: eligibleFrom ?? self.eligibilityStart(
                records: Array(normalizedRecords),
                now: now,
                calendar: calendar
            )
        )

        if day > today {
            return .future
        }

        if normalizedRecords.contains(day) {
            return .applied
        }

        if day < eligibilityStart {
            return .untracked
        }

        if day == today {
            return .todayPending
        }

        return .missed
    }

    static func currentStreak(records: [Date], now: Date, calendar: Calendar = Calendar.current) -> Int {
        currentStreakDays(records: records, now: now, calendar: calendar).count
    }

    static func currentStreakDays(records: [Date], now: Date, calendar: Calendar = Calendar.current) -> [Date] {
        let byDay = normalizedDays(records, calendar: calendar)
        let today = calendar.startOfDay(for: now)

        var cursor = byDay.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var days: [Date] = []

        while byDay.contains(cursor) {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        return days.sorted()
    }

    static func longestStreak(records: [Date], calendar: Calendar = Calendar.current) -> Int {
        let byDay = normalizedDays(records, calendar: calendar).sorted()
        guard let firstDay = byDay.first else { return 0 }

        var longest = 1
        var current = 1
        var previousDay = firstDay

        for day in byDay.dropFirst() {
            guard let nextExpectedDay = calendar.date(byAdding: .day, value: 1, to: previousDay),
                  calendar.isDate(nextExpectedDay, inSameDayAs: day) else {
                longest = max(longest, current)
                current = 1
                previousDay = day
                continue
            }

            current += 1
            longest = max(longest, current)
            previousDay = day
        }

        return max(longest, current)
    }

    static func weeklyReport(
        records: [Date],
        now: Date,
        eligibleFrom: Date? = nil,
        calendar: Calendar = Calendar.current
    ) -> WeeklyReport {
        let today = calendar.startOfDay(for: now)
        let rollingStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let resolvedEligibilityStart = eligibleFrom.map { calendar.startOfDay(for: $0) }
            ?? eligibilityStart(records: records, now: now, calendar: calendar)
        let eligibleStart = min(resolvedEligibilityStart, today)
        let start = max(rollingStart, eligibleStart)
        let seen = Set(normalizedDays(records, calendar: calendar).filter { (start...today).contains($0) })

        var missed: [String] = []
        var dayCursor = start
        while dayCursor <= today {
            if !seen.contains(dayCursor) {
                missed.append(dayCursor.formatted(.dateTime.weekday(.abbreviated)))
            }
            dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor) ?? dayCursor
        }

        let totalDays = start <= today
            ? (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            : 0

        let streak = currentStreak(records: records, now: now, calendar: calendar)

        return WeeklyReport(
            startDate: start,
            endDate: today,
            appliedCount: seen.count,
            totalDays: totalDays,
            missedDays: missed,
            streak: streak
        )
    }

    static func routineProgress(
        recordDays: [Date],
        verifiedAtDates: [Date],
        highUVDays: Set<Date> = [],
        now: Date,
        eligibleFrom: Date,
        windowDays: Int = 30,
        calendar: Calendar = Calendar.current
    ) -> RoutineProgressInsights {
        let today = calendar.startOfDay(for: now)
        let boundedWindowDays = max(1, windowDays)
        let rollingStart = calendar.date(byAdding: .day, value: -(boundedWindowDays - 1), to: today) ?? today
        let start = max(rollingStart, min(calendar.startOfDay(for: eligibleFrom), today))
        let eligibleDayCount = start <= today
            ? (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            : 0
        let loggedDays = normalizedDays(recordDays, calendar: calendar).filter { (start...today).contains($0) }
        let loggedCount = loggedDays.count
        let consistencyPercent = eligibleDayCount > 0
            ? Int((Double(loggedCount) / Double(eligibleDayCount) * 100).rounded())
            : 0

        let applicationMinutes = verifiedAtDates.compactMap { timestamp -> Int? in
            let day = calendar.startOfDay(for: timestamp)
            guard (start...today).contains(day) else {
                return nil
            }
            let components = calendar.dateComponents([.hour, .minute], from: timestamp)
            guard let hour = components.hour, let minute = components.minute else {
                return nil
            }
            return hour * 60 + minute
        }.sorted()
        let typicalApplicationMinute = median(of: applicationMinutes)

        let eligibleHighUVDays = Set(highUVDays.map { calendar.startOfDay(for: $0) })
            .filter { (start...today).contains($0) }
        let highUVEligibleDayCount = eligibleHighUVDays.isEmpty ? nil : eligibleHighUVDays.count
        let highUVLoggedCount = eligibleHighUVDays.isEmpty
            ? nil
            : eligibleHighUVDays.intersection(loggedDays).count

        return RoutineProgressInsights(
            startDate: start,
            endDate: today,
            loggedCount: loggedCount,
            eligibleDayCount: eligibleDayCount,
            consistencyPercent: consistencyPercent,
            typicalApplicationMinute: typicalApplicationMinute,
            highUVLoggedCount: highUVLoggedCount,
            highUVEligibleDayCount: highUVEligibleDayCount,
            nextStep: nextStep(
                loggedCount: loggedCount,
                loggedToday: loggedDays.contains(today),
                consistencyPercent: consistencyPercent
            )
        )
    }

    private static func nextStep(
        loggedCount: Int,
        loggedToday: Bool,
        consistencyPercent: Int
    ) -> String {
        if loggedCount == 0 {
            return "Log once when sunscreen is part of your day."
        }
        if !loggedToday {
            return "Today is open if you wore sunscreen."
        }
        if consistencyPercent == 100 {
            return "Keep using the quick log when sunscreen is part of your day."
        }
        return "Use the quickest logging option that fits your routine."
    }

    private static func median(of values: [Int]) -> Int? {
        guard !values.isEmpty else {
            return nil
        }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }
}
