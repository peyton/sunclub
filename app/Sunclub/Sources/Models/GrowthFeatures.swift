import Foundation

struct SunclubGrowthSettings: Codable, Equatable, Sendable {
    var preferredName: String
    var healthKit: SunclubHealthKitPreferences
    var uvBriefing: SunclubUVBriefingPreferences
    var friends: [SunclubFriendSnapshot]
    var presentedAchievementIDs: [String]
    var telemetry: SunclubGrowthTelemetry
    var scannedSPFLevels: [Int]
    var accountability: SunclubAccountabilitySettings
    var automation: SunclubAutomationPreferences

    init(
        preferredName: String = "",
        healthKit: SunclubHealthKitPreferences = SunclubHealthKitPreferences(),
        uvBriefing: SunclubUVBriefingPreferences = SunclubUVBriefingPreferences(),
        friends: [SunclubFriendSnapshot] = [],
        presentedAchievementIDs: [String] = [],
        telemetry: SunclubGrowthTelemetry = SunclubGrowthTelemetry(),
        scannedSPFLevels: [Int] = [],
        accountability: SunclubAccountabilitySettings = SunclubAccountabilitySettings(),
        automation: SunclubAutomationPreferences = SunclubAutomationPreferences()
    ) {
        self.preferredName = preferredName
        self.healthKit = healthKit
        self.uvBriefing = uvBriefing
        self.friends = friends
        self.presentedAchievementIDs = presentedAchievementIDs
        self.telemetry = telemetry
        self.scannedSPFLevels = Self.normalizedSPFLevels(scannedSPFLevels)
        self.accountability = accountability
        self.automation = automation
    }

    private enum CodingKeys: String, CodingKey {
        case preferredName
        case healthKit
        case uvBriefing
        case friends
        case presentedAchievementIDs
        case telemetry
        case scannedSPFLevels
        case accountability
        case automation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        preferredName = try container.decodeIfPresent(String.self, forKey: .preferredName) ?? ""
        healthKit = try container.decodeIfPresent(SunclubHealthKitPreferences.self, forKey: .healthKit)
            ?? SunclubHealthKitPreferences()
        uvBriefing = try container.decodeIfPresent(SunclubUVBriefingPreferences.self, forKey: .uvBriefing)
            ?? SunclubUVBriefingPreferences()
        friends = try container.decodeIfPresent([SunclubFriendSnapshot].self, forKey: .friends) ?? []
        presentedAchievementIDs = try container.decodeIfPresent([String].self, forKey: .presentedAchievementIDs) ?? []
        telemetry = try container.decodeIfPresent(SunclubGrowthTelemetry.self, forKey: .telemetry)
            ?? SunclubGrowthTelemetry()
        scannedSPFLevels = Self.normalizedSPFLevels(
            try container.decodeIfPresent([Int].self, forKey: .scannedSPFLevels) ?? []
        )
        accountability = try container.decodeIfPresent(SunclubAccountabilitySettings.self, forKey: .accountability)
            ?? SunclubAccountabilitySettings()
        automation = try container.decodeIfPresent(SunclubAutomationPreferences.self, forKey: .automation)
            ?? SunclubAutomationPreferences()
    }

    static func normalizedSPFLevels(_ levels: [Int]) -> [Int] {
        var seenLevels = Set<Int>()

        return levels.compactMap { level in
            let normalizedLevel = max(1, min(level, 100))
            guard seenLevels.insert(normalizedLevel).inserted else {
                return nil
            }

            return normalizedLevel
        }
    }
}

struct SunclubAutomationPreferences: Codable, Equatable, Sendable {
    var shortcutWritesEnabled: Bool
    var urlOpenActionsEnabled: Bool
    var urlWriteActionsEnabled: Bool
    var callbackResultDetailsEnabled: Bool

    init(
        shortcutWritesEnabled: Bool = true,
        urlOpenActionsEnabled: Bool = true,
        urlWriteActionsEnabled: Bool = true,
        callbackResultDetailsEnabled: Bool = true
    ) {
        self.shortcutWritesEnabled = shortcutWritesEnabled
        self.urlOpenActionsEnabled = urlOpenActionsEnabled
        self.urlWriteActionsEnabled = urlWriteActionsEnabled
        self.callbackResultDetailsEnabled = callbackResultDetailsEnabled
    }
}

struct SunclubGrowthTelemetry: Codable, Equatable, Sendable {
    var shareActionCount: Int
    var productScanUseCount: Int
    var lastSharedAt: Date?
    var lastProductScanUsedAt: Date?

