import SwiftUI

private struct VerificationAgentStatus: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let tint: Color
}

struct LiveVerifyView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @StateObject private var coordinator = SunscreenDetectionCoordinator()
    @State private var latestResult = SunscreenDetectionResult.idle
    @State private var statusMessage = "Hold your sunscreen bottle in view while Sunclub scans."
    @State private var hasAdvanced = false
    @State private var appearedAt = Date()
    private let shouldHoldUITestVerifyScreen = ProcessInfo.processInfo.arguments.contains("UITEST_HOLD_VERIFY_SCREEN")

    var body: some View {
        SunDarkScreen {
            VStack(alignment: .leading, spacing: 24) {
                header

                cameraCard

                statusCard

                pipelineCard

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
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var pipelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pipeline")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))

            ForEach(agentStatuses) { agent in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(agent.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))

                        Spacer(minLength: 12)

                        Text(agent.value)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(agent.tint)
                    }

                    Text(agent.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("verify.agent.\(agent.id)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var answerLabel: String {
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
        guard let ttft = latestResult.timeToFirstTokenMs,
              let latency = latestResult.latencyMs else {
            return nil
        }

        return "TTFT \(ttft) ms · Total \(latency) ms"
    }

    private var normalizedOutput: String {
        latestResult.parsedAnswer?.rawValue ?? "NO"
    }

    private var rawOutputSummary: String {
        if let errorDescription = latestResult.errorDescription {
            return errorDescription
        }

        if latestResult.rawOutput.isEmpty {
            return "Prompt: Is there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO."
        }

        if latestResult.parsedAnswer == .yes && !latestResult.isDetected {
            return "Normalized output: \(normalizedOutput) · Confirming response \(latestResult.consecutiveYesCount) / 2"
        }

        if latestResult.rawOutput == normalizedOutput {
            return "Normalized output: \(normalizedOutput)"
        }

        return "Normalized output: \(normalizedOutput) · Raw response: \(latestResult.rawOutput)"
    }

    private var agentStatuses: [VerificationAgentStatus] {
        [
            VerificationAgentStatus(
                id: "prompt",
                title: "Prompt agent",
                value: latestResult.isLoadingModel ? "READYING" : "LOCKED",
                detail: "Asks for a strict YES or NO answer and defaults to NO when uncertain.",
                tint: latestResult.isLoadingModel ? AppPalette.sun : Color.white.opacity(0.84)
            ),
            VerificationAgentStatus(
                id: "vision",
                title: "Vision agent",
                value: answerLabel,
                detail: visionAgentDetail,
                tint: answerColor
            ),
            VerificationAgentStatus(
                id: "decision",
                title: "Decision agent",
                value: decisionAgentValue,
                detail: decisionAgentDetail,
                tint: decisionAgentTint
            )
        ]
    }

    private var visionAgentDetail: String {
        if let errorDescription = latestResult.errorDescription {
            return errorDescription
        }

        if let timingSummary {
            return "Structured to report \(normalizedOutput) only. \(timingSummary)."
        }

        if latestResult.isLoadingModel {
            return "Loading FastVLM so the vision pass can start."
        }

        return "Waiting for a frame with the sunscreen bottle centered in view."
    }

    private var decisionAgentValue: String {
        if latestResult.errorDescription != nil {
            return "BLOCKED"
        }

        if latestResult.isDetected {
            return "CONFIRMED"
        }

        if latestResult.parsedAnswer == .yes {
            return "CHECKING"
        }

        if latestResult.isLoadingModel {
            return "STANDBY"
        }

        return "WATCHING"
    }

    private var decisionAgentTint: Color {
        if latestResult.errorDescription != nil {
            return Color(red: 0.960, green: 0.500, blue: 0.360)
        }

        if latestResult.isDetected {
            return AppPalette.success
        }

        if latestResult.parsedAnswer == .yes || latestResult.isLoadingModel {
            return AppPalette.sun
        }

        return Color.white.opacity(0.82)
    }

    private var decisionAgentDetail: String {
        if let errorDescription = latestResult.errorDescription {
            return errorDescription
        }

        if latestResult.isDetected {
            return "Two YES responses in a row were collected, so Sunclub can log today."
        }

        if latestResult.parsedAnswer == .yes {
            return "Collected \(latestResult.consecutiveYesCount) of 2 required YES responses."
        }

        if latestResult.isLoadingModel {
            return "Waiting for the model before starting confirmation."
        }

        return "Needs two consecutive YES responses before the check-in succeeds."
    }

    private func updateStatus(using result: SunscreenDetectionResult) {
        if coordinator.permissionDenied {
            statusMessage = "Camera access is required for sunscreen verification."
            return
        }

        if let errorDescription = result.errorDescription {
            statusMessage = errorDescription
            return
        }

        if result.isLoadingModel {
            statusMessage = "Loading the FastVLM model…"
            return
        }

        switch result.parsedAnswer {
        case .yes where result.isDetected:
            statusMessage = "Sunscreen detected. Locked in with a confirmed YES."
        case .yes:
            statusMessage = "Sunscreen detected. Waiting for one more YES to confirm."
        case .no:
            statusMessage = "No sunscreen detected yet. Keep the bottle centered in view."
        case nil:
            statusMessage = "Hold your sunscreen bottle in view while Sunclub scans."
        }
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
