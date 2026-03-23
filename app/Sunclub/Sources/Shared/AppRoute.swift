import Foundation
import Observation

enum AppRoute: String, Hashable, Codable, Identifiable {
    case welcome
    case enableNotifications
    case home
    case verifyCamera
    case verifySuccess
    case weeklySummary
    case settings
    case history
    case manualLog

    var id: String { rawValue }

    func resolved(scanEnabled: Bool) -> AppRoute {
        guard self == .verifyCamera, !scanEnabled else {
            return self
        }

        return .manualLog
    }
}

@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func open(_ route: AppRoute) {
        if route == .home || route == .welcome {
            path.removeAll()
        } else {
            path = [route]
        }
    }

    func goHome() {
        path.removeAll()
    }

    func goToWelcome() {
        path.removeAll()
    }
}
