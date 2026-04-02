import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            rootScreen
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .tint(AppPalette.sun)
    }

    @ViewBuilder
    private var rootScreen: some View {
        if appState.settings.hasCompletedOnboarding {
            HomeView()
        } else {
            WelcomeView()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .welcome:
            WelcomeView()
        case .enableNotifications:
            EnableNotificationsView()
        case .home:
            HomeView()
        case .verifySuccess:
            VerificationSuccessView()
        case .weeklySummary:
            WeeklyReportView()
        case .settings:
            SettingsView()
        case .history:
            HistoryView()
        case .manualLog:
            ManualLogView()
        }
    }
}
