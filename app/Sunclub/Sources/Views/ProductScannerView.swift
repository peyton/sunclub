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

                actionRow

                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Use Camera") {
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

            Button("Use In Today's Log") {
                let note = result.expirationText.map { "Bottle expiry: \($0)" } ?? ""
                appState.setManualLogPrefill(spfLevel: result.spfLevel, notes: note)
                appState.recordProductScanUsedForLog(spfLevel: result.spfLevel)
                router.open(.manualLog)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .disabled(result.spfLevel == nil)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
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
}

#Preview {
    SunclubPreviewHost {
        ProductScannerView()
    }
}
