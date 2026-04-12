import PhotosUI
import SwiftUI
import UIKit

struct ProductScannerView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var scanResult: SunclubProductScanResult?
    @State private var isShowingCamera = false
    @State private var errorMessage: String?
    @State private var isScanning = false
    @State private var scanResultPendingUse: SunclubProductScanResult?
    @State private var scanSheenActive = false
    @State private var feedbackTrigger = 0

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Product Scanner", showsBack: true, onBack: {
                    router.goBack()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text("Know your SPF")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Point the camera at a sunscreen label or import a photo. Sunclub reads the SPF and keeps the final edit in your hands.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }

                if previewImage == nil {
                    SunAssetHero(
                        asset: .illustrationScannerLabel,
                        height: 178,
                        glowColor: AppPalette.pool
                    )
                }

                actionRow

                if let previewImage {
                    scanPreview(for: previewImage)
                }

                if isScanning {
                    ProgressView("Scanning bottle")
                        .tint(AppPalette.sun)
                }

                if let errorMessage {
                    SunStatusCard(
                        title: "Scan issue",
                        detail: errorMessage,
                        tint: Color.red.opacity(0.8),
                        symbol: "exclamationmark.triangle.fill"
                    )
                }

                if let scanResult {
                    resultCard(for: scanResult)
                }

                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureSheet(
                onImage: { image in
                    isShowingCamera = false
                    handleImage(image)
                },
                onCancel: {
                    isShowingCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadPhoto(from: newValue)
            }
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .confirmationDialog(
            "Use scanned SPF?",
            isPresented: Binding(
                get: { scanResultPendingUse != nil },
                set: { if !$0 { scanResultPendingUse = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let scanResultPendingUse {
                Button(confirmUseTitle(for: scanResultPendingUse)) {
                    useScanInTodaysLog(scanResultPendingUse)
                    self.scanResultPendingUse = nil
                }
            }

            Button("Cancel", role: .cancel) {
                scanResultPendingUse = nil
            }
        } message: {
            Text("Sunclub will add this SPF to today's optional details. You can still edit it before logging.")
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Use Camera") {
                    feedbackTrigger += 1
                    isShowingCamera = true
                }
                .buttonStyle(SunPrimaryButtonStyle())
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text("Pick Photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SunSecondaryButtonStyle())
        }
    }

    private func resultCard(for result: SunclubProductScanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(result.summary)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            if let expirationText = result.expirationText {
                Text("Detected expiry: \(expirationText)")
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.softInk)
            }

            if !result.recognizedText.isEmpty {
                Text(result.recognizedText.joined(separator: "\n"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .lineLimit(6)
            }

            Button(result.spfLevel == nil ? "No SPF Found" : "Use in Today's Log") {
                feedbackTrigger += 1
                scanResultPendingUse = result
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .disabled(result.spfLevel == nil)
        }
        .padding(18)
        .sunGlassCard(cornerRadius: 20)
    }

    private func scanPreview(for image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppPalette.sun.opacity(0.64), lineWidth: 2)
            }
            .overlay {
                SunclubVisualAsset.motifScanSheen.image
                    .resizable()
                    .scaledToFill()
                    .opacity(isScanning ? 0.42 : 0.16)
                    .offset(x: scanSheenActive ? 220 : -220)
                    .animation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false), value: scanSheenActive)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topLeading) {
                SunCameraOverlayLabel(title: "SPF scan", tint: AppPalette.pool)
                    .padding(14)
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 6) {
                    SunCameraOverlayLabel(title: "Label", tint: AppPalette.sun)
                    SunCameraOverlayLabel(title: "Expiry", tint: AppPalette.aloe)
                }
                .padding(14)
            }
            .onAppear {
                scanSheenActive = true
            }
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Sunclub could not load that photo."
                return
            }
            handleImage(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImage(_ image: UIImage) {
        feedbackTrigger += 1
        previewImage = image
        scanResult = nil
        errorMessage = nil
        isScanning = true

        Task {
            defer { isScanning = false }
            do {
                let result = try await SunclubProductScannerService.scan(image: image)
                scanResult = result
                appState.rememberScannedSPF(result.spfLevel)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func confirmUseTitle(for result: SunclubProductScanResult) -> String {
        guard let spfLevel = result.spfLevel else {
            return "Use Scan"
        }

        return "Use SPF \(spfLevel)"
    }

    private func useScanInTodaysLog(_ result: SunclubProductScanResult) {
        let note = result.expirationText.map { "Bottle expiry: \($0)" } ?? ""
        appState.setManualLogPrefill(spfLevel: result.spfLevel, notes: note)
        appState.recordProductScanUsedForLog(spfLevel: result.spfLevel)
        router.open(.manualLog)
    }
}

#Preview {
    SunclubPreviewHost {
        ProductScannerView()
    }
}
