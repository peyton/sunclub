import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var showScanSheet = false
    @State private var showCameraPermissionMessage = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Welcome to SunscreenTrack")
                    .font(.largeTitle)
                    .bold()
                Text("Camera + notifications are used only on this device to verify and track daily sunscreen use.")
                    .multilineTextAlignment(.center)

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Track daily application from camera only.", systemImage: "camera")
                        Label("Store all data on-device with SwiftData.", systemImage: "lock.shield")
                        Label("Receive morning and weekly reminders locally.", systemImage: "bell.badge")
                    }
                    .padding(.vertical, 6)
                }

                if appState.settings.expectedBarcode == nil {
                    Button {
                        showScanSheet = true
                    } label: {
                        Label("Scan sunscreen barcode to set your bottle", systemImage: "barcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else if let barcode = appState.settings.expectedBarcode {
                    Text("Expected barcode set: \(barcode)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Train bottle recognition (recommended)") {
                    router.open(.training)
                }
                .buttonStyle(.bordered)

                Button("Enable notifications") {
                    Task {
                        let granted = await NotificationManager.shared.configure()
                        showCameraPermissionMessage = !granted
                    }
                }
                .buttonStyle(.bordered)

                Button("Continue to App") {
                    appState.completeOnboarding()
                    Task {
                        await NotificationManager.shared.scheduleReminders(using: appState)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.settings.expectedBarcode == nil)

                if showCameraPermissionMessage {
                    Text("Notifications permission not granted. You can still use the app, but reminders will be suppressed.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showScanSheet) {
            BarcodeScanView(onboardingMode: true)
        }
    }
}
