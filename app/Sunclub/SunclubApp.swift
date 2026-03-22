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
    private let isUITesting = RuntimeEnvironment.isUITesting
    private let isRunningTests = RuntimeEnvironment.isRunningTests

    init() {
        let schema = Schema([
            DailyRecord.self,
            Settings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: RuntimeEnvironment.isRunningTests)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            fatalError("Failed to create ModelContainer")
        }
        self.container = container
        AppDataContainer.shared = container

        let state = AppState(context: ModelContext(container))
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
                    Task(priority: .utility) {
                        guard appState.settings.hasCompletedOnboarding else { return }
                        let modelDirectory = await FastVLMModelDownloadService.shared.prepareForVerification()
                        await FastVLMService.shared.prewarmIfPossible(modelDirectory: modelDirectory)
                    }
                }
        }
    }

    private func applyUITestLaunchConfigurationIfNeeded() {
        guard !appliedUITestLaunchConfiguration else { return }
        appliedUITestLaunchConfiguration = true

        let arguments = ProcessInfo.processInfo.arguments
        let requestedRoute = requestedUITestRoute(from: arguments)

        if (arguments.contains("UITEST_COMPLETE_ONBOARDING") || requestedRoute.map({ $0 != .welcome }) == true),
           !appState.settings.hasCompletedOnboarding {
            appState.completeOnboarding()
        }

        if let requestedRoute {
            if requestedRoute == .verifySuccess {
                appState.verificationSuccessPresentation = VerificationSuccessPresentation(streak: 3, isPersonalBest: true)
            }
            router.open(requestedRoute)
        } else if arguments.contains("UITEST_ROUTE_VERIFY_CAMERA") {
            router.open(.verifyCamera)
        } else if arguments.contains("UITEST_ROUTE_WEEKLY_SUMMARY") {
            router.open(.weeklySummary)
        }
    }

    private func requestedUITestRoute(from arguments: [String]) -> AppRoute? {
        guard let routeArgument = arguments.first(where: { $0.hasPrefix("UITEST_ROUTE=") }) else {
            return nil
        }

        let rawValue = String(routeArgument.dropFirst("UITEST_ROUTE=".count))
        return AppRoute(rawValue: rawValue)
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.registerBackgroundTaskIfNeeded()
        return true
    }
}
