import AVFoundation
import Combine
import Foundation

final class BarcodeScannerCoordinator: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let queue = DispatchQueue(label: "sunscreen.scanner.queue")
    nonisolated(unsafe) private let metadataOutput = AVCaptureMetadataOutput()

    var onBarcode: ((String) -> Void)?
    @Published var lastScannedCode: String?
    @Published var permissionDenied = false
    nonisolated(unsafe) private var started = false
    nonisolated(unsafe) private var isProcessingCode = false

    func startIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            let status = await CameraPermission.request()
            guard status == .granted else {
                await MainActor.run { permissionDenied = true }
                return
            }

            await MainActor.run { permissionDenied = false }
            queue.async { [weak self] in
                guard let self else { return }
                if !started {
                    configure()
                    started = true
                }
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    nonisolated(unsafe) private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
            metadataOutput.metadataObjectTypes = [
                .ean8,
                .ean13,
                .upce
            ]
        }

        session.commitConfiguration()
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isProcessingCode else { return }
        guard let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let value = object.stringValue else { return }

        isProcessingCode = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastScannedCode = value
            self.onBarcode?(value)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isProcessingCode = false
            }
        }
    }
}
