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
        OnboardingScreen(contentMaxWidth: SunLayout.ContentWidth.wideReadable) {
            welcomeContent
                .padding(.vertical, AppSpacing.lg)
        } footer: {
            Button {
                startFeedbackTrigger += 1
                Self.beginOnboarding(router: router)
            } label: {
                OnboardingActionLabel(title: "Get Started", isPrimary: true)
            }
            .sunGlassPrimaryButton()
            .accessibilityIdentifier("welcome.getStarted")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: startFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
    }

    static func beginOnboarding(router: AppRouter) {
        router.open(.enableNotifications)
    }

    @ViewBuilder
    private var welcomeContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppSpacing.xl) {
                welcomeHero
                    .frame(minWidth: 400, maxWidth: 440)

                welcomeValueProps
                    .frame(minWidth: 360, maxWidth: 420, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: 0) {
                welcomeHero
                welcomeValueProps
                    .padding(.top, AppSpacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var welcomeHero: some View {
        VStack(spacing: AppSpacing.sm) {
            SunLogoMark(size: 80)
                .accessibilityHidden(true)
            VStack(spacing: AppSpacing.xxs) {
                AppText("sunclub", style: .largeTitle, alignment: .center)
                    .accessibilityAddTraits(.isHeader)
                AppText(
                    "Your daily dose of sun sense.",
                    style: .body,
                    color: AppColor.Text.secondary,
                    alignment: .center
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var welcomeValueProps: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            welcomeValuePropRow(
                symbol: .sunscreen,
                title: "Log sunscreen in seconds",
                detail: "Record SPF, timing, covered areas, and notes."
            )
            welcomeValuePropRow(
                symbol: .sun,
                title: "See local UV context",
                detail: "Check current risk, hourly forecast, and peak sun time."
            )
            welcomeValuePropRow(
                symbol: .bell,
                title: "Get reapply reminders",
                detail: "Use reminders, widgets, Apple Watch, and Shortcuts."
            )
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    private func welcomeValuePropRow(symbol: SunIcon, title: String, detail: String) -> some View {
        WelcomeValuePropRow(title: title, detail: detail, icon: symbol)
    }
}

private struct WelcomeValuePropRow: View {
    let title: String
    let detail: String
    let icon: SunIcon

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            icon.image.resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(AppColor.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                AppText(title, style: .bodyMedium)
                AppText(detail, style: .caption, color: AppColor.Text.secondary)
            }

            Spacer(minLength: AppSpacing.xxs)
        }
        .accessibilityElement(children: .combine)
    }
}

struct EnableLocationView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var feedbackTrigger = 0
    @State private var isChoosingCity = false

    var body: some View {
        OnboardingScreen() {
            VStack(spacing: AppSpacing.lg) {
                SunIcon.sun.image.resizable().scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(AppColor.sun)
                    .accessibilityHidden(true)
                    .padding(.top, AppSpacing.sm)

                VStack(spacing: AppSpacing.sm) {
                    AppText("Use your location for local UV", style: .title, alignment: .center)
                        .accessibilityAddTraits(.isHeader)

                    AppText("See local UV and hourly forecasts. You can also choose a city or continue with a local estimate.", color: AppColor.Text.secondary, alignment: .center)
                }
            }
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: .infinity)
        } footer: {
            VStack(spacing: AppSpacing.xs) {
                Button {
                    continueToReminders(usesLiveUV: true)
                } label: {
                    OnboardingActionLabel(title: "Allow location", isPrimary: true)
                }
                .sunGlassPrimaryButton()
                .accessibilityIdentifier("onboarding.enableLocation")

                Button {
                    isChoosingCity = true
                } label: {
                    OnboardingActionLabel(title: "Choose a city instead")
                }
                .sunGlassSecondaryButton()
                .accessibilityHint("Opens an Apple Maps city search without asking for location access.")
                .accessibilityIdentifier("onboarding.skipLocation")

                Button {
                    continueToReminders(usesLiveUV: false)
                } label: {
                    OnboardingActionLabel(title: "Continue without location")
                }
                .buttonStyle(SunTextButtonStyle())
                .accessibilityHint("Continues setup without location. Sunclub will show a clearly labeled season-and-time UV estimate.")
                .accessibilityIdentifier("onboarding.skipUV")
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
        .sheet(isPresented: $isChoosingCity) {
            CitySearchView { place in
                guard appState.updateSelectedUVPlace(place) else {
                    return false
                }
                feedbackTrigger += 1
                router.open(.enableNotifications)
                return true
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private func continueToReminders(usesLiveUV: Bool) {
        if usesLiveUV {
            guard appState.updateLiveUVPreference(
                enabled: true,
                allowPermissionPrompt: !appState.isUITesting
            ) else {
                return
            }
        }
        feedbackTrigger += 1
        router.open(.enableNotifications)
    }
}

struct EnableNotificationsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var isCompleting = false
    @State private var completionFeedbackTrigger = 0
    @State private var completionError: String?
    @State private var notificationManager = OnboardingNotificationManagerFactory.make()

    var body: some View {
        OnboardingScreen() {
            VStack(spacing: AppSpacing.lg) {
                notificationIcon
                    .padding(.top, AppSpacing.sm)

                VStack(spacing: AppSpacing.sm) {
                    AppText("Enable reminders", style: .title, alignment: .center)
                        .accessibilityAddTraits(.isHeader)

                    AppText(reminderDescription, color: AppColor.Text.secondary, alignment: .center)

                    AppText("Your logs stay private. No ads. No data sale.", style: .captionMedium, alignment: .center)
                        .padding(.top, AppSpacing.xxs)

                    if let completionError {
                        SunStatusCard(
                            title: appState.settings.hasCompletedOnboarding
                                ? "Reminders were not scheduled"
                                : "Setup was not saved",
                            detail: completionError,
                            tint: AppColor.warning.opacity(0.8),
                            symbol: "exclamationmark.triangle.fill"
                        )
                        .accessibilityIdentifier("onboarding.completionError")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, AppSpacing.lg)
            .frame(maxWidth: .infinity)
        } footer: {
            VStack(spacing: AppSpacing.xs) {
                if !appState.settings.hasCompletedOnboarding || completionError == nil {
                    Button {
                        completeOnboarding(requestsNotifications: true)
                    } label: {
                        OnboardingActionLabel(
                            title: isCompleting ? "Setting up" : enableRemindersTitle,
                            isPrimary: true,
                            isLoading: isCompleting
                        )
                    }
                    .sunGlassPrimaryButton()
                    .disabled(isCompleting)
                    .accessibilityIdentifier("onboarding.enableNotifications")
                }

                Button {
                    completeOnboarding(requestsNotifications: false)
                } label: {
                    OnboardingActionLabel(title: continueTitle)
                }
                .sunGlassSecondaryButton()
                .disabled(isCompleting)
                .accessibilityHint(appState.settings.hasCompletedOnboarding
                    ? "Opens Today. You can review reminders in Settings."
                    : "Finishes setup without requesting notification access.")
                .accessibilityIdentifier("onboarding.skipNotifications")
            }
        }
        .sensoryFeedback(.success, trigger: completionFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var notificationIcon: some View {
        SunIcon.bell.image.resizable().scaledToFit()
            .frame(width: 60, height: 60)
            .foregroundStyle(AppColor.accent)
            .accessibilityHidden(true)
    }

    private var reminderDescription: String {
        "Sunclub can remind you when it is time to log sunscreen or reapply. You can change this anytime in Settings."
    }

    private var enableRemindersTitle: String {
        guard completionError != nil else { return "Enable reminders" }
        return "Retry with reminders"
    }

    private var continueTitle: String {
        guard completionError != nil else { return "Not now" }
        return appState.settings.hasCompletedOnboarding ? "Continue to Today" : "Retry without reminders"
    }

    private func completeOnboarding(requestsNotifications: Bool) {
        guard !isCompleting else {
            return
        }

        isCompleting = true
        completionError = nil
        let completionID = router.beginOnboardingCompletion(
            hasCompletedOnboarding: appState.settings.hasCompletedOnboarding
        )

        Task { @MainActor in
            defer { isCompleting = false }
            guard router.isCurrentOnboardingCompletion(completionID) else { return }
            let completionResult = appState.completeOnboarding()
            guard completionResult.succeeded else {
                completionError = appState.logActionErrorMessage
                    ?? "Sunclub could not save your setup. Your choices are still here—please try again."
                return
            }

            if requestsNotifications {
                let granted = await notificationManager.configure()
                guard router.isCurrentOnboardingCompletion(completionID) else { return }
                if granted {
                    var report = await notificationManager.scheduleReminders(using: appState)
                    guard router.isCurrentOnboardingCompletion(completionID) else { return }
                    if !report.isSuccessful {
                        report = await notificationManager.scheduleReminders(using: appState)
                    }
                    guard router.isCurrentOnboardingCompletion(completionID) else { return }
                    if !report.isSuccessful {
                        completionError = "Setup was saved, but some reminders could not be scheduled. Sunclub will retry automatically. Continue to Today to start logging."
                        return
                    }
                }
            }

            completionFeedbackTrigger += 1

            Self.finishOnboarding(appState: appState, router: router)
        }
    }

    static func finishOnboarding(appState: AppState, router: AppRouter) {
        router.goHome()
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

/// Large text and short windows keep the actions in the same scroll flow as the copy.
private struct OnboardingScreen<Content: View, Footer: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var contentMaxWidth: CGFloat = SunLayout.ContentWidth.wizard
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        GeometryReader { geometry in
            let scrollsActions = dynamicTypeSize.isAccessibilitySize || geometry.size.height < 600
            SunLightScreen(
                contentAlignment: .center,
                contentMaxWidth: contentMaxWidth,
                contentFrameAlignment: .center,
                footerMaxWidth: SunLayout.ContentWidth.wizard,
                showsFooter: !scrollsActions,
                scrollAccessibilityIdentifier: "onboarding.scroll"
            ) {
                VStack(spacing: AppSpacing.lg) {
                    content()
                    if scrollsActions {
                        footer()
                            .frame(maxWidth: SunLayout.ContentWidth.wizard)
                    }
                }
                .frame(maxWidth: .infinity)
            } footer: {
                footer()
            }
        }
    }
}

private struct OnboardingActionLabel: View {
    let title: String
    var isPrimary = false
    var isLoading = false

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            if isLoading {
                ProgressView()
                    .tint(AppColor.primaryActionForeground)
                    .accessibilityHidden(true)
            }
            AppText(
                title,
                style: .bodyMedium,
                color: isPrimary ? AppColor.primaryActionForeground : AppColor.accent,
                alignment: .center
            )
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}
