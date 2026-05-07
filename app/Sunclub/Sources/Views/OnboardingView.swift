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
                router.open(.enableNotifications)
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
        VStack(spacing: 14) {
            SunBrandLockup(
                layout: .stacked,
                markSize: 96,
                subtitle: "Your daily dose of sun sense."
            )
            .frame(maxWidth: .infinity)

            Text("Log sunscreen. See UV context. Build better habits.")
                .font(AppFont.rounded(size: 31, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var welcomeValueProps: some View {
        VStack(alignment: .leading, spacing: 26) {
            welcomeValuePropRow(
                symbol: "hand.tap.fill",
                title: "Daily logging made simple",
                detail: "Record SPF, timing, notes, and reapply check-ins."
            )
            welcomeValuePropRow(
                symbol: "sun.max.fill",
                title: "UV context you can trust",
                detail: "See live or estimated UV and clear guidance for the day."
            )
            welcomeValuePropRow(
                symbol: "applewatch",
                title: "Works across your Apple devices",
                detail: "Use reminders, widgets, Apple Watch, and Shortcuts."
            )
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    private func welcomeValuePropRow(symbol: String, title: String, detail: String) -> some View {
        SunInfoRow(title: title, detail: detail, systemImage: symbol, tint: AppPalette.pool)
        .accessibilityElement(children: .combine)
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
                    Text("Turn on reminders")
                        .font(AppFont.rounded(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(reminderDescription)
                        .font(AppFont.rounded(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)
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

                        Text(isCompleting ? "Setting up" : "Allow Reminders")
                    }
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .disabled(isCompleting)
                .accessibilityIdentifier("onboarding.enableNotifications")

                Button("Skip") {
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
        "A daily sunscreen reminder, plus optional reapply timing after you log."
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
