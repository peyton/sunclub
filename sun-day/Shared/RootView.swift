import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            Group {
                if appState.settings.hasCompletedOnboarding {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
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
        .tint(AppPalette.coral)
    }
}
