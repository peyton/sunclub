import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if appState.shouldShowInitialICloudRestoreGate {
                InitialICloudRestoreView()
            } else if appState.settings.hasCompletedOnboarding && !router.retainsOnboarding {
                tabbedRoot
            } else {
                onboardingRoot
            }
        }
        .tint(AppPalette.nativeChromeTint)
    }

    private var onboardingRoot: some View {
        NavigationStack(path: pathBinding(for: .today)) {
            WelcomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route, in: .today)
                }
        }
        .overlay(alignment: .leading) { legacyBackGesture(for: .today) }
    }

    private var tabbedRoot: some View {
        TabView(selection: selectedTabBinding) {
            nativeTab(.today)
            nativeTab(.history)
            nativeTab(.settings)
        }
        .background { SunNativeTabAccessibilityIdentifierInstaller() }
        .toolbar(router.showsRootTabChrome ? .visible : .hidden, for: .tabBar)
        .tint(AppPalette.nativeChromeTint)
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { router.selectTab($0) }
        )
    }

    private func nativeTab(_ tab: AppTab) -> some TabContent<AppTab> {
        Tab(value: tab) {
            NavigationStack(path: pathBinding(for: tab)) {
                tabRoot(for: tab)
                    .navigationTitle(tab.title)
                    .navigationBarTitleDisplayMode(.large)
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route, in: tab)
                            .navigationBarTitleDisplayMode(.inline)
                    }
            }
            .overlay(alignment: .leading) { legacyBackGesture(for: tab) }
            .toolbar(router.path(for: tab).isEmpty ? .visible : .hidden, for: .tabBar)
        } label: {
            Label {
                Text(tab.title)
            } icon: {
                SunIcon(tab: tab).image
            }
        }
        .accessibilityIdentifier(tab.accessibilityIdentifier)
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
    private func legacyBackGesture(for tab: AppTab) -> some View {
        if #available(iOS 26.0, *) {
            EmptyView()
        } else {
            EdgeBackSwipeOverlay(canGoBack: !router.path(for: tab).isEmpty) {
                var path = router.path(for: tab)
                guard !path.isEmpty else { return }
                path.removeLast()
                router.setPath(path, for: tab)
            }
        }
    }

    @ViewBuilder
    private func tabRoot(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            TimelineHomeView()
        case .history:
            HistoryView(showsBackButton: false)
        case .settings:
            SettingsView(showsBackButton: false)
        }
    }

    @ViewBuilder
    // swiftlint:disable:next cyclomatic_complexity
    private func destination(for route: AppRoute, in tab: AppTab) -> some View {
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
        case .settingsSunscreen:
            SettingsView(detail: .sunscreen)
        case .settingsHealth:
            SettingsView(detail: .health)
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
            let today = appState.startOfLocalDay(appState.referenceDate)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
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
            ManualLogRouteView(payload: router.payload(for: tab))
                .id(router.payload(for: tab))
        case .achievements:
            WeeklyReportView()
        case .friends:
            SettingsView()
        case .accountabilityOnboarding:
            SettingsView()
        case .skinHealthReport:
            HistoryView()
        case .productScanner:
            ManualLogRouteView(payload: router.payload(for: tab))
                .id(router.payload(for: tab))
        case .yearInReview:
            HistoryView()
        case .valueProps:
            WelcomeView()
        }
    }

}

/// Resolve external context once, before displaying the fixed-date editor.
private struct ManualLogRouteView: View {
    @Environment(AppState.self) private var appState
    let payload: AppRoutePayload
    @State private var context: AppLogContext?

    var body: some View {
        Group {
            if let context {
                ManualLogView(context: context)
            } else {
                ProgressView()
                    .task {
                        let pending = appState.pendingManualLogContext
                        _ = appState.consumeManualLogRouteContext()
                        let date = payload.targetDate ?? pending?.date ?? appState.referenceDate
                        context = appState.currentLogContext(
                            for: date,
                            source: pending?.source ?? .manualLog,
                            dayPart: payload.targetDayPart ?? pending?.dayPart
                        )
                    }
            }
        }
    }
}

// Native tab item IDs are installed by title because UIKit owns the accessible tab controls.
private struct SunNativeTabAccessibilityIdentifierInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InstallerViewController {
        InstallerViewController()
    }

    func updateUIViewController(_ uiViewController: InstallerViewController, context: Context) {
        uiViewController.installIdentifiers()
    }

    final class InstallerViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installIdentifiers()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            installIdentifiers()
        }

        func installIdentifiers() {
            guard let window = view.window else { return }
            let identifiers = Dictionary(
                uniqueKeysWithValues: AppTab.allCases.map { ($0.title, $0.accessibilityIdentifier) }
            )
            installIdentifiers(in: window, identifiers: identifiers)
        }

        private func installIdentifiers(in view: UIView, identifiers: [String: String]) {
            if let tabBar = view as? UITabBar {
                for item in tabBar.items ?? [] {
                    if let title = item.title, let identifier = identifiers[title] {
                        item.accessibilityIdentifier = identifier
                    }
                }
            }
            for subview in view.subviews {
                installIdentifiers(in: subview, identifiers: identifiers)
            }
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
