import SwiftUI

struct SelfieCaptureView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = SelfieCaptureCoordinator()
    @State private var statusMessage: String = "Use the front camera and keep both your face and bottle visible."
    @State private var lastResult: SelfieCaptureResult?

    var body: some View {
        SunScreen {
            SunSectionHeader(
                eyebrow: "Selfie check-in",
                title: "Check in with a selfie",
                detail: "Keep your face and bottle in view. The app checks the expected barcode when possible and also compares the bottle to your saved training images."
            )

            cameraCard

            if let result = lastResult {
                SunStatusCard(
                    title: result.verified ? "Verification passed" : "Verification failed",
                    detail: resultMessage(for: result),
                    tint: result.verified ? AppPalette.success : AppPalette.danger,
                    symbol: result.verified ? "checkmark.seal.fill" : "xmark.circle.fill"
                )
            } else {
                SunStatusCard(
                    title: "Frame your face and bottle",
                    detail: statusMessage,
                    tint: AppPalette.sea,
                    symbol: "person.crop.square"
                )
            }

            VStack(spacing: 12) {
                Button {
                    coordinator.capture()
                } label: {
                    Label("Take Selfie", systemImage: "camera.circle.fill")
                }
                .buttonStyle(SunPrimaryButtonStyle())

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
                    coordinator.onResult = handleResult
                    coordinator.configure(expectedBarcode: appState.settings.expectedBarcode, trainingPayloads: appState.trainingFeatureData())
                }
                .onDisappear {
                    coordinator.stop()
                }

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)

            VStack {
                HStack {
                    SunCameraOverlayLabel(title: "Front camera", tint: AppPalette.sea)
                    Spacer(minLength: 0)
                    SunCameraOverlayLabel(title: "Bottle visible", tint: AppPalette.sun)
                }

                Spacer()
            }
            .padding(18)

            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [10, 8]))
                .foregroundStyle(AppPalette.sun.opacity(0.86))
                .frame(width: 220, height: 220)

            if coordinator.permissionDenied {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.58))
                Text("Camera access denied")
                    .foregroundStyle(.white)
            }

            VStack {
                Spacer()

                if coordinator.isProcessing {
                    Text("Analyzing photo")
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

    private func handleResult(_ result: SelfieCaptureResult) {
        lastResult = result

        if result.verified {
            appState.markAppliedToday(
                method: .selfie,
                barcode: result.barcode,
                featureDistance: result.featureDistance,
                barcodeConfidence: nil
            )
            statusMessage = "Today's sunscreen is recorded."
            router.goHome()
            dismiss()
        } else {
            statusMessage = "The bottle could not be verified. Try again with the bottle fully visible."
        }
    }

    private func resultMessage(for result: SelfieCaptureResult) -> String {
        if result.verified {
            if let distance = result.featureDistance {
                return String(format: "Bottle matched with feature distance %.3f.", distance)
            }
            return "The check passed and today was recorded."
        }

        if let distance = result.featureDistance {
            return String(format: "The bottle match was too weak at %.3f. Try again with less glare.", distance)
        }

        return "The bottle or expected barcode could not be confirmed in this photo."
    }
}
