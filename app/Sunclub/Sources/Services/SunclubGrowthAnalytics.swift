import Foundation

enum SunclubGrowthAnalytics {
    static func achievements(
        records: [DailyRecord],
        changeBatches: [SunclubChangeBatch],
        settings: Settings? = nil,
        growthSettings: SunclubGrowthSettings = SunclubGrowthSettings(),
        historicalUVIndexes: [Date: Int] = [:],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SunclubAchievement] {
        let context = achievementProgressContext(
            records: records,
            changeBatches: changeBatches,
            settings: settings,
            growthSettings: growthSettings,
            historicalUVIndexes: historicalUVIndexes,
            now: now,
            calendar: calendar
        )
        return SunclubAchievementID.allCases.map { achievement(for: $0, context: context) }
    }

    static func challenges(
        records: [DailyRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SunclubSeasonalChallenge] {
        SunclubChallengeID.allCases.map { id in
            let interval = challengeInterval(for: id, around: now, calendar: calendar)
            let protectedCount = loggedDays(in: interval, records: records, calendar: calendar).count
            let targetValue = challengeTargetValue(for: id)

            return SunclubSeasonalChallenge(
                id: id,
                title: id.title,
                detail: challengeDetail(for: id),
                symbolName: id.symbolName,
                dateInterval: interval,
                currentValue: protectedCount,
                targetValue: targetValue,
                isComplete: protectedCount >= targetValue
            )
        }
    }

    static func reportSummary(
        records: [DailyRecord],
        interval: DateInterval,
        historicalUVIndexes: [Date: Int] = [:],
        calendar: Calendar = .current
    ) -> SunclubSkinHealthReportSummary {
        let filteredRecords = records
            .filter { interval.contains($0.startOfDay) }
            .sorted { $0.startOfDay < $1.startOfDay }
        let normalizedDays = Set(filteredRecords.map { calendar.startOfDay(for: $0.startOfDay) })
        let longestStreak = CalendarAnalytics.longestStreak(
            records: Array(normalizedDays),
            calendar: calendar
        )
        let averageStreakLength = averageStreakLength(from: Array(normalizedDays), calendar: calendar)
        let mostUsedSPF = SunscreenUsageAnalytics.mostUsedSPFInsight(from: filteredRecords)
        let spfDistribution = spfDistribution(from: filteredRecords)
        let monthlyConsistency = monthlyConsistency(
            from: filteredRecords,
            interval: interval,
            calendar: calendar
        )
        let normalizedUVIndexes = historicalUVIndexes.reduce(into: [Date: Int]()) { result, entry in
            let day = calendar.startOfDay(for: entry.key)
            result[day] = max(result[day] ?? 0, entry.value)
        }
        let highUVProtectedDays = filteredRecords.reduce(into: 0) { result, record in
            guard let verifiedIndex = normalizedUVIndexes[calendar.startOfDay(for: record.startOfDay)],
                  verifiedIndex >= 6 else {
                return
            }
            result += 1
        }

        return SunclubSkinHealthReportSummary(
            interval: interval,
            totalProtectedDays: normalizedDays.count,
            longestStreak: longestStreak,
            averageStreakLength: averageStreakLength,
            highUVProtectedDays: highUVProtectedDays,
            mostUsedSPF: mostUsedSPF,
            spfDistribution: spfDistribution,
            monthlyConsistency: monthlyConsistency
        )
    }

    static func seasonalStyle(for date: Date, calendar: Calendar = .current) -> SunclubSeasonStyle {
        let month = calendar.component(.month, from: date)
        switch month {
        case 11, 12, 1, 2:
            return .winterShield
        default:
            return .summerGlow
        }
    }

    private struct AchievementProgressContext {
        let longestStreak: Int
        let hasReapplied: Bool
        let hasBackfilled: Bool
        let summerLoggedDays: Int
        let winterLoggedDays: Int
        let morningLogCount: Int
        let completedWeekendCount: Int
        let distinctSPFCount: Int
        let notedLogCount: Int
        let maxReapplyCount: Int
        let highUVProtectedDays: Int
        let hasHomeBase: Bool
        let hasLiveSignal: Bool
        let productScanUseCount: Int
    }

    private static func achievementProgressContext(
        records: [DailyRecord],
        changeBatches: [SunclubChangeBatch],
        settings: Settings?,
        growthSettings: SunclubGrowthSettings,
        historicalUVIndexes: [Date: Int],
        now: Date,
        calendar: Calendar
    ) -> AchievementProgressContext {
        let leaveHomeReminder = settings?.smartReminderSettings.leaveHomeReminder

        return AchievementProgressContext(
            longestStreak: CalendarAnalytics.longestStreak(records: records.map(\.startOfDay), calendar: calendar),
            hasReapplied: records.contains(where: \.hasReapplied),
            hasBackfilled: changeBatches.contains { $0.kind == .historyBackfill },
            summerLoggedDays: seasonalLoggedDayCount(.summer, records: records, around: now, calendar: calendar),
            winterLoggedDays: seasonalLoggedDayCount(.winter, records: records, around: now, calendar: calendar),
            morningLogCount: records.filter { DayPart.resolve(for: $0.verifiedAt, calendar: calendar) == .morning }.count,
            completedWeekendCount: completedWeekendCount(records: records, calendar: calendar),
            distinctSPFCount: Set(records.compactMap(\.spfLevel)).count,
            notedLogCount: records.filter { $0.trimmedNotes != nil }.count,
            maxReapplyCount: records.map(\.reapplyCount).max() ?? 0,
            highUVProtectedDays: highUVProtectedDayCount(
                records: records,
                historicalUVIndexes: historicalUVIndexes,
                calendar: calendar
            ),
            hasHomeBase: leaveHomeReminder?.isEnabled == true && leaveHomeReminder?.homeLocation != nil,
            hasLiveSignal: growthSettings.uvBriefing.dailyBriefingEnabled,
            productScanUseCount: growthSettings.telemetry.productScanUseCount
        )
    }

    private static func achievement(
        for id: SunclubAchievementID,
        context: AchievementProgressContext
    ) -> SunclubAchievement {
        let rawCurrentValue = rawCurrentValue(for: id, context: context)
        let isUnlocked = rawCurrentValue >= id.targetValue
        let currentValue = cappedCurrentValue(rawCurrentValue, targetValue: id.targetValue)

        return SunclubAchievement(
            id: id,
            title: id.title,
            detail: achievementDetail(for: id, value: rawCurrentValue, isUnlocked: isUnlocked),
            symbolName: id.symbolName,
            currentValue: currentValue,
            targetValue: id.targetValue,
            isUnlocked: isUnlocked,
            shareBlurb: "I unlocked \(id.title) in Sunclub."
        )
    }

    private static func rawCurrentValue(
        for id: SunclubAchievementID,
        context: AchievementProgressContext
    ) -> Int {
        switch id {
        case .streak7, .streak30, .streak100, .streak365:
            return context.longestStreak
        case .firstReapply:
            return context.hasReapplied ? 1 : 0
        case .firstBackfill:
            return context.hasBackfilled ? 1 : 0
        case .summerSurvivor:
            return context.summerLoggedDays
        case .winterWarrior:
            return context.winterLoggedDays
        case .morningGlow:
            return context.morningLogCount
        case .weekendCanopy:
            return context.completedWeekendCount
        case .spfSampler:
            return context.distinctSPFCount
        case .noteTaker:
            return context.notedLogCount
        case .reapplyRelay:
            return context.maxReapplyCount
        case .highUVHero:
            return context.highUVProtectedDays
        case .homeBase:
            return context.hasHomeBase ? 1 : 0
        case .liveSignal:
            return context.hasLiveSignal ? 1 : 0
        case .bottleDetective:
            return context.productScanUseCount
        }
    }

    private static func achievementDetail(
        for id: SunclubAchievementID,
        value: Int,
        isUnlocked: Bool
    ) -> String {
        switch id {
        case .streak7, .streak30, .streak100, .streak365:
            return isUnlocked ? "Your longest streak reached \(value) days." : "Reach a \(id.targetValue)-day streak to unlock this badge."
        case .firstReapply:
            return isUnlocked ? "You logged your first reapply check-in." : "Log a reapply to unlock this badge."
        case .firstBackfill:
            return isUnlocked ? "You repaired your history with a backfill." : "Backfill a missing day to unlock this badge."
        case .summerSurvivor:
            return isUnlocked ? "You stayed protected through \(value) summer days." : "Log \(id.targetValue) days during June through August."
        case .winterWarrior:
            return isUnlocked ? "You kept winter protection going for \(value) days." : "Log \(id.targetValue) days during December through February."
        case .morningGlow:
            return isUnlocked ? "You logged sunscreen before 10 AM on \(value) mornings." : "Log sunscreen before 10 AM on \(id.targetValue) mornings."
        case .weekendCanopy:
            return isUnlocked ? "You covered both weekend days \(value) times." : "Log both Saturday and Sunday across \(id.targetValue) weekends."
        case .spfSampler:
            return isUnlocked ? "Your history includes \(value) different SPF levels." : "Log \(id.targetValue) different SPF levels."
        case .noteTaker:
            return isUnlocked ? "You added notes to \(value) sunscreen logs." : "Add notes to \(id.targetValue) sunscreen logs."
        case .reapplyRelay:
            return isUnlocked ? "You checked in \(value) reapplications in one day." : "Log \(id.targetValue) reapply check-ins on one day."
        case .highUVHero:
            return isUnlocked ? "You were protected on \(value) verified higher-UV days." : "Log protection on \(id.targetValue) days with verified high UV."
        case .homeBase:
            return isUnlocked ? "Your leave-home reminder has a saved home base." : "Turn on leave-home reminders and save your home base."
        case .liveSignal:
            return isUnlocked ? "Daily UV briefing is enabled for morning guidance." : "Turn on Daily UV Briefing in Settings."
        case .bottleDetective:
            return isUnlocked ? "You used the product scanner to prefill an SPF log." : "Scan a sunscreen bottle and use the SPF in a log."
        }
    }

    private static func seasonalLoggedDayCount(
        _ window: SeasonalWindow,
        records: [DailyRecord],
        around now: Date,
        calendar: Calendar
    ) -> Int {
        loggedDays(in: seasonalInterval(window, around: now, calendar: calendar), records: records, calendar: calendar).count
    }

    private static func highUVProtectedDayCount(
        records: [DailyRecord],
        historicalUVIndexes: [Date: Int],
        calendar: Calendar
    ) -> Int {
        let normalizedUVIndexes = historicalUVIndexes.reduce(into: [Date: Int]()) { result, entry in
            let day = calendar.startOfDay(for: entry.key)
            result[day] = max(result[day] ?? 0, entry.value)
        }
        return records.reduce(into: 0) { result, record in
            guard let verifiedIndex = normalizedUVIndexes[calendar.startOfDay(for: record.startOfDay)],
                  verifiedIndex >= 6 else {
                return
            }
            result += 1
        }
    }

    private static func cappedCurrentValue(_ value: Int, targetValue: Int) -> Int {
        max(0, min(value, targetValue))
    }

    private static func completedWeekendCount(
        records: [DailyRecord],
        calendar: Calendar
    ) -> Int {
        var weekdaysBySaturday: [Date: Set<Int>] = [:]

        for record in records {
            let day = calendar.startOfDay(for: record.startOfDay)
            let weekday = calendar.component(.weekday, from: day)

            switch weekday {
            case 7:
                weekdaysBySaturday[day, default: []].insert(7)
            case 1:
                let saturday = calendar.date(byAdding: .day, value: -1, to: day) ?? day
                weekdaysBySaturday[calendar.startOfDay(for: saturday), default: []].insert(1)
            default:
                continue
            }
        }

        return weekdaysBySaturday.values.filter { weekdays in
            weekdays.contains(7) && weekdays.contains(1)
        }.count
    }

    private enum SeasonalWindow {
        case summer
        case winter
    }

    private static func challengeInterval(
        for id: SunclubChallengeID,
        around now: Date,
        calendar: Calendar
    ) -> DateInterval {
        let year = calendar.component(.year, from: now)

        switch id {
        case .summerShield:
            return dateInterval(
                start: DateComponents(year: year, month: 6, day: 1),
                end: DateComponents(year: year, month: 8, day: 31, hour: 23, minute: 59, second: 59),
                calendar: calendar
            )
        case .uvAwarenessWeek:
            return dateInterval(
                start: DateComponents(year: year, month: 7, day: 1),
                end: DateComponents(year: year, month: 7, day: 7, hour: 23, minute: 59, second: 59),
                calendar: calendar
            )
        case .winterSkin:
            return dateInterval(
                start: DateComponents(year: year, month: 12, day: 1),
                end: DateComponents(year: year + 1, month: 2, day: 28, hour: 23, minute: 59, second: 59),
                calendar: calendar
            )
        }
    }

    private static func challengeTargetValue(for id: SunclubChallengeID) -> Int {
        switch id {
        case .summerShield:
            return 90
        case .uvAwarenessWeek:
            return 7
        case .winterSkin:
            return 60
        }
    }

    private static func challengeDetail(for id: SunclubChallengeID) -> String {
        switch id {
        case .summerShield:
            return "Protect all summer long with 90 logged days."
        case .uvAwarenessWeek:
            return "Keep the streak perfect for the first week of July."
        case .winterSkin:
            return "Stay consistent through dry, low-sun months."
        }
    }

    private static func seasonalInterval(
        _ window: SeasonalWindow,
        around now: Date,
        calendar: Calendar
    ) -> DateInterval {
        let year = calendar.component(.year, from: now)

        switch window {
        case .summer:
            return dateInterval(
                start: DateComponents(year: year, month: 6, day: 1),
                end: DateComponents(year: year, month: 8, day: 31, hour: 23, minute: 59, second: 59),
                calendar: calendar
            )
        case .winter:
            return dateInterval(
                start: DateComponents(year: year, month: 12, day: 1),
                end: DateComponents(year: year + 1, month: 2, day: 28, hour: 23, minute: 59, second: 59),
                calendar: calendar
            )
        }
    }

    private static func dateInterval(
        start: DateComponents,
        end: DateComponents,
        calendar: Calendar
    ) -> DateInterval {
        let resolvedStart = calendar.date(from: start) ?? Date.distantPast
        let resolvedEnd = calendar.date(from: end) ?? resolvedStart
        return DateInterval(start: resolvedStart, end: resolvedEnd)
    }

    private static func loggedDays(
        in interval: DateInterval,
        records: [DailyRecord],
        calendar: Calendar
    ) -> Set<Date> {
        Set(
            records
                .map { calendar.startOfDay(for: $0.startOfDay) }
                .filter { interval.contains($0) }
        )
    }

    private static func averageStreakLength(
        from days: [Date],
        calendar: Calendar
    ) -> Double {
        let sortedDays = Set(days.map { calendar.startOfDay(for: $0) }).sorted()
        guard let first = sortedDays.first else {
            return 0
        }

        var streakLengths: [Int] = []
        var currentStreak = 1
        var previous = first

        for day in sortedDays.dropFirst() {
            let expected = calendar.date(byAdding: .day, value: 1, to: previous) ?? previous
            if calendar.isDate(expected, inSameDayAs: day) {
                currentStreak += 1
            } else {
                streakLengths.append(currentStreak)
                currentStreak = 1
            }
            previous = day
        }

        streakLengths.append(currentStreak)
        let total = streakLengths.reduce(0, +)
        return streakLengths.isEmpty ? 0 : Double(total) / Double(streakLengths.count)
    }

    private static func spfDistribution(from records: [DailyRecord]) -> [SunclubSPFDistributionEntry] {
        Dictionary(grouping: records.compactMap { record -> Int? in
            record.spfLevel
        }, by: { $0 })
        .map { key, values in
            SunclubSPFDistributionEntry(spf: key, count: values.count)
        }
        .sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.spf < $1.spf
        }
    }

    private static func monthlyConsistency(
        from records: [DailyRecord],
        interval: DateInterval,
        calendar: Calendar
    ) -> [SunclubMonthlyConsistencyEntry] {
        var monthCursor = calendar.date(
            from: calendar.dateComponents([.year, .month], from: interval.start)
        ) ?? interval.start
        let normalizedDays = Set(records.map { calendar.startOfDay(for: $0.startOfDay) })
        var entries: [SunclubMonthlyConsistencyEntry] = []

        while monthCursor <= interval.end {
            guard let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: monthCursor)
            ),
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
            let range = calendar.range(of: .day, in: .month, for: monthStart) else {
                break
            }

            let protectedDays = normalizedDays.filter { $0 >= monthStart && $0 < monthEnd }.count
            entries.append(
                SunclubMonthlyConsistencyEntry(
                    monthIndex: calendar.component(.month, from: monthStart),
                    monthLabel: monthStart.formatted(.dateTime.month(.abbreviated)),
                    protectedDays: protectedDays,
                    totalDays: range.count
                )
            )
            monthCursor = monthEnd
        }

        return entries
    }

}
