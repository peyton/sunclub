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
                SunBrandLockup(
                    layout: .stacked,
                    markSize: 120,
                    subtitle: SunclubCopy.Brand.welcomeTitle
                )
                .frame(maxWidth: .infinity)

                Text(SunclubCopy.Brand.welcomeDetail)
                    .font(.system(size: 17))
                    .foregroundStyle(AppPalette.softInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
        } footer: {
            Button("Get Started") {
                router.open(.enableNotifications)
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
                Circle()
                    .fill(AppPalette.warmGlow)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 48))
                    }
                    .frame(maxWidth: .infinity)

                VStack(spacing: 14) {
                    Text(SunclubCopy.Brand.reminderTitle)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(reminderDescription)
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)

                    Text("You can change reminder times later in Settings.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
        } footer: {
            Button("Turn On Reminders") {
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
        .interactivePopGestureEnabled()
    }

    private var reminderDescription: String {
        SunclubCopy.Brand.reminderDetail
    }
}

#Preview {
    SunclubPreviewHost(scenario: .onboarding) {
        OnboardingView()
    }
}

#Preview("Welcome") {
    SunclubPreviewHost(scenario: .onboarding) {
        WelcomeView()
    }
}

#Preview("Enable Notifications") {
    SunclubPreviewHost(scenario: .onboarding) {
        EnableNotificationsView()
    }
}
