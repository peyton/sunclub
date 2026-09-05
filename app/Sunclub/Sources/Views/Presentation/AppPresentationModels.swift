import Foundation

struct HomeTodayMetadataRow: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let symbolName: String

    var accessibilityLabel: String {
        "\(title): \(value)"
    }
}

struct HomeTodayCardPresentation: Equatable {
    let title: String
    let detail: String
    let logBadgeText: String?
    let streakRiskBadgeText: String?
    let uvHeadline: String?
    let uvSymbolName: String?
    let metadataRows: [HomeTodayMetadataRow]

    var accessibilityValue: String {
        ([title, detail] + metadataRows.map(\.accessibilityLabel)).joined(separator: ". ")
    }
}

struct HomeRecoveryAction: Equatable, Identifiable {
    enum Kind: String {
        case logToday
        case backfillYesterday
    }

    let kind: Kind
    let title: String
    let detail: String
    let buttonTitle: String

    var id: Kind { kind }
}

enum HomeDailyPlanTone: Equatable {
    case calm
    case action
    case warning
    case complete
}

struct HomeDailyPlanFact: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let symbolName: String

    var accessibilityLabel: String {
        "\(title): \(value)"
    }
}

struct HomeDailyPlanPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String
    let action: HomeDailyPlanAction
    let symbolName: String
    let tone: HomeDailyPlanTone
    let facts: [HomeDailyPlanFact]

    var accessibilityValue: String {
        ([title, detail] + facts.map(\.accessibilityLabel)).joined(separator: ". ")
    }
}

struct DailyReminderPreview: Equatable {
    let fireDate: Date
    let summary: String
}

struct ReapplyReminderPlan: Equatable {
    let baseIntervalMinutes: Int
    let intervalMinutes: Int
    let notificationTitle: String
    let notificationBody: String
    let confirmationText: String
    let confirmationSymbolName: String
    let fireDate: Date?
    let isElevated: Bool

    var intervalSummary: String {
        Self.formattedInterval(intervalMinutes)
    }

    var shouldScheduleNotification: Bool {
        fireDate != nil
    }

    init(
        baseIntervalMinutes: Int,
        uvReading: UVReading?,
        now: Date = Date(),
        calendar: Calendar = Calendar.current
    ) {
        let level = uvReading?.level ?? .unknown
        let labelInterval = max(30, min(480, baseIntervalMinutes))
        let isElevated = level.reapplyLabelPrefix != nil
        let scheduledFireDate = ReminderPlanner.reapplyFireDate(
            from: now,
            intervalMinutes: labelInterval,
            calendar: calendar
        )

        self.baseIntervalMinutes = labelInterval
        self.intervalMinutes = labelInterval
        self.isElevated = isElevated
        self.notificationTitle = "Time to check your sunscreen"
        self.fireDate = scheduledFireDate

        if isElevated {
            self.notificationBody = "UV is elevated. Follow your sunscreen label, and reapply after swimming, sweating, or toweling off."
        } else {
            self.notificationBody = "Follow your sunscreen label, and reapply after swimming, sweating, or toweling off."
        }

        if scheduledFireDate != nil {
            if let prefix = level.reapplyLabelPrefix {
                self.confirmationText = "\(prefix): label check in \(Self.formattedInterval(labelInterval))"
            } else {
                self.confirmationText = "Label check in \(Self.formattedInterval(labelInterval))"
            }
            self.confirmationSymbolName = "timer"
        } else {
            self.confirmationText = "No reapply reminder today after sunset."
            self.confirmationSymbolName = "moon.stars"
        }
    }

    init(snoozeMinutes: Int, now: Date = Date(), calendar: Calendar = Calendar.current) {
        let clampedMinutes = max(5, min(60, snoozeMinutes))
        self.baseIntervalMinutes = clampedMinutes
        self.intervalMinutes = clampedMinutes
        self.notificationTitle = "Reapply reminder"
        self.notificationBody = "Snoozed for \(Self.formattedInterval(clampedMinutes)). Open Sunclub when you reapply."
        self.confirmationText = "Reminder snoozed for \(Self.formattedInterval(clampedMinutes))"
        self.confirmationSymbolName = "timer"
        self.fireDate = calendar.date(byAdding: .minute, value: clampedMinutes, to: now)
        self.isElevated = false
    }

    private static func formattedInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
    }
}

struct VerificationSuccessPresentation: Equatable {
    let streak: Int
    let isPersonalBest: Bool
    let canAddDetails: Bool
    let title: String

    init(streak: Int, isPersonalBest: Bool = false, canAddDetails: Bool = false, title: String = SunclubCopy.Success.defaultTitle) {
        self.streak = streak
        self.isPersonalBest = isPersonalBest
        self.canAddDetails = canAddDetails
        self.title = title
    }

    var detail: String {
        SunclubCopy.Success.streakDetail(streak)
    }
}

struct ReapplyCheckInPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String
}

enum LiveUVActionKind: Equatable {
    case requestPermission
    case openSettings
    case refresh
}

