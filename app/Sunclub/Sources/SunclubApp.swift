import SwiftData
import SwiftUI
import UIKit

@main
struct SunclubApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState
    @State private var router = AppRouter()
    @State private var appliedUITestLaunchConfiguration = false
    @State private var hasRefreshedForegroundSinceVisibility = false
    private let container: ModelContainer
    private let isRunningTests = RuntimeEnvironment.isRunningTests

    private enum UITestNotificationHealth: String {
        case denied
        case stale
        case healthy
    }

    init() {
        do {
            container = try SunclubModelContainerFactory.makeSharedContainer(
                isStoredInMemoryOnly: RuntimeEnvironment.isRunningTests
            )
        } catch {
            assertionFailure("Failed to create ModelContainer: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
        NotificationManager.shared.configure(modelContainer: container)

        let state = AppState(context: ModelContext(container), notificationManager: NotificationManager.shared)
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
                .modelContainer(container)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    NotificationManager.shared.setRouteHandler { route in
                        router.open(route)
                    }
                    guard !isRunningTests else {
                        applyUITestLaunchConfigurationIfNeeded()
                        return
                    }
                    guard scenePhase == .active, !hasRefreshedForegroundSinceVisibility else {
                        return
                    }
                    hasRefreshedForegroundSinceVisibility = true
                    refreshAppStateForForeground()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else {
                        hasRefreshedForegroundSinceVisibility = false
                        return
                    }
                    guard !hasRefreshedForegroundSinceVisibility else { return }
                    hasRefreshedForegroundSinceVisibility = true
                    refreshAppStateForForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshAppStateForForeground()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                    refreshAppStateForForeground()
                }
        }
    }

    private func applyUITestLaunchConfigurationIfNeeded() {
        guard !appliedUITestLaunchConfiguration else { return }
        appliedUITestLaunchConfiguration = true

        let arguments = ProcessInfo.processInfo.arguments
        let requestedRoute = requestedUITestRoute(from: arguments)
        let requestedURL = requestedUITestURL(from: arguments)
        let requestedShortcutType = requestedUITestShortcutType(from: arguments)
        let requestedUVIndex = requestedUITestUVIndex(from: arguments)
        let requestedReapplyInterval = requestedUITestReapplyInterval(from: arguments)

        if arguments.contains("UITEST_COMPLETE_ONBOARDING") || requestedRoute.map({ $0 != .welcome }) == true,
           !appState.settings.hasCompletedOnboarding {
            appState.completeOnboarding()
        }

        if let requestedUVIndex {
            appState.setUVReadingForTesting(UVReading(index: requestedUVIndex))
        }

        if arguments.contains("UITEST_REAPPLY_ENABLED") {
            appState.updateReapplySettings(
                enabled: true,
                intervalMinutes: requestedReapplyInterval ?? appState.settings.reapplyIntervalMinutes
            )
        }

        applyUITestSeedData(from: arguments)

        if let requestedURL {
            handleIncomingURL(requestedURL)
        } else if let requestedShortcutType {
            if SunclubHomeScreenQuickAction.handleShortcutType(requestedShortcutType),
               let pendingRoute = SunclubWidgetSnapshotStore().takePendingRoute() {
                openExternalRoute(pendingRoute)
            }
        } else if let requestedRoute {
            if requestedRoute == .verifySuccess {
                appState.verificationSuccessPresentation = VerificationSuccessPresentation(streak: 3, isPersonalBest: true)
            }
            router.open(requestedRoute)
        }
    }

    private func requestedUITestRoute(from arguments: [String]) -> AppRoute? {
        guard let routeArgument = arguments.first(where: { $0.hasPrefix("UITEST_ROUTE=") }) else {
            return nil
        }

        let rawValue = String(routeArgument.dropFirst("UITEST_ROUTE=".count))
        return AppRoute(rawValue: rawValue)
    }

    private func requestedUITestURL(from arguments: [String]) -> URL? {
        guard let urlArgument = arguments.first(where: { $0.hasPrefix("UITEST_URL=") }) else {
            return nil
        }

        let rawValue = String(urlArgument.dropFirst("UITEST_URL=".count))
        return URL(string: rawValue)
    }

    private func requestedUITestShortcutType(from arguments: [String]) -> String? {
        guard let shortcutArgument = arguments.first(where: { $0.hasPrefix("UITEST_SHORTCUT_TYPE=") }) else {
            return nil
        }

        return String(shortcutArgument.dropFirst("UITEST_SHORTCUT_TYPE=".count))
    }

    private func requestedUITestUVIndex(from arguments: [String]) -> Int? {
        requestedIntegerArgument(withPrefix: "UITEST_UV_INDEX=", from: arguments)
    }

    private func requestedUITestReapplyInterval(from arguments: [String]) -> Int? {
        requestedIntegerArgument(withPrefix: "UITEST_REAPPLY_INTERVAL=", from: arguments)
    }

    private func requestedIntegerArgument(withPrefix prefix: String, from arguments: [String]) -> Int? {
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }

        return Int(argument.dropFirst(prefix.count))
    }

    private func applyUITestSeedData(from arguments: [String]) {
        if let seedArgument = arguments.first(where: { $0.hasPrefix("UITEST_SEED_HISTORY=") }) {
            let scenario = String(seedArgument.dropFirst("UITEST_SEED_HISTORY=".count))
            switch scenario {
            case "editBackfill":
                seedHistoryEditBackfillScenario()
            case "manualSuggestions":
                seedManualSuggestionsScenario()
            case "todayLogged":
                seedTodayLoggedScenario()
            case "reapplyToday":
                seedReapplyTodayScenario()
            case "reminderCoaching":
                seedReminderCoachingScenario()
            case "monthlyReview":
                seedCurrentMonthReviewScenario()
            case "conflictDay":
                seedDayConflictScenario()
            case "undoDeleteToday":
                seedUndoDeleteTodayScenario()
            default:
                break
            }
        }

        if let notificationHealth = requestedUITestNotificationHealth(from: arguments) {
            appState.setNotificationHealthSnapshotForTesting(
                notificationHealthSnapshot(for: notificationHealth)
            )
        }

        seedUsageInsightsForUITestsIfNeeded(arguments: arguments)
    }

    private func seedHistoryEditBackfillScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: today)
        appState.saveManualRecord(for: today, verifiedAt: verifiedAt, spfLevel: 30, notes: "Seeded today")
        appState.refresh()
    }

    private func seedManualSuggestionsScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) else {
            return
        }

        insertSeedRecord(day: yesterday, hour: 9, minute: 0, spfLevel: 50, notes: "Morning beach walk")
        insertSeedRecord(day: twoDaysAgo, hour: 8, minute: 15, spfLevel: 30, notes: "Before lunch")
        appState.save()
        appState.refresh()
    }

    private func seedTodayLoggedScenario() {
        let today = Calendar.current.startOfDay(for: Date())
        insertSeedRecord(day: today, hour: 9, minute: 0, spfLevel: 50, notes: "Seeded today")
        appState.save()
        appState.refresh()
    }

    private func seedReapplyTodayScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastReappliedAt = calendar.date(byAdding: .hour, value: 2, to: today)
        insertSeedRecord(
            day: today,
            hour: 9,
            minute: 0,
            spfLevel: 50,
            notes: "Seeded today",
            reapplyCount: 1,
            lastReappliedAt: lastReappliedAt
        )
        appState.save()
        appState.refresh()
    }

    private func seedReminderCoachingScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var weekdayDays: [Date] = []
        var weekendDays: [Date] = []

        for offset in 1..<29 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }

            if calendar.isDateInWeekend(day) {
                if weekendDays.count < 3 {
                    weekendDays.append(day)
                }
            } else if weekdayDays.count < 3 {
                weekdayDays.append(day)
            }

            if weekdayDays.count == 3, weekendDays.count == 3 {
                break
            }
        }

        let weekdayTimes = [(9, 15), (9, 0), (9, 30)]
        for (day, time) in zip(weekdayDays, weekdayTimes) {
            insertSeedRecord(day: day, hour: time.0, minute: time.1, spfLevel: 50, notes: "Weekday seed")
        }

        let weekendTimes = [(11, 0), (10, 45), (11, 15)]
        for (day, time) in zip(weekendDays, weekendTimes) {
            insertSeedRecord(day: day, hour: time.0, minute: time.1, spfLevel: 30, notes: "Weekend seed")
        }

        appState.save()
        appState.refresh()
    }

    private func seedCurrentMonthReviewScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today

        insertSeedRecord(day: monthStart, hour: 9, minute: 0, spfLevel: 50, notes: "Month start")
        if let secondDay = calendar.date(byAdding: .day, value: 1, to: monthStart), secondDay <= today {
            insertSeedRecord(day: secondDay, hour: 10, minute: 0, spfLevel: 30, notes: "Day two")
        }
        if let thirdDay = calendar.date(byAdding: .day, value: 2, to: monthStart), thirdDay <= today {
            insertSeedRecord(day: thirdDay, hour: 9, minute: 30, spfLevel: 50, notes: "Day three")
        }

        appState.save()
        appState.refresh()
    }

    private func seedDayConflictScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: today) ?? today
        appState.saveManualRecord(for: today, verifiedAt: verifiedAt, spfLevel: 30, notes: "Local entry")

        let remoteCreatedAt = Date().addingTimeInterval(60)
        let remoteBatch = SunclubChangeBatch(
            createdAt: remoteCreatedAt,
            kind: .historyEdit,
            scope: .day,
            scopeIdentifier: today.formatted(.iso8601.year().month().day()),
            authorDeviceID: "uitest-remote-device",
            summary: "Remote history edit",
            isLocalOnly: false,
            isPublishedToCloud: true,
            cloudPublishedAt: remoteCreatedAt
        )
        appState.modelContext.insert(remoteBatch)
        appState.modelContext.insert(
            DailyRecordRevision(
                batch: remoteBatch,
                snapshot: DailyRecordProjectionSnapshot(
                    startOfDay: today,
                    verifiedAt: verifiedAt,
                    methodRawValue: VerificationMethod.manual.rawValue,
                    verificationDuration: nil,
                    spfLevel: 50,
                    notes: "Remote entry",
                    reapplyCount: 0,
                    lastReappliedAt: nil
                ),
                changedFields: [.spfLevel, .notes]
            )
        )
        appState.save()
        appState.refresh()
    }

    private func seedUndoDeleteTodayScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        insertSeedRecord(day: yesterday, hour: 8, minute: 30, spfLevel: 50, notes: "Yesterday")
        insertSeedRecord(day: today, hour: 9, minute: 0, spfLevel: 30, notes: "Today")
        appState.deleteRecord(for: today)
        appState.refresh()
    }

    private func seedUsageInsightsForUITestsIfNeeded(arguments: [String]) {
        guard arguments.contains("UITEST_SEED_USAGE_INSIGHTS") else {
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let seedData: [(dayOffset: Int, spfLevel: Int?, notes: String?)] = [
            (0, 50, "Before beach walk"),
            (1, 30, "Applied before morning run"),
            (2, 50, nil),
            (4, 50, "Reapplied after lunch")
        ]

        for entry in seedData {
            guard let day = calendar.date(byAdding: .day, value: -entry.dayOffset, to: today),
                  let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: day) else {
                continue
            }

            appState.saveManualRecord(
                for: day,
                verifiedAt: verifiedAt,
                spfLevel: entry.spfLevel,
                notes: entry.notes
            )
        }

        appState.save()
        appState.refresh()
    }

    private func insertSeedRecord(
        day: Date,
        hour: Int,
        minute: Int,
        spfLevel: Int? = nil,
        notes: String? = nil,
        reapplyCount: Int = 0,
        lastReappliedAt: Date? = nil
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let verifiedAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) ?? startOfDay

        appState.saveManualRecord(
            for: startOfDay,
            verifiedAt: verifiedAt,
            spfLevel: spfLevel,
            notes: notes
        )

        if reapplyCount > 0 {
            for _ in 0..<reapplyCount {
                appState.recordReapplication(for: startOfDay, performedAt: lastReappliedAt)
            }
        }
    }

    private func requestedUITestNotificationHealth(from arguments: [String]) -> UITestNotificationHealth? {
        guard let value = RuntimeEnvironment.argumentValue(withPrefix: "UITEST_NOTIFICATION_HEALTH=") else {
            return nil
        }

        return UITestNotificationHealth(rawValue: value)
    }

    private func notificationHealthSnapshot(for health: UITestNotificationHealth) -> NotificationHealthSnapshot {
        switch health {
        case .denied:
            return NotificationHealthSnapshot(
                authorizationState: .denied,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            )
        case .stale:
            return NotificationHealthSnapshot(
                authorizationState: .authorized,
                pendingDailyReminderCount: 0,
                pendingStreakRiskReminderCount: 0,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: nil
            )
        case .healthy:
            return NotificationHealthSnapshot(
                authorizationState: .authorized,
                pendingDailyReminderCount: 3,
                pendingStreakRiskReminderCount: 1,
                pendingReapplyReminderCount: 0,
                lastScheduledAt: Date()
            )
        }
    }

    private func refreshAppStateForForeground() {
        appState.refresh()
        appState.refreshNotificationHealth()
        appState.refreshUVReadingIfNeeded()
        if let route = SunclubWidgetSnapshotStore().takePendingRoute() {
            openExternalRoute(route)
        }
        refreshReminderScheduleIfNeeded()
    }

    private func refreshReminderScheduleIfNeeded() {
        guard !isRunningTests, appState.settings.hasCompletedOnboarding else { return }

        Task {
            _ = await NotificationManager.shared.configure()
            await NotificationManager.shared.scheduleReminders(using: appState)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        _ = SunclubDeepLinkHandler.handle(url: url, appState: appState, router: router)
    }

    private func openExternalRoute(_ route: AppRoute) {
        guard appState.settings.hasCompletedOnboarding else {
            router.goToWelcome()
            return
        }

        router.open(route)
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.registerBackgroundTaskIfNeeded()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SunclubSceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(SunclubHomeScreenQuickAction.handleShortcutItem(shortcutItem))
    }
}

final class SunclubSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            _ = SunclubHomeScreenQuickAction.handleShortcutItem(shortcutItem)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(SunclubHomeScreenQuickAction.handleShortcutItem(shortcutItem))
    }
}
