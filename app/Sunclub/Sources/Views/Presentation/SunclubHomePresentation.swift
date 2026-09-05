import Foundation

/// Value inputs only: building home copy cannot mutate storage or start background work.
struct SunclubHomePresentation {
    struct Record {
        let startOfDay: Date
        let verifiedAt: Date
        let spfLevel: Int?
        let trimmedNotes: String?
        let reapplyCount: Int
    }

    let now: Date
    let calendar: Calendar
    let records: [Record]
    let reapplyReminderEnabled: Bool
    let smartReminderSettings: SmartReminderSettings
    let reapplyReminderPlan: ReapplyReminderPlan
    let uvReading: UVReading?
    let uvForecast: SunclubUVForecast?
    let pendingImportedBatchCount: Int
    let conflictCount: Int
    let notificationHealthPresentation: NotificationHealthPresentation?
    let homeRecoveryActions: [HomeRecoveryAction]

    private var recordedDays: [Date] { records.map(\.startOfDay) }

    private func record(for day: Date) -> Record? {
        records.first { calendar.isDate($0.startOfDay, inSameDayAs: day) }
    }

    var todayCardPresentation: HomeTodayCardPresentation {
        let now = self.now
        let todayRecord = record(for: now)
        let hasLoggedToday = todayRecord != nil
        let title = hasLoggedToday ? "Today's log is in" : "Ready for today's log"
        let defaultDetail = hasLoggedToday
            ? "Update today's SPF or note any time."
            : "Add a log to start your reminder."
        let logBadgeText = todayRecord.map { Self.logBadgeText(for: $0) }
        let streakRiskBadgeText = streakRiskBadgeText(now: now, hasLoggedToday: hasLoggedToday)
        let metadataRows = todayCardMetadataRows(now: now, todayRecord: todayRecord)

        guard let level = uvReading?.level,
              let uvHeadline = level.homeHeadline else {
            return HomeTodayCardPresentation(
                title: title,
                detail: defaultDetail,
                logBadgeText: logBadgeText,
                streakRiskBadgeText: streakRiskBadgeText,
                uvHeadline: nil,
                uvSymbolName: nil,
                metadataRows: metadataRows
            )
        }

        let detail: String
        if reapplyReminderPlan.isElevated {
            detail = hasLoggedToday
                ? "You've logged today. Follow the product label and reapply after swimming or sweating."
                : "Log now, then follow the product label while UV stays elevated."
        } else {
            detail = defaultDetail
        }

        return HomeTodayCardPresentation(
            title: title,
            detail: detail,
            logBadgeText: logBadgeText,
            streakRiskBadgeText: streakRiskBadgeText,
            uvHeadline: uvHeadline,
            uvSymbolName: level.symbolName,
            metadataRows: metadataRows
        )
    }

    var homeDailyPlanPresentation: HomeDailyPlanPresentation {
        let now = self.now
        let todayRecord = record(for: now)
        let facts = dailyPlanFacts(now: now, todayRecord: todayRecord)

        guard let todayRecord else {
            let hour = calendar.component(.hour, from: now)
            let title: String
            let detail: String

            if hour >= 18 {
                title = "Log before midnight"
                detail = "Today is still open. Add a log if you wore sunscreen."
            } else if reapplyReminderPlan.isElevated {
                title = "Log before outdoor time"
                detail = "UV is elevated today. Save the first log now, then follow the product label outdoors."
            } else if uvReading?.level == .low {
                title = "Keep the routine steady"
                detail = "UV is low, but logging now keeps the habit simple and consistent."
            } else {
                title = "Log sunscreen today"
                detail = "One quick check-in is enough to keep the day on track."
            }

            return HomeDailyPlanPresentation(
                title: title,
                detail: detail,
                actionTitle: "Log Today",
                action: .logToday,
                symbolName: "sun.max.fill",
                tone: .action,
                facts: facts
            )
        }

        if appStateNeedsRecoveryReview {
            return HomeDailyPlanPresentation(
                title: syncRecoveryTitle,
                detail: syncRecoveryDetail,
                actionTitle: "Review Changes",
                action: .reviewRecovery,
                symbolName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                tone: .warning,
                facts: facts
            )
        }

        if let notificationHealthPresentation {
            let action: HomeDailyPlanAction = notificationHealthPresentation.state == .stale ? .repairReminders : .openSettings
            return HomeDailyPlanPresentation(
                title: notificationHealthPresentation.title,
                detail: "\(notificationHealthPresentation.detail) Manual logging still works.",
                actionTitle: notificationHealthPresentation.actionTitle,
                action: action,
                symbolName: "bell.badge.fill",
                tone: .warning,
                facts: facts
            )
        }

        if let backfillAction = homeRecoveryActions.first(where: { $0.kind == .backfillYesterday }) {
            return HomeDailyPlanPresentation(
                title: backfillAction.title,
                detail: backfillAction.detail,
                actionTitle: backfillAction.buttonTitle,
                action: .backfillYesterday,
                symbolName: "calendar.badge.exclamationmark",
                tone: .warning,
                facts: facts
            )
        }

        if reapplyReminderEnabled, reapplyReminderPlan.shouldScheduleNotification {
            let title = todayRecord.reapplyCount > 0 ? "Reapply again if you're outside" : "Plan the next reapply"
            let detail: String
            if let fireDate = reapplyReminderPlan.fireDate {
                detail = "Sunclub can remind you around \(fireDate.formatted(date: .omitted, time: .shortened)). Log a reapply whenever you put more on."
            } else {
                detail = "Log a reapply whenever you put more on so today's history stays accurate."
            }

            return HomeDailyPlanPresentation(
                title: title,
                detail: detail,
                actionTitle: todayRecord.reapplyCount > 0 ? "Log Another Reapply" : "Log Reapply",
                action: .logReapply,
                symbolName: "timer",
                tone: .action,
                facts: facts
            )
        }

        if todayRecord.spfLevel == nil, todayRecord.trimmedNotes == nil {
            return HomeDailyPlanPresentation(
                title: "Add details if useful",
                detail: "Today's log is saved. Add SPF or a note only if it helps future you understand the day.",
                actionTitle: "Add SPF or Note",
                action: .addDetails,
                symbolName: "note.text",
                tone: .calm,
                facts: facts
            )
        }

        if !reapplyReminderEnabled {
            return HomeDailyPlanPresentation(
                title: "You're set for today",
                detail: "Today's log is saved. Reapply reminders are off, so Sunclub will stay quiet unless you open it.",
                actionTitle: "View Progress",
                action: .viewProgress,
                symbolName: "checkmark.circle.fill",
                tone: .complete,
                facts: facts
            )
        }

        return HomeDailyPlanPresentation(
            title: "You're set for today",
            detail: "Today's log is saved. Check your week if you want a quick progress read.",
            actionTitle: "View Progress",
            action: .viewProgress,
            symbolName: "checkmark.circle.fill",
            tone: .complete,
            facts: facts
        )
    }

