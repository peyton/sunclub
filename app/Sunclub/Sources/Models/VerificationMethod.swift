import Foundation

enum VerificationMethod: Int, Codable, CaseIterable, Identifiable {
    case camera
    case manual

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .camera:
            return "camera"
        case .manual:
            return "manual"
        }
    }
}

extension VerificationMethod {
    var displayName: String {
        switch self {
        case .camera:
            return "Live Camera"
        case .manual:
            return "Manual Log"
        }
    }

    var symbolName: String {
        switch self {
        case .camera:
            return "camera.viewfinder"
        case .manual:
            return "hand.tap"
        }
    }
}
