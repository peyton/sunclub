import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var showScanSheet = false
    @State private var showCameraPermissionMessage = false

    var body: some View {
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            SunPill(title: "Private by default", systemImage: "lock.shield.fill", tint: AppPalette.sea)

                            Text("Welcome to SunscreenTrack")
                                .font(.system(size: 36, weight: .bold, design: .serif))
                                .foregroundStyle(AppPalette.ink)

                            Text("Camera plus local notifications, no photo library, no cloud, no mystery server with sunscreen opinions.")
                                .font(.callout)
                                .foregroundStyle(AppPalette.softInk)
                        }

                        Spacer(minLength: 0)

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
                    .sunCard()

                    VStack(alignment: .leading, spacing: 12) {
                        onboardingFeatureRow("Track daily application from camera only.", systemImage: "camera.fill", tint: AppPalette.sun)
                        onboardingFeatureRow("Store records and training data on-device with SwiftData.", systemImage: "internaldrive.fill", tint: AppPalette.sea)
                        onboardingFeatureRow("Receive local morning and weekly reminders.", systemImage: "bell.badge.fill", tint: AppPalette.coral)
                    }
                    .sunCard()

                    if appState.settings.expectedBarcode == nil {
                        Button {
                            showScanSheet = true
                        } label: {
                            Label("Scan sunscreen barcode to set your bottle", systemImage: "barcode.viewfinder")
                        }
                        .buttonStyle(SunPrimaryButtonStyle())
                    } else if let barcode = appState.settings.expectedBarcode {
                        VStack(alignment: .leading, spacing: 8) {
                            SunPill(title: "Bottle saved", systemImage: "checkmark.seal.fill", tint: AppPalette.success)
                            Text("Expected barcode: \(barcode)")
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sunCard()
                    }

                    Button("Train bottle recognition (recommended)") {
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

                    if showCameraPermissionMessage {
                        Text("Notifications permission not granted. You can still use the app, but reminders will be suppressed.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .sunCard(padding: 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showScanSheet) {
            BarcodeScanView(onboardingMode: true)
        }
    }

    private func onboardingFeatureRow(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
        }
    }
}
