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
            guard appState.settings.hasCompletedOnboarding else {
                router.goToWelcome()
                return true
            }

            appState.recordVerificationSuccess(method: .manual)
            if appState.settings.reapplyReminderEnabled {
                appState.scheduleReapplyReminder()
            }
            router.open(.verifySuccess)
            return true
        case let .widgetRoute(route):
            guard appState.settings.hasCompletedOnboarding else {
                router.goToWelcome()
                return true
            }

            router.open(route.appRoute)
            return true
        }
    }
}
