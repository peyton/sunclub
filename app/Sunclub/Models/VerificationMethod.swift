import Foundation
import SwiftData

enum VerificationMethod: Int, Codable, CaseIterable, Identifiable {
    case barcode
    case selfie
    case video

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .barcode:
            return "barcode"
        case .selfie:
            return "selfie"
        case .video:
            return "video"
        }
    }
}

extension VerificationMethod {
    var displayName: String {
        switch self {
        case .barcode:
            return "Scan Barcode"
        case .selfie:
            return "Take Selfie"
        case .video:
            return "Live Verify"
        }
    }

    var symbolName: String {
        switch self {
        case .barcode:
            return "barcode.viewfinder"
        case .selfie:
            return "person.crop.square"
        case .video:
            return "camera.viewfinder"
        }
    }
}
