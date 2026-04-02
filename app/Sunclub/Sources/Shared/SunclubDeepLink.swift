import Foundation

enum SunclubDeepLink: Equatable {
    case widgetLogToday

    private static let scheme = "sunclub"

    init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare(Self.scheme) == .orderedSame else {
            return nil
        }

        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch (host, pathComponents) {
        case ("widget", ["log-today"]):
            self = .widgetLogToday
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .widgetLogToday:
            return URL(string: "\(Self.scheme)://widget/log-today")!
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

            _ = SunclubQuickLogAction.perform(using: appState)
            router.open(.verifySuccess)
            return true
        }
    }
}
