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
}

enum CalendarAnalytics {
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
        let byDay = Set(records.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)

        var cursor = byDay.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var streak = 0

        while byDay.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        return streak
    }

    static func weeklyReport(records: [Date], now: Date, calendar: Calendar = Calendar.current) -> WeeklyReport {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        var seen = Set<Date>()

        for record in records {
            let day = calendar.startOfDay(for: record)
            if (start...today).contains(day) {
                seen.insert(day)
            }
        }

        var missed: [String] = []
        var dayCursor = start
        while dayCursor <= today {
            if !seen.contains(dayCursor) {
                missed.append(dayCursor.formatted(.dateTime.weekday(.abbreviated)))
            }
            dayCursor = calendar.date(byAdding: .day, value: 1, to: dayCursor) ?? dayCursor
        }

        let allRecords = records.map { calendar.startOfDay(for: $0) }
        let streak = currentStreak(records: allRecords, now: now, calendar: calendar)

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
