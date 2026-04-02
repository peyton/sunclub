import Foundation
import Observation

enum AppRoute: String, Hashable, Codable, Identifiable {
    case welcome
    case enableNotifications
    case home
    case verifySuccess
    case weeklySummary
    case settings
    case history
    case manualLog

    var id: String { rawValue }
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
