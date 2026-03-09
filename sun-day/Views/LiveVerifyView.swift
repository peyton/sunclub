import SwiftUI

struct LiveVerifyView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @StateObject private var coordinator = VideoVerificationCoordinator()
    @State private var detected = false
    @State private var didAutoMark = false
    @State private var message = "Hold the bottle in frame for 2 seconds."
    @State private var lastDistance: Float? = nil

    var body: some View {
        VStack {
            Text("Live Video Verify")
                .font(.headline)

            ZStack {
                CameraPreview(session: coordinator.session)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                    .onAppear {
                        coordinator.onStateChange = { result in
                            detected = result.isDetected
                            lastDistance = result.featureDistance
                            if let distance = result.featureDistance {
                                message = String(format: "Bottle distance: %.3f", distance)
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

                if detected {
                    VStack {
                        Text("Bottle detected ✅")
                            .padding(8)
                            .background(.green)
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                }

                if coordinator.permissionDenied {
                    Color.black.opacity(0.6)
                    Text("Camera access denied")
                        .foregroundStyle(.white)
                }
            }

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()

            if detected {
                Button("Mark Applied") {
                    appState.markAppliedToday(
                        method: .video,
                        barcode: appState.settings.expectedBarcode,
                        featureDistance: lastDistance.map { Double($0) },
                        barcodeConfidence: nil
                    )
                    router.goHome()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Back") {
                router.goHome()
                dismiss()
            }
            .buttonStyle(.bordered)
                .padding(.top, 6)
        }
        .navigationTitle("Live Verify")
    }
}
