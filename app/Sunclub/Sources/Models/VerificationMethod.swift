import Foundation

enum VerificationMethod: Int, Codable, CaseIterable, Identifiable {
    case manual = 1
    case quickLog = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "manual"
        case .quickLog:
            return "quick log"
        }
    }
}

extension VerificationMethod {
    var displayName: String {
        switch self {
        case .manual:
            return "Manual Log"
        case .quickLog:
            return "Quick Log"
        }
    }

    var symbolName: String {
        switch self {
        case .manual:
            return "hand.tap"
        case .quickLog:
            return "bolt.fill"
        }
    }
}
