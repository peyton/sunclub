import SwiftUI

struct LiveVerifyView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @StateObject private var coordinator = SunscreenDetectionCoordinator()
    @State private var modelDownloadService = FastVLMModelDownloadService.shared
    @State private var latestResult = SunscreenDetectionResult.idle
    @State private var statusMessage = "Hold your sunscreen bottle in view while Sunclub scans."
    @State private var hasAdvanced = false
    @State private var appearedAt = Date()
    private let shouldHoldUITestVerifyScreen = ProcessInfo.processInfo.arguments.contains("UITEST_HOLD_VERIFY_SCREEN")
    private let shouldRequireUITestModelDownload = ProcessInfo.processInfo.arguments.contains("UITEST_REQUIRE_MODEL_DOWNLOAD")

    var body: some View {
        SunDarkScreen {
            VStack(alignment: .leading, spacing: 24) {
                header

                cameraCard

                statusCard

                Text(statusMessage)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("verify.status")
            }
        }
        .onAppear {
            appearedAt = Date()
            hasAdvanced = false

            if PreviewRuntime.isRunning {
                latestResult = SunscreenDetectionResult(
                    isDetected: false,
                    isLoadingModel: false,
                    parsedAnswer: .yes,
                    rawOutput: "YES",
                    consecutiveYesCount: 1,
                    timeToFirstTokenMs: 182,
                    latencyMs: 448,
                    errorDescription: nil
                )
                statusMessage = "Previewing a FastVLM YES response."
                return
            }

            coordinator.onStateChange = { result in
                latestResult = result
                updateStatus(using: result)
                if result.isDetected {
                    completeVerification()
                }
            }

            if appState.isUITesting {
                if shouldRequireUITestModelDownload {
                    latestResult = .idle
                    statusMessage = "Download FastVLM once to turn on camera verification."
                    return
                }

                latestResult = SunscreenDetectionResult(
                    isDetected: false,
                    isLoadingModel: false,
                    parsedAnswer: .yes,
                    rawOutput: "YES",
                    consecutiveYesCount: 1,
                    timeToFirstTokenMs: 90,
                    latencyMs: 150,
                    errorDescription: nil
                )
                statusMessage = "Checking for sunscreen…"
                guard !shouldHoldUITestVerifyScreen else { return }
                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await MainActor.run {
                        completeVerification()
                    }
                }
                return
            }

            coordinator.configure()
            Task {
                await modelDownloadService.refresh()
                await prepareModelIfPossible()
            }
        }
        .onChange(of: modelDownloadService.availability) { _, _ in
            updateStatus(using: latestResult)
        }
        .onDisappear {
            coordinator.stop()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                router.goHome()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .buttonStyle(.plain)

            Text("Verify Sunscreen")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .accessibilityIdentifier("verify.title")
        }
    }

    private var cameraCard: some View {
        ZStack {
            SunCameraFrame(session: coordinator.session)

            if coordinator.permissionDenied {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.45))

                Text("Camera access denied")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FastVLM")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))

                Spacer(minLength: 0)

                Text(answerLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(answerColor)
                    .accessibilityIdentifier("verify.answer")
            }

            if let timingSummary {
                Text(timingSummary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }

            Text(rawOutputSummary)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.62))

            if showsModelDownloadButton || showsManualFallbackButton {
                actionButtons
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var answerLabel: String {
        switch effectiveModelAvailability {
        case .notDownloaded:
            return "DOWNLOAD"
        case .downloading:
            return "DOWNLOADING"
        case .failed:
            return "ERROR"
        case .ready:
            break
        }

        if latestResult.isLoadingModel {
            return "LOADING"
        }

        if let parsedAnswer = latestResult.parsedAnswer {
            return parsedAnswer.rawValue
        }

        if latestResult.errorDescription != nil {
            return "ERROR"
        }

        return "READY"
    }

    private var answerColor: Color {
        switch effectiveModelAvailability {
        case .notDownloaded:
            return AppPalette.sun
        case .downloading:
            return AppPalette.sun
        case .failed:
            return Color(red: 0.960, green: 0.500, blue: 0.360)
        case .ready:
            break
        }

        if latestResult.errorDescription != nil {
            return Color(red: 0.960, green: 0.500, blue: 0.360)
        }

        if latestResult.isLoadingModel {
            return AppPalette.sun
        }

        switch latestResult.parsedAnswer {
        case .yes:
            return AppPalette.success
        case .no:
            return Color.white.opacity(0.82)
        case nil:
            return Color.white.opacity(0.72)
        }
    }

    private var timingSummary: String? {
        guard case .ready = effectiveModelAvailability else {
            return nil
        }

        guard let ttft = latestResult.timeToFirstTokenMs,
              let latency = latestResult.latencyMs else {
            return nil
        }

        return "TTFT \(ttft) ms · Total \(latency) ms"
    }

    private var rawOutputSummary: String {
        switch effectiveModelAvailability {
        case .notDownloaded:
            return "Camera verification needs a one-time FastVLM model download. After that, Sunclub keeps verification available offline on this device."
        case let .downloading(progress):
            return "Download progress: \(Int(progress * 100))%"
        case let .failed(message):
            return message
        case .ready:
            break
        }

        if let errorDescription = latestResult.errorDescription {
            return errorDescription
        }

        if latestResult.rawOutput.isEmpty {
            return "Prompt: Is there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO."
        }

        if latestResult.parsedAnswer == .yes && !latestResult.isDetected {
            return "Confirming response \(latestResult.consecutiveYesCount) / 2"
        }

        return "Model output: \(latestResult.rawOutput)"
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsModelDownloadButton {
                Button(downloadButtonTitle) {
                    Task {
                        await startModelDownload()
                    }
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("verify.downloadModel")
            }

            if showsManualFallbackButton {
                Button("Log Manually Instead") {
                    router.open(.manualLog)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("verify.logManual")
            }
        }
    }

    private var effectiveModelAvailability: FastVLMModelAvailability {
        if appState.isUITesting && shouldRequireUITestModelDownload {
            return .notDownloaded
        }

        return modelDownloadService.availability
    }

    private var showsModelDownloadButton: Bool {
        switch effectiveModelAvailability {
        case .notDownloaded, .failed:
            return !coordinator.permissionDenied
        case .downloading, .ready:
            return false
        }
    }

    private var downloadButtonTitle: String {
        if appState.isUITesting && shouldRequireUITestModelDownload {
            return "Download FastVLM to Verify"
        }

        switch effectiveModelAvailability {
        case .failed:
            return "Retry FastVLM Download"
        case .notDownloaded, .downloading, .ready:
            return modelDownloadService.requiresDownloadConsent ? "Download FastVLM to Verify" : "Resume FastVLM Download"
        }
    }

    private var showsManualFallbackButton: Bool {
        coordinator.permissionDenied || latestResult.errorDescription != nil || showsModelDownloadButton
    }

    private func updateStatus(using result: SunscreenDetectionResult) {
        if coordinator.permissionDenied {
            statusMessage = "Camera access is required for sunscreen verification."
            return
        }

        switch effectiveModelAvailability {
        case .notDownloaded:
            statusMessage = "Download FastVLM once to turn on camera verification."
            return
        case let .downloading(progress):
            statusMessage = "Downloading FastVLM (\(Int(progress * 100))%)."
            return
        case let .failed(message):
            statusMessage = message
            return
        case .ready:
            break
        }

        if let errorDescription = result.errorDescription {
            statusMessage = errorDescription
            return
        }

        if result.isLoadingModel {
            statusMessage = "Preparing FastVLM for camera verification…"
            return
        }

        switch result.parsedAnswer {
        case .yes where result.isDetected:
            statusMessage = "Sunscreen detected."
        case .yes:
            statusMessage = "Sunscreen detected. Confirming one more frame…"
        case .no:
            statusMessage = "No sunscreen detected yet. Keep the bottle centered in view."
        case nil:
            statusMessage = "Hold your sunscreen bottle in view while Sunclub scans."
        }
    }

    private func prepareModelIfPossible() async {
        if appState.isUITesting || PreviewRuntime.isRunning {
            return
        }

        if let modelDirectory = await modelDownloadService.prepareForVerification() {
            coordinator.prepareModel(using: modelDirectory)
        } else {
            coordinator.resetModelState()
        }

        await MainActor.run {
            updateStatus(using: latestResult)
        }
    }

    private func startModelDownload() async {
        if modelDownloadService.requiresDownloadConsent {
            modelDownloadService.recordDownloadConsent()
        }

        await prepareModelIfPossible()
    }

    private func completeVerification() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        appState.recordVerificationSuccess(
            method: .camera,
            verificationDuration: Date().timeIntervalSince(appearedAt)
        )
        router.open(.verifySuccess)
    }
}

#Preview {
    SunclubPreviewHost {
        LiveVerifyView()
    }
}
