import Foundation

enum DayPart: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning:
            return "Morning"
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
        case .evening:
            return 15
        case .night:
            return 21
        }
    }

    var order: Int {
        switch self {
        case .morning:
            return 0
        case .evening:
            return 1
        case .night:
            return 2
        }
    }

    static func resolve(for date: Date, calendar: Calendar = .current) -> DayPart {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return .morning
        case 12..<18:
            return .evening
        default:
            return .night
        }
    }
}