    private var appStateNeedsRecoveryReview: Bool {
        pendingImportedBatchCount > 0 || conflictCount > 0
    }

    var syncRecoveryTitle: String {
        if conflictCount > 0 {
            return "Review changes"
        }

        return "Saved only on this phone"
    }

    var syncRecoveryDetail: String {
        var parts: [String] = []

        if pendingImportedBatchCount > 0 {
            parts.append(SunclubCopy.Sync.readyToSendToICloud(pendingImportedBatchCount))
        }

        if conflictCount > 0 {
            parts.append(SunclubCopy.Sync.mergedChangesNeedReview(conflictCount))
        }

        return parts.joined(separator: " ")
    }

    private func dailyPlanFacts(now: Date, todayRecord: Record?) -> [HomeDailyPlanFact] {
        var facts = [
            todayDailyPlanFact(now: now, record: todayRecord),
            weekLoggedDailyPlanFact(now: now)
        ]

        if let uvFact = uvDailyPlanFact() {
            facts.append(uvFact)
        }

        if let detailsFact = detailsDailyPlanFact(for: todayRecord) {
            facts.append(detailsFact)
        }

        return Array(facts.prefix(4))
    }

    private func todayDailyPlanFact(now: Date, record: Record?) -> HomeDailyPlanFact {
        if let record {
            return HomeDailyPlanFact(
                id: "today",
                title: "Today",
                value: "Logged \(record.verifiedAt.formatted(date: .omitted, time: .shortened))",
                symbolName: "checkmark.circle.fill"
            )
        }

        return HomeDailyPlanFact(
            id: "reminder",
            title: "Reminder",
            value: nextReminderSummary(now: now),
            symbolName: "bell.fill"
        )
    }

    private func weekLoggedDailyPlanFact(now: Date) -> HomeDailyPlanFact {
        let weekLoggedCount = CalendarAnalytics.weeklyReport(
            records: recordedDays,
            now: now,
            calendar: calendar
        ).appliedCount
        return HomeDailyPlanFact(
            id: "week",
            title: "This Week",
            value: "\(weekLoggedCount)/7 logged",
            symbolName: "calendar"
        )
    }

    private func uvDailyPlanFact() -> HomeDailyPlanFact? {
        if let uvForecast,
           uvForecast.isAvailable,
           let peakHour = uvForecast.peakHour {
            return HomeDailyPlanFact(
                id: "uv",
                title: "Peak UV",
                value: "\(peakHour.index) at \(peakHour.date.formatted(date: .omitted, time: .shortened))",
                symbolName: peakHour.level.symbolName
            )
        }

        guard let uvReading else {
            return nil
        }

        return HomeDailyPlanFact(
            id: "uv",
            title: "UV Now",
            value: "\(uvReading.index), \(uvReading.level.displayName)",
            symbolName: uvReading.level.symbolName
        )
    }

