import AVFoundation
import Combine
import Foundation
import UIKit

struct SelfieCaptureResult {
    let verified: Bool
    let barcodeMatched: Bool
    let featureDistance: Double?
    let barcode: String?
    let imageData: Data?
}

final class SelfieCaptureCoordinator: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var expectedBarcode: String?
    private var trainingPayloads: [Data] = []
    private let featureMatchThreshold = 18.5

    @Published var isProcessing = false
    @Published var permissionDenied = false
    var onResult: ((SelfieCaptureResult) -> Void)?

    func configure(expectedBarcode: String?, trainingPayloads: [Data]) {
        self.expectedBarcode = expectedBarcode
        self.trainingPayloads = trainingPayloads

        Task {
            let status = await CameraPermission.request()
            await MainActor.run {
                permissionDenied = status != .granted
                guard status == .granted else { return }

                if session.inputs.isEmpty {
                    configureSession()
                }
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func capture() {
        guard !isProcessing else { return }
        isProcessing = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            onResult?(.init(verified: false, barcodeMatched: false, featureDistance: nil, barcode: nil, imageData: nil))
            isProcessing = false
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            onResult?(.init(verified: false, barcodeMatched: false, featureDistance: nil, barcode: nil, imageData: nil))
            isProcessing = false
            return
        }

        isProcessing = true

        Task {
            let featureDistance = await extractFeatureDistance(from: data)
            let barcodes = await VisionFeaturePrintService.shared.detectBarcodes(in: data)
            let matchedBarcode = expectedBarcode.flatMap { expected in barcodes.first(where: { $0 == expected }) }
            let featureMatched = featureDistance.map { $0 <= featureMatchThreshold } ?? false

            let verified: Bool
            if !trainingPayloads.isEmpty {
                verified = featureMatched || matchedBarcode != nil
            } else {
                verified = matchedBarcode != nil
            }

            await MainActor.run {
                isProcessing = false
                onResult?(
                    SelfieCaptureResult(
                        verified: verified,
                        barcodeMatched: matchedBarcode != nil,
                        featureDistance: featureDistance,
                        barcode: matchedBarcode,
                        imageData: data
                    )
                )
            }
        }
    }

    private func extractFeatureDistance(from data: Data) async -> Double? {
        guard !trainingPayloads.isEmpty else { return nil }

        do {
            let observation = try await VisionFeaturePrintService.shared.featurePrint(from: data)
            let best = await VisionFeaturePrintService.shared.bestDistance(for: observation, to: trainingPayloads)
            return best.map { Double($0) }
        } catch {
            return nil
        }
    }
}
