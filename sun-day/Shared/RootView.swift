import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        Group {
            if appState.settings.hasCompletedOnboarding {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .home:
                                HomeView()
                            case .barcodeScan:
                                BarcodeScanView(onboardingMode: false)
                            case .selfie:
                                SelfieCaptureView()
                            case .videoVerify:
                                LiveVerifyView()
                            case .training:
                                TrainingView()
                            case .calendar:
                                CalendarGridView()
                            case .weeklyReport:
                                WeeklyReportView()
                            }
                        }
                }
            } else {
                OnboardingView()
            }
        }
        .tint(AppPalette.coral)
    }
}
