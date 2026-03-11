import SwiftUI

struct TrainingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = TrainingCoordinator()
    @State private var message = "Move around the bottle and capture about 15 photos."
    @State private var targetCount = 15

    var body: some View {
        SunScreen {
            SunSectionHeader(
                eyebrow: "Bottle training",
                title: "Train your bottle",
                detail: "Capture several views of your bottle so daily check-ins feel faster and more reliable."
            )

            cameraCard
            progressCard

            VStack(spacing: 12) {
                Button("Capture photo") {
                    coordinator.captureFrame(targetCount: targetCount)
                }
                .buttonStyle(SunPrimaryButtonStyle())

                HStack(spacing: 12) {
                    Button("Reset training") {
                        appState.clearTrainingData()
                        coordinator.reset()
                        message = "Training cleared. Start fresh."
                    }
                    .buttonStyle(SunSecondaryButtonStyle())

                    Button("Done") {
                        if appState.trainingAssets.count == 0 {
                            if coordinator.capturedCount > 0 {
                                message = "Capture a few more views to strengthen matching."
                            } else {
                                message = "Capture at least one photo first."
                            }
                        }
                        router.goHome()
                        dismiss()
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cameraCard: some View {
        ZStack {
            CameraPreview(session: coordinator.session)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .frame(height: 430)
                .onAppear {
                    coordinator.onResult = onCapture
                    coordinator.onError = { message = $0 }
                    coordinator.configure()
                }
                .onDisappear {
                    coordinator.stop()
                }

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)

            VStack {
                HStack {
                    SunCameraOverlayLabel(title: "Training", tint: AppPalette.sea)
                    Spacer(minLength: 0)
                    SunCameraOverlayLabel(title: "Move around the bottle", tint: AppPalette.sun)
                }

                Spacer()
            }
            .padding(18)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [10, 8]))
                .foregroundStyle(AppPalette.sun.opacity(0.86))
                .frame(width: 230, height: 270)

            if coordinator.permissionDenied {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.58))

                Text("Camera access denied")
                    .foregroundStyle(.white)
                    .font(.headline)
            }

            VStack {
                Spacer()

                if coordinator.isProcessing {
                    Text("Saving training data")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.40), in: Capsule())
                        .padding(.bottom, 18)
                }
            }
        }
        .sunCard(padding: 12)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MetricTile(value: "\(coordinator.capturedCount)", title: "captured", tint: AppPalette.sun)
                MetricTile(value: "\(max(targetCount - coordinator.capturedCount, 0))", title: "remaining", tint: AppPalette.sea)
            }

            ProgressView(value: Double(coordinator.capturedCount), total: Double(targetCount))
                .tint(AppPalette.coral)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            Text(message)
                .font(.footnote)
                .foregroundStyle(AppPalette.softInk)
        }
        .sunCard()
    }

    private func onCapture(_ result: TrainingCaptureResult) {
        appState.addTrainingFeature(result.featurePrintData, width: result.width, height: result.height)
        if coordinator.capturedCount >= targetCount {
            message = "Training complete. Your bottle is ready for check-ins."
        } else {
            message = "Photo saved. Keep moving around the bottle."
        }
    }
}