    init(
        shareActionCount: Int = 0,
        productScanUseCount: Int = 0,
        lastSharedAt: Date? = nil,
        lastProductScanUsedAt: Date? = nil
    ) {
        self.shareActionCount = max(0, shareActionCount)
        self.productScanUseCount = max(0, productScanUseCount)
        self.lastSharedAt = lastSharedAt
        self.lastProductScanUsedAt = lastProductScanUsedAt
    }

    mutating func recordShare(at date: Date) {
        shareActionCount += 1
        lastSharedAt = date
    }

    mutating func recordProductScanUse(at date: Date) {
        productScanUseCount += 1
        lastProductScanUsedAt = date
    }
}

struct SunclubHealthKitPreferences: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var importedSampleCount: Int
    var lastExportAt: Date?

    init(
        isEnabled: Bool = false,
        importedSampleCount: Int = 0,
        lastExportAt: Date? = nil
    ) {
        self.isEnabled = isEnabled
        self.importedSampleCount = importedSampleCount
        self.lastExportAt = lastExportAt
    }
}

struct SunclubUVBriefingPreferences: Codable, Equatable, Sendable {
    var dailyBriefingEnabled: Bool
    var extremeAlertEnabled: Bool
    var morningHour: Int
    var morningMinute: Int

    init(
        dailyBriefingEnabled: Bool = true,
        extremeAlertEnabled: Bool = false,
        morningHour: Int = 8,
        morningMinute: Int = 0
    ) {
        self.dailyBriefingEnabled = dailyBriefingEnabled
        self.extremeAlertEnabled = extremeAlertEnabled
        self.morningHour = max(0, min(23, morningHour))
        self.morningMinute = max(0, min(59, morningMinute))
    }
}

struct SunclubFriendSnapshot: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var currentStreak: Int
    var longestStreak: Int
    var hasLoggedToday: Bool
    var lastSharedAt: Date
    var seasonStyleRawValue: String

    init(
        id: UUID = UUID(),
        name: String,
        currentStreak: Int,
        longestStreak: Int,
        hasLoggedToday: Bool,
        lastSharedAt: Date,
        seasonStyle: SunclubSeasonStyle
    ) {
        self.id = id
        self.name = name
        self.currentStreak = max(0, currentStreak)
        self.longestStreak = max(0, longestStreak)
        self.hasLoggedToday = hasLoggedToday
        self.lastSharedAt = lastSharedAt
        seasonStyleRawValue = seasonStyle.rawValue
    }

    var seasonStyle: SunclubSeasonStyle {
        SunclubSeasonStyle(rawValue: seasonStyleRawValue) ?? .summerGlow
    }
}

enum SunclubSeasonStyle: String, Codable, CaseIterable, Sendable {
    case summerGlow
    case winterShield
}

enum SunclubAchievementID: String, Codable, CaseIterable, Identifiable, Sendable {
    case streak7
    case streak30
    case streak100
    case streak365
    case firstReapply
    case firstBackfill
    case summerSurvivor
    case winterWarrior
    case morningGlow
    case weekendCanopy
    case spfSampler
    case noteTaker
    case reapplyRelay
    case highUVHero
    case homeBase
    case liveSignal
    case bottleDetective
    case socialSpark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .streak7:
            return "7-Day Shield"
        case .streak30:
            return "30-Day Shield"
        case .streak100:
            return "100-Day Shield"
        case .streak365:
            return "365-Day Shield"
        case .firstReapply:
            return "Reapply Rookie"
        case .firstBackfill:
            return "History Keeper"
        case .summerSurvivor:
            return "Summer Survivor"
        case .winterWarrior:
            return "Winter Warrior"
        case .morningGlow:
            return "Morning Glow"
        case .weekendCanopy:
            return "Weekend Canopy"
        case .spfSampler:
            return "SPF Sampler"
        case .noteTaker:
            return "Field Notes"
        case .reapplyRelay:
            return "Reapply Relay"
        case .highUVHero:
            return "High-UV Hero"
        case .homeBase:
            return "Home Base"
        case .liveSignal:
            return "Live Signal"
        case .bottleDetective:
            return "Bottle Detective"
        case .socialSpark:
            return "Social Spark"
        }
    }

    var symbolName: String {
        switch self {
        case .streak7:
            return "sparkles"
        case .streak30:
            return "sun.max.fill"
        case .streak100:
            return "flame.fill"
        case .streak365:
            return "crown.fill"
        case .firstReapply:
            return "drop.fill"
        case .firstBackfill:
            return "calendar.badge.plus"
        case .summerSurvivor:
            return "sun.haze.fill"
        case .winterWarrior:
            return "snowflake"
        case .morningGlow:
            return "sunrise.fill"
        case .weekendCanopy:
            return "calendar.circle.fill"
        case .spfSampler:
            return "number.circle.fill"
        case .noteTaker:
            return "note.text"
        case .reapplyRelay:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .highUVHero:
            return "shield.lefthalf.filled"
        case .homeBase:
            return "house.fill"
        case .liveSignal:
            return "antenna.radiowaves.left.and.right"
        case .bottleDetective:
            return "magnifyingglass.circle.fill"
        case .socialSpark:
            return "person.2.fill"
        }
    }

    var targetValue: Int {
        switch self {
        case .streak7:
            return 7
        case .streak30:
            return 30
        case .streak100:
            return 100
        case .streak365:
            return 365
        case .firstReapply, .firstBackfill:
            return 1
        case .summerSurvivor, .winterWarrior:
            return 30
        case .morningGlow:
            return 5
        case .weekendCanopy:
            return 4
        case .spfSampler:
            return 5
        case .noteTaker:
            return 10
        case .reapplyRelay:
            return 3
        case .highUVHero:
            return 10
        case .homeBase, .liveSignal, .bottleDetective, .socialSpark:
            return 1
        }
    }
}

