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
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        SunPill(title: "Hands-free proof", systemImage: "video.badge.checkmark", tint: AppPalette.coral)

                        Text("Live video verify")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(AppPalette.ink)

                        Text(message)
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

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 1)

                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                            .foregroundStyle((detected ? AppPalette.success : AppPalette.sun).opacity(0.85))
                            .frame(width: 230, height: 260)

                        if detected {
                            VStack {
                                Text("Bottle detected")
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(AppPalette.success, in: Capsule())
                                    .foregroundStyle(.white)
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                        }

                        if coordinator.permissionDenied {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.black.opacity(0.58))
                            Text("Camera access denied")
                                .foregroundStyle(.white)
                        }
                    }
                    .sunCard(padding: 12)

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
                        .buttonStyle(SunPrimaryButtonStyle())
                    }

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
}
