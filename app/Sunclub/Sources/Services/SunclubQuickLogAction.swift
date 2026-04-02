import Foundation
import SwiftData

struct SunclubQuickLogResult: Equatable {
    let streak: Int
}

enum SunclubQuickLogError: LocalizedError {
    case onboardingRequired
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .onboardingRequired:
            return "Open Sunclub once to finish setup before using outside-app logging."
        case let .unavailable(message):
            return message
        }
    }
}

@MainActor
enum SunclubQuickLogAction {
    static func perform(using appState: AppState) -> SunclubQuickLogResult {
        appState.recordVerificationSuccess(method: .manual)

        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }

        return SunclubQuickLogResult(streak: appState.currentStreak)
    }

    static func performStandalone() throws -> SunclubQuickLogResult {
        do {
            let container = try SunclubModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: false)
            NotificationManager.shared.configure(modelContainer: container)

            let appState = AppState(
                context: ModelContext(container),
                notificationManager: NotificationManager.shared
            )

            guard appState.settings.hasCompletedOnboarding else {
                throw SunclubQuickLogError.onboardingRequired
            }

            return perform(using: appState)
        } catch let error as SunclubQuickLogError {
            throw error
        } catch {
            throw SunclubQuickLogError.unavailable(error.localizedDescription)
        }
    }
}