struct SunclubAchievement: Equatable, Identifiable, Sendable {
    let id: SunclubAchievementID
    let title: String
    let detail: String
    let symbolName: String
    let currentValue: Int
    let targetValue: Int
    let isUnlocked: Bool
    let shareBlurb: String

    var progress: Double {
        guard targetValue > 0 else { return isUnlocked ? 1 : 0 }
        return min(Double(currentValue) / Double(targetValue), 1)
    }
}

enum SunclubChallengeID: String, Codable, CaseIterable, Identifiable, Sendable {
    case summerShield
    case uvAwarenessWeek
    case winterSkin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summerShield:
            return "Summer Shield"
        case .uvAwarenessWeek:
            return "UV Awareness Week"
        case .winterSkin:
            return "Winter Skin"
        }
    }

    var symbolName: String {
        switch self {
        case .summerShield:
            return "sun.max.trianglebadge.exclamationmark"
        case .uvAwarenessWeek:
            return "calendar.circle.fill"
        case .winterSkin:
            return "snowflake.circle.fill"
        }
    }
}

struct SunclubSeasonalChallenge: Equatable, Identifiable, Sendable {
    let id: SunclubChallengeID
    let title: String
    let detail: String
    let symbolName: String
    let dateInterval: DateInterval
    let currentValue: Int
    let targetValue: Int
    let isComplete: Bool

    var progress: Double {
        guard targetValue > 0 else { return isComplete ? 1 : 0 }
        return min(Double(currentValue) / Double(targetValue), 1)
    }
}

struct SunclubUVHourForecast: Codable, Equatable, Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let index: Int
    let sourceLabel: String

    var level: UVLevel {
        UVLevel.from(index: index)
    }
}

struct SunclubUVForecast: Equatable, Sendable {
    let generatedAt: Date
    let sourceLabel: String
    let hours: [SunclubUVHourForecast]
    let peakHour: SunclubUVHourForecast?
    let recommendation: String

    var headline: String {
        guard let peakHour else {
            return "No UV forecast available"
        }

        return "Peak UV \(peakHour.index) at \(peakHour.date.formatted(date: .omitted, time: .shortened))"
    }
}

struct SunclubSPFDistributionEntry: Equatable, Identifiable, Sendable {
    var id: String { "spf-\(spf)" }
    let spf: Int
    let count: Int
}

struct SunclubMonthlyConsistencyEntry: Equatable, Identifiable, Sendable {
    var id: Int { monthIndex }
    let monthIndex: Int
    let monthLabel: String
    let protectedDays: Int
    let totalDays: Int

    var ratio: Double {
        guard totalDays > 0 else { return 0 }
        return Double(protectedDays) / Double(totalDays)
    }
}

struct SunclubSkinHealthReportSummary: Equatable, Sendable {
    let interval: DateInterval
    let totalProtectedDays: Int
    let longestStreak: Int
    let averageStreakLength: Double
    let highUVProtectedDays: Int
    let mostUsedSPF: MostUsedSPFInsight?
    let spfDistribution: [SunclubSPFDistributionEntry]
    let monthlyConsistency: [SunclubMonthlyConsistencyEntry]
}

struct SunclubShareArtifact: Equatable {
    let title: String
    let subtitle: String
    let fileURL: URL
    let shareText: String?

    init(
        title: String,
        subtitle: String,
        fileURL: URL,
        shareText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.fileURL = fileURL
        self.shareText = shareText
    }
}
