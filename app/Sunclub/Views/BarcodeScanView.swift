import SwiftUI

struct BarcodeScanView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @StateObject private var coordinator = BarcodeScannerCoordinator()
    @State private var hasAdvanced = false

    var body: some View {
        SunDarkScreen {
            VStack(spacing: 26) {
                SunStepHeader(step: 1, total: 3)

                cameraCard

                VStack(alignment: .leading, spacing: 10) {
                    Text("Scan Your Sunscreen")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("scan.title")

                    Text("Point your camera at the barcode on your sunscreen bottle.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if appState.isUITesting {
                    Button("Scan Demo Barcode") {
                        handleBarcode("UITEST-DEMO-BARCODE")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.sun)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("scan.demoBarcode")
                }
            }
        }
        .onAppear {
            coordinator.onBarcode = handleBarcode
            if !appState.isUITesting {
                coordinator.startIfNeeded()
            }
        }
        .onDisappear {
            coordinator.stop()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var cameraCard: some View {
        ZStack {
            SunCameraFrame(session: coordinator.session, square: true)

            if coordinator.permissionDenied {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.45))

                Text("Camera access denied")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private func handleBarcode(_ code: String) {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        appState.setExpectedBarcode(code)
        router.open(.trainPhotos)
    }
}
