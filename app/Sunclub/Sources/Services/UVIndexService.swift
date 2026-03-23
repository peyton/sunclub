import CoreLocation
import Foundation

enum UVLevel: Equatable {
    case low       // 0-2
    case moderate  // 3-5
    case high      // 6-7
    case veryHigh  // 8-10
    case extreme   // 11+
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

struct UVReading: Equatable {
    let index: Int
    let level: UVLevel
    let timestamp: Date

    init(index: Int, timestamp: Date = Date()) {
        self.index = index
        self.level = UVLevel.from(index: index)
        self.timestamp = timestamp
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > 3600
    }
}

@MainActor
@Observable
final class UVIndexService {
    private(set) var currentReading: UVReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func fetchUVIndex() {
        guard !isLoading else { return }

        if let reading = currentReading, !reading.isStale {
            return
        }

        isLoading = true
        errorMessage = nil

        // Estimate UV index based on time of day and season
        // This is a simplified heuristic; a real implementation would use WeatherKit
        let estimate = estimateUVFromTimeAndSeason()
        currentReading = UVReading(index: estimate)
        isLoading = false
    }

    private func estimateUVFromTimeAndSeason() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let month = calendar.component(.month, from: now)

        // Base UV by season (Northern Hemisphere approximation)
        let seasonalBase: Int
        switch month {
        case 6, 7, 8: seasonalBase = 8       // Summer
        case 5, 9: seasonalBase = 6           // Late spring / early fall
        case 4, 10: seasonalBase = 4          // Spring / fall
        case 3, 11: seasonalBase = 3          // Early spring / late fall
        default: seasonalBase = 2             // Winter
        }

        // Adjust for time of day
        let timeMultiplier: Double
        switch hour {
        case 0...5: timeMultiplier = 0.0
        case 6: timeMultiplier = 0.1
        case 7: timeMultiplier = 0.2
        case 8: timeMultiplier = 0.4
        case 9: timeMultiplier = 0.6
        case 10: timeMultiplier = 0.8
        case 11, 12, 13: timeMultiplier = 1.0
        case 14: timeMultiplier = 0.9
        case 15: timeMultiplier = 0.7
        case 16: timeMultiplier = 0.5
        case 17: timeMultiplier = 0.3
        case 18: timeMultiplier = 0.1
        default: timeMultiplier = 0.0
        }

        return max(0, Int(Double(seasonalBase) * timeMultiplier))
    }
}
