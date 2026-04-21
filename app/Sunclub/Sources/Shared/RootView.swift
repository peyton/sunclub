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
        .overlay(alignment: .leading) {
            EdgeBackSwipeOverlay(canGoBack: router.canGoBack) {
                router.goBack()
            }
        }
        .interactivePopGestureEnabled()
        .tint(AppPalette.sun)
    }

    @ViewBuilder
    private var rootScreen: some View {
        if appState.settings.hasCompletedOnboarding {
            if RuntimeEnvironment.shouldUseLegacyHome {
                HomeView()
            } else {
                TimelineHomeView()
            }
        } else {
            WelcomeView()
        }
    }

    @ViewBuilder
    // swiftlint:disable:next cyclomatic_complexity
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .welcome:
            WelcomeView()
        case .enableNotifications:
            EnableNotificationsView()
        case .home:
            if RuntimeEnvironment.shouldUseLegacyHome {
                HomeView()
            } else {
                TimelineHomeView()
            }
        case .verifySuccess:
            VerificationSuccessView()
        case .reapplyCheckIn:
            ReapplyCheckInView()
        case .weeklySummary:
            WeeklyReportView()
        case .settings:
            SettingsView()
        case .automation:
            AutomationView()
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
        case .accountabilityOnboarding:
            AccountabilityOnboardingView()
        case .skinHealthReport:
            SkinHealthReportView()
        case .productScanner:
            ProductScannerView()
        case .yearInReview:
            YearInReviewView()
        case .valueProps:
            ValuePropsView()
        }
    }
}

private struct EdgeBackSwipeOverlay: View {
    private let edgeWidth: CGFloat = 32
    private let minimumHorizontalTravel: CGFloat = 60
    private let verticalToleranceMultiplier: CGFloat = 2

    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        if canGoBack {
            Color.clear
                .frame(width: edgeWidth)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 18, coordinateSpace: .global)
                        .onEnded { value in
                            guard value.translation.width >= minimumHorizontalTravel,
                                  value.translation.width > abs(value.translation.height) * verticalToleranceMultiplier else {
                                return
                            }

                            onBack()
                        }
                )
                .accessibilityHidden(true)
        }
    }
}
