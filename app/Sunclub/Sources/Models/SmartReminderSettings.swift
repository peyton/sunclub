import Foundation

enum ReminderScheduleKind: String, CaseIterable, Codable, Identifiable {
    case weekday
    case weekend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekday:
            return "Weekday Reminder"
        case .weekend:
            return "Weekend Reminder"
        }
    }

    var shortTitle: String {
        switch self {
        case .weekday:
            return "Weekdays"
        case .weekend:
            return "Weekends"
        }
    }
}

struct ReminderTime: Codable, Equatable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
    }

    var totalMinutes: Int {
        (hour * 60) + minute
    }
}

struct HomeLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct LeaveHomeReminderSettings: Codable, Equatable {
    static let defaultRadiusMeters = 150.0

    var isEnabled: Bool
    var homeLocation: HomeLocation?
    var radiusMeters: Double

    init(
        isEnabled: Bool = false,
        homeLocation: HomeLocation? = nil,
        radiusMeters: Double = LeaveHomeReminderSettings.defaultRadiusMeters
    ) {
        self.isEnabled = isEnabled
        self.homeLocation = homeLocation
        self.radiusMeters = max(50, min(300, radiusMeters))
    }
}

struct SmartReminderSettings: Codable, Equatable {
    var weekdayTime: ReminderTime
    var weekendTime: ReminderTime
    var followsTravelTimeZone: Bool
    var anchoredTimeZoneIdentifier: String
    var streakRiskEnabled: Bool
    var leaveHomeReminder: LeaveHomeReminderSettings

    init(
        weekdayTime: ReminderTime,
        weekendTime: ReminderTime,
        followsTravelTimeZone: Bool = true,
        anchoredTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier,
        streakRiskEnabled: Bool = true,
        leaveHomeReminder: LeaveHomeReminderSettings = LeaveHomeReminderSettings()
    ) {
        self.weekdayTime = weekdayTime
        self.weekendTime = weekendTime
        self.followsTravelTimeZone = followsTravelTimeZone
        self.anchoredTimeZoneIdentifier = anchoredTimeZoneIdentifier
        self.streakRiskEnabled = streakRiskEnabled
        self.leaveHomeReminder = leaveHomeReminder
    }

    static func legacyDefault(
        hour: Int,
        minute: Int,
        timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
    ) -> SmartReminderSettings {
        let time = ReminderTime(hour: hour, minute: minute)
        return SmartReminderSettings(
            weekdayTime: time,
            weekendTime: time,
            followsTravelTimeZone: true,
            anchoredTimeZoneIdentifier: timeZoneIdentifier,
            streakRiskEnabled: true,
            leaveHomeReminder: LeaveHomeReminderSettings()
        )
    }

    var anchoredTimeZone: TimeZone {
        TimeZone(identifier: anchoredTimeZoneIdentifier) ?? .autoupdatingCurrent
    }

    func notificationTimeZone(currentTimeZone: TimeZone = .autoupdatingCurrent) -> TimeZone {
        followsTravelTimeZone ? currentTimeZone : anchoredTimeZone
    }

    func time(for kind: ReminderScheduleKind) -> ReminderTime {
        switch kind {
        case .weekday:
            return weekdayTime
        case .weekend:
            return weekendTime
        }
    }

    func time(for date: Date, calendar: Calendar = Calendar.current) -> ReminderTime {
        time(for: ReminderPlanner.scheduleKind(for: date, calendar: calendar))
    }

    func normalized(
        fallbackHour: Int,
        fallbackMinute: Int,
        currentTimeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
    ) -> SmartReminderSettings {
        let resolvedTimeZoneIdentifier = anchoredTimeZoneIdentifier.isEmpty ? currentTimeZoneIdentifier : anchoredTimeZoneIdentifier

        return SmartReminderSettings(
            weekdayTime: weekdayTime,
            weekendTime: weekendTime,
            followsTravelTimeZone: followsTravelTimeZone,
            anchoredTimeZoneIdentifier: resolvedTimeZoneIdentifier,
            streakRiskEnabled: streakRiskEnabled,
            leaveHomeReminder: leaveHomeReminder
        )
    }

    private enum CodingKeys: String, CodingKey {
        case weekdayTime
        case weekendTime
        case followsTravelTimeZone
        case anchoredTimeZoneIdentifier
        case streakRiskEnabled
        case leaveHomeReminder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let weekday = try container.decodeIfPresent(ReminderTime.self, forKey: .weekdayTime) ?? ReminderTime(hour: 8, minute: 0)
        weekdayTime = weekday
        weekendTime = try container.decodeIfPresent(ReminderTime.self, forKey: .weekendTime) ?? weekday
        followsTravelTimeZone = try container.decodeIfPresent(Bool.self, forKey: .followsTravelTimeZone) ?? true
        anchoredTimeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .anchoredTimeZoneIdentifier)
            ?? TimeZone.autoupdatingCurrent.identifier
        streakRiskEnabled = try container.decodeIfPresent(Bool.self, forKey: .streakRiskEnabled) ?? true
        leaveHomeReminder = try container.decodeIfPresent(LeaveHomeReminderSettings.self, forKey: .leaveHomeReminder)
            ?? LeaveHomeReminderSettings()
    }
}

extension Settings {
    var smartReminderSettings: SmartReminderSettings {
        get {
            guard let smartReminderSettingsData,
                  let decoded = try? JSONDecoder().decode(SmartReminderSettings.self, from: smartReminderSettingsData) else {
                return SmartReminderSettings.legacyDefault(hour: reminderHour, minute: reminderMinute)
            }

            return decoded.normalized(fallbackHour: reminderHour, fallbackMinute: reminderMinute)
        }
        set {
            let normalized = newValue.normalized(fallbackHour: reminderHour, fallbackMinute: reminderMinute)
            reminderHour = normalized.weekdayTime.hour
            reminderMinute = normalized.weekdayTime.minute
            smartReminderSettingsData = try? JSONEncoder().encode(normalized)
        }
    }
}
