import SwiftUI

struct LiveVerifyView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @StateObject private var coordinator = VideoVerificationCoordinator()
    @State private var statusMessage = "Hold your bottle in view while Sunclub verifies it."
    @State private var lastDistance: Float?
    @State private var hasAdvanced = false
    @State private var appearedAt = Date()

    var body: some View {
        SunDarkScreen {
            VStack(alignment: .leading, spacing: 24) {
                header

                cameraCard

                Text(statusMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("verify.status")
            }
        }
        .onAppear {
            appearedAt = Date()
            coordinator.onStateChange = { result in
                lastDistance = result.featureDistance
                if result.isDetected {
                    completeVerification(distance: result.featureDistance)
                } else if let distance = result.featureDistance {
                    statusMessage = String(format: "Matching bottle model… %.3f", distance)
                }
            }

            if appState.isUITesting {
                statusMessage = "Matching bottle model…"
                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await MainActor.run {
                        completeVerification(distance: 0.118)
                    }
                }
                return
            }

            if appState.activeProduct == nil {
                statusMessage = "Add a sunscreen bottle before verifying."
                return
            }

            if appState.trainingFeatureData().isEmpty {
                statusMessage = "Train your bottle model in Settings before verifying."
                return
            }

            coordinator.configure(trainingPayloads: appState.trainingFeatureData())
        }
        .onDisappear {
            coordinator.stop()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                router.goHome()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .buttonStyle(.plain)

            Text("Verify Sunscreen")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .accessibilityIdentifier("verify.title")

            if let product = appState.activeProduct {
                Text(product.name)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
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

    private func completeVerification(distance: Float?) {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        appState.recordVerificationSuccess(
            method: .video,
            barcode: appState.activeProduct?.barcode,
            featureDistance: distance.map(Double.init),
            barcodeConfidence: nil,
            verificationDuration: Date().timeIntervalSince(appearedAt)
        )
        router.open(.verifySuccess)
    }
}
