import SwiftUI
import UIKit

extension SunAppTabBarAction {
    init(presentation: HomeDailyPlanPresentation) {
        let shortTitle: String
        switch presentation.action {
        case .logToday: shortTitle = "Log"
        case .backfillYesterday: shortTitle = "Backfill"
        case .logReapply: shortTitle = "Reapply"
        case .addDetails: shortTitle = "Details"
        case .viewProgress: shortTitle = "Progress"
        case .reviewRecovery: shortTitle = "Review"
        case .repairReminders: shortTitle = "Repair"
        case .openSettings: shortTitle = "Settings"
        }
        self.init(
            shortTitle: shortTitle,
            title: presentation.actionTitle,
            systemImage: presentation.symbolName,
            accessibilityHint: presentation.detail
        )
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if appState.shouldShowInitialICloudRestoreGate {
                InitialICloudRestoreView()
            } else if appState.settings.hasCompletedOnboarding {
                tabbedRoot
            } else {
                onboardingRoot
            }
        }
        .overlay(alignment: .leading) {
            if RuntimeEnvironment.isUITesting {
                EdgeBackSwipeOverlay(canGoBack: router.canGoBack) {
                    router.goBack()
                }
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

    @ViewBuilder
    private var tabbedRoot: some View {
        if #available(iOS 26.0, *) {
            nativeTabbedRoot
        } else {
            legacyTabbedRoot
        }
    }

    private var legacyTabbedRoot: some View {
        VStack(spacing: 0) {
            NavigationStack(path: pathBinding(for: router.selectedTab)) {
                tabRoot(for: router.selectedTab)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if router.path(for: router.selectedTab).isEmpty {
                SunAppTabBar(
                    selectedTab: router.selectedTab,
                    onSelectTab: { tab in
                        router.open(tab.rootRoute)
                    },
                    centerAction: contextualTabAction,
                    onAdd: performHomeDailyPlanAction
                )
            }
        }
    }

    @available(iOS 26.0, *)
    private var nativeTabbedRoot: some View {
        nativeTabView
            .toolbar(router.showsRootTabChrome ? .visible : .hidden, for: .tabBar)
            .tint(AppPalette.nativeChromeTint)
    }

    @ViewBuilder
    @available(iOS 26.0, *)
    private var nativeTabView: some View {
        #if SUNCLUB_HAS_PROMINENT_TAB_ROLE
        if #available(iOS 27.0, *) {
            nativeTabView(actionRole: .prominent)
        } else {
            nativeTabView(actionRole: .search)
        }
        #else
        nativeTabView(actionRole: .search)
        #endif
    }

    @available(iOS 26.0, *)
    private func nativeTabView(actionRole: TabRole) -> some View {
        TabView(selection: selectedTabBinding) {
            nativeTab(.today)
            nativeTab(.history)
            nativeTab(.insights)
            nativeTab(.settings)
            nativeActionTab(role: actionRole)
        }
        .background {
            SunNativeTabAccessibilityIdentifierInstaller()
        }
        .tabBarMinimizeBehavior(.never)
    }

    private var selectedTabBinding: Binding<SunNativeTabSelection> {
        Binding(
            get: { .content(router.selectedTab) },
            set: { selection in
                switch selection {
                case let .content(tab):
                    router.selectTab(tab)
                case .action:
                    performHomeDailyPlanAction()
                }
            }
        )
    }

    @available(iOS 26.0, *)
    private func nativeTab(_ tab: AppTab) -> some TabContent<SunNativeTabSelection> {
        Tab(value: .content(tab)) {
            NavigationStack(path: pathBinding(for: tab)) {
                tabRoot(for: tab)
                    .navigationTitle(tab.title)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
            .toolbar(router.path(for: tab).isEmpty ? .visible : .hidden, for: .tabBar)
        } label: {
            Label(tab.title, systemImage: tab.systemImage)
        }
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    @available(iOS 26.0, *)
    private func nativeActionTab(role: TabRole) -> some TabContent<SunNativeTabSelection> {
        Tab(value: .action, role: role) {
            EmptyView()
        } label: {
            Label {
                Text(contextualTabAction.title)
            } icon: {
                Image(
                    uiImage: UIImage(systemName: contextualTabAction.systemImage)?.withTintColor(
                        UIColor(AppColor.accent),
                        renderingMode: .alwaysOriginal
                    ) ?? UIImage()
                )
            }
        }
        .accessibilityLabel(contextualTabAction.title)
        .accessibilityHint(contextualTabAction.accessibilityHint)
        .accessibilityIdentifier("home.logManually")
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
        case .enableLocation:
            EnableLocationView()
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
        case .settingsSunscreenReminders:
            SettingsView(detail: .sunscreenReminders)
        case .settingsReapplyReminder:
            SettingsView(detail: .reapplyReminder)
        case .settingsNotifications:
            SettingsView(detail: .notifications)
        case .settingsHealthWeather:
            SettingsView(detail: .healthWeather)
        case .settingsData:
            SettingsView(detail: .data)
        case .settingsShortcuts:
            SettingsView(detail: .shortcuts)
        case .settingsHelp:
            SettingsView(detail: .help)
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
            WeeklyReportView()
        case .friends:
            SettingsView()
        case .accountabilityOnboarding:
            SettingsView()
        case .skinHealthReport:
            HistoryView()
        case .productScanner:
            ManualLogView(context: consumeManualLogContext())
        case .yearInReview:
            HistoryView()
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

    private func performHomeDailyPlanAction() {
        switch appState.homeDailyPlanPresentation.action {
        case .logToday, .addDetails:
            appState.clearManualLogPrefill()
            let today = appState.startOfLocalDay(appState.referenceDate)
            let context = appState.currentLogContext(for: today, source: .manualLog)
            appState.prepareManualLogRouteContext(
                targetDate: context.date,
                targetDayPart: context.dayPart,
                source: context.source
            )
            router.push(.manualLog, targetDate: context.date, targetDayPart: context.dayPart)
        case .backfillYesterday:
            router.open(.backfillYesterday)
        case .logReapply:
            router.open(.reapplyCheckIn)
        case .viewProgress:
            router.open(.weeklySummary)
        case .reviewRecovery:
            router.open(.recovery)
        case .repairReminders:
            appState.repairReminderSchedule()
        case .openSettings:
            router.open(.settingsNotifications)
        }
    }

    private var contextualTabAction: SunAppTabBarAction {
        SunAppTabBarAction(presentation: appState.homeDailyPlanPresentation)
    }
}

private enum SunNativeTabSelection: Hashable {
    case content(AppTab)
    case action
}

@available(iOS 26.0, *)
private struct SunNativeTabAccessibilityIdentifierInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InstallerViewController {
        InstallerViewController()
    }

    func updateUIViewController(_ uiViewController: InstallerViewController, context: Context) {
        uiViewController.installIdentifiers()
    }

    final class InstallerViewController: UIViewController {
        private var didInstallIdentifiers = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installIdentifiers()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            installIdentifiers()
        }

        func installIdentifiers() {
            let identifiers = AppTab.allCases.map(\.accessibilityIdentifier) + ["home.logManually"]
            guard let window = view.window,
                  let tabBar = findTabBar(in: window),
                  let items = tabBar.items,
                  items.count == identifiers.count else {
                return
            }

            if !didInstallIdentifiers {
                for (item, identifier) in zip(items, identifiers) {
                    item.accessibilityIdentifier = identifier
                }
                didInstallIdentifiers = true
            }
        }

        private func findTabBar(in view: UIView) -> UITabBar? {
            if let tabBar = view as? UITabBar {
                return tabBar
            }

            for subview in view.subviews {
                if let tabBar = findTabBar(in: subview) {
                    return tabBar
                }
            }
            return nil
        }
    }
}

private struct InitialICloudRestoreView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                Spacer(minLength: AppSpacing.xl)
                SunBrandLockup()
                    .accessibilityHidden(true)
                SunScreenTitleBlock(
                    eyebrow: "iCloud",
                    title: title,
                    detail: detail
                )
                if case .checking = appState.initialICloudRestoreState {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppPalette.sun)
                        .accessibilityLabel("Checking iCloud")
                }
                Spacer(minLength: AppSpacing.xl)
            }
        } footer: {
            if case .failed = appState.initialICloudRestoreState {
                VStack(spacing: AppSpacing.sm) {
                    Button("Try Again") {
                        appState.retryInitialICloudRestore()
                    }
                    .sunGlassPrimaryButton()
                    .accessibilityIdentifier("icloudRestore.retry")

                    Button("Continue on This Phone") {
                        appState.continueWithoutInitialICloudRestore()
                    }
                    .sunGlassSecondaryButton()
                    .accessibilityIdentifier("icloudRestore.continue")
                }
            }
        }
        .accessibilityIdentifier("icloudRestore.gate")
    }

    private var title: String {
        switch appState.initialICloudRestoreState {
        case .checking:
            return "Checking iCloud"
        case .failed:
            return "iCloud needs attention"
        case .notNeeded, .restored, .noRemoteHistory, .continuedLocally:
            return "Checking iCloud"
        }
    }

    private var detail: String {
        switch appState.initialICloudRestoreState {
        case .checking:
            return "Looking for your synced Sunclub history before setup continues."
        case let .failed(message):
            return message
        case .notNeeded, .restored, .noRemoteHistory, .continuedLocally:
            return "Looking for your synced Sunclub history before setup continues."
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
