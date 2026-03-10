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
                    title: "Notifications stayed off",
                    detail: "The app still works, but morning and weekly reminders will stay quiet until you enable them.",
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
        ViewThatFits {
            HStack(alignment: .top, spacing: 16) {
                onboardingCopy

                Spacer(minLength: 0)

                onboardingBadge
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    onboardingBadge
                    Spacer(minLength: 0)
                }

                onboardingCopy
            }
        }
        .sunCard()
    }

    private var setupSteps: some View {
        VStack(alignment: .leading, spacing: 14) {
            SunSectionHeader(
                eyebrow: "Setup flow",
                title: "Three quick moves",
                detail: "No accounts, no photo library, no analytics. Just local camera proof and a calendar that keeps score."
            )

            SunInfoRow(
                title: "Step 1: Scan your bottle",
                detail: appState.settings.expectedBarcode == nil ? "Capture the expected UPC or EAN once so daily scans know what counts." : "Expected bottle barcode saved. You can rescan later if you switch products.",
                systemImage: "barcode.viewfinder",
                tint: appState.settings.expectedBarcode == nil ? AppPalette.sun : AppPalette.success
            )

            SunInfoRow(
                title: "Step 2: Train bottle recognition",
                detail: "Optional, but it makes selfie and live video verification much more reliable.",
                systemImage: "camera.macro",
                tint: AppPalette.sea
            )

            SunInfoRow(
                title: "Step 3: Turn on reminders",
                detail: "Morning nudges and weekly reports stay on-device and never leave the phone.",
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
                    Label("Scan sunscreen barcode", systemImage: "barcode.viewfinder")
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

            Button("Continue to App") {
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
            SunPill(title: "Private setup", systemImage: "lock.shield.fill", tint: AppPalette.sea)

            Text("Welcome to SunscreenTrack")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(AppPalette.ink)

            Text("This setup is short: lock in your bottle, optionally teach the app what it looks like, then let local reminders do their job.")
                .font(.callout)
                .foregroundStyle(AppPalette.softInk)
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
                .frame(width: 88, height: 88)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
