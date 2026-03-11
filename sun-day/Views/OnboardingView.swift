import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showScanSheet = false
    @State private var showTrainingSheet = false
    @State private var showCameraPermissionMessage = false

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = currentWindowWidth
            let columnWidth = min(max(viewportWidth - 40, 0), 352)
            let horizontalOffset = -max(proxy.size.width - viewportWidth, 0) / 2

            ZStack {
                SunBackdrop()

                ViewThatFits(in: .vertical) {
                    VStack(spacing: 0) {
                        onboardingContent(columnWidth: columnWidth, viewportWidth: viewportWidth)
                        Spacer(minLength: 0)
                    }

                    ScrollView(showsIndicators: false) {
                        onboardingContent(columnWidth: columnWidth, viewportWidth: viewportWidth)
                    }
                }
                .offset(x: horizontalOffset)
            }
        }
        .sheet(isPresented: $showScanSheet) {
            BarcodeScanView(onboardingMode: true)
        }
        .sheet(isPresented: $showTrainingSheet) {
            TrainingView()
        }
    }

    @ViewBuilder
    private func onboardingContent(columnWidth: CGFloat, viewportWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            heroCard
            setupSteps
            actionButtons(columnWidth: columnWidth)

            if showCameraPermissionMessage {
                SunStatusCard(
                    title: "Notifications are off",
                    detail: "The app still works, but daily check-ins and weekly reports stay quiet until notifications are enabled.",
                    tint: AppPalette.warning,
                    symbol: "bell.slash.fill"
                )
            }
        }
        .frame(width: columnWidth, alignment: .top)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(width: viewportWidth, alignment: .center)
    }

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 14) {
            onboardingBadge
            onboardingCopy
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sunCard(padding: 12)
    }

    private var setupSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SUN CLUB")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(AppPalette.softInk)

                Text("Start your routine")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.ink)

                Text("Lock in your bottle, build the habit, and stay ready for the next bottle.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SunInfoRow(
                title: "Step 1: Lock in your bottle",
                detail: appState.settings.expectedBarcode == nil ? "Scan the UPC or EAN on your bottle once so Sun Club knows what to look for." : "Your bottle barcode is saved. You can scan again later if you switch products.",
                systemImage: "barcode.viewfinder",
                tint: appState.settings.expectedBarcode == nil ? AppPalette.sun : AppPalette.success
            )

            SunInfoRow(
                title: "Step 2: Train your match",
                detail: "Optional. Capture a few views to make selfie and live video check-ins more reliable.",
                systemImage: "camera.macro",
                tint: AppPalette.sea
            )

            SunInfoRow(
                title: "Step 3: Turn on check-ins",
                detail: "Daily reminders and weekly reports are sent as local notifications.",
                systemImage: "bell.badge.fill",
                tint: AppPalette.coral
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sunCard()
    }

    private func actionButtons(columnWidth: CGFloat) -> some View {
        let secondaryWidth = max((columnWidth - 12) / 2, 0)

        return VStack(spacing: 12) {
            if appState.settings.expectedBarcode == nil {
                Button {
                    showScanSheet = true
                } label: {
                    Label("Scan bottle barcode", systemImage: "barcode.viewfinder")
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .frame(width: columnWidth)
            } else if let barcode = appState.settings.expectedBarcode {
                SunStatusCard(
                    title: "Bottle locked",
                    detail: "Expected barcode: \(barcode)",
                    tint: AppPalette.success,
                    symbol: "checkmark.seal.fill"
                )
                .frame(width: columnWidth)
            }

            HStack(spacing: 12) {
                Button("Train bottle") {
                    showTrainingSheet = true
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .frame(width: secondaryWidth)

                Button("Notifications") {
                    Task {
                        let granted = await NotificationManager.shared.configure()
                        showCameraPermissionMessage = !granted
                    }
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .frame(width: secondaryWidth)
            }
            .frame(width: columnWidth)

            Button("Join Sun Club") {
                appState.completeOnboarding()
                Task {
                    await NotificationManager.shared.scheduleReminders(using: appState)
                }
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .disabled(appState.settings.expectedBarcode == nil)
            .frame(width: columnWidth)
        }
        .frame(width: columnWidth)
    }

    private var onboardingCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            SunPill(title: "Club setup", systemImage: "sun.max.fill", tint: AppPalette.sea)
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
                .frame(width: 60, height: 60)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var currentWindowWidth: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .bounds.width ?? UIScreen.main.bounds.width
    }
}
