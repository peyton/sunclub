import Foundation

struct SunclubHistoryWidgetPresentation: Equatable, Sendable {
    let title: String
    let compactTitle: String
    let weekSummary: String
    let streakSummary: String
    let monthSummary: String

    var accessibilityLabel: String {
        "\(title), \(weekSummary), \(streakSummary), \(monthSummary)"
    }

    static func make(
        snapshot: SunclubWidgetSnapshot,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> SunclubHistoryWidgetPresentation {
        let monthName = now.formatted(.dateTime.month(.wide))
        let currentStreak = snapshot.streakValue(now: now, calendar: calendar)

        return SunclubHistoryWidgetPresentation(
            title: "\(monthName) sunscreen history",
            compactTitle: "\(monthName) history",
            weekSummary: "\(snapshot.currentWeekAppliedValue(now: now, calendar: calendar))/7 this week",
            streakSummary: "\(currentStreak)d current streak",
            monthSummary: monthPercent(snapshot: snapshot, now: now, calendar: calendar)
        )
    }

    private static func monthPercent(
        snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> String {
        let applied = snapshot.monthlyAppliedValue(now: now, calendar: calendar)
        let total = snapshot.monthlyDayValue(now: now, calendar: calendar)
        guard total > 0 else {
            return "0% month"
        }

        return "\(Int((Double(applied) / Double(total)) * 100))% month"
    }
}
