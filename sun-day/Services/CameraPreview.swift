import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = gravity
        preview.frame = container.bounds
        preview.backgroundColor = UIColor.black.cgColor
        container.layer.addSublayer(preview)
        context.coordinator.previewLayer = preview
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
