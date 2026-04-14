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
                SunBrandLockup(
                    layout: .stacked,
                    markSize: 104,
                    subtitle: SunclubCopy.Brand.welcomeTitle
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 72)

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
        .sensoryFeedback(.impact(.medium), trigger: startFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct EnableNotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var isCompleting = false
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
                        .foregroundStyle(AppPalette.onAccent)
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
            VStack(spacing: 10) {
                Button {
                    completeOnboarding(requestsNotifications: true)
                } label: {
                    HStack(spacing: 8) {
                        if isCompleting {
                            ProgressView()
                                .tint(AppPalette.onAccent)
                                .accessibilityHidden(true)
                        }

                        Text(isCompleting ? "Setting Up" : "Turn On Reminders")
                    }
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .disabled(isCompleting)
                .accessibilityIdentifier("onboarding.enableNotifications")

                Button("Not Now") {
                    completeOnboarding(requestsNotifications: false)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .disabled(isCompleting)
                .accessibilityHint("Finishes setup without turning on reminder notifications.")
                .accessibilityIdentifier("onboarding.skipNotifications")
            }
        }
        .sensoryFeedback(.success, trigger: completionFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var reminderDescription: String {
        SunclubCopy.Brand.reminderDetail
    }

    private func completeOnboarding(requestsNotifications: Bool) {
        guard !isCompleting else {
            return
        }

        completionFeedbackTrigger += 1
        isCompleting = true

        Task { @MainActor in
            if requestsNotifications, !appState.isUITesting {
                let granted = await NotificationManager.shared.configure()
                if granted {
                    await NotificationManager.shared.scheduleReminders(using: appState)
                }
            }

            appState.completeOnboarding()
            isCompleting = false

            if appState.importPendingAccountabilityInvitesIfNeeded() {
                router.open(.friends)
            } else {
                router.goHome()
            }
        }
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
