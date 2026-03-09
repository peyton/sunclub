import SwiftUI

struct TrainingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = TrainingCoordinator()
    @State private var message = "Move around your bottle and capture 15 photos."
    @State private var targetCount = 15

    var body: some View {
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        SunPill(title: "Optional but recommended", systemImage: "camera.macro", tint: AppPalette.sea)

                        Text("Train bottle recognition")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundStyle(AppPalette.ink)

                        Text(message)
                            .font(.callout)
                            .foregroundStyle(AppPalette.softInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sunCard()

                    ZStack {
                        CameraPreview(session: coordinator.session)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .frame(height: 420)
                            .onAppear {
                                coordinator.onResult = onCapture
                                coordinator.onError = { message = $0 }
                                coordinator.configure()
                            }
                            .onDisappear { coordinator.stop() }

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                            .foregroundStyle(AppPalette.sun.opacity(0.7))
                            .frame(width: 220, height: 260)

                        if coordinator.permissionDenied {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.black.opacity(0.58))

                            Text("Camera access denied")
                                .foregroundStyle(.white)
                                .font(.headline)
                        }
                    }

                    if coordinator.isProcessing {
                        ProgressView("Capturing")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.86), in: Capsule())
                    }

                    HStack {
                        Spacer()
                        SunPill(title: "Move around the bottle", systemImage: "arrow.trianglehead.2.clockwise", tint: AppPalette.sun)
                    }
                    .padding(18)
                }
                .sunCard(padding: 12)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        MetricTile(value: "\(coordinator.capturedCount)", title: "captured", tint: AppPalette.sun)
                        MetricTile(value: "\(max(targetCount - coordinator.capturedCount, 0))", title: "remaining", tint: AppPalette.sea)
                    }

                    ProgressView(value: Double(coordinator.capturedCount), total: Double(targetCount))
                        .tint(AppPalette.coral)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
                .sunCard()

                HStack(spacing: 12) {
                    Button("Capture") {
                        coordinator.captureFrame(targetCount: targetCount)
                    }
                    .buttonStyle(SunPrimaryButtonStyle())

                    Button("Reset") {
                        appState.clearTrainingData()
                        coordinator.reset()
                        message = "Cleared and ready."
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
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
                .buttonStyle(SunSecondaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .navigationBarTitleDisplayMode(.inline)
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
