import SwiftData
import SwiftUI
import UIKit

@main
struct SunscreenTrackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState
    @State private var router = AppRouter()
    private let container: ModelContainer

    init() {
        let schema = Schema([
            DailyRecord.self,
            TrainingAsset.self,
            Settings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
                    Task {
                        await NotificationManager.shared.configure()
                        await NotificationManager.shared.scheduleReminders(using: appState)
                    }
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }
}
