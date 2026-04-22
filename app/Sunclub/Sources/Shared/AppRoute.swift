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
    case automation
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
    case yearInReview
    case valueProps

    var id: String { rawValue }
}

struct AppRoutePayload: Equatable {
    var targetDate: Date?
    var targetDayPart: DayPart?

    static let empty = AppRoutePayload(targetDate: nil, targetDayPart: nil)
}

@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var payload: AppRoutePayload = .empty

    var canGoBack: Bool {
        !path.isEmpty
    }

    func open(
        _ route: AppRoute,
        targetDate: Date? = nil,
        targetDayPart: DayPart? = nil
    ) {
        payload = AppRoutePayload(targetDate: targetDate, targetDayPart: targetDayPart)
        if route == .home || route == .welcome {
            path.removeAll()
        } else {
            path = [route]
        }
    }

    func push(
        _ route: AppRoute,
        targetDate: Date? = nil,
        targetDayPart: DayPart? = nil
    ) {
        payload = AppRoutePayload(targetDate: targetDate, targetDayPart: targetDayPart)
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
        payload = .empty
        path.removeAll()
    }

    func goToWelcome() {
        payload = .empty
        path.removeAll()
    }
}
