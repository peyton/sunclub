import Foundation

enum DayPart: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        }
    }

    var shortTitle: String {
        title
    }

    var defaultHour: Int {
        switch self {
        case .morning:
            return 8
        case .afternoon:
            return 15
        case .evening:
            return 18
        case .night:
            return 21
        }
    }

    var order: Int {
        switch self {
        case .morning:
            return 0
        case .afternoon:
            return 1
        case .evening:
            return 2
        case .night:
            return 3
        }
    }

    static let standardLogParts: [DayPart] = [.morning, .afternoon, .evening]

    static func logPickerParts(including selectedPart: DayPart) -> [DayPart] {
        guard selectedPart == .night else {
            return standardLogParts
        }
        return standardLogParts + [.night]
    }

    static func resolve(for date: Date, calendar: Calendar = .current) -> DayPart {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return .morning
        case 12..<18:
            return .afternoon
        case 18..<21:
            return .evening
        default:
            return .night
        }
    }
}
