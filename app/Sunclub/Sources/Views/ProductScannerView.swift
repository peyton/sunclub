import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ProductScannerView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var scanResult: SunclubProductScanResult?
    @State private var isShowingCamera = false
    @State private var cameraAuthorizationState = ProductScannerView.initialCameraAuthorizationState()
    @State private var errorMessage: String?
    @State private var isScanning = false
    @State private var scanResultPendingUse: SunclubProductScanResult?
    @State private var scanSheenActive = false
    @State private var feedbackTrigger = 0
    @State private var activeScanID = UUID()

    private enum CameraAuthorizationState {
        case notDetermined
        case authorized
        case denied
    }

    private static let maximumScanImageDimension: CGFloat = 1600

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

                if cameraAuthorizationState == .denied {
                    cameraAccessDeniedCard
                }

                if previewImage == nil {
                    SunAssetHero(
                        asset: .illustrationScannerLabel,
                        height: 132,
                        glowColor: AppPalette.pool
                    )
                }

                if let previewImage {
                    scanPreview(for: previewImage)
                }

                if isScanning {
                    ProgressView("Scanning bottle")
                        .tint(AppPalette.sun)
                        .accessibilityIdentifier("productScanner.scanning")
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                scannerActions
            }

            VStack(spacing: 10) {
                scannerActions
            }
        }
    }

    @ViewBuilder
    private var scannerActions: some View {
        if Self.isCameraSourceAvailable, cameraAuthorizationState != .denied {
            Button("Use Camera") {
                requestCameraAccess()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .disabled(isScanning)
            .accessibilityIdentifier("productScanner.useCamera")
        }

        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Text("Pick Photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SunSecondaryButtonStyle())
        .disabled(isScanning)
        .accessibilityIdentifier("productScanner.pickPhoto")
    }

    private static var isCameraSourceAvailable: Bool {
        RuntimeEnvironment.cameraAuthorizationOverride != nil || UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private static func initialCameraAuthorizationState() -> CameraAuthorizationState {
        switch RuntimeEnvironment.cameraAuthorizationOverride {
        case "authorized":
            return .authorized
        case "denied", "restricted":
            return .denied
        default:
            break
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private func requestCameraAccess() {
        feedbackTrigger += 1

        switch cameraAuthorizationState {
        case .authorized:
            isShowingCamera = true
        case .denied:
            errorMessage = nil
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    cameraAuthorizationState = granted ? .authorized : .denied
                    if granted {
                        isShowingCamera = true
                    }
                }
            }
        }
    }

    private var cameraAccessDeniedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SunStatusCard(
                title: "Camera access denied",
                detail: "Turn on camera access in Settings to scan sunscreen labels. You can still pick a photo.",
                tint: Color.red.opacity(0.8),
                symbol: "camera.fill"
            )
            .accessibilityIdentifier("productScanner.cameraDenied")

            Button("Open Settings") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                openURL(settingsURL)
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityIdentifier("productScanner.openSettings")
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

            Button(result.spfLevel == nil ? "No SPF Found" : "Use in Today's Log") {
                feedbackTrigger += 1
                scanResultPendingUse = result
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .disabled(result.spfLevel == nil)
            .accessibilityIdentifier("productScanner.useResult")

            if !result.recognizedText.isEmpty {
                Text("Read from label")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                Text(result.recognizedText.joined(separator: "\n"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("productScanner.recognizedText")
            }

        }
        .padding(18)
        .sunGlassCard(cornerRadius: 20)
        .accessibilityIdentifier("productScanner.result")
    }

    private func scanPreview(for image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 280)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppPalette.sun.opacity(0.64), lineWidth: 2)
            }
            .overlay {
                SunclubVisualAsset.motifScanSheen.image
                    .resizable()
                    .scaledToFill()
                    .opacity(isScanning ? 0.42 : 0.12)
                    .offset(x: reduceMotion || !isScanning ? 0 : (scanSheenActive ? 220 : -220))
                    .animation(
                        SunMotion.repeatingEaseInOut(
                            duration: 1.45,
                            reduceMotion: reduceMotion,
                            autoreverses: false
                        ),
                        value: scanSheenActive
                    )
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
                scanSheenActive = isScanning && !reduceMotion
            }
            .onChange(of: isScanning) { _, newValue in
                scanSheenActive = newValue && !reduceMotion
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Selected sunscreen photo")
            .accessibilityValue(isScanning ? "Scanning bottle" : "Ready to scan")
    }

    private func loadPhoto(from item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }

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
        let preparedImage = Self.preparedImageForScanning(image)
        let scanID = UUID()
        activeScanID = scanID
        previewImage = preparedImage
        scanResult = nil
        errorMessage = nil
        isScanning = true
        scanSheenActive = !reduceMotion

        Task {
            do {
                let result = try await SunclubProductScannerService.scan(image: preparedImage)
                guard activeScanID == scanID else {
                    return
                }
                scanResult = result
                appState.rememberScannedSPF(result.spfLevel)
            } catch {
                guard activeScanID == scanID else {
                    return
                }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }

            if activeScanID == scanID {
                isScanning = false
                scanSheenActive = false
            }
        }
    }

    private static func preparedImageForScanning(_ image: UIImage) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maximumScanImageDimension else {
            return image
        }

        let scale = maximumScanImageDimension / longestSide
        let targetSize = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
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