    private func detailsDailyPlanFact(for record: Record?) -> HomeDailyPlanFact? {
        guard let record, record.spfLevel != nil || record.trimmedNotes != nil else {
            return nil
        }

        return HomeDailyPlanFact(
            id: "details",
            title: "Details",
            value: dailyPlanDetailsValue(for: record),
            symbolName: "note.text"
        )
    }

    private func dailyPlanDetailsValue(for record: Record) -> String {
        switch (record.spfLevel, record.trimmedNotes) {
        case let (.some(spfLevel), .some(_)):
            return "SPF \(spfLevel), note saved"
        case let (.some(spfLevel), .none):
            return "SPF \(spfLevel)"
        case (.none, .some(_)):
            return "Note saved"
        case (.none, .none):
            return "Optional"
        }
    }

    private func todayCardMetadataRows(now: Date, todayRecord: Record?) -> [HomeTodayMetadataRow] {
        var rows: [HomeTodayMetadataRow] = []

        if let todayRecord {
            rows.append(
                HomeTodayMetadataRow(
                    id: "logged",
                    title: "Last Saved",
                    value: todayRecord.verifiedAt.formatted(date: .omitted, time: .shortened),
                    symbolName: "checkmark.circle.fill"
                )
            )

            rows.append(
                HomeTodayMetadataRow(
                    id: "spf",
                    title: "SPF",
                    value: todayRecord.spfLevel.map { "SPF \($0)" } ?? "Not saved",
                    symbolName: "sun.max.fill"
                )
            )

            if todayRecord.trimmedNotes != nil {
                rows.append(
                    HomeTodayMetadataRow(
                        id: "notes",
                        title: "Notes",
                        value: "Saved",
                        symbolName: "note.text"
                    )
                )
            }

            if reapplyReminderEnabled {
                rows.append(
                    HomeTodayMetadataRow(
                        id: "reapply",
                        title: "Reapply",
                        value: reapplyWindowSummary,
                        symbolName: "timer"
                    )
                )
            }
        } else {
            rows.append(
                HomeTodayMetadataRow(
                    id: "reminder",
                    title: "Reminder",
                    value: nextReminderSummary(now: now),
                    symbolName: "bell.fill"
                )
            )

            if reapplyReminderEnabled {
                rows.append(
                    HomeTodayMetadataRow(
                        id: "reapply",
                        title: "Reapply",
                        value: "After today's log",
                        symbolName: "timer"
                    )
                )
            }
        }

        rows.append(contentsOf: uvMetadataRows())
        return Array(rows.prefix(6))
    }

    private var reapplyWindowSummary: String {
        let plan = reapplyReminderPlan
        guard plan.shouldScheduleNotification else {
            return "No reminder after sunset"
        }

        return "Label check in \(plan.intervalSummary)"
    }

    private func nextReminderSummary(now: Date) -> String {
        let kind = ReminderPlanner.scheduleKind(for: now, calendar: calendar)
        let time = smartReminderSettings.time(for: kind)
        let day = calendar.startOfDay(for: now)
        let reminderDate = calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: day
        ) ?? day
        return "\(kind.shortTitle) \(reminderDate.formatted(date: .omitted, time: .shortened))"
    }

    private func uvMetadataRows() -> [HomeTodayMetadataRow] {
        if let uvForecast,
           uvForecast.isAvailable,
           let peakHour = uvForecast.peakHour {
            return [
                HomeTodayMetadataRow(
                    id: "uvPeak",
                    title: "Peak UV",
                    value: "\(peakHour.index) at \(peakHour.date.formatted(date: .omitted, time: .shortened))",
                    symbolName: peakHour.level.symbolName
                ),
                HomeTodayMetadataRow(
                    id: "uvSource",
                    title: "Source",
                    value: uvForecast.sourceLabel,
                    symbolName: "location.fill"
                )
            ]
        }

        if let uvReading,
           uvReading.source == .weatherKit,
           uvReading.isFresh(at: now) {
            return [
                HomeTodayMetadataRow(
                    id: "uvNow",
                    title: "UV Now",
                    value: "\(uvReading.index), \(uvReading.source.statusLabel)",
                    symbolName: uvReading.level.symbolName
                )
            ]
        }

        return []
    }

    private static func logBadgeText(for record: Record) -> String {
        guard record.reapplyCount > 0 else {
            return "Logged"
        }

        let noun = record.reapplyCount == 1 ? "reapply" : "reapplies"
            return "Logged + \(record.reapplyCount) \(noun)"
    }

    private func streakRiskBadgeText(now: Date, hasLoggedToday: Bool) -> String? {
        guard !hasLoggedToday else {
            return nil
        }

        let hour = calendar.component(.hour, from: now)
        guard hour >= 18 else {
            return nil
        }

        let activeStreak = CalendarAnalytics.currentStreak(
            records: recordedDays,
            now: now,
            calendar: calendar
        )
        guard activeStreak > 0 else {
            return nil
        }

        return "Today still open"
    }

}
