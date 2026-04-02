import SwiftData
import SwiftUI

enum PreviewScenario {
    case onboarding
    case home
    case verificationSuccess
}

@MainActor
struct SunclubPreviewHost<Content: View>: View {
    @State private var appState: AppState
    @State private var router: AppRouter

    private let container: ModelContainer
    private let content: Content

    init(
        scenario: PreviewScenario = .home,
        @ViewBuilder content: () -> Content
    ) {
        let container = Self.makeContainer()
        NotificationManager.shared.configure(modelContainer: container)

        let appState = AppState(context: ModelContext(container), notificationManager: NotificationManager.shared)
        Self.seed(appState, for: scenario)

        _appState = State(initialValue: appState)
        _router = State(initialValue: AppRouter())
        self.container = container
        self.content = content()
    }

    var body: some View {
        content
            .environment(appState)
            .environment(router)
            .modelContainer(container)
    }

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            DailyRecord.self,
            Settings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            fatalError("Failed to create preview ModelContainer")
        }

        return container
    }

    private static func seed(_ appState: AppState, for scenario: PreviewScenario) {
        switch scenario {
        case .onboarding:
            break
        case .home:
            seedHome(into: appState)
        case .verificationSuccess:
            seedHome(into: appState)
            appState.verificationSuccessPresentation = VerificationSuccessPresentation(streak: appState.currentStreak)
        }
    }

    private static func seedHome(into appState: AppState) {
        appState.completeOnboarding()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let successfulOffsets = [0, 1, 2, 4, 5]

        for offset in successfulOffsets {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let verifiedAt = calendar.date(byAdding: .hour, value: 9, to: day) else {
                continue
            }

            let record = DailyRecord(
                startOfDay: day,
                verifiedAt: verifiedAt,
                method: .manual
            )
            appState.modelContext.insert(record)
        }

        appState.refresh()
        appState.save()
    }
}
