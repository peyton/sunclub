import SwiftUI

struct LiveVerifyView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = VideoVerificationCoordinator()
    @State private var detected = false
    @State private var didAutoMark = false
    @State private var message = "Hold the bottle in frame for about two seconds."
    @State private var lastDistance: Float? = nil

    var body: some View {
        SunScreen {
            SunSectionHeader(
                eyebrow: "Live video",
                title: "Live video check-in",
                detail: "Keep the bottle inside the guide. When the match stays stable, today's check-in can be recorded automatically."
            )

            cameraCard

            SunStatusCard(
                title: detected ? "Bottle detected" : "Looking for your bottle",
                detail: detected ? detectionDetail : message,
                tint: detected ? AppPalette.success : AppPalette.warning,
                symbol: detected ? "checkmark.seal.fill" : "clock.fill"
            )

            VStack(spacing: 12) {
                Button("Record check-in") {
                    appState.markAppliedToday(
                        method: .video,
                        barcode: appState.settings.expectedBarcode,
                        featureDistance: lastDistance.map { Double($0) },
                        barcodeConfidence: nil
                    )
                    router.goHome()
                    dismiss()
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .disabled(!detected)

                Button("Back to home") {
                    router.goHome()
                    dismiss()
                }
                .buttonStyle(SunSecondaryButtonStyle())
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cameraCard: some View {
        ZStack {
            CameraPreview(session: coordinator.session)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .frame(height: 440)
                .onAppear {
                    coordinator.onStateChange = { result in
                        detected = result.isDetected
                        lastDistance = result.featureDistance
                        if let distance = result.featureDistance {
                            message = String(format: "Current bottle distance %.3f.", distance)
                        }
                    }
                    coordinator.configure(trainingPayloads: appState.trainingFeatureData())
                }
                .onDisappear {
                    coordinator.stop()
                }
                .onChange(of: detected) { _, newValue in
                    if newValue && !didAutoMark {
                        didAutoMark = true
                        appState.markAppliedToday(
                            method: .video,
                            barcode: appState.settings.expectedBarcode,
                            featureDistance: lastDistance.map { Double($0) },
                            barcodeConfidence: nil
                        )
                        router.goHome()
                        dismiss()
                    }
                    if !newValue {
                        didAutoMark = false
                    }
                }

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)

            VStack {
                HStack {
                    SunCameraOverlayLabel(title: "Live match", tint: AppPalette.coral)
                    Spacer(minLength: 0)
                    SunCameraOverlayLabel(title: detected ? "Detected" : "Searching", tint: detected ? AppPalette.success : AppPalette.warning)
                }

                Spacer()
            }
            .padding(18)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [10, 8]))
                .foregroundStyle((detected ? AppPalette.success : AppPalette.sun).opacity(0.88))
                .frame(width: 240, height: 270)

            if detected {
                VStack {
                    Spacer()

                    Text("Bottle detected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppPalette.success.opacity(0.94), in: Capsule())
                        .padding(.bottom, 20)
                }
            }

            if coordinator.permissionDenied {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.58))

                Text("Camera access denied")
                    .foregroundStyle(.white)
            }
        }
        .sunCard(padding: 12)
    }

    private var detectionDetail: String {
        if let distance = lastDistance {
            return String(format: "Current match distance: %.3f. You can confirm now.", distance)
        }
        return "The bottle match is stable."
    }
}
