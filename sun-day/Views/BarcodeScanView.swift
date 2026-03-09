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
        VStack {
            Text(onboardingMode ? "Scan expected bottle barcode" : "Scan barcode")
                .font(.headline)
            ZStack {
                CameraPreview(session: coordinator.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .onAppear {
                        coordinator.onBarcode = handleBarcode
                        coordinator.startIfNeeded()
                    }
                    .onDisappear {
                        coordinator.stop()
                    }

                if coordinator.permissionDenied {
                    Color.black.opacity(0.6)
                    Text("Camera access denied")
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 360)

            if let message = bannerMessage {
                Text(message)
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }

            Text("Aim the barcode at the camera until it is detected.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            Button("Done") {
                if onboardingMode {
                    if appState.settings.expectedBarcode != nil {
                        appState.completeOnboarding()
                    }
                }
                router.goHome()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
        .navigationTitle("Barcode Scan")
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
