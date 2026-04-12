import SwiftUI

struct OnboardingView: View {
    var body: some View {
        WelcomeView()
    }
}

struct WelcomeView: View {
    @Environment(AppRouter.self) private var router
    @State private var startFeedbackTrigger = 0

    var body: some View {
        SunLightScreen {
            VStack(spacing: 22) {
                SunAssetHero(
                    asset: .heroWelcomeMorningKit,
                    height: 238,
                    glowColor: AppPalette.sun
                )
                .padding(.top, 8)

                SunBrandLockup(
                    layout: .stacked,
                    markSize: 82,
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
                startFeedbackTrigger += 1
                router.open(.enableNotifications)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("welcome.getStarted")
        }
        .sensoryFeedback(.selection, trigger: startFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct EnableNotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var completionFeedbackTrigger = 0

    var body: some View {
        SunLightScreen {
            VStack(spacing: 24) {
                SunAssetHero(
                    asset: .heroNotificationNudge,
                    height: 232,
                    glowColor: AppPalette.pool
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(AppPalette.sun, in: Circle())
                        .shadow(color: AppPalette.sun.opacity(0.28), radius: 16, x: 0, y: 8)
                        .offset(x: -18, y: 18)
                        .accessibilityHidden(true)
                }

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
                completionFeedbackTrigger += 1
                Task {
                    if !appState.isUITesting {
                        _ = await NotificationManager.shared.configure()
                        await NotificationManager.shared.scheduleReminders(using: appState)
                    }
                    appState.completeOnboarding()
                    if appState.importPendingAccountabilityInvitesIfNeeded() {
                        router.open(.friends)
                    } else {
                        router.goHome()
                    }
                }
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("onboarding.enableNotifications")
        }
        .sensoryFeedback(.success, trigger: completionFeedbackTrigger)
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
