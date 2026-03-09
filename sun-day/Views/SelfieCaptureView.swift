import SwiftUI

struct SelfieCaptureView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = SelfieCaptureCoordinator()
    @State private var statusMessage: String = "Use front camera and include your sunscreen bottle."
    @State private var lastResult: SelfieCaptureResult?

    var body: some View {
        VStack {
            Text("Selfie verification")
                .font(.headline)

            ZStack {
                CameraPreview(session: coordinator.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .onAppear {
                        coordinator.onResult = handleResult
                        coordinator.configure(expectedBarcode: appState.settings.expectedBarcode, trainingPayloads: appState.trainingFeatureData())
                    }
                    .onDisappear { coordinator.stop() }

                if coordinator.permissionDenied {
                    Color.black.opacity(0.6)
                    Text("Camera access denied")
                        .foregroundStyle(.white)
                }

                VStack {
                    Spacer()
                    if coordinator.isProcessing {
                        ProgressView("Analyzing...")
                            .padding(8)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }

            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let result = lastResult {
                VStack(spacing: 6) {
                    if result.verified {
                        Text("Verification passed")
                            .font(.headline)
                            .foregroundStyle(.green)
                    } else {
                        Text("Verification failed")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }

                    if let distance = result.featureDistance {
                        Text(String(format: "Feature distance: %.3f", distance))
                            .font(.caption)
                    }
                    if result.barcodeMatched {
                        Text("Expected barcode found")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Button {
                coordinator.capture()
            } label: {
                Label("Capture Selfie", systemImage: "camera.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()

            Button("Back") {
                router.goHome()
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .navigationTitle("Selfie")
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
}
