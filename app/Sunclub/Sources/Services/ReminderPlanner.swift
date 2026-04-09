import Foundation

struct StreakRiskReminderPlan: Equatable {
    let targetDay: Date
    let fireDate: Date
    let streakCount: Int
}

enum ReminderPlanner {
    private static let streakRiskOffsetMinutes = 8 * 60
    private static let streakRiskFloorMinutes = 17 * 60
    private static let streakRiskCeilingMinutes = 21 * 60

    static func scheduleKind(for date: Date, calendar: Calendar = Calendar.current) -> ReminderScheduleKind {
        switch calendar.component(.weekday, from: date) {
        case 1, 7:
            return .weekend
        default:
            return .weekday
        }
    }

    static func notificationComponents(
        for day: Date,
        time: ReminderTime,
        timeZone: TimeZone,
        calendar: Calendar = Calendar.current
    ) -> DateComponents {
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone

        let normalizedDay = scheduleCalendar.startOfDay(for: day)
        var components = scheduleCalendar.dateComponents([.year, .month, .day], from: normalizedDay)
        components.timeZone = timeZone
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return components
    }

    static func scheduledDate(
        for day: Date,
        time: ReminderTime,
        timeZone: TimeZone,
        calendar: Calendar = Calendar.current
    ) -> Date? {
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone
        return scheduleCalendar.date(from: notificationComponents(for: day, time: time, timeZone: timeZone, calendar: scheduleCalendar))
    }

    // Approximate a local sunset cutoff without requiring location access or live weather data.
    static func reapplyFireDate(
        from startDate: Date,
        intervalMinutes: Int,
        calendar: Calendar = Calendar.current
    ) -> Date? {
        guard intervalMinutes > 0,
              let fireDate = calendar.date(byAdding: .minute, value: intervalMinutes, to: startDate) else {
            return nil
        }

        let sunset = estimatedSunset(for: startDate, calendar: calendar)
        guard fireDate < sunset else {
            return nil
        }

        return fireDate
    }

    static func estimatedSunset(
        for day: Date,
        calendar: Calendar = Calendar.current
    ) -> Date {
        let sunsetTime = estimatedSunsetTime(for: day, calendar: calendar)
        let startOfDay = calendar.startOfDay(for: day)

        return calendar.date(
            bySettingHour: sunsetTime.hour,
            minute: sunsetTime.minute,
            second: 0,
            of: startOfDay
        ) ?? startOfDay
    }

    static func streakRiskPlan(
        records: [Date],
        now: Date,
        settings: SmartReminderSettings,
        calendar: Calendar = Calendar.current,
        currentTimeZone: TimeZone = .autoupdatingCurrent
    ) -> StreakRiskReminderPlan? {
        guard settings.streakRiskEnabled else { return nil }

        let streak = CalendarAnalytics.currentStreak(records: records, now: now, calendar: calendar)
        guard streak > 0 else { return nil }

        let today = calendar.startOfDay(for: now)
        let recordedDays = Set(records.map { calendar.startOfDay(for: $0) })
        let targetDay = recordedDays.contains(today)
            ? (calendar.date(byAdding: .day, value: 1, to: today) ?? today)
            : today

        guard !recordedDays.contains(targetDay) else { return nil }

        let reminderTime = settings.time(for: targetDay, calendar: calendar)
        guard let riskTime = streakRiskTime(after: reminderTime) else { return nil }

        let timeZone = settings.notificationTimeZone(currentTimeZone: currentTimeZone)
        guard let fireDate = scheduledDate(for: targetDay, time: riskTime, timeZone: timeZone, calendar: calendar),
              fireDate > now else {
            return nil
        }

        return StreakRiskReminderPlan(targetDay: targetDay, fireDate: fireDate, streakCount: streak)
    }

    static func streakRiskTime(after reminderTime: ReminderTime) -> ReminderTime? {
        let reminderMinutes = reminderTime.totalMinutes
        guard reminderMinutes < streakRiskCeilingMinutes else { return nil }

        let candidate = max(reminderMinutes + streakRiskOffsetMinutes, streakRiskFloorMinutes)
        let clamped = min(candidate, streakRiskCeilingMinutes)
        guard clamped > reminderMinutes else { return nil }

        return ReminderTime(hour: clamped / 60, minute: clamped % 60)
    }

    private static func estimatedSunsetTime(
        for day: Date,
        calendar: Calendar
    ) -> ReminderTime {
        switch calendar.component(.month, from: day) {
        case 12, 1:
            return ReminderTime(hour: 17, minute: 0)
        case 2, 11:
            return ReminderTime(hour: 17, minute: 30)
        case 3, 10:
            return ReminderTime(hour: 18, minute: 15)
        case 4, 9:
            return ReminderTime(hour: 19, minute: 0)
        case 5, 8:
            return ReminderTime(hour: 19, minute: 45)
        default:
            return ReminderTime(hour: 20, minute: 15)
        }
    }
}
