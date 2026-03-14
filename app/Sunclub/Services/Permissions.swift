import Foundation
import AVFoundation

enum CameraPermissionState {
    case granted
    case denied
    case notDetermined
}

enum CameraPermission {
    static func request() async -> CameraPermissionState {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .granted : .denied
        @unknown default:
            return .denied
        }
    }
}
