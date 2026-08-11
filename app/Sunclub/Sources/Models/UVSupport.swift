import Foundation

enum UVLevel: Equatable, Sendable {
    case low
    case moderate
    case high
    case veryHigh
    case extreme
    case unknown

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        case .extreme: return "Extreme"
        case .unknown: return "Unknown"
        }
    }

    var shortAdvice: String {
        switch self {
        case .low: return "Minimal protection needed."
        case .moderate: return "Wear sunscreen if outside for extended periods."
        case .high: return "Sunscreen strongly recommended today."
        case .veryHigh: return "UV is very high; limit midday sun."
        case .extreme: return "Avoid midday sun. Reapply sunscreen frequently."
        case .unknown: return ""
        }
    }

    var symbolName: String {
        switch self {
        case .low: return "sun.min"
        case .moderate: return "sun.max"
        case .high: return "sun.max.fill"
        case .veryHigh: return "exclamationmark.triangle"
        case .extreme: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    var shouldShowBanner: Bool {
        switch self {
        case .moderate, .high, .veryHigh, .extreme: return true
        default: return false
        }
    }

    var homeHeadline: String? {
        switch self {
        case .moderate: return "UV is moderate today"
        case .high: return "UV is high today"
        case .veryHigh: return "UV is very high today"
        case .extreme: return "UV is extreme today"
        default: return nil
        }
    }

    var reapplyLabelPrefix: String? {
        switch self {
        case .high:
            return "High UV today"
        case .veryHigh:
            return "Very high UV today"
        case .extreme:
            return "Extreme UV today"
        default:
            return nil
        }
    }

    static func from(index: Int) -> UVLevel {
        switch index {
        case 0...2: return .low
        case 3...5: return .moderate
        case 6...7: return .high
        case 8...10: return .veryHigh
        case 11...: return .extreme
        default: return .unknown
        }
    }
}

enum UVReadingSource: Equatable, Sendable {
    case weatherKit

    static let weatherKitSourceLabel = "Apple Weather"
    static let unavailableSourceLabel = "UV unavailable"

    var statusLabel: String {
        Self.weatherKitSourceLabel
    }

    var forecastLabel: String {
        Self.weatherKitSourceLabel
    }

    var hourlySourceLabel: String {
        Self.weatherKitSourceLabel
    }

    var shouldDisplayAttribution: Bool {
        true
    }
}

enum SunclubUVAvailability: Equatable, Sendable {
    case available
    case unavailable
}

enum SunclubUVLocationSource: Equatable, Sendable {
    case liveLocation
    case selectedPlace(displayName: String)

    var displayName: String {
        switch self {
        case .liveLocation:
            return "Current Location"
        case .selectedPlace(let displayName):
            return displayName
        }
    }
}

enum SunclubUVFreshness: Equatable, Sendable {
    case fresh
    case stale
    case unavailable
}

struct SunclubUVStatus: Equatable, Sendable {
    let availability: SunclubUVAvailability
    let source: SunclubUVLocationSource?
    let freshness: SunclubUVFreshness
    let updatedAt: Date?

    static let unavailable = SunclubUVStatus(
        availability: .unavailable,
        source: nil,
        freshness: .unavailable,
        updatedAt: nil
    )
}

struct SunclubUVProtectionWindow: Equatable, Sendable {
    let start: Date
    let end: Date
}

extension SunclubUVForecastBundle {
    func protectionWindow(
        for day: Date,
        calendar: Calendar = .current
    ) -> SunclubUVProtectionWindow? {
        let elevatedHours = hourly
            .filter { calendar.isDate($0.date, inSameDayAs: day) && $0.index >= 3 }
            .sorted { $0.date < $1.date }
        guard let first = elevatedHours.first,
              let last = elevatedHours.last else {
            return nil
        }

        return SunclubUVProtectionWindow(
            start: first.date,
            end: calendar.date(byAdding: .hour, value: 1, to: last.date) ?? last.date
        )
    }
}

enum LiveUVAccessState: Equatable, Sendable {
    case disabled
    case live
    case needsPermission
    case denied
    case unavailable
}

struct UVReading: Equatable, Sendable {
    let index: Int
    let level: UVLevel
    let timestamp: Date
    let source: UVReadingSource

    init(
        index: Int,
        timestamp: Date = Date(),
        source: UVReadingSource = .weatherKit
    ) {
        self.index = index
        self.level = UVLevel.from(index: index)
        self.timestamp = timestamp
        self.source = source
    }

    var isStale: Bool {
        !isFresh(at: Date())
    }

    func isFresh(
        at date: Date,
        maxAge: TimeInterval = 2 * 60 * 60
    ) -> Bool {
        let age = date.timeIntervalSince(timestamp)
        return age >= 0 && age <= maxAge
    }
}
