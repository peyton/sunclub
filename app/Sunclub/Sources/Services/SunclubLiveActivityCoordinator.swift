import ActivityKit
import Foundation

@MainActor
protocol SunclubLiveActivityCoordinating: AnyObject {
    func sync(using state: AppState) async
    func endAll() async
}

@MainActor
final class SunclubLiveActivityCoordinator: SunclubLiveActivityCoordinating {
    static let shared = SunclubLiveActivityCoordinator()

    func sync(using state: AppState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        guard let record = state.record(for: state.currentDateValue),
              let currentUVIndex = state.uvReading?.index,
              let peakUVIndex = state.uvForecast?.peakHour?.index else {
            await endAll()
            return
        }

        let level = state.uvReading?.level ?? .unknown
        guard level == .high || level == .veryHigh || level == .extreme else {
            await endAll()
            return
        }

        let countdownLabel: String
        if let deadline = state.reapplyReminderPlan.fireDate ?? state.uvForecast?.peakHour?.date {
            countdownLabel = deadline.formatted(date: .omitted, time: .shortened)
        } else {
            countdownLabel = "Later today"
        }

        let lastAppliedLabel = record.verifiedAt.formatted(date: .omitted, time: .shortened)
        let contentState = SunclubLiveActivityAttributes.ContentState(
            currentUVIndex: currentUVIndex,
            peakUVIndex: peakUVIndex,
            countdownLabel: countdownLabel,
            lastAppliedLabel: lastAppliedLabel,
            streakLabel: "\(state.currentStreak)d streak"
        )

        let attributes = SunclubLiveActivityAttributes(headline: "Sunclub UV Guard")
        let content = ActivityContent(state: contentState, staleDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date()))

        if let existing = Activity<SunclubLiveActivityAttributes>.activities.first {
            await existing.update(content)
        } else {
            do {
                _ = try Activity<SunclubLiveActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                return
            }
        }
    }

    func endAll() async {
        for activity in Activity<SunclubLiveActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .default)
        }
    }
}

private extension AppState {
    var currentDateValue: Date {
        Date()
    }
}
