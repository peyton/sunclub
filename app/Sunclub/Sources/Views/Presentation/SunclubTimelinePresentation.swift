import Foundation

/// Read-only timeline algorithms, driven by one captured date and forecast bundle.
@MainActor
struct SunclubTimelinePresentation {
    let referenceDate: Date
    let calendar: Calendar
    let selectedDay: Date
    let records: [DailyRecord]
    let scannedSPFLevels: [Int]
    let reapplyIntervalMinutes: Int
    let uvReading: UVReading?
    let uvForecast: SunclubUVForecast?
    let forecastBundle: SunclubUVForecastBundle?

    private func startOfLocalDay(_ day: Date) -> Date { calendar.startOfDay(for: day) }
    private func dayPart(for date: Date) -> DayPart { DayPart.resolve(for: date, calendar: calendar) }
    private func record(for day: Date) -> DailyRecord? {
        records.first { calendar.isDate($0.startOfDay, inSameDayAs: day) }
    }

    var timelineShowsFutureDays: Bool {
        timelineBounds.futureEndDay > timelineBounds.today
    }

    var timelineAllowsFutureSelection: Bool {
        timelineShowsFutureDays
    }

    var timelineBounds: TimelineBounds {
        TimelineBounds(
            today: referenceDate,
            forecastDays: timelineForecastDates,
            calendar: calendar
        )
    }

    var timelineVisibleDays: [Date] {
        timelineBounds.visibleDays
    }

    var timelineForecastUVLevels: [Date: UVLevel] {
        guard let bundle = usableTimelineForecastBundle else {
            return [:]
        }

        let today = startOfLocalDay(referenceDate)
        var levels: [Date: UVLevel] = [:]

        for forecast in bundle.daily {
            let day = startOfLocalDay(forecast.day)
            guard day > today else {
                continue
            }
            levels[day] = forecast.level
        }

        let hoursByFutureDay = Dictionary(grouping: bundle.hourly) { hour in
            startOfLocalDay(hour.date)
        }
        for (day, hours) in hoursByFutureDay where day > today && levels[day] == nil {
            levels[day] = hours.max(by: { $0.index < $1.index })?.level
        }

        return levels
    }

    func timelineForecastUVLevel(for day: Date) -> UVLevel? {
        timelineForecastUVLevels[startOfLocalDay(day)]
    }

    func canSelectTimelineDay(_ day: Date) -> Bool {
        timelineBounds.canSelect(day, calendar: calendar)
    }

    func timelineClampedDay(_ day: Date) -> Date {
        timelineBounds.clamp(day, calendar: calendar)
    }

    func timelineUVForecast(for day: Date) -> SunclubUVForecast? {
        let dayStart = startOfLocalDay(day)
        let today = startOfLocalDay(referenceDate)

        if dayStart <= today {
            return uvForecast
        }

        guard canSelectTimelineDay(dayStart),
              let bundle = usableTimelineForecastBundle else {
            return nil
        }
        let readingSource = timelineReadingSource(for: bundle)

        let dayHours = bundle.hourly.filter { hour in
            calendar.isDate(hour.date, inSameDayAs: dayStart)
        }.map { hour in
            SunclubUVHourForecast(
                date: hour.date,
                index: hour.index,
                sourceLabel: readingSource.hourlySourceLabel
            )
        }
        if !dayHours.isEmpty {
            return makeTimelineUVForecast(
                generatedAt: bundle.generatedAt,
                sourceLabel: readingSource.forecastLabel,
                hours: dayHours
            )
        }

        guard let daily = bundle.daily.first(where: { forecast in
            calendar.isDate(forecast.day, inSameDayAs: dayStart)
        }) else {
            return nil
        }

        let peakDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart
        return makeTimelineUVForecast(
            generatedAt: bundle.generatedAt,
            sourceLabel: readingSource.forecastLabel,
            hours: [
                SunclubUVHourForecast(
                    date: peakDate,
                    index: daily.maxIndex,
                    sourceLabel: readingSource.hourlySourceLabel
                )
            ]
        )
    }

    func currentLogContext(
        for day: Date? = nil,
        source: LogSource = .manualLog,
        dayPart: DayPart? = nil
    ) -> AppLogContext {
        let targetDay = startOfLocalDay(day ?? selectedDay)
        let resolvedPart: DayPart
        if let dayPart {
            resolvedPart = dayPart
        } else if let existingRecord = record(for: targetDay) {
            resolvedPart = existingRecord.loggedDayPart(calendar: calendar)
        } else if calendar.isDate(targetDay, inSameDayAs: referenceDate) {
            resolvedPart = self.dayPart(for: referenceDate)
        } else {
            resolvedPart = .morning
        }

        return AppLogContext(date: targetDay, dayPart: resolvedPart, source: source)
    }

