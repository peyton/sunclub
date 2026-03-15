import SwiftUI

struct TrainingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @StateObject private var coordinator = TrainingCoordinator()
    @State private var hasAdvanced = false

    private let targetCount = 5

    private var capturedCount: Int {
        min(appState.trainingAssets.count, targetCount)
    }

    private var isRetraining: Bool {
        appState.settings.hasCompletedOnboarding
    }

    var body: some View {
        SunDarkScreen {
            VStack(spacing: 26) {
                if !isRetraining {
                    SunStepHeader(step: 2, total: 3)
                }

                cameraCard

                VStack(spacing: 12) {
                    Text("Train Your Bottle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("training.title")

                    Text("\(capturedCount) / \(targetCount) photos captured")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
            }
        } footer: {
            Button("Capture Photo") {
                capturePhoto()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("training.capturePhoto")
        }
        .onAppear {
            coordinator.onResult = onCapture
            coordinator.onError = { _ in }
            if !appState.isUITesting {
                coordinator.configure(initialCount: capturedCount)
            }
        }
        .onDisappear {
            coordinator.stop()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var cameraCard: some View {
        ZStack {
            SunCameraFrame(session: coordinator.session)

            if coordinator.permissionDenied {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.45))

                Text("Camera access denied")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private func capturePhoto() {
        if appState.isUITesting {
            let payload = Data("uitest-\(UUID().uuidString)".utf8)
            appState.addTrainingFeature(payload, width: 1, height: 1)
            coordinator.recordSyntheticCapture()
            advanceIfNeeded()
            return
        }

        coordinator.captureFrame(targetCount: targetCount)
    }

    private func onCapture(_ result: TrainingCaptureResult) {
        appState.addTrainingFeature(result.featurePrintData, width: result.width, height: result.height)
        advanceIfNeeded()
    }

    private func advanceIfNeeded() {
        guard !hasAdvanced, capturedCount >= targetCount else { return }
        hasAdvanced = true

        if isRetraining {
            router.open(.settings)
        } else {
            router.open(.enableNotifications)
        }
    }
}
