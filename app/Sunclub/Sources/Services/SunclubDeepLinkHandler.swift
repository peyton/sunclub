import Foundation

enum SunclubDeepLinkHandler {
    @discardableResult
    @MainActor
    static func handle(url: URL, appState: AppState, router: AppRouter) -> Bool {
        guard let deepLink = SunclubDeepLink(url: url) else {
            return false
        }

        return handle(deepLink, appState: appState, router: router)
    }

    @discardableResult
    @MainActor
    static func handle(_ deepLink: SunclubDeepLink, appState: AppState, router: AppRouter) -> Bool {
        switch deepLink {
        case .widgetLogToday:
            return handleWidgetLogToday(appState: appState, router: router)
        case let .widgetRoute(route):
            return openAfterOnboarding(route.appRoute, appState: appState, router: router)
        case let .accountabilityInvite(code):
            return handleAccountabilityInvite(code, appState: appState, router: router)
        case let .accountabilityPoke(friendID):
            return handleAccountabilityPoke(friendID, appState: appState, router: router)
        }
    }

    @MainActor
    private static func handleWidgetLogToday(appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return true
        }

        appState.recordVerificationSuccess(method: .manual)
        if let presentation = appState.verificationSuccessPresentation {
            appState.verificationSuccessPresentation = VerificationSuccessPresentation(
                streak: presentation.streak,
                isPersonalBest: presentation.isPersonalBest,
                canAddDetails: true
            )
        }
        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        router.open(.verifySuccess)
        return true
    }

    @MainActor
    private static func handleAccountabilityInvite(_ code: String, appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            try? appState.queuePendingAccountabilityInviteCode(code)
            router.goToWelcome()
            return true
        }

        try? appState.importAccountabilityInviteCode(code)
        router.open(.friends)
        return true
    }

    @MainActor
    private static func handleAccountabilityPoke(_ friendID: UUID?, appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return true
        }

        if let friendID {
            appState.sendDirectPoke(to: friendID)
        }
        router.open(.friends)
        return true
    }

    @MainActor
    private static func openAfterOnboarding(_ route: AppRoute, appState: AppState, router: AppRouter) -> Bool {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return true
        }

        router.open(route)
        return true
    }
}
