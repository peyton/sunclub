import SwiftData
import SwiftUI
import UIKit

@main
struct SunclubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState
    @State private var router = AppRouter()
    @State private var appliedUITestLaunchConfiguration = false
    private let container: ModelContainer
    private let isRunningTests = RuntimeEnvironment.isRunningTests

    init() {
        let schema = Schema([
            DailyRecord.self,
            Settings.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: RuntimeEnvironment.isRunningTests,
            groupContainer: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
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
                .onAppear {
                    NotificationManager.shared.setRouteHandler { route in
                        router.open(route)
                    }
                    guard !isRunningTests else {
                        applyUITestLaunchConfigurationIfNeeded()
                        return
                    }
                    Task {
                        guard appState.settings.hasCompletedOnboarding else { return }
                        _ = await NotificationManager.shared.configure()
                        await NotificationManager.shared.scheduleReminders(using: appState)
                    }
                }
        }
    }

    private func applyUITestLaunchConfigurationIfNeeded() {
        guard !appliedUITestLaunchConfiguration else { return }
        appliedUITestLaunchConfiguration = true

        let arguments = ProcessInfo.processInfo.arguments
        let requestedRoute = requestedUITestRoute(from: arguments)
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

        if let requestedRoute {
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
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.registerBackgroundTaskIfNeeded()
        return true
    }
}
