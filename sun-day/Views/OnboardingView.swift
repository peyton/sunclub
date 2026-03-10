import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var showScanSheet = false
    @State private var showCameraPermissionMessage = false

    var body: some View {
        SunScreen {
            heroCard
            setupSteps
            actionButtons

            if showCameraPermissionMessage {
                SunStatusCard(
                    title: "Notifications are off",
                    detail: "The app still works, but you will not receive daily or weekly reminders until notifications are enabled.",
                    tint: AppPalette.warning,
                    symbol: "bell.slash.fill"
                )
            }
        }
        .sheet(isPresented: $showScanSheet) {
            BarcodeScanView(onboardingMode: true)
        }
    }

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 14) {
            onboardingBadge
            onboardingCopy
            Spacer(minLength: 0)
        }
        .sunCard(padding: 16)
    }

    private var setupSteps: some View {
        VStack(alignment: .leading, spacing: 14) {
            SunSectionHeader(
                eyebrow: "Set up",
                title: "Three quick steps",
                detail: "Use the camera to verify sunscreen each day. Everything stays on this device."
            )

            SunInfoRow(
                title: "Step 1: Scan your bottle",
                detail: appState.settings.expectedBarcode == nil ? "Scan the UPC or EAN on your bottle once to set the barcode for daily checks." : "Your bottle barcode is saved. You can scan again later if you change products.",
                systemImage: "barcode.viewfinder",
                tint: appState.settings.expectedBarcode == nil ? AppPalette.sun : AppPalette.success
            )

            SunInfoRow(
                title: "Step 2: Train bottle recognition",
                detail: "Optional. Capture a few views of the bottle to improve selfie and live video verification.",
                systemImage: "camera.macro",
                tint: AppPalette.sea
            )

            SunInfoRow(
                title: "Step 3: Turn on reminders",
                detail: "Morning reminders and weekly reports are sent as local notifications.",
                systemImage: "bell.badge.fill",
                tint: AppPalette.coral
            )
        }
        .sunCard()
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if appState.settings.expectedBarcode == nil {
                Button {
                    showScanSheet = true
                } label: {
                    Label("Scan bottle barcode", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(SunPrimaryButtonStyle())
            } else if let barcode = appState.settings.expectedBarcode {
                SunStatusCard(
                    title: "Bottle locked",
                    detail: "Expected barcode: \(barcode)",
                    tint: AppPalette.success,
                    symbol: "checkmark.seal.fill"
                )
            }

            Button("Train bottle recognition") {
                router.open(.training)
            }
            .buttonStyle(SunSecondaryButtonStyle())

            Button("Enable notifications") {
                Task {
                    let granted = await NotificationManager.shared.configure()
                    showCameraPermissionMessage = !granted
                }
            }
            .buttonStyle(SunSecondaryButtonStyle())

            Button("Open Sun Dae") {
                appState.completeOnboarding()
                Task {
                    await NotificationManager.shared.scheduleReminders(using: appState)
                }
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .disabled(appState.settings.expectedBarcode == nil)
        }
    }

    private var onboardingCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            SunPill(title: "On-device setup", systemImage: "lock.shield.fill", tint: AppPalette.sea)
        }
    }

    private var onboardingBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppPalette.sun, AppPalette.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
