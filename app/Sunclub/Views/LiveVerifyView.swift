import SwiftUI

struct LiveVerifyView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @StateObject private var coordinator = VideoVerificationCoordinator()
    @State private var statusMessage = "Hold your bottle in view while Sunclub verifies it."
    @State private var lastDistance: Float?
    @State private var confidenceSamples: [Float] = []
    @State private var smoothedConfidence: Float = 0
    @State private var hasAdvanced = false
    @State private var appearedAt = Date()

    var body: some View {
        SunDarkScreen {
            VStack(alignment: .leading, spacing: 24) {
                header

                cameraCard

                confidenceCard

                Text(statusMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("verify.status")
            }
        }
        .onAppear {
            appearedAt = Date()
            confidenceSamples = []
            smoothedConfidence = 0
            coordinator.onStateChange = { result in
                lastDistance = result.featureDistance
                updateConfidence(result.confidence)
                if result.isDetected {
                    completeVerification(distance: result.featureDistance)
                } else if let distance = result.featureDistance, smoothedConfidence > 0 {
                    statusMessage = String(
                        format: "Confidence %d%% · distance %.3f",
                        confidencePercent,
                        distance
                    )
                } else {
                    statusMessage = "Hold your bottle steady and centered."
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

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Match Confidence")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))

                Spacer(minLength: 0)

                Text("\(confidencePercent)%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(confidenceColor)
                    .accessibilityIdentifier("verify.confidence")
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))

                    Capsule(style: .continuous)
                        .fill(confidenceColor)
                        .frame(width: proxy.size.width * CGFloat(smoothedConfidence))
                        .animation(.easeOut(duration: 0.16), value: smoothedConfidence)
                }
            }
            .frame(height: 12)

            Text(confidenceHint)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var confidencePercent: Int {
        Int((smoothedConfidence * 100).rounded())
    }

    private var confidenceColor: Color {
        switch smoothedConfidence {
        case 0.75...:
            return AppPalette.success
        case 0.45...:
            return AppPalette.sun
        default:
            return Color(red: 0.960, green: 0.500, blue: 0.360)
        }
    }

    private var confidenceHint: String {
        if coordinator.permissionDenied {
            return "Camera access is required for live verification."
        }

        if let distance = lastDistance, smoothedConfidence > 0 {
            return String(format: "Current feature distance: %.3f", distance)
        }

        return "Confidence rises as the current frame matches your trained bottle model."
    }

    private func updateConfidence(_ confidence: Float) {
        let clamped = min(max(confidence, 0), 1)
        confidenceSamples.append(clamped)
        if confidenceSamples.count > 5 {
            confidenceSamples.removeFirst(confidenceSamples.count - 5)
        }
        guard !confidenceSamples.isEmpty else {
            smoothedConfidence = 0
            return
        }
        smoothedConfidence = confidenceSamples.reduce(0, +) / Float(confidenceSamples.count)
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
