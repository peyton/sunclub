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
        ZStack {
            SunBackdrop()

            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    SunPill(
                        title: onboardingMode ? "Set your bottle" : "Daily barcode proof",
                        systemImage: "barcode.viewfinder",
                        tint: AppPalette.sun
                    )

                    Text(onboardingMode ? "Scan your bottle barcode" : "Scan barcode")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(AppPalette.ink)

                    Text("Aim the UPC or EAN code inside the frame and let the camera do the boring part.")
                        .font(.callout)
                        .foregroundStyle(AppPalette.softInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .sunCard()

                ZStack {
                    CameraPreview(session: coordinator.session)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .onAppear {
                            coordinator.onBarcode = handleBarcode
                            coordinator.startIfNeeded()
                        }
                        .onDisappear {
                            coordinator.stop()
                        }

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 7]))
                        .foregroundStyle(AppPalette.sun.opacity(0.82))
                        .frame(width: 250, height: 120)

                    if coordinator.permissionDenied {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.black.opacity(0.58))
                        Text("Camera access denied")
                            .foregroundStyle(.white)
                            .font(.headline)
                    }
                }
                .frame(height: 380)
                .sunCard(padding: 12)

                if let message = bannerMessage {
                    Text(message)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sunCard(padding: 16)
                }

                Button(onboardingMode ? "Use this barcode" : "Done") {
                    if onboardingMode {
                        if appState.settings.expectedBarcode != nil {
                            appState.completeOnboarding()
                        }
                    }
                    router.goHome()
                    dismiss()
                }
                .buttonStyle(SunPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .navigationBarTitleDisplayMode(.inline)
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
}
