import SwiftUI

struct TrainingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @StateObject private var coordinator = TrainingCoordinator()
    @State private var hasAdvanced = false
    @State private var showMarginalAlert = false
    @State private var showPoorAlert = false

    private let targetCount = 5

    private var capturedCount: Int {
        min(appState.activeTrainingAssets.count, targetCount)
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

                    if let product = appState.activeProduct {
                        Text(product.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppPalette.sun)
                            .accessibilityIdentifier("training.productName")
                    }
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
        .alert("Photos Look a Bit Different", isPresented: $showMarginalAlert) {
            Button("Retake Photos") {
                resetCapture()
            }
            Button("Continue Anyway") {
                proceedAfterTraining()
            }
        } message: {
            Text("Your photos look a bit different from each other — try keeping the bottle centered and well-lit.")
        }
        .alert("Let\u{2019}s Try Again", isPresented: $showPoorAlert) {
            Button("Retake Photos") {
                resetCapture()
            }
        } message: {
            Text("We couldn\u{2019}t get a consistent read on your bottle — let\u{2019}s try again.")
        }
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

        let quality = coordinator.validateEnrollmentQuality(
            payloads: appState.trainingFeatureData()
        )

        switch quality {
        case .good:
            hasAdvanced = true
            proceedAfterTraining()
        case .marginal:
            showMarginalAlert = true
        case .poor, .insufficient:
            showPoorAlert = true
        }
    }

    private func proceedAfterTraining() {
        hasAdvanced = true
        if isRetraining {
            router.open(.settings)
        } else {
            router.open(.enableNotifications)
        }
    }

    private func resetCapture() {
        hasAdvanced = false
        appState.clearTrainingDataForActiveProduct()
        coordinator.reset()
    }
}