    func futureDayPreview(for day: Date) -> FutureDayPreview? {
        let dayStart = startOfLocalDay(day)
        let today = startOfLocalDay(referenceDate)
        guard dayStart > today, canSelectTimelineDay(dayStart) else {
            return nil
        }

        let suggestion = ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: dayStart,
            calendar: calendar,
            scannedSPFLevels: scannedSPFLevels
        )
        let spf = suggestion.defaultSPF ?? 30
        let interval = reapplyIntervalMinutes
        let intervalText = interval >= 60
            ? "every \(interval / 60)h" + (interval % 60 == 0 ? "" : " \(interval % 60)m")
            : "every \(interval) min"
        let text = "Plan SPF \(spf)+. Reapply \(intervalText) if you're outside."
        return FutureDayPreview(suggestedSPF: spf, suggestionText: text)
    }

    func timelineDayLogSummary(for day: Date) -> TimelineDayLogSummary {
        let dayStart = timelineBounds.clamp(day, calendar: calendar)
        let today = startOfLocalDay(referenceDate)
        let record = record(for: dayStart)
        let resolvedDayPart = resolvedTimelineDayPart(for: dayStart, record: record)
        let loggingContext = currentLogContext(for: dayStart, source: .timeline, dayPart: resolvedDayPart)

        if dayStart > today {
            let preview = futureDayPreview(for: dayStart)
            let spf = preview?.suggestedSPF ?? 30
            return TimelineDayLogSummary(
                day: dayStart,
                category: .future,
                record: nil,
                futurePreview: preview,
                sunscreenStatusText: "Plan SPF \(spf)+",
                reapplyStatusText: "Forecast ahead",
                notesStatusText: nil,
                factorsStatusText: "View only",
                dayPart: resolvedDayPart,
                loggingContext: loggingContext,
                canLog: false,
                partStatuses: timelinePartStatuses(
                    for: dayStart,
                    record: nil,
                    canLog: false
                ),
                helperText: "Cannot log future date. Choose today or earlier."
            )
        }

        let isToday = calendar.isDate(dayStart, inSameDayAs: today)
        let category: TimelineDayLogSummary.Category = isToday ? .today : .past

        if let record {
            let sunscreenText: String
            if let spfLevel = record.spfLevel {
                sunscreenText = "Logged · SPF \(spfLevel)"
            } else {
                sunscreenText = "Logged"
            }

            let reapplyText: String
            switch record.reapplyCount {
            case 0:
                reapplyText = "None"
            case 1:
                reapplyText = "1 check-in"
            default:
                reapplyText = "\(record.reapplyCount) check-ins"
            }

            let factorsText: String
            if isToday, let level = uvReading?.level {
                factorsText = "UV \(level.displayName)"
            } else {
                factorsText = record.method.displayName
            }

            return TimelineDayLogSummary(
                day: dayStart,
                category: category,
                record: record,
                futurePreview: nil,
                sunscreenStatusText: sunscreenText,
                reapplyStatusText: reapplyText,
                notesStatusText: record.trimmedNotes,
                factorsStatusText: factorsText,
                dayPart: resolvedDayPart,
                loggingContext: loggingContext,
                canLog: true,
                partStatuses: timelinePartStatuses(
                    for: dayStart,
                    record: record,
                    canLog: true
                ),
                helperText: nil
            )
        }

        let sunscreenText = isToday ? "Not logged — tap to log" : "Not logged — tap to backfill"
        let factorsText: String
        if isToday, let level = uvReading?.level {
            factorsText = "UV \(level.displayName)"
        } else {
            factorsText = "—"
        }

        return TimelineDayLogSummary(
            day: dayStart,
            category: category,
            record: nil,
            futurePreview: nil,
            sunscreenStatusText: sunscreenText,
            reapplyStatusText: "None",
            notesStatusText: nil,
            factorsStatusText: factorsText,
            dayPart: resolvedDayPart,
            loggingContext: loggingContext,
            canLog: true,
            partStatuses: timelinePartStatuses(
                for: dayStart,
                record: nil,
                canLog: true
            ),
            helperText: nil
        )
    }

    private func resolvedTimelineDayPart(for day: Date, record: DailyRecord?) -> DayPart {
        if let record {
            return record.loggedDayPart(calendar: calendar)
        }
        if calendar.isDate(day, inSameDayAs: referenceDate) {
            return dayPart(for: referenceDate)
        }
        return .morning
    }

    private func timelinePartStatuses(
        for day: Date,
        record: DailyRecord?,
        canLog: Bool
    ) -> [TimelineDayPartStatus] {
        let isToday = calendar.isDate(day, inSameDayAs: referenceDate)
        let currentPart = dayPart(for: referenceDate)

        return DayPart.allCases.map { part in
            if !canLog {
                return TimelineDayPartStatus(
                    dayPart: part,
                    statusText: "Cannot log future date",
                    isCompleted: false,
                    canLog: false
                )
            }

            if let record, record.isLogged(in: part, calendar: calendar) {
                let suffix = record.spfLevel.map { " · SPF \($0)" } ?? ""
                return TimelineDayPartStatus(
                    dayPart: part,
                    statusText: "Logged\(suffix)",
                    isCompleted: true,
                    canLog: true
                )
            }

            if isToday {
                if part.order < currentPart.order {
                    return TimelineDayPartStatus(
                        dayPart: part,
                        statusText: "Missed window",
                        isCompleted: false,
                        canLog: true
                    )
                }
                if part.order > currentPart.order {
                    return TimelineDayPartStatus(
                        dayPart: part,
                        statusText: "Later today",
                        isCompleted: false,
                        canLog: true
                    )
                }
                return TimelineDayPartStatus(
                    dayPart: part,
                    statusText: "Ready now",
                    isCompleted: false,
                    canLog: true
                )
            }

            return TimelineDayPartStatus(
                dayPart: part,
                statusText: "Not logged",
                isCompleted: false,
                canLog: true
            )
        }
    }

    var daysWithExtras: Set<Date> {
        var set: Set<Date> = []
        for record in records where record.trimmedNotes != nil || record.reapplyCount > 0 {
            set.insert(startOfLocalDay(record.startOfDay))
        }
        return set
    }

    var dailyDetailsForTimeline: [Date: SunDayDetails] {
        var map: [Date: SunDayDetails] = [:]
        for record in records {
            let day = startOfLocalDay(record.startOfDay)
            map[day] = SunDayDetails(
                spfLevel: record.spfLevel,
                reapplyCount: record.reapplyCount,
                hasNotes: record.trimmedNotes != nil
            )
        }
        return map
    }

    var elevatedUVDays: Set<Date> {
        var set: Set<Date> = []

        if let daily = forecastBundle?.daily {
            for day in daily where day.level == .high || day.level == .veryHigh || day.level == .extreme {
                set.insert(calendar.startOfDay(for: day.day))
            }
        }

        if let forecast = uvForecast {
            let today = calendar.startOfDay(for: referenceDate)
            let todayElevated = forecast.hours.contains { hour in
                switch hour.level {
                case .high, .veryHigh, .extreme:
                    return true
                default:
                    return false
                }
            }
            if todayElevated {
                set.insert(today)
            }
        }

        return set
    }

    var dailyUVForecast: [SunclubUVDayForecast] {
        forecastBundle?.daily ?? []
    }

    private var timelineForecastDates: [Date] {
        guard let bundle = usableTimelineForecastBundle else {
            return []
        }

        return bundle.daily.map(\.day) + bundle.hourly.map(\.date)
    }

    private var usableTimelineForecastBundle: SunclubUVForecastBundle? {
        guard let bundle = forecastBundle,
              bundle.isFresh(now: referenceDate, ttl: UVIndexService.lastKnownDataMaxAge) else {
            return nil
        }
        return bundle
    }

    private func timelineReadingSource(for bundle: SunclubUVForecastBundle) -> UVReadingSource {
        guard bundle.isFresh(now: referenceDate, ttl: UVIndexService.verifiedDataMaxAge),
              uvReading?.source == .weatherKit,
              uvReading?.timestamp == bundle.generatedAt else {
            return .cachedWeatherKit
        }
        return .weatherKit
    }

    private func makeTimelineUVForecast(
        generatedAt: Date,
        sourceLabel: String,
        hours: [SunclubUVHourForecast]
    ) -> SunclubUVForecast {
        let peakHour = hours.max(by: { $0.index < $1.index })
        return SunclubUVForecast(
            generatedAt: generatedAt,
            sourceLabel: sourceLabel,
            hours: hours,
            peakHour: peakHour,
            recommendation: peakHour?.level.shortAdvice ?? ""
        )
    }

}
