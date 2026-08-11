import Foundation
import SwiftData

struct SunclubSelectedUVPlace: Codable, Equatable, Sendable {
    let displayName: String
    let latitude: Double
    let longitude: Double

    init(displayName: String, latitude: Double, longitude: Double) {
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.latitude = latitude
        self.longitude = longitude
    }

    private enum CodingKeys: String, CodingKey {
        case displayName
        case latitude
        case longitude
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            displayName: try container.decode(String.self, forKey: .displayName),
            latitude: try container.decode(Double.self, forKey: .latitude),
            longitude: try container.decode(Double.self, forKey: .longitude)
        )
    }
}

enum SunclubSunscreenWaterResistance: Int, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case none = 0
    case fortyMinutes = 40
    case eightyMinutes = 80

    var durationMinutes: Int? {
        self == .none ? nil : rawValue
    }
}

struct SunclubSunscreenProfile: Codable, Equatable, Sendable {
    let name: String
    let spf: Int
    let waterResistance: SunclubSunscreenWaterResistance

    init(
        name: String,
        spf: Int,
        waterResistance: SunclubSunscreenWaterResistance = .none
    ) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.spf = max(1, min(spf, 100))
        self.waterResistance = waterResistance
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case spf
        case waterResistance
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            spf: try container.decode(Int.self, forKey: .spf),
            waterResistance: try container.decode(SunclubSunscreenWaterResistance.self, forKey: .waterResistance)
        )
    }
}

@Model
final class Settings {
    @Attribute(.unique) var id: UUID
    var hasCompletedOnboarding: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var weeklyHour: Int
    var weeklyWeekday: Int
    var dailyPhraseState: Data?
    var weeklyPhraseState: Data?
    var smartReminderSettingsData: Data?
    var longestStreak: Int
    var reapplyReminderEnabled: Bool
    var reapplyIntervalMinutes: Int
    var lastReminderScheduleAt: Date?
    var usesLiveUV: Bool = false
    var selectedUVPlaceData: Data?
    var sunscreenProfileData: Data?
    var restorablePreferencesData: Data?

    init() {
        self.id = UUID()
        self.hasCompletedOnboarding = false
        self.reminderHour = 8
        self.reminderMinute = 0
        self.weeklyHour = 18
        self.weeklyWeekday = 1
        self.dailyPhraseState = nil
        self.weeklyPhraseState = nil
        self.smartReminderSettingsData = nil
        self.longestStreak = 0
        self.reapplyReminderEnabled = false
        self.reapplyIntervalMinutes = 120
        self.lastReminderScheduleAt = nil
        self.usesLiveUV = false
        self.selectedUVPlaceData = nil
        self.sunscreenProfileData = nil
        self.restorablePreferencesData = nil
    }

    var selectedUVPlace: SunclubSelectedUVPlace? {
        get { Self.decode(SunclubSelectedUVPlace.self, from: selectedUVPlaceData) }
        set { selectedUVPlaceData = Self.encode(newValue) }
    }

    var sunscreenProfile: SunclubSunscreenProfile? {
        get { Self.decode(SunclubSunscreenProfile.self, from: sunscreenProfileData) }
        set { sunscreenProfileData = Self.encode(newValue) }
    }

    var restorablePreferences: SunclubRestorablePreferences? {
        get { Self.decode(SunclubRestorablePreferences.self, from: restorablePreferencesData) }
        set { restorablePreferencesData = Self.encode(newValue) }
    }

    private static func encode<Value: Encodable>(_ value: Value?) -> Data? {
        guard let value else { return nil }
        return try? JSONEncoder().encode(value)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
