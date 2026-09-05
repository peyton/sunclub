import SwiftUI

struct TimelineAttentionContent {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let actionTitle: String
    let identifier: String
}

@MainActor
struct TimelineHomeSharedPresentation {
    let today: Date
    let homeDailyPlanPresentation: HomeDailyPlanPresentation
    let recordedDays: Set<Date>
    let currentStreakDays: Set<Date>
    let elevatedUVDays: Set<Date>
    let forecastUVLevels: [Date: UVLevel]
    let extrasDays: Set<Date>
    let logDetails: [Date: SunDayDetails]
    let visibleDays: [Date]
    let weekProgressDays: [SunWeekProgressDay]
    let eligibilityStart: Date
    let allowsFuture: Bool
    let uvReading: UVReading?
    let uvStatus: SunclubUVStatus
    let uvProtectionWindow: SunclubUVProtectionWindow?
    let weatherAttribution: SunclubWeatherAttribution?
    let currentStreak: Int
    let longestStreak: Int

    init(appState: AppState) {
        let referenceDate = appState.referenceDate
        let days = appState.timelineVisibleDays
        let recordSet = Set(appState.recordedDays)

        today = referenceDate
        homeDailyPlanPresentation = appState.homeDailyPlanPresentation
        recordedDays = recordSet
        currentStreakDays = Set(appState.currentStreakDays)
        elevatedUVDays = appState.elevatedUVDays
        forecastUVLevels = appState.timelineForecastUVLevels
        extrasDays = appState.daysWithExtras
        logDetails = appState.dailyDetailsForTimeline
        visibleDays = days
        weekProgressDays = Self.weekProgressDays(today: referenceDate, recordedDays: recordSet)
        eligibilityStart = CalendarAnalytics.eligibilityStart(
            records: Array(recordSet),
            now: referenceDate
        )
        allowsFuture = appState.timelineShowsFutureDays
        uvReading = appState.uvReading
        uvStatus = appState.uvStatus
        uvProtectionWindow = appState.uvProtectionWindow
        weatherAttribution = appState.weatherAttribution
        currentStreak = appState.currentStreak
        longestStreak = appState.longestStreak
    }

    private static func weekProgressDays(today: Date, recordedDays: Set<Date>) -> [SunWeekProgressDay] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }
            let dayStart = calendar.startOfDay(for: day)
            return SunWeekProgressDay(
                date: dayStart,
                isLogged: recordedDays.contains(dayStart),
                isToday: dayStart == todayStart,
                isFuture: dayStart > todayStart
            )
        }
    }
}

@MainActor
struct TimelineHomePresentation {
    let selectedDay: Date
    let today: Date
    let logSummary: TimelineDayLogSummary
    let homeDailyPlanPresentation: HomeDailyPlanPresentation
    let recordedDays: Set<Date>
    let currentStreakDays: Set<Date>
    let elevatedUVDays: Set<Date>
    let forecastUVLevels: [Date: UVLevel]
    let extrasDays: Set<Date>
    let logDetails: [Date: SunDayDetails]
    let visibleDays: [Date]
    let weekProgressDays: [SunWeekProgressDay]
    let eligibilityStart: Date
    let allowsFuture: Bool
    let uvReading: UVReading?
    let uvStatus: SunclubUVStatus
    let uvProtectionWindow: SunclubUVProtectionWindow?
    let uvForecast: SunclubUVForecast?
    let weatherAttribution: SunclubWeatherAttribution?
    let currentStreak: Int
    let longestStreak: Int

    init(
        appState: AppState,
        selectedDay requestedSelectedDay: Date? = nil,
        shared: TimelineHomeSharedPresentation? = nil
    ) {
        let sharedPresentation = shared ?? TimelineHomeSharedPresentation(appState: appState)
        let selected = appState.timelineClampedDay(requestedSelectedDay ?? appState.selectedDay)

        selectedDay = selected
        today = sharedPresentation.today
        logSummary = appState.timelineDayLogSummary(for: selected)
        homeDailyPlanPresentation = sharedPresentation.homeDailyPlanPresentation
        recordedDays = sharedPresentation.recordedDays
        currentStreakDays = sharedPresentation.currentStreakDays
        elevatedUVDays = sharedPresentation.elevatedUVDays
        forecastUVLevels = sharedPresentation.forecastUVLevels
        extrasDays = sharedPresentation.extrasDays
        logDetails = sharedPresentation.logDetails
        visibleDays = sharedPresentation.visibleDays
        weekProgressDays = sharedPresentation.weekProgressDays
        eligibilityStart = sharedPresentation.eligibilityStart
        allowsFuture = sharedPresentation.allowsFuture
        uvReading = sharedPresentation.uvReading
        uvStatus = sharedPresentation.uvStatus
        uvProtectionWindow = sharedPresentation.uvProtectionWindow
        uvForecast = appState.timelineUVForecast(for: selected)
        weatherAttribution = sharedPresentation.weatherAttribution
        currentStreak = sharedPresentation.currentStreak
        longestStreak = sharedPresentation.longestStreak
    }
}
