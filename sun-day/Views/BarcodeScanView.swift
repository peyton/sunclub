import SwiftUI

struct BarcodeScanView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = BarcodeScannerCoordinator()
    @State private var bannerMessage: String?
    let onboardingMode: Bool

    init(onboardingMode: Bool) {
        self.onboardingMode = onboardingMode
    }

    var body: some View {
        SunScreen {
            SunSectionHeader(
                eyebrow: onboardingMode ? "Bottle setup" : "Daily proof",
                title: onboardingMode ? "Scan your bottle barcode" : "Scan barcode",
                detail: "Aim the UPC or EAN inside the guide. The app will grab it as soon as the camera sees a clean match."
            )

            cameraCard

            if let message = bannerMessage {
                SunStatusCard(
                    title: feedbackTitle(for: message),
                    detail: message,
                    tint: feedbackTint(for: message),
                    symbol: feedbackSymbol(for: message)
                )
            }

            VStack(spacing: 12) {
                if onboardingMode, appState.settings.expectedBarcode != nil {
                    Button("Save bottle and continue") {
                        appState.completeOnboarding()
                        router.goHome()
                        dismiss()
                    }
                    .buttonStyle(SunPrimaryButtonStyle())
                }

                Button(onboardingMode ? "Back to setup" : "Back to home") {
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
                .frame(height: 430)
                .onAppear {
                    coordinator.onBarcode = handleBarcode
                    coordinator.startIfNeeded()
                }
                .onDisappear {
                    coordinator.stop()
                }

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)

            VStack {
                HStack {
                    SunCameraOverlayLabel(title: "Rear camera", tint: AppPalette.sea)
                    Spacer(minLength: 0)
                    SunCameraOverlayLabel(title: "UPC / EAN", tint: AppPalette.sun)
                }

                Spacer()
            }
            .padding(18)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 2.5, dash: [10, 8]))
                .foregroundStyle(AppPalette.sun.opacity(0.86))
                .frame(width: 250, height: 120)

            VStack {
                Spacer()

                Text("Hold steady until the code locks in")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.38), in: Capsule())
                    .padding(.bottom, 22)
            }

            if coordinator.permissionDenied {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.58))

                Text("Camera access denied")
                    .foregroundStyle(.white)
                    .font(.headline)
            }
        }
        .sunCard(padding: 12)
    }

    private func handleBarcode(_ code: String) {
        if onboardingMode {
            appState.setExpectedBarcode(code)
            bannerMessage = "Barcode captured: \(code)"
            return
        }

        if let expected = appState.settings.expectedBarcode {
            if code == expected {
                appState.markAppliedToday(method: .barcode, barcode: code, featureDistance: nil, barcodeConfidence: nil)
                bannerMessage = "Verified and marked for today."
                router.goHome()
                dismiss()
            } else {
                bannerMessage = "This barcode does not match your expected bottle."
            }
        } else {
            bannerMessage = "Set an expected barcode first from onboarding."
        }
    }

    private func feedbackTitle(for message: String) -> String {
        if message.contains("Verified") || message.contains("captured") {
            return "Barcode accepted"
        }
        return "Barcode issue"
    }

    private func feedbackTint(for message: String) -> Color {
        if message.contains("Verified") || message.contains("captured") {
            return AppPalette.success
        }
        return AppPalette.danger
    }

    private func feedbackSymbol(for message: String) -> String {
        if message.contains("Verified") || message.contains("captured") {
            return "checkmark.seal.fill"
        }
        return "xmark.circle.fill"
    }
}
