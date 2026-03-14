import AVFoundation
import Combine
import Foundation

struct VideoVerificationResult {
    let isDetected: Bool
    let featureDistance: Float?
}

final class VideoVerificationCoordinator: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var trainingPayloads: [Data] = []
    private var sampleCounter = 0
    private var consecutiveDetections = 0
    private let sampleEvery = 5
    private let requiredConsecutive = 12

    @Published var isDetected = false
    @Published var featureDistance: Float?
    @Published var permissionDenied = false
    @Published var processingFrame = false

    var onStateChange: ((VideoVerificationResult) -> Void)?

    func configure(trainingPayloads: [Data]) {
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

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let queue = DispatchQueue(label: "sunscreen.video.queue")
        if session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)
            if let conn = videoOutput.connection(with: .video) {
                conn.videoOrientation = .portrait
            }
        }
        session.commitConfiguration()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !processingFrame else { return }
        guard !trainingPayloads.isEmpty else {
            Task { @MainActor in
                isDetected = false
                featureDistance = nil
                onStateChange?(.init(isDetected: false, featureDistance: nil))
            }
            return
        }

        sampleCounter += 1
        if sampleCounter % sampleEvery != 0 { return }

        processingFrame = true

        Task {
            guard let observation = try? await VisionFeaturePrintService.shared.featurePrint(from: sampleBuffer) else {
                await MainActor.run {
                    processingFrame = false
                    consecutiveDetections = 0
                    isDetected = false
                    featureDistance = nil
                    onStateChange?(.init(isDetected: false, featureDistance: nil))
                }
                return
            }

            let match = FeaturePrintMatcher.shared.evaluate(
                sample: observation,
                storedPayloads: trainingPayloads,
                configuration: .video
            )
            let detected = match.isMatch

            await MainActor.run {
                featureDistance = match.bestDistance
                consecutiveDetections = detected ? (consecutiveDetections + 1) : 0
                isDetected = consecutiveDetections >= requiredConsecutive
                processingFrame = false
                onStateChange?(.init(isDetected: isDetected, featureDistance: featureDistance))
            }
        }
    }
}
