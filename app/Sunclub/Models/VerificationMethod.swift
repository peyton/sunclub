import Foundation

enum VerificationMethod: Int, Codable, CaseIterable, Identifiable {
    case camera

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .camera:
            return "camera"
        }
    }
}

extension VerificationMethod {
    var displayName: String {
        switch self {
        case .camera:
            return "Live Camera"
        }
    }

    var symbolName: String {
        switch self {
        case .camera:
            return "camera.viewfinder"
        }
    }
}
