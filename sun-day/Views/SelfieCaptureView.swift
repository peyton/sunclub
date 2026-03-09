import SwiftUI

struct SelfieCaptureView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = SelfieCaptureCoordinator()
    @State private var statusMessage: String = "Use front camera and include your sunscreen bottle."
    @State private var lastResult: SelfieCaptureResult?

    var body: some View {
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        SunPill(title: "Front camera proof", systemImage: "person.crop.square", tint: AppPalette.sea)

                        Text("Selfie verification")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(AppPalette.ink)

                        Text(statusMessage)
                            .font(.callout)
                            .foregroundStyle(AppPalette.softInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sunCard()

                    ZStack {
                        CameraPreview(session: coordinator.session)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .frame(height: 420)
                            .onAppear {
                                coordinator.onResult = handleResult
                                coordinator.configure(expectedBarcode: appState.settings.expectedBarcode, trainingPayloads: appState.trainingFeatureData())
                            }
                            .onDisappear { coordinator.stop() }

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)

                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 7]))
                            .foregroundStyle(AppPalette.sun.opacity(0.75))
                            .frame(width: 220, height: 220)

                        if coordinator.permissionDenied {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.black.opacity(0.58))
                            Text("Camera access denied")
                                .foregroundStyle(.white)
                        }

                        VStack {
                            Spacer()
                            if coordinator.isProcessing {
                                ProgressView("Analyzing...")
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.86), in: Capsule())
                            }
                            Spacer()
                        }
                    }
                    .sunCard(padding: 12)

                    if let result = lastResult {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(result.verified ? "Verification passed" : "Verification failed")
                                .font(.headline)
                                .foregroundStyle(result.verified ? AppPalette.success : AppPalette.danger)

                            if let distance = result.featureDistance {
                                detailLine(title: "Feature distance", value: String(format: "%.3f", distance))
                            }
                            if result.barcodeMatched {
                                detailLine(title: "Barcode", value: "Expected code found")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sunCard()
                    }

                    Button {
                        coordinator.capture()
                    } label: {
                        Label("Capture Selfie", systemImage: "camera.circle.fill")
                    }
                    .buttonStyle(SunPrimaryButtonStyle())

                    Button("Back") {
                        router.goHome()
                        dismiss()
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
            statusMessage = "Marked as applied for today."
            router.goHome()
            dismiss()
        } else {
            statusMessage = "No barcode match and feature match not confident. Try another angle with bottle visible."
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppPalette.softInk)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
        }
    }
}
