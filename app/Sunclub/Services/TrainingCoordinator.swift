import AVFoundation
import Combine
import Foundation
import UIKit

struct TrainingCaptureResult {
    let featurePrintData: Data
    let width: Int
    let height: Int
}

final class TrainingCoordinator: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    var onResult: ((TrainingCaptureResult) -> Void)?
    var onError: ((String) -> Void)?

    @Published var capturedCount = 0
    @Published var permissionDenied = false
    @Published var isProcessing = false

    func configure() {
        Task {
            let status = await CameraPermission.request()
            await MainActor.run {
                permissionDenied = status != .granted
                guard status == .granted else { return }
                if session.inputs.isEmpty { configureSession() }
                if !session.isRunning { session.startRunning() }
            }
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func captureFrame(targetCount: Int) {
        guard !isProcessing else { return }
        if capturedCount >= targetCount {
            return
        }
        isProcessing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func reset() {
        capturedCount = 0
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard isProcessing else { return }
        if let error {
            Task { @MainActor in
                isProcessing = false
                onError?("Capture error: \(error.localizedDescription)")
            }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            Task { @MainActor in
                onError?("No image data")
                isProcessing = false
            }
            return
        }

        Task {
            do {
                let obs = try await VisionFeaturePrintService.shared.featurePrint(from: data)
                guard let stored = VisionFeaturePrintService.shared.serialize(obs) else {
                    await MainActor.run {
                        onError?("Failed to serialize feature print")
                        isProcessing = false
                    }
                    return
                }
                let image = UIImage(data: data)
                await MainActor.run {
                    capturedCount += 1
                    isProcessing = false
                    onResult?(
                        TrainingCaptureResult(
                            featurePrintData: stored,
                            width: Int(image?.size.width ?? 0),
                            height: Int(image?.size.height ?? 0)
                        )
                    )
                }
            } catch {
                await MainActor.run {
                    onError?("Failed feature extraction")
                    isProcessing = false
                }
            }
        }
    }
}
