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
    case uvForecast
    case privacy
    case support
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

    var rootTab: AppTab? {
        switch self {
        case .home:
            return .today
        case .history:
            return .history
        case .weeklySummary:
            return .insights
        case .settings:
            return .settings
        default:
            return nil
        }
    }

    var preferredTab: AppTab {
        switch self {
        case .history, .backfillYesterday, .historyEditToday, .historyBackfillTwoDaysAgo:
            return .history
        case .weeklySummary, .achievements, .skinHealthReport, .yearInReview:
            return .insights
        case .settings, .automation, .privacy, .support, .recovery, .friends, .accountabilityOnboarding:
            return .settings
        default:
            return .today
        }
    }
}

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case today
    case history
    case insights
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .history:
            return "History"
        case .insights:
            return "Insights"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "sun.max.fill"
        case .history:
            return "calendar"
        case .insights:
            return "chart.bar.fill"
        case .settings:
            return "gearshape.fill"
        }
    }

    var rootRoute: AppRoute {
        switch self {
        case .today:
            return .home
        case .history:
            return .history
        case .insights:
            return .weeklySummary
        case .settings:
            return .settings
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .today:
            return "timeline.footer.today"
        case .history:
            return "home.historyCard"
        case .insights:
            return "home.streakCard"
        case .settings:
            return "timeline.footer.settings"
        }
    }
}

struct AppRoutePayload: Equatable {
    var targetDate: Date?
    var targetDayPart: DayPart?

    static let empty = AppRoutePayload(targetDate: nil, targetDayPart: nil)
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var todayPath: [AppRoute] = []
    var historyPath: [AppRoute] = []
    var insightsPath: [AppRoute] = []
    var settingsPath: [AppRoute] = []
    var payload: AppRoutePayload = .empty

    var path: [AppRoute] {
        get {
            path(for: selectedTab)
        }
        set {
            setPath(newValue, for: selectedTab)
        }
    }

    var canGoBack: Bool {
        !path.isEmpty
    }

    func path(for tab: AppTab) -> [AppRoute] {
        switch tab {
        case .today:
            return todayPath
        case .history:
            return historyPath
        case .insights:
            return insightsPath
        case .settings:
            return settingsPath
        }
    }

    func setPath(_ path: [AppRoute], for tab: AppTab) {
        switch tab {
        case .today:
            todayPath = path
        case .history:
            historyPath = path
        case .insights:
            insightsPath = path
        case .settings:
            settingsPath = path
        }
    }

    func selectTab(_ tab: AppTab) {
        payload = .empty
        selectedTab = tab
    }

    func open(
        _ route: AppRoute,
        targetDate: Date? = nil,
        targetDayPart: DayPart? = nil
    ) {
        payload = AppRoutePayload(targetDate: targetDate, targetDayPart: targetDayPart)
        if route == .welcome {
            selectedTab = .today
            clearAllPaths()
        } else if let rootTab = route.rootTab {
            selectedTab = rootTab
            setPath([], for: rootTab)
        } else {
            let tab = route.preferredTab
            selectedTab = tab
            setPath([route], for: tab)
        }
    }

    func push(
        _ route: AppRoute,
        targetDate: Date? = nil,
        targetDayPart: DayPart? = nil
    ) {
        payload = AppRoutePayload(targetDate: targetDate, targetDayPart: targetDayPart)
        if route == .welcome {
            selectedTab = .today
            clearAllPaths()
        } else if let rootTab = route.rootTab {
            selectedTab = rootTab
            setPath([], for: rootTab)
        } else {
            var currentPath = path(for: selectedTab)
            currentPath.append(route)
            setPath(currentPath, for: selectedTab)
        }
    }

    func replace(with route: AppRoute) {
        if let rootTab = route.rootTab {
            selectedTab = rootTab
            setPath([], for: rootTab)
            return
        }

        var currentPath = path(for: selectedTab)
        if currentPath.isEmpty {
            currentPath = [route]
        } else {
            currentPath[currentPath.count - 1] = route
        }
        setPath(currentPath, for: selectedTab)
    }

    func goBack() {
        var currentPath = path(for: selectedTab)
        guard !currentPath.isEmpty else {
            return
        }

        currentPath.removeLast()
        setPath(currentPath, for: selectedTab)
    }

    func goHome() {
        payload = .empty
        selectedTab = .today
        clearAllPaths()
    }

    func goToWelcome() {
        payload = .empty
        selectedTab = .today
        clearAllPaths()
    }

    private func clearAllPaths() {
        todayPath = []
        historyPath = []
        insightsPath = []
        settingsPath = []
    }
}
