import Foundation

enum VerificationMethod: Int, Codable, CaseIterable, Identifiable {
    case manual = 1

    var id: Int { rawValue }

    var title: String {
        "manual"
    }
}

extension VerificationMethod {
    var displayName: String {
        "Manual Log"
    }

    var symbolName: String {
        "hand.tap"
    }
}
