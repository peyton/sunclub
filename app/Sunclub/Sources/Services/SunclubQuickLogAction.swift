import Foundation

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
    static func performStandalone() throws -> SunclubQuickLogResult {
        do {
            let result = try SunclubAutomationRuntime.performStandalone(
                .logToday(spfLevel: nil, notes: nil),
                invocation: .widget
            )
            return SunclubQuickLogResult(streak: result.currentStreak ?? 0)
        } catch SunclubAutomationError.onboardingRequired {
            throw SunclubQuickLogError.onboardingRequired
        } catch let error as SunclubQuickLogError {
            throw error
        } catch {
            throw SunclubQuickLogError.unavailable(error.localizedDescription)
        }
    }
}
