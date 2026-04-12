import Foundation
import Observation

enum AppRoute: String, Hashable, Codable, Identifiable {
    case welcome
    case enableNotifications
    case home
    case verifySuccess
    case reapplyCheckIn
    case weeklySummary
    case settings
    case recovery
    case history
    case backfillYesterday
    case historyEditToday
    case historyBackfillTwoDaysAgo
    case manualLog
    case achievements
    case friends
    case accountabilityOnboarding
    case skinHealthReport
    case productScanner

    var id: String { rawValue }
}

@Observable
final class AppRouter {
    var path: [AppRoute] = []

    var canGoBack: Bool {
        !path.isEmpty
    }

    func open(_ route: AppRoute) {
        if route == .home || route == .welcome {
            path.removeAll()
        } else {
            path = [route]
        }
    }

    func push(_ route: AppRoute) {
        if route == .home || route == .welcome {
            path.removeAll()
        } else {
            path.append(route)
        }
    }

    func replace(with route: AppRoute) {
        open(route)
    }

    func goBack() {
        guard !path.isEmpty else {
            return
        }

        path.removeLast()
    }

    func goHome() {
        path.removeAll()
    }

    func goToWelcome() {
        path.removeAll()
    }
}
