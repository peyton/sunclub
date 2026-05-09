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
        SunLightScreen(
            contentAlignment: .center,
            contentMaxWidth: SunLayout.ContentWidth.wideReadable,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.wizard
        ) {
            welcomeContent
                .padding(.vertical, 32)
        } footer: {
            Button("Get Started") {
                startFeedbackTrigger += 1
                router.open(.enableLocation)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("welcome.getStarted")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: startFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var welcomeContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 56) {
                welcomeHero
                    .frame(minWidth: 400, maxWidth: 440)

                welcomeValueProps
                    .frame(minWidth: 360, maxWidth: 420, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 0) {
                welcomeHero
                welcomeValueProps
                    .padding(.top, 44)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var welcomeHero: some View {
        VStack(spacing: 0) {
            SunBrandLockup(
                layout: .stacked,
                markSize: 96,
                subtitle: "Your daily dose of sun sense."
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var welcomeValueProps: some View {
        VStack(alignment: .leading, spacing: 26) {
            welcomeValuePropRow(
                symbol: "hand.tap.fill",
                title: "Log sunscreen in seconds",
                detail: "Record SPF, timing, covered areas, and notes."
            )
            welcomeValuePropRow(
                symbol: "sun.max.fill",
                title: "See local UV context",
                detail: "Check current risk, hourly forecast, and peak sun time."
            )
            welcomeValuePropRow(
                symbol: "timer",
                title: "Get reapply reminders",
                detail: "Use reminders, widgets, Apple Watch, and Shortcuts."
            )
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    private func welcomeValuePropRow(symbol: String, title: String, detail: String) -> some View {
        WelcomeValuePropRow(title: title, detail: detail, systemImage: symbol)
    }
}

private struct WelcomeValuePropRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            SunProductIcon(systemName: systemImage, tint: AppPalette.pool, size: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(AppTextStyle.sectionHeader.font)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EnableLocationView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var feedbackTrigger = 0

    var body: some View {
        SunLightScreen(
            contentAlignment: .center,
            contentMaxWidth: SunLayout.ContentWidth.wizard,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.wizard
        ) {
            VStack(spacing: 18) {
                SunProductIcon(systemName: "location.fill", tint: AppPalette.sun, size: 76)
                    .padding(.top, 24)

                VStack(spacing: 14) {
                    Text("Use your location for local UV")
                        .font(AppFont.rounded(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Sunclub can show local UV and hourly forecast context. Defaults start with Face and Neck selected, SPF optional, and a 2-hour reapply reminder.")
                        .font(AppFont.rounded(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        } footer: {
            VStack(spacing: 10) {
                Button("Allow location") {
                    continueToReminders(usesLiveUV: true)
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("onboarding.enableLocation")

                Button("Choose a city instead") {
                    continueToReminders(usesLiveUV: false)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityHint("Continues setup without asking for location access.")
                .accessibilityIdentifier("onboarding.skipLocation")
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private func continueToReminders(usesLiveUV: Bool) {
        feedbackTrigger += 1
        if usesLiveUV, !appState.isUITesting {
            appState.updateLiveUVPreference(enabled: true, allowPermissionPrompt: true)
        }
        router.open(.enableNotifications)
    }
}

struct EnableNotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var isCompleting = false
    @State private var completionFeedbackTrigger = 0

    var body: some View {
        SunLightScreen(
            contentAlignment: .center,
            contentMaxWidth: SunLayout.ContentWidth.wizard,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.wizard
        ) {
            VStack(spacing: 18) {
                notificationIcon
                    .padding(.top, 24)

                VStack(spacing: 14) {
                    Text("Enable reminders")
                        .font(AppFont.rounded(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(reminderDescription)
                        .font(AppFont.rounded(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)

                    Text("Your logs stay private. No ads. No data sale.")
                        .font(AppTextStyle.captionMedium.font)
                        .foregroundStyle(AppPalette.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 32)
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

                        Text(isCompleting ? "Setting up" : "Enable reminders")
                    }
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .disabled(isCompleting)
                .accessibilityIdentifier("onboarding.enableNotifications")

                Button("Not now") {
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
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppPalette.pearl, AppPalette.warmGlow.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 104, height: 104)

            Image(systemName: "bell.badge.fill")
                .font(AppFont.rounded(size: 36, weight: .semibold))
                .foregroundStyle(AppPalette.sun)
        }
        .accessibilityHidden(true)
    }

    private var reminderDescription: String {
        "Sunclub can remind you when it is time to log sunscreen or reapply. You can change this anytime in Settings."
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
