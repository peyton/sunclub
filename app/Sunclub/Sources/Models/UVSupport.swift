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
    case cachedWeatherKit
    case localEstimate
    case weatherKit

    static let cachedWeatherKitSourceLabel = "Cached Apple Weather"
    static let localEstimateSourceLabel = "Local estimate"
    static let localEstimateHourlySourceLabel = "Estimated"
    static let weatherKitSourceLabel = "Apple Weather"
    static let unavailableSourceLabel = "UV unavailable"

    var statusLabel: String {
        switch self {
        case .cachedWeatherKit:
            return Self.cachedWeatherKitSourceLabel
        case .localEstimate:
            return Self.localEstimateSourceLabel
        case .weatherKit:
            return Self.weatherKitSourceLabel
        }
    }

    var forecastLabel: String {
        statusLabel
    }

    var hourlySourceLabel: String {
        switch self {
        case .cachedWeatherKit:
            return Self.cachedWeatherKitSourceLabel
        case .localEstimate:
            return Self.localEstimateHourlySourceLabel
        case .weatherKit:
            return Self.weatherKitSourceLabel
        }
    }

    var shouldDisplayAttribution: Bool {
        self != .localEstimate
    }

    var isAppleWeather: Bool {
        switch self {
        case .cachedWeatherKit, .weatherKit:
            return true
        case .localEstimate:
            return false
        }
    }

    nonisolated static func shouldDisplayAttribution(for sourceLabel: String) -> Bool {
        sourceLabel == weatherKitSourceLabel || sourceLabel == cachedWeatherKitSourceLabel
    }
}

enum SunclubUVDataFreshness {
    nonisolated static let verifiedMaxAge: TimeInterval = 8 * 60 * 60
    nonisolated static let lastKnownMaxAge: TimeInterval = 24 * 60 * 60
}

enum SunclubUVEstimator {
    nonisolated static func estimatedIndex(
        at date: Date,
        calendar: Calendar = .current,
        latitude: Double? = nil
    ) -> Int {
        let hour = Double(calendar.component(.hour, from: date))
            + Double(calendar.component(.minute, from: date)) / 60
        let daylightShape = max(0, cos((hour - 12) * .pi / 12))

        guard let latitude else {
            return min(6, max(0, Int((6 * pow(daylightShape, 1.35)).rounded())))
        }

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 172
        let declinationDegrees = 23.44 * sin(2 * .pi * (Double(dayOfYear) - 81) / 365)
        let latitudeRadians = latitude * .pi / 180
        let declinationRadians = declinationDegrees * .pi / 180
        let hourAngleRadians = 15 * (hour - 12) * .pi / 180
        let solarElevationSine = sin(latitudeRadians) * sin(declinationRadians)
            + cos(latitudeRadians) * cos(declinationRadians) * cos(hourAngleRadians)
        guard solarElevationSine > 0 else {
            return 0
        }

        let estimate = 12 * pow(min(1, solarElevationSine), 1.2)
        return min(12, max(0, Int(estimate.rounded())))
    }

    nonisolated static func hourlyForecast(
        for date: Date,
        calendar: Calendar = .current,
        latitude: Double?
    ) -> [SunclubUVHourForecast] {
        let dayStart = calendar.startOfDay(for: date)
        return (6...18).compactMap { hour in
            guard let hourDate = calendar.date(
                bySettingHour: hour,
                minute: 0,
                second: 0,
                of: dayStart
            ) else {
                return nil
            }
            return SunclubUVHourForecast(
                date: hourDate,
                index: estimatedIndex(at: hourDate, calendar: calendar, latitude: latitude),
                sourceLabel: UVReadingSource.localEstimate.hourlySourceLabel
            )
        }
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

    func displayName(for readingSource: UVReadingSource?) -> String {
        guard readingSource == .cachedWeatherKit else {
            return displayName
        }
        return "Near \(displayName)"
    }
}

enum SunclubUVFreshness: Equatable, Sendable {
    case estimated
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
    func index(
        at date: Date,
        calendar: Calendar = .current
    ) -> Int? {
        let sameDayHours = hourly.filter { calendar.isDate($0.date, inSameDayAs: date) }
        if let closest = sameDayHours.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) {
            return closest.index
        }
        return calendar.isDate(generatedAt, inSameDayAs: date) ? currentIndex : nil
    }

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
        maxAge: TimeInterval = SunclubUVDataFreshness.verifiedMaxAge
    ) -> Bool {
        let age = date.timeIntervalSince(timestamp)
        return age >= 0 && age <= maxAge
    }
}
