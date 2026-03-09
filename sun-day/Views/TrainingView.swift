import SwiftUI

struct TrainingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = TrainingCoordinator()
    @State private var message = "Move around your bottle and capture 15 photos."
    @State private var targetCount = 15

    var body: some View {
        VStack {
            Text("Train Bottle Recognition")
                .font(.headline)

            Text(message)
                .foregroundStyle(.secondary)
                .font(.footnote)
                .padding(.horizontal)

            ZStack {
                CameraPreview(session: coordinator.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .onAppear {
                        coordinator.onResult = onCapture
                        coordinator.onError = { message = $0 }
                        coordinator.configure()
                    }
                    .onDisappear { coordinator.stop() }
                    .overlay(
                        Group {
                            if coordinator.permissionDenied {
                                Color.black.opacity(0.6)
                                Text("Camera access denied")
                                    .foregroundStyle(.white)
                                    .font(.headline)
                            }
                        }
                    )

                if coordinator.isProcessing {
                    ProgressView("Capturing")
                        .padding(8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            Text("Captured \(coordinator.capturedCount) / \(targetCount)")
                .font(.title2)
                .bold()

            HStack {
                Button("Capture") {
                    coordinator.captureFrame(targetCount: targetCount)
                }
                .buttonStyle(.borderedProminent)

                Button("Reset") {
                    appState.clearTrainingData()
                    coordinator.reset()
                    message = "Cleared and ready."
                }
                .buttonStyle(.bordered)
            }

            Button("Done") {
                if appState.trainingAssets.count == 0 {
                    if coordinator.capturedCount > 0 {
                        message = "Keep capturing a bit more for reliability."
                    } else {
                        message = "Capture at least one photo first."
                    }
                }
                router.goHome()
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    private func onCapture(_ result: TrainingCaptureResult) {
        appState.addTrainingFeature(result.featurePrintData, width: result.width, height: result.height)
        if coordinator.capturedCount >= targetCount {
            message = "Training complete. You can return home."
        } else {
            message = "Good capture. Keep going around the bottle."
        }
    }
}
