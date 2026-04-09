import Foundation

struct ReminderCoachingSuggestion: Equatable, Identifiable {
    let kind: ReminderScheduleKind
    let currentTime: ReminderTime
    let suggestedTime: ReminderTime
    let typicalLogTime: ReminderTime
    let sampleCount: Int

    var id: ReminderScheduleKind { kind }

    var title: String {
        switch kind {
        case .weekday:
            return "Weekday reminder"
        case .weekend:
            return "Weekend reminder"
        }
    }

    var actionTitle: String {
        "Use \(suggestedTime.displayText)"
    }

    var detail: String {
        "You usually log around \(typicalLogTime.displayText) on \(kind.shortTitle.lowercased()). Move the reminder from \(currentTime.displayText) to \(suggestedTime.displayText)."
    }
}

enum ReminderCoachingEngine {
    private static let lookbackDays = 45
    private static let minimumSampleCount = 3
    private static let leadMinutes = 30
    private static let minimumMeaningfulShift = 20
    private static let earliestSuggestedMinute = 6 * 60
    private static let latestSuggestedMinute = 21 * 60

    static func suggestions(
        from records: [DailyRecord],
        settings: SmartReminderSettings,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) -> [ReminderCoachingSuggestion] {
        guard let windowStart = calendar.date(byAdding: .day, value: -lookbackDays, to: now) else {
            return []
        }

        let recentRecords = records.filter { record in
            record.verifiedAt >= windowStart && record.verifiedAt <= now
        }

        return ReminderScheduleKind.allCases.compactMap { kind in
            suggestion(
                for: kind,
                records: recentRecords,
                settings: settings,
                calendar: calendar
            )
        }
    }

    private static func suggestion(
        for kind: ReminderScheduleKind,
        records: [DailyRecord],
        settings: SmartReminderSettings,
        calendar: Calendar
    ) -> ReminderCoachingSuggestion? {
        let matchingMinutes = records.compactMap { record -> Int? in
            guard ReminderPlanner.scheduleKind(for: record.startOfDay, calendar: calendar) == kind else {
                return nil
            }

            let components = calendar.dateComponents([.hour, .minute], from: record.verifiedAt)
            guard let hour = components.hour,
                  let minute = components.minute else {
                return nil
            }

            return (hour * 60) + minute
        }
        .sorted()

        guard matchingMinutes.count >= minimumSampleCount else {
            return nil
        }

        let medianMinute = matchingMinutes[matchingMinutes.count / 2]
        let suggestedMinute = min(
            latestSuggestedMinute,
            max(earliestSuggestedMinute, medianMinute - leadMinutes)
        )
        let currentTime = settings.time(for: kind)

        guard abs(suggestedMinute - currentTime.totalMinutes) >= minimumMeaningfulShift else {
            return nil
        }

        return ReminderCoachingSuggestion(
            kind: kind,
            currentTime: currentTime,
            suggestedTime: ReminderTime(totalMinutes: suggestedMinute),
            typicalLogTime: ReminderTime(totalMinutes: medianMinute),
            sampleCount: matchingMinutes.count
        )
    }
}

private extension ReminderTime {
    init(totalMinutes: Int) {
        self.init(hour: totalMinutes / 60, minute: totalMinutes % 60)
    }

    var displayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short

        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: Date())
        let date = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: referenceDay
        ) ?? referenceDay
        return formatter.string(from: date)
    }
}
