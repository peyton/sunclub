import AVFoundation
import Combine
import Foundation
import UIKit
import Vision

enum EnrollmentQuality {
    case insufficient, poor, marginal, good
}

struct TrainingCaptureResult {
    let featurePrintData: Data
    let width: Int
    let height: Int
}

final class TrainingCoordinator: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var usesSyntheticCapture = false
    var onResult: ((TrainingCaptureResult) -> Void)?
    var onError: ((String) -> Void)?

    @Published var capturedCount = 0
    @Published var permissionDenied = false
    @Published var isProcessing = false

    func configure(initialCount: Int = 0) {
        Task {
            let status = await CameraPermission.request()
            await MainActor.run {
                capturedCount = initialCount
                permissionDenied = status != .granted
                guard status == .granted else { return }
                if session.inputs.isEmpty {
                    usesSyntheticCapture = !configureSession()
                }

                guard !usesSyntheticCapture else { return }

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

        if usesSyntheticCapture {
            recordSyntheticTrainingSample()
            return
        }

        isProcessing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func reset() {
        capturedCount = 0
    }

    func validateEnrollmentQuality(payloads: [Data]) -> EnrollmentQuality {
        let prints = payloads.compactMap {
            VisionFeaturePrintService.shared.deserialize($0)
        }
        guard prints.count >= 5 else { return .insufficient }

        var distances: [Float] = []
        for i in 0..<prints.count {
            for j in (i + 1)..<prints.count {
                var d: Float = 0
                try? prints[i].computeDistance(&d, to: prints[j])
                distances.append(d)
            }
        }

        let mean = distances.reduce(0, +) / Float(distances.count)
        let maxDist = distances.max() ?? 0

        if mean > 0.65 || maxDist > 0.80 {
            return .poor
        } else if mean > 0.50 {
            return .marginal
        } else {
            return .good
        }
    }

    func recordSyntheticCapture() {
        capturedCount += 1
    }

    @discardableResult
    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return false
        }

        if session.canAddInput(input) { session.addInput(input) }
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return false
        }

        session.addOutput(photoOutput)
        session.commitConfiguration()
        return true
    }

    private func recordSyntheticTrainingSample() {
        isProcessing = true

        Task {
            let payload = Data("simulator-training-\(UUID().uuidString)".utf8)
            await MainActor.run {
                capturedCount += 1
                isProcessing = false
                onResult?(
                    TrainingCaptureResult(
                        featurePrintData: payload,
                        width: 1,
                        height: 1
                    )
                )
            }
        }
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
