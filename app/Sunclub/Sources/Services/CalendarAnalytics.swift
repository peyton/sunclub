import Foundation

enum DayStatus: Equatable {
    case applied
    case todayPending
    case missed
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

    static func status(for date: Date, with records: Set<Date>, now: Date, calendar: Calendar = Calendar.current) -> DayStatus {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)

        if day > today {
            return .future
        }

        if records.contains(day) {
            return .applied
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

    static func weeklyReport(records: [Date], now: Date, calendar: Calendar = Calendar.current) -> WeeklyReport {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let seen = Set(normalizedDays(records, calendar: calendar).filter { (start...today).contains($0) })

        var missed: [String] = []
        var dayCursor = start
        while dayCursor <= today {
            if !seen.contains(dayCursor) {
                missed.append(dayCursor.formatted(.dateTime.weekday(.abbreviated)))
            }
            dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor) ?? dayCursor
        }

        let streak = currentStreak(records: records, now: now, calendar: calendar)

        return WeeklyReport(
            startDate: start,
            endDate: today,
            appliedCount: seen.count,
            totalDays: 7,
            missedDays: missed,
            streak: streak
        )
    }
}
