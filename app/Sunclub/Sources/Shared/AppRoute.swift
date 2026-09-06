import Foundation
import Observation

enum AppRoute: String, Hashable, Codable, Identifiable {
    case welcome
    case enableLocation
    case enableNotifications
    case home
    case verifySuccess
    case reapplyCheckIn
    case departureCheckIn
    case weeklySummary
    case settings
    case settingsSunscreen
    case settingsHealth
    case settingsSunscreenReminders
    case settingsReapplyReminder
    case settingsNotifications
    case settingsHealthWeather
    case settingsData
    case settingsShortcuts
    case settingsHelp
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

    case skinHealthReport
    case productScanner
    case yearInReview
    case valueProps

    var id: String { rawValue }

    var productionRoute: AppRoute {
        switch self {
        case .achievements, .yearInReview:
            return .weeklySummary
        case .skinHealthReport:
            return .history
        case .productScanner:
            return .manualLog
        case .settingsReapplyReminder, .settingsNotifications:
            return .settingsSunscreenReminders
        case .settingsHelp:
            return .support
        default:
            return self
        }
    }

    var rootTab: AppTab? {
        switch self {
        case .home:
            return .today
        case .history:
            return .history
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
            return .history
        case .settings,
             .settingsSunscreen,
             .settingsHealth,
             .settingsSunscreenReminders,
             .settingsReapplyReminder,
             .settingsNotifications,
             .settingsHealthWeather,
             .settingsData,
             .settingsShortcuts,
             .settingsHelp,
             .automation,
             .privacy,
             .support,
             .recovery:
            return .settings
        default:
            return .today
        }
    }
}

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case today
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var rootRoute: AppRoute {
        switch self {
        case .today:
            return .home
        case .history:
            return .history
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
        case .settings:
            return "timeline.footer.settings"
        }
    }
}

struct AppRoutePayload: Hashable {
    let presentationID = UUID()
    var targetDate: Date?
    var targetDayPart: DayPart?

    static let empty = AppRoutePayload(targetDate: nil, targetDayPart: nil)
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .today {
        didSet {
            if selectedTab != oldValue { releaseOnboardingPresentation() }
        }
    }
    var todayPath: [AppRoute] = []
    var historyPath: [AppRoute] = []
    var settingsPath: [AppRoute] = []
    private var tabPayloads: [AppTab: AppRoutePayload] = [:]
    private(set) var retainsOnboarding = false
    private var onboardingCompletionID: UUID?

    func beginOnboardingCompletion(hasCompletedOnboarding: Bool) -> UUID {
        let id = UUID()
        onboardingCompletionID = id
        if !hasCompletedOnboarding { retainsOnboarding = true }
        return id
    }

    func isCurrentOnboardingCompletion(_ id: UUID) -> Bool {
        onboardingCompletionID == id
    }

    var payload: AppRoutePayload {
        get { payload(for: selectedTab) }
        set { tabPayloads[selectedTab] = newValue }
    }

    func payload(for tab: AppTab) -> AppRoutePayload {
        tabPayloads[tab] ?? .empty
    }

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

    var showsRootTabChrome: Bool {
        path(for: selectedTab).isEmpty
    }

    func path(for tab: AppTab) -> [AppRoute] {
        switch tab {
        case .today:
            return todayPath
        case .history:
            return historyPath
        case .settings:
            return settingsPath
        }
    }

    func setPath(_ path: [AppRoute], for tab: AppTab) {
        if tab == selectedTab, path != self.path(for: tab) {
            releaseOnboardingPresentation()
        }
        if path.isEmpty { tabPayloads[tab] = nil }
        switch tab {
        case .today:
            todayPath = path
        case .history:
            historyPath = path
        case .settings:
            settingsPath = path
        }
    }

    func selectTab(_ tab: AppTab) {
        selectedTab = tab
    }

    func open(
        _ route: AppRoute,
        targetDate: Date? = nil,
        targetDayPart: DayPart? = nil
    ) {
        releaseOnboardingPresentation()
        let route = route.productionRoute
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
        payload = AppRoutePayload(targetDate: targetDate, targetDayPart: targetDayPart)
    }

    func push(
        _ route: AppRoute,
        targetDate: Date? = nil,
        targetDayPart: DayPart? = nil
    ) {
        let route = route.productionRoute
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
        if targetDate != nil || targetDayPart != nil || route == .manualLog {
            payload = AppRoutePayload(targetDate: targetDate, targetDayPart: targetDayPart)
        }
    }

    func replace(with route: AppRoute) {
        let route = route.productionRoute
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
        tabPayloads = [:]
        todayPath = []
        historyPath = []
        settingsPath = []
        releaseOnboardingPresentation()
    }

    private func releaseOnboardingPresentation() {
        retainsOnboarding = false
        onboardingCompletionID = nil
    }
}
