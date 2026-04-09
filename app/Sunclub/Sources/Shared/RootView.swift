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
        .interactivePopGestureEnabled()
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
        case .reapplyCheckIn:
            ReapplyCheckInView()
        case .weeklySummary:
            WeeklyReportView()
        case .settings:
            SettingsView()
        case .recovery:
            RecoveryView()
        case .history:
            HistoryView()
        case .backfillYesterday:
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            HistoryRecordEditorView(
                day: yesterday,
                existingRecord: appState.record(for: yesterday),
                route: .backfillYesterday
            )
        case .historyEditToday:
            HistoryEditorTestHarnessView(day: Calendar.current.startOfDay(for: Date()))
        case .historyBackfillTwoDaysAgo:
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let missedDay = calendar.date(byAdding: .day, value: -2, to: today) ?? today
            HistoryEditorTestHarnessView(day: missedDay)
        case .manualLog:
            ManualLogView()
        case .achievements:
            AchievementsView()
        case .friends:
            FriendsView()
        case .skinHealthReport:
            SkinHealthReportView()
        case .productScanner:
            ProductScannerView()
        }
    }
}
