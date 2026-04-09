import Foundation

enum SunclubGrowthAnalytics {
    static func achievements(
        records: [DailyRecord],
        changeBatches: [SunclubChangeBatch],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SunclubAchievement] {
        let longestStreak = CalendarAnalytics.longestStreak(
            records: records.map(\.startOfDay),
            calendar: calendar
        )
        let hasReapplied = records.contains(where: \.hasReapplied)
        let hasBackfilled = changeBatches.contains { $0.kind == .historyBackfill }
        let summerLoggedDays = loggedDays(in: seasonalInterval(.summer, around: now, calendar: calendar), records: records, calendar: calendar).count
        let winterLoggedDays = loggedDays(in: seasonalInterval(.winter, around: now, calendar: calendar), records: records, calendar: calendar).count

        return SunclubAchievementID.allCases.map { id in
            let currentValue: Int
            let isUnlocked: Bool
            let detail: String
            let shareBlurb: String

            switch id {
            case .streak7, .streak30, .streak100, .streak365:
                currentValue = longestStreak
                isUnlocked = longestStreak >= id.targetValue
                detail = isUnlocked
                    ? "Your longest streak reached \(longestStreak) days."
                    : "Reach a \(id.targetValue)-day streak to unlock this badge."
                shareBlurb = "I unlocked \(id.title) in Sunclub."
            case .firstReapply:
                currentValue = hasReapplied ? 1 : 0
                isUnlocked = hasReapplied
                detail = isUnlocked
                    ? "You logged your first reapply check-in."
                    : "Log a reapply to unlock this badge."
                shareBlurb = "I unlocked \(id.title) in Sunclub."
            case .firstBackfill:
                currentValue = hasBackfilled ? 1 : 0
                isUnlocked = hasBackfilled
                detail = isUnlocked
                    ? "You repaired your history with a backfill."
                    : "Backfill a missing day to unlock this badge."
                shareBlurb = "I unlocked \(id.title) in Sunclub."
            case .summerSurvivor:
                currentValue = summerLoggedDays
                isUnlocked = summerLoggedDays >= id.targetValue
                detail = isUnlocked
                    ? "You stayed protected through \(summerLoggedDays) summer days."
                    : "Log \(id.targetValue) days during June through August."
                shareBlurb = "I unlocked \(id.title) in Sunclub."
            case .winterWarrior:
                currentValue = winterLoggedDays
                isUnlocked = winterLoggedDays >= id.targetValue
                detail = isUnlocked
                    ? "You kept winter protection going for \(winterLoggedDays) days."
                    : "Log \(id.targetValue) days during December through February."
                shareBlurb = "I unlocked \(id.title) in Sunclub."
            }

            return SunclubAchievement(
                id: id,
                title: id.title,
                detail: detail,
                symbolName: id.symbolName,
                currentValue: currentValue,
                targetValue: id.targetValue,
                isUnlocked: isUnlocked,
                shareBlurb: shareBlurb
            )
        }
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
        let highUVProtectedDays = filteredRecords.reduce(into: 0) { result, record in
            guard middayUVLevel(for: record.startOfDay, calendar: calendar).rawValue >= UVLevel.high.rawValue else {
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

    static func localFriendSnapshot(
        preferredName: String,
        records: [DailyRecord],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SunclubFriendSnapshot {
        let recordedDays = records.map(\.startOfDay)
        let currentStreak = CalendarAnalytics.currentStreak(records: recordedDays, now: now, calendar: calendar)
        let longestStreak = CalendarAnalytics.longestStreak(records: recordedDays, calendar: calendar)
        let hasLoggedToday = Set(recordedDays.map { calendar.startOfDay(for: $0) }).contains(calendar.startOfDay(for: now))
        let resolvedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let seasonStyle = seasonalStyle(for: now, calendar: calendar)

        return SunclubFriendSnapshot(
            name: resolvedName.isEmpty ? "Sunclub Friend" : resolvedName,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            hasLoggedToday: hasLoggedToday,
            lastSharedAt: now,
            seasonStyle: seasonStyle
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

    private static func middayUVLevel(for date: Date, calendar: Calendar) -> UVLevel {
        let midday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        return UVLevel.from(index: UVIndexService.estimatedUVIndex(at: midday, calendar: calendar))
    }
}

enum SunclubFriendCodeCodec {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode(_ snapshot: SunclubFriendSnapshot) throws -> String {
        let payload = try encoder.encode(snapshot)
        return payload.base64EncodedString()
    }

    static func decode(_ code: String) throws -> SunclubFriendSnapshot {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed) else {
            throw SunclubFriendCodeError.invalidCode
        }

        do {
            return try decoder.decode(SunclubFriendSnapshot.self, from: data)
        } catch {
            throw SunclubFriendCodeError.invalidCode
        }
    }
}

enum SunclubFriendCodeError: LocalizedError {
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "That friend code could not be read."
        }
    }
}

private extension UVLevel {
    var rawValue: Int {
        switch self {
        case .low:
            return 0
        case .moderate:
            return 1
        case .high:
            return 2
        case .veryHigh:
            return 3
        case .extreme:
            return 4
        case .unknown:
            return -1
        }
    }
}
