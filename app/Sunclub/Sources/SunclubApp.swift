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
    private let container: ModelContainer
    private let isRunningTests = RuntimeEnvironment.isRunningTests

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
                    refreshReminderScheduleIfNeeded()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    refreshReminderScheduleIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshReminderScheduleIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                    refreshReminderScheduleIfNeeded()
                }
        }
    }

    private func applyUITestLaunchConfigurationIfNeeded() {
        guard !appliedUITestLaunchConfiguration else { return }
        appliedUITestLaunchConfiguration = true

        let arguments = ProcessInfo.processInfo.arguments
        let requestedRoute = requestedUITestRoute(from: arguments)
        let requestedURL = requestedUITestURL(from: arguments)
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
            appState.settings.reapplyReminderEnabled = true
            if let requestedReapplyInterval {
                appState.settings.reapplyIntervalMinutes = max(30, min(480, requestedReapplyInterval))
            }
            appState.save()
        }

        applyUITestSeedData(from: arguments)

        if let requestedURL {
            handleIncomingURL(requestedURL)
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
            if scenario == "editBackfill" {
                seedHistoryEditBackfillScenario()
            }
        }

        seedUsageInsightsForUITestsIfNeeded(arguments: arguments)
    }

    private func seedHistoryEditBackfillScenario() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: today) else {
            return
        }

        let todayRecord = DailyRecord(
            startOfDay: today,
            verifiedAt: verifiedAt,
            method: .manual,
            spfLevel: 30,
            notes: "Seeded today"
        )
        appState.modelContext.insert(todayRecord)
        appState.save()
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

            let record = DailyRecord(
                startOfDay: day,
                verifiedAt: verifiedAt,
                method: .manual,
                spfLevel: entry.spfLevel,
                notes: entry.notes
            )
            appState.modelContext.insert(record)
        }

        appState.save()
        appState.refresh()
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
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.registerBackgroundTaskIfNeeded()
        return true
    }
}
