import AVFoundation
import Combine
import Foundation

struct VideoVerificationResult {
    let isDetected: Bool
    let featureDistance: Float?
    let confidence: Float
}

final class VideoVerificationCoordinator: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let analysisQueue = DispatchQueue(label: "sunscreen.video.queue")
    nonisolated(unsafe) private var trainingPayloads: [Data] = []
    nonisolated(unsafe) private var sampleCounter = 0
    nonisolated(unsafe) private var consecutiveDetections = 0
    private let sampleEvery = 5
    private let requiredConsecutive = 12

    @Published var permissionDenied = false
    nonisolated(unsafe) private var isDetected = false
    nonisolated(unsafe) private var featureDistance: Float?
    nonisolated(unsafe) private var processingFrame = false
    nonisolated(unsafe) private var sessionConfigured = false

    var onStateChange: ((VideoVerificationResult) -> Void)?

    func configure(trainingPayloads: [Data]) {
        Task {
            let status = await CameraPermission.request()
            await MainActor.run { permissionDenied = status != .granted }
            guard status == .granted else { return }

            analysisQueue.async { [weak self] in
                guard let self else { return }
                self.trainingPayloads = trainingPayloads
                self.sampleCounter = 0
                self.consecutiveDetections = 0
                self.isDetected = false
                self.featureDistance = nil
                self.processingFrame = false

                if !sessionConfigured {
                    configureSession()
                    sessionConfigured = true
                }
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }
    }

    func stop() {
        analysisQueue.async { [weak self] in
            guard let self else { return }
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    nonisolated private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        if session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)
            if let conn = videoOutput.connection(with: .video) {
                if conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90
                }
            }
        }
        session.commitConfiguration()
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !processingFrame else { return }
        guard !trainingPayloads.isEmpty else {
            Task { @MainActor in
                isDetected = false
                featureDistance = nil
                onStateChange?(.init(isDetected: false, featureDistance: nil, confidence: 0))
            }
            return
        }

        sampleCounter += 1
        if sampleCounter % sampleEvery != 0 { return }

        processingFrame = true

        guard let observation = try? VisionFeaturePrintService.shared.featurePrintSync(from: sampleBuffer) else {
            processingFrame = false
            consecutiveDetections = 0
            isDetected = false
            featureDistance = nil
            DispatchQueue.main.async { [weak self] in
                self?.onStateChange?(.init(isDetected: false, featureDistance: nil, confidence: 0))
            }
            return
        }

        let match = FeaturePrintMatcher.evaluate(
            sample: observation,
            storedPayloads: trainingPayloads,
            configuration: FeaturePrintMatchConfiguration.video
        )
        let detected = match.isMatch

        featureDistance = match.bestDistance
        consecutiveDetections = detected ? (consecutiveDetections + 1) : 0
        isDetected = consecutiveDetections >= requiredConsecutive
        processingFrame = false

        let result = VideoVerificationResult(isDetected: isDetected, featureDistance: featureDistance, confidence: match.confidence)
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(result)
        }
    }
}
