import Foundation

struct SunclubReminderPresentation {
    let now: Date
    let calendar: Calendar
    let reminderSettings: SmartReminderSettings
    let reapplyReminderEnabled: Bool
    let recordedDays: [Date]
    let todayRecord: DailyRecordProjectionSnapshot?

    var reminderDate: Date {
        reminderDate(for: ReminderPlanner.scheduleKind(for: now, calendar: calendar))
    }

    func reminderDate(for kind: ReminderScheduleKind) -> Date {
        let reminderTime = reminderSettings.time(for: kind)
        let today = calendar.startOfDay(for: now)
        return calendar.date(
            bySettingHour: reminderTime.hour,
            minute: reminderTime.minute,
            second: 0,
            of: today
        ) ?? today
    }

    var nextDailyReminderPreview: DailyReminderPreview? {
        nextDailyReminderPreview(now: now)
    }

    private func nextDailyReminderPreview(now: Date) -> DailyReminderPreview? {
        let timeZone = reminderSettings.notificationTimeZone(currentTimeZone: calendar.timeZone)
        var scheduleCalendar = calendar
        scheduleCalendar.timeZone = timeZone
        let today = scheduleCalendar.startOfDay(for: now)

        for dayOffset in 0..<14 {
            guard let day = scheduleCalendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            let kind = ReminderPlanner.scheduleKind(for: day, calendar: scheduleCalendar)
            let time = reminderSettings.time(for: kind)
            guard let fireDate = ReminderPlanner.scheduledDate(
                for: day,
                time: time,
                timeZone: timeZone,
                calendar: scheduleCalendar
            ),
                fireDate > now else {
                continue
            }

            let summary = "Next reminder: \(fireDate.formatted(.dateTime.weekday(.wide).hour().minute()))."
            return DailyReminderPreview(fireDate: fireDate, summary: summary)
        }

        return nil
    }

    var homeRecoveryActions: [HomeRecoveryAction] {
        var actions: [HomeRecoveryAction] = []

        let now = self.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        if recordedDays.count >= 3, !recordedDays.contains(where: { calendar.isDate($0, inSameDayAs: yesterday) }) {
            actions.append(
                HomeRecoveryAction(
                    kind: .backfillYesterday,
                    title: "Yesterday is missing",
                    detail: "Add it now without opening your full history.",
                    buttonTitle: "Backfill Yesterday"
                )
            )
        }

        return actions
    }

    var reapplyCheckInPresentation: ReapplyCheckInPresentation? {
        guard let todayRecord else {
            return nil
        }

        if !reapplyReminderEnabled {
            return ReapplyCheckInPresentation(
                title: "Reapply",
                detail: "Record another application. Reapply reminders are off.",
                actionTitle: todayRecord.reapplyCount > 0 ? "Log Another Reapply" : "Log Reapply"
            )
        }

        if todayRecord.reapplyCount > 0 {
            let detail: String
            if let lastReappliedAt = todayRecord.lastReappliedAt {
                detail = "Checked in \(todayRecord.reapplyCount) \(todayRecord.reapplyCount == 1 ? "time" : "times") today. Last one at \(lastReappliedAt.formatted(date: .omitted, time: .shortened)). If there is enough daylight left, Sunclub will set up the next reminder."
            } else {
                detail = "Checked in \(todayRecord.reapplyCount) \(todayRecord.reapplyCount == 1 ? "time" : "times") today. If there is enough daylight left, Sunclub will set up the next reminder."
            }

            return ReapplyCheckInPresentation(
                title: "Reapply",
                detail: detail,
                actionTitle: "Log Another Reapply"
            )
        }

        return ReapplyCheckInPresentation(
            title: "Reapply",
            detail: "Use this whenever you reapply. If there is enough daylight left, Sunclub will set up the next interval reminder.",
            actionTitle: "Log Reapply"
        )
    }

}
