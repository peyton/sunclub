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
        case .veryHigh: return "Stay protected — UV is very high."
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

    var reapplyAdvanceMinutes: Int {
        switch self {
        case .high:
            return 30
        case .veryHigh, .extreme:
            return 60
        default:
            return 0
        }
    }

    var strongerReapplyMessage: String? {
        switch self {
        case .high:
            return "UV is high today, so reapply sooner if you're outside."
        case .veryHigh:
            return "UV is very high today, so reapply sooner and stay covered."
        case .extreme:
            return "UV is extreme today, so reapply as early as you can and minimize direct sun."
        default:
            return nil
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
    case heuristic
    case weatherKit

    static let heuristicSourceLabel = "Estimated locally"
    static let heuristicHourlySourceLabel = "Estimated"
    static let weatherKitSourceLabel = "Apple Weather"

    var statusLabel: String {
        switch self {
        case .heuristic:
            return Self.heuristicSourceLabel
        case .weatherKit:
            return Self.weatherKitSourceLabel
        }
    }

    var forecastLabel: String {
        switch self {
        case .heuristic:
            return Self.heuristicSourceLabel
        case .weatherKit:
            return Self.weatherKitSourceLabel
        }
    }

    var hourlySourceLabel: String {
        switch self {
        case .heuristic:
            return Self.heuristicHourlySourceLabel
        case .weatherKit:
            return Self.weatherKitSourceLabel
        }
    }

    var shouldDisplayAttribution: Bool {
        self == .weatherKit
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
        source: UVReadingSource = .heuristic
    ) {
        self.index = index
        self.level = UVLevel.from(index: index)
        self.timestamp = timestamp
        self.source = source
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }
}
