import SwiftUI

struct OnboardingView: View {
    var body: some View {
        WelcomeView()
    }
}

struct WelcomeView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        SunLightScreen {
            VStack(spacing: 24) {
                Spacer(minLength: 80)

                SunLogoMark(size: 120)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Text("Sunclub")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Your daily sunscreen companion")
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 320)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            Button("Get Started") {
                router.open(.scanBarcode)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("welcome.getStarted")
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct EnableNotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        SunLightScreen {
            VStack(spacing: 26) {
                SunStepHeader(step: 3, total: 3, tint: AppPalette.softInk)

                Spacer(minLength: 120)

                Circle()
                    .fill(AppPalette.warmGlow)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Text("🔔")
                            .font(.system(size: 48))
                    }
                    .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    Text("Stay on Track")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Get daily reminders to apply sunscreen")
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 260)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            Button("Enable Notifications") {
                Task {
                    if !appState.isUITesting {
                        _ = await NotificationManager.shared.configure()
                        await NotificationManager.shared.scheduleReminders(using: appState)
                    }
                    appState.completeOnboarding()
                    router.goHome()
                }
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("onboarding.enableNotifications")
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
