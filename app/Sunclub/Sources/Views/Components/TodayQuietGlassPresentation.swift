import Foundation

@MainActor
struct TodayQuietGlassLogPresentation {
    let title: String
    let detail: String
    let statusIdentifier: String
    let reminderText: String?

    init(
        record: DailyRecord?,
        now: Date,
        remindersEnabled: Bool,
        reapplyPlan: ReapplyReminderPlan,
        calendar: Calendar = .current
    ) {
        title = record.map { record in
            let latest = max(record.verifiedAt, record.lastReappliedAt ?? record.verifiedAt)
            return "Logged at \(latest.formatted(date: .omitted, time: .shortened))"
        } ?? "Not logged"
        statusIdentifier = record == nil ? "timeline.todayStatus" : "home.todayStatus"

        if let record {
            let spf = record.spfLevel.map { "SPF \($0)" }
            let savedAreas = SunManualLogInput.coveredAreas(in: record.notes)
            let areas = SunManualLogInput.coveredAreas.filter { savedAreas.contains($0) }
            detail = [spf, areas.isEmpty ? nil : areas.joined(separator: " & ")]
                .compactMap { $0 }.joined(separator: " · ")
        } else {
            detail = ""
        }

        reminderText = remindersEnabled ? Self.reminder(record: record, now: now, plan: reapplyPlan, calendar: calendar) : nil
    }

    private static func reminder(
        record: DailyRecord?,
        now: Date,
        plan: ReapplyReminderPlan,
        calendar: Calendar
    ) -> String? {
        guard let record else {
            return nil
        }
        let base = max(record.lastReappliedAt ?? record.verifiedAt, record.verifiedAt)
        guard calendar.isDate(base, inSameDayAs: now) else {
            return nil
        }
        guard now < ReminderPlanner.estimatedSunset(for: now, calendar: calendar),
              let deadline = ReminderPlanner.reapplyFireDate(from: base, intervalMinutes: plan.intervalMinutes, calendar: calendar) else {
            return nil
        }
        let text = deadline <= now
            ? "Reapply reminder"
            : "Reapply around \(deadline.formatted(date: .omitted, time: .shortened))"
        return text
    }
}

struct TodayQuietGlassUVPresentation {
    let index: Int?
    let level: UVLevel
    let title: String
    let sourceLabel: String?
    let detail: String

    var gaugeFraction: Double {
        guard let index else { return 0 }
        return min(1, max(0, Double(index) / 11))
    }

    var accessibilityLabel: String {
        if let index {
            return ["\(title) \(index), \(level.displayName)", sourceLabel, detail]
                .compactMap { $0 }.joined(separator: ". ")
        }
        return "UV unavailable. \(detail)"
    }

    init(
        reading: UVReading?,
        forecast: SunclubUVForecast?,
        status: SunclubUVStatus,
        protectionWindow: SunclubUVProtectionWindow?,
        selectedDay: Date,
        now: Date,
        calendar: Calendar = .current
    ) {
        let isToday = calendar.isDate(selectedDay, inSameDayAs: now)
        let usableStatus = status.availability == .available
            && status.freshness != .stale && status.freshness != .unavailable
        let currentReading = isToday && usableStatus ? reading : nil
        let peak = isToday && usableStatus && forecast?.isAvailable == true ? forecast?.peakHour : nil

        if let currentReading, currentReading.index >= 0 {
            index = currentReading.index
            level = currentReading.level
            title = "UV index"
            sourceLabel = Self.sourceLabel(
                source: currentReading.source,
                location: status.source,
                updatedAt: status.updatedAt ?? currentReading.timestamp
            )
            detail = Self.recommendation(level: currentReading.level, window: protectionWindow)
        } else if let peak, peak.index >= 0, calendar.isDate(peak.date, inSameDayAs: selectedDay), let forecast {
            index = peak.index
            level = peak.level
            title = "Peak UV today"
            let source: UVReadingSource = forecast.sourceLabel == UVReadingSource.weatherKit.forecastLabel
                ? .weatherKit : (forecast.sourceLabel == UVReadingSource.cachedWeatherKit.forecastLabel ? .cachedWeatherKit : .localEstimate)
            sourceLabel = Self.sourceLabel(source: source, location: status.source, updatedAt: forecast.generatedAt)
            detail = Self.recommendation(level: peak.level, window: protectionWindow)
        } else {
            index = nil
            level = .unknown
            title = "UV unavailable"
            sourceLabel = nil
            detail = isToday
                ? Self.unavailableDetail(status: status)
                : "No UV reading was saved for this day. Open the forecast to browse available UV data."
        }
    }

    private static func sourceLabel(source: UVReadingSource, location: SunclubUVLocationSource?, updatedAt: Date?) -> String {
        let place = location.map { " · \($0.displayName(for: source))" } ?? ""
        let update = updatedAt.map { " · Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
        return "\(source.statusLabel)\(place)\(update)"
    }

    private static func recommendation(level: UVLevel, window: SunclubUVProtectionWindow?) -> String {
        guard let window else { return level.shortAdvice }
        let start = window.start.formatted(date: .omitted, time: .shortened)
        let end = window.end.formatted(date: .omitted, time: .shortened)
        return "Protection recommended \(start)–\(end). \(level.shortAdvice)"
    }

    private static func unavailableDetail(status: SunclubUVStatus) -> String {
        if status.freshness == .stale {
            let source = status.source.map { " for \($0.displayName)" } ?? ""
            let update = status.updatedAt.map {
                " Last updated \($0.formatted(date: .abbreviated, time: .shortened))."
            } ?? ""
            return "The cached UV reading\(source) is out of date.\(update) Refresh to try again."
        }
        if let source = status.source?.displayName {
            return "No Apple Weather or local UV value is available for \(source). Refresh to try again."
        }
        return "Sunclub could not calculate a local UV estimate. Refresh to try again."
    }
}
