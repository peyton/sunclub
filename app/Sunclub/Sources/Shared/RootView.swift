import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if appState.settings.hasCompletedOnboarding {
                tabbedRoot
            } else {
                onboardingRoot
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

    private var onboardingRoot: some View {
        NavigationStack(path: pathBinding(for: .today)) {
            WelcomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    private var tabbedRoot: some View {
        NavigationStack(path: pathBinding(for: router.selectedTab)) {
            tabRoot(for: router.selectedTab)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if router.path(for: router.selectedTab).isEmpty {
                SunAppTabBar(
                    selectedTab: router.selectedTab,
                    onSelectTab: { tab in
                        router.open(tab.rootRoute)
                    },
                    onAdd: openManualLogFromCurrentTab
                )
            }
        }
    }

    private func pathBinding(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: {
                router.path(for: tab)
            },
            set: { newPath in
                router.setPath(newPath, for: tab)
            }
        )
    }

    @ViewBuilder
    private func tabRoot(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TimelineHomeView()
        case .history:
            HistoryView(showsBackButton: false)
        case .insights:
            WeeklyReportView(showsBackButton: false)
        case .settings:
            SettingsView(showsBackButton: false)
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
            TimelineHomeView()
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
        case .uvForecast:
            UVForecastDetailView()
        case .privacy:
            PrivacyView()
        case .support:
            SupportView()
        case .recovery:
            RecoveryView()
        case .history:
            HistoryView()
        case .backfillYesterday:
            let calendar = Calendar.current
            let selectedDay = appState.startOfLocalDay(appState.selectedDay)
            let today = appState.startOfLocalDay(appState.referenceDate)
            let anchorDay = min(selectedDay, today)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: anchorDay) ?? anchorDay
            HistoryRecordEditorView(
                day: yesterday,
                existingRecord: appState.record(for: yesterday),
                route: .backfillYesterday,
                targetContext: AppLogContext(
                    date: yesterday,
                    dayPart: .morning,
                    source: .history
                )
            )
        case .historyEditToday:
            HistoryEditorTestHarnessView(day: Calendar.current.startOfDay(for: Date()))
        case .historyBackfillTwoDaysAgo:
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let missedDay = calendar.date(byAdding: .day, value: -2, to: today) ?? today
            HistoryEditorTestHarnessView(day: missedDay)
        case .manualLog:
            ManualLogView(context: consumeManualLogContext())
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
            WelcomeView()
        }
    }

    private func consumeManualLogContext() -> AppLogContext {
        let payload = router.payload
        router.payload = .empty
        let baseContext = appState.consumeManualLogRouteContext()
        guard payload.targetDate != nil || payload.targetDayPart != nil else {
            return baseContext
        }
        return AppLogContext(
            date: payload.targetDate.map(appState.startOfLocalDay) ?? baseContext.date,
            dayPart: payload.targetDayPart ?? baseContext.dayPart,
            source: baseContext.source
        )
    }

    private func openManualLogFromCurrentTab() {
        let context = appState.currentLogContext(for: appState.selectedDay, source: .manualLog)
        appState.prepareManualLogRouteContext(
            targetDate: context.date,
            targetDayPart: context.dayPart,
            source: context.source
        )
        router.push(.manualLog, targetDate: context.date, targetDayPart: context.dayPart)
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
