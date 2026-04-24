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
        SunLightScreen(contentAlignment: .center) {
            VStack(spacing: 0) {
                SunBrandLockup(
                    layout: .stacked,
                    markSize: 96,
                    subtitle: "Build a sunscreen habit that actually sticks."
                )
                .frame(maxWidth: .infinity)

                Text("Track applications, get gentle reminders, and see your sun-care streak.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.softInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
                    .padding(.top, 18)

                VStack(alignment: .leading, spacing: 26) {
                    welcomeValuePropRow(
                        symbol: "flame.fill",
                        title: "Stay consistent",
                        detail: "Keep the routine visible without making it a chore."
                    )
                    welcomeValuePropRow(
                        symbol: "bell.badge.fill",
                        title: "Get nudged at the right time",
                        detail: "Use gentle reminders that fit weekdays, weekends, and travel."
                    )
                    welcomeValuePropRow(
                        symbol: "hand.tap.fill",
                        title: "Log in seconds",
                        detail: "Save the day from the app, widgets, Shortcuts, or notifications."
                    )
                }
                .frame(maxWidth: 320, alignment: .leading)
                .padding(.top, 44)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } footer: {
            Button("Get Started") {
                startFeedbackTrigger += 1
                router.open(.enableNotifications)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("welcome.getStarted")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: startFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func welcomeValuePropRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
                .frame(width: 36, height: 36)
                .background(AppPalette.warmGlow.opacity(0.5), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct EnableNotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var isCompleting = false
    @State private var completionFeedbackTrigger = 0

    var body: some View {
        SunLightScreen {
            VStack(spacing: 18) {
                notificationIcon
                    .padding(.top, 128)

                VStack(spacing: 14) {
                    Text("Turn on gentle reminders")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(reminderDescription)
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)
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

    private var notificationIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppPalette.pearl, AppPalette.warmGlow.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 104, height: 104)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
        }
        .accessibilityHidden(true)
    }

    private var reminderDescription: String {
        "Sunclub only sends sunscreen reminders. No marketing, no upsells, no spam."
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
