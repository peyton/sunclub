import AVFoundation
import Combine
import Foundation

extension CMSampleBuffer: @unchecked @retroactive Sendable {}

struct SunscreenDetectionResult: Sendable {
    let isDetected: Bool
    let isLoadingModel: Bool
    let parsedAnswer: SunscreenDetectionAnswer?
    let rawOutput: String
    let consecutiveYesCount: Int
    let timeToFirstTokenMs: Int?
    let latencyMs: Int?
    let errorDescription: String?

    static let idle = SunscreenDetectionResult(
        isDetected: false,
        isLoadingModel: false,
        parsedAnswer: nil,
        rawOutput: "",
        consecutiveYesCount: 0,
        timeToFirstTokenMs: nil,
        latencyMs: nil,
        errorDescription: nil
    )
}

final class SunscreenDetectionCoordinator: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    private let analysisQueue = DispatchQueue(label: "sunclub.vlm.video.queue")
    private let sampleEvery = 15
    private let requiredConsecutiveYes = 2

    @Published var permissionDenied = false

    nonisolated(unsafe) private var sampleCounter = 0
    nonisolated(unsafe) private var consecutiveYesCount = 0
    nonisolated(unsafe) private var processingFrame = false
    nonisolated(unsafe) private var sessionConfigured = false
    nonisolated(unsafe) private var modelIsLoading = false
    nonisolated(unsafe) private var modelIsReady = false
    nonisolated(unsafe) private var parsedAnswer: SunscreenDetectionAnswer?
    nonisolated(unsafe) private var rawOutput = ""
    nonisolated(unsafe) private var timeToFirstTokenMs: Int?
    nonisolated(unsafe) private var latencyMs: Int?
    nonisolated(unsafe) private var errorDescription: String?
    nonisolated(unsafe) private var loadTask: Task<Void, Never>?

    var onStateChange: ((SunscreenDetectionResult) -> Void)?

    func configure() {
        Task {
            let status = await CameraPermission.request()
            await MainActor.run {
                permissionDenied = status != .granted
            }
            guard status == .granted else {
                emitResult()
                return
            }

            analysisQueue.async { [weak self] in
                guard let self else { return }
                sampleCounter = 0
                consecutiveYesCount = 0
                processingFrame = false
                parsedAnswer = nil
                rawOutput = ""
                timeToFirstTokenMs = nil
                latencyMs = nil
                errorDescription = nil

                if !sessionConfigured {
                    configureSession()
                    sessionConfigured = true
                }
                if !session.isRunning {
                    session.startRunning()
                }
                startLoadingModel()
                emitResult()
            }
        }
    }

    func stop() {
        analysisQueue.async { [weak self] in
            guard let self else { return }
            loadTask?.cancel()
            loadTask = nil
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

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(self, queue: analysisQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard modelIsReady else { return }
        guard !processingFrame else { return }

        sampleCounter += 1
        if sampleCounter % sampleEvery != 0 { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        processingFrame = true

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            do {
                let inference = try await FastVLMService.shared.detectSunscreen(in: pixelBuffer)
                self.analysisQueue.async { [weak self] in
                    self?.handleInference(inference)
                }
            } catch {
                self.analysisQueue.async { [weak self] in
                    self?.handleError(error)
                }
            }
        }
    }

    private func startLoadingModel() {
        guard !modelIsReady, !modelIsLoading else { return }

        modelIsLoading = true
        errorDescription = nil
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            do {
                _ = try await FastVLMService.shared.loadModelIfNeeded()
                self?.analysisQueue.async { [weak self] in
                    guard let self else { return }
                    modelIsLoading = false
                    modelIsReady = true
                    emitResult()
                }
            } catch {
                self?.analysisQueue.async { [weak self] in
                    guard let self else { return }
                    modelIsLoading = false
                    modelIsReady = false
                    errorDescription = error.localizedDescription
                    emitResult()
                }
            }
        }
    }

    private func handleInference(_ inference: FastVLMInference) {
        processingFrame = false
        parsedAnswer = inference.answer
        rawOutput = inference.rawOutput
        timeToFirstTokenMs = inference.timeToFirstTokenMs
        latencyMs = inference.latencyMs
        errorDescription = nil

        if inference.answer == .yes {
            consecutiveYesCount += 1
        } else {
            consecutiveYesCount = 0
        }

        let detected = consecutiveYesCount >= requiredConsecutiveYes
        if detected, session.isRunning {
            session.stopRunning()
        }

        emitResult(isDetected: detected)
    }

    private func handleError(_ error: Error) {
        processingFrame = false
        parsedAnswer = nil
        rawOutput = ""
        timeToFirstTokenMs = nil
        latencyMs = nil
        consecutiveYesCount = 0
        errorDescription = error.localizedDescription
        emitResult()
    }

    private func emitResult(isDetected: Bool = false) {
        let result = SunscreenDetectionResult(
            isDetected: isDetected,
            isLoadingModel: modelIsLoading,
            parsedAnswer: parsedAnswer,
            rawOutput: rawOutput,
            consecutiveYesCount: consecutiveYesCount,
            timeToFirstTokenMs: timeToFirstTokenMs,
            latencyMs: latencyMs,
            errorDescription: errorDescription
        )

        let onStateChange = self.onStateChange
        DispatchQueue.main.async {
            onStateChange?(result)
        }
    }
}
