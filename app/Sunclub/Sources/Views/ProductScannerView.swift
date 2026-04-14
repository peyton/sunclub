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

    private struct SendableImage: @unchecked Sendable {
        let image: UIImage
    }

    private struct ScanImageSource: @unchecked Sendable {
        let data: Data?
        let image: UIImage?

        static func photoData(_ data: Data) -> Self {
            Self(data: data, image: nil)
        }

        static func cameraImage(_ image: UIImage) -> Self {
            Self(data: nil, image: image)
        }

        func preparedImage() throws -> SendableImage {
            if let data {
                return SendableImage(image: try SunclubProductScannerService.preparedImageForScanning(data: data))
            }

            if let image {
                return SendableImage(image: try SunclubProductScannerService.preparedImageForScanning(image: image))
            }

            throw SunclubProductScannerError.imageUnavailable
        }
    }

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
                    handleImageSource(.cameraImage(image))
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
                detail: "Turn on camera access in Settings to scan sunscreen labels. You can still pick a photo or enter SPF manually.",
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

            Button("Enter SPF Manually") {
                router.open(.manualLog)
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityIdentifier("productScanner.manualLog")
        }
    }

    private func resultCard(for result: SunclubProductScanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(result.summary)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text(result.confirmationDetail)
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("productScanner.confirmationDetail")

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
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Sunclub could not load that photo."
                return
            }
            handleImageSource(.photoData(data))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImageSource(_ source: ScanImageSource) {
        feedbackTrigger += 1
        let scanID = UUID()
        activeScanID = scanID
        previewImage = nil
        scanResult = nil
        errorMessage = nil
        isScanning = true
        scanSheenActive = !reduceMotion

        Task {
            do {
                let preparedImage = try await Task.detached(priority: .userInitiated) {
                    try source.preparedImage()
                }.value
                guard activeScanID == scanID else {
                    return
                }

                previewImage = preparedImage.image

                let result = try await Task.detached(priority: .userInitiated) {
                    try await SunclubProductScannerService.scan(image: preparedImage.image)
                }.value
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
