import Foundation

enum SunclubDeepLink: Equatable {
    case widgetLogToday
    case widgetRoute(SunclubWidgetRoute)

    private static let scheme = "sunclub"

    init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare(Self.scheme) == .orderedSame else {
            return nil
        }

        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard host == "widget" else {
            return nil
        }

        if pathComponents == ["log-today"] {
            self = .widgetLogToday
            return
        }

        if pathComponents.count == 2,
           pathComponents.first == "open",
           let route = SunclubWidgetRoute(rawValue: pathComponents[1]) {
            self = .widgetRoute(route)
            return
        }

        return nil
    }

    var url: URL {
        switch self {
        case .widgetLogToday:
            return URL(string: "\(Self.scheme)://widget/log-today")!
        case let .widgetRoute(route):
            return route.url
        }
    }
}

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
