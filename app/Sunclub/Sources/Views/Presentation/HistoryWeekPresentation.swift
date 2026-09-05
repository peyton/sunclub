import Foundation

struct HistoryWeekPresentation {
    let days: [Date]
    let eligibleDayCount: Int
    let loggedDayCount: Int

    init(
        selectedDay: Date,
        recordDays: Set<Date>,
        today: Date,
        eligibleFrom: Date,
        calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: selectedDay)
        let weekdayOffset = (calendar.component(.weekday, from: day) - calendar.firstWeekday + 7) % 7
        let weekStart = calendar.date(byAdding: .day, value: -weekdayOffset, to: day) ?? day
        days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        let eligibleStart = calendar.startOfDay(for: eligibleFrom)
        let eligibleEnd = calendar.startOfDay(for: today)
        let eligibleDays = days.filter { $0 >= eligibleStart && $0 <= eligibleEnd }
        let loggedDays = Set(recordDays.map { calendar.startOfDay(for: $0) })
        eligibleDayCount = eligibleDays.count
        loggedDayCount = eligibleDays.filter { loggedDays.contains($0) }.count
    }

    static func initialSelection(
        preselectedDay: Date?,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.startOfDay(for: min(preselectedDay ?? referenceDate, referenceDate))
    }

    static func selectionAfterMovingMonth(
        from displayedMonth: Date,
        by offset: Int,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard offset != 0,
              let monthStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start,
              let destination = calendar.date(byAdding: .month, value: offset, to: monthStart) else {
            return nil
        }
        let today = calendar.startOfDay(for: referenceDate)
        guard destination <= today else { return nil }
        return calendar.isDate(destination, equalTo: today, toGranularity: .month) ? today : destination
    }
}

/// DailyRecord retains a count and the latest reapplication time, not every timestamp.
struct HistoryApplicationPresentation {
    let applicationCount: Int
    let timestamps: [Timestamp]
    let untimedReapplicationCount: Int

    enum Kind: String {
        case application, reapplication
    }

    struct Timestamp: Identifiable, Equatable {
        let kind: Kind
        let date: Date

        var id: String { kind.rawValue }
    }

    init(verifiedAt: Date, reapplyCount: Int, lastReappliedAt: Date?) {
        let count = max(0, reapplyCount)
        applicationCount = 1 + count
        var savedTimes = [Timestamp(kind: .application, date: verifiedAt)]
        if count > 0, let lastReappliedAt {
            savedTimes.append(Timestamp(kind: .reapplication, date: lastReappliedAt))
        }
        timestamps = savedTimes.sorted {
            if $0.date == $1.date { return $0.kind == .reapplication }
            return $0.date > $1.date
        }
        untimedReapplicationCount = count - (savedTimes.count - 1)
    }
}
