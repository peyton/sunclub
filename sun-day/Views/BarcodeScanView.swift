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
                eyebrow: onboardingMode ? "Bottle setup" : "Today's check-in",
                title: onboardingMode ? "Scan your bottle barcode" : "Scan your barcode",
                detail: "Point the camera at the UPC or EAN on your bottle and hold steady."
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
                    Button("Save bottle") {
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

                Text("Hold steady until the barcode is scanned")
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
            bannerMessage = "Bottle barcode saved: \(code)"
            return
        }

        if let expected = appState.settings.expectedBarcode {
            if code == expected {
                appState.markAppliedToday(method: .barcode, barcode: code, featureDistance: nil, barcodeConfidence: nil)
                bannerMessage = "Today's sunscreen is recorded."
                router.goHome()
                dismiss()
            } else {
                bannerMessage = "This barcode does not match your saved bottle."
            }
        } else {
            bannerMessage = "Set your bottle barcode during setup first."
        }
    }

    private func feedbackTitle(for message: String) -> String {
        if message.contains("recorded") || message.contains("saved") {
            return "Barcode accepted"
        }
        return "Barcode issue"
    }

    private func feedbackTint(for message: String) -> Color {
        if message.contains("recorded") || message.contains("saved") {
            return AppPalette.success
        }
        return AppPalette.danger
    }

    private func feedbackSymbol(for message: String) -> String {
        if message.contains("recorded") || message.contains("saved") {
            return "checkmark.seal.fill"
        }
        return "xmark.circle.fill"
    }
}
