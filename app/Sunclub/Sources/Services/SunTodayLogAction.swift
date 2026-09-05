import Foundation

/// The Today button resolves its date and defaults at the moment of the tap.
@MainActor
enum SunTodayLogAction {
    static func perform(in state: AppState) -> SunclubHistoryMutationResult {
        let now = state.referenceDate
        if state.record(for: now) != nil {
            return state.recordReapplication(for: now, performedAt: now)
        }
        let defaults = state.oneTapLogInput(for: now)
        let result = state.recordApplication(
            for: .quickLog, part: state.dayPart(for: now), on: now,
            source: .quickLog, verifiedAt: now, spfLevel: defaults.spfLevel, notes: defaults.oneTapNotes
        )
        if case let .success(receipt) = result, receipt.didChange, state.settings.reapplyReminderEnabled {
            state.scheduleReapplyReminder()
        }
        return result
    }
}