struct LiveUVStatusPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String?
    let actionKind: LiveUVActionKind?
}

enum LeaveHomeReminderActionKind: Equatable {
    case setHomeFromCurrentLocation
    case requestAlwaysAuthorization
    case openSettings
}

enum LeaveHomeReminderTone: Equatable {
    case neutral
    case success
    case warning
}

struct LeaveHomeReminderStatusPresentation: Equatable {
    let title: String
    let detail: String
    let symbol: String
    let tone: LeaveHomeReminderTone
    let actionTitle: String?
    let actionKind: LeaveHomeReminderActionKind?
}

struct CloudSyncStatusPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String?
    let pendingImportedBatchCount: Int
}

struct ManualLogPrefill: Equatable {
    let spfLevel: Int?
    let notes: String
}

enum HomeAccountabilityActionKind: Equatable {
    case invite
    case poke
    case view
}

struct HomeAccountabilityFriendPresentation: Equatable, Identifiable {
    let id: UUID
    let name: String
    let status: String
    let streak: String
    let hasLoggedToday: Bool
}

struct HomeAccountabilityPresentation: Equatable {
    let title: String
    let detail: String
    let openCountText: String
    let loggedCountText: String
    let primaryActionTitle: String
    let primaryActionKind: HomeAccountabilityActionKind
    let primaryFriendID: UUID?
    let latestPokeText: String?
    let friends: [HomeAccountabilityFriendPresentation]
}

struct FutureDayPreview: Equatable {
    let suggestedSPF: Int
    let suggestionText: String
}

struct SunDayDetails: Equatable {
    let spfLevel: Int?
    let reapplyCount: Int
    let hasNotes: Bool

    var isHighProtection: Bool {
        (spfLevel ?? 0) >= 50
    }

    var isReapplyDense: Bool {
        reapplyCount >= 2
    }
}

struct TimelineBounds: Equatable {
    let startDay: Date
    let today: Date
    let futureEndDay: Date
    let forecastDays: Set<Date>
    let visibleDays: [Date]

    init(
        today: Date,
        forecastDays: [Date],
        calendar: Calendar
    ) {
        let todayStart = calendar.startOfDay(for: today)
        let normalizedForecastDays = Set(forecastDays.map { calendar.startOfDay(for: $0) })
        let forecastEndDay = normalizedForecastDays
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 > todayStart }
            .max()

        self.startDay = calendar.date(byAdding: .day, value: -365, to: todayStart) ?? todayStart
        self.today = todayStart
        self.futureEndDay = max(todayStart, forecastEndDay ?? todayStart)
        self.forecastDays = normalizedForecastDays
        self.visibleDays = Self.visibleDays(
            from: startDay,
            through: todayStart,
            forecastDays: normalizedForecastDays,
            calendar: calendar
        )
    }

    func clamp(_ day: Date, calendar: Calendar) -> Date {
        let boundedDay = min(max(calendar.startOfDay(for: day), startDay), futureEndDay)
        guard boundedDay > today else {
            return boundedDay
        }
        if forecastDays.contains(boundedDay) {
            return boundedDay
        }

        return nearestFutureForecastDay(to: boundedDay) ?? today
    }

    func canSelect(_ day: Date, calendar: Calendar) -> Bool {
        let normalized = calendar.startOfDay(for: day)
        if normalized < startDay || normalized > futureEndDay {
            return false
        }
        return normalized <= today || forecastDays.contains(normalized)
    }

    private static func visibleDays(
        from startDay: Date,
        through today: Date,
        forecastDays: Set<Date>,
        calendar: Calendar
    ) -> [Date] {
        var days: [Date] = []
        var cursor = startDay

        while cursor <= today {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        let futureForecastDays = forecastDays
            .filter { $0 > today }
            .sorted()
        return days + futureForecastDays
    }

    private func nearestFutureForecastDay(to day: Date) -> Date? {
        forecastDays
            .filter { $0 > today }
            .sorted()
            .min { first, second in
                let firstDistance = abs(first.timeIntervalSince(day))
                let secondDistance = abs(second.timeIntervalSince(day))
                if firstDistance == secondDistance {
                    return first < second
                }
                return firstDistance < secondDistance
            }
    }
}

struct TimelineDayPartStatus: Equatable, Identifiable {
    let dayPart: DayPart
    let statusText: String
    let isCompleted: Bool
    let canLog: Bool

    var id: DayPart { dayPart }
}

struct TimelineDayLogSummary: Equatable {
    enum Category: Equatable {
        case past
        case today
        case future
    }

    let day: Date
    let category: Category
    let record: DailyRecord?
    let futurePreview: FutureDayPreview?
    let sunscreenStatusText: String
    let reapplyStatusText: String
    let notesStatusText: String?
    let factorsStatusText: String
    let dayPart: DayPart
    let loggingContext: AppLogContext
    let canLog: Bool
    let partStatuses: [TimelineDayPartStatus]
    let helperText: String?
}
