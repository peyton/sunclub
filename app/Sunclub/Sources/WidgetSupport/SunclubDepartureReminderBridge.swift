import Foundation
import UserNotifications

/// Extension-safe reconciliation after a committed check-in action.
@MainActor
enum SunclubDepartureReminderBridge {
    static let prefix = "sunscreen.leave-home."
    static let category = "SUNSCREEN_DEPARTURE_CHECK_IN"
    private static var operation: Task<Void, Never>?

    static func request(id: UUID, fireDate: Date, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Did you apply sunscreen?"
        content.body = "Already applied? Choose when, and Sunclub will keep track from there."
        content.categoryIdentifier = category
        content.sound = .default
        content.userInfo = ["targetRoute": "departure-check-in", "type": "leaveHome", "checkInID": id.uuidString]
        return UNNotificationRequest(identifier: prefix + id.uuidString, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: max(fireDate, now.addingTimeInterval(1))), repeats: false))
    }

    static func sync(snapshot _: SunclubWidgetSnapshot, now: Date) async {
        guard !RuntimeEnvironment.isRunningTests else { return }
        let previous = operation
        let task = Task { @MainActor in
            await previous?.value
            let center = UNUserNotificationCenter.current()
            await reconcile(
                now: now,
                loadSnapshot: { SunclubWidgetSnapshotStore().load() },
                pendingRequests: { await center.pendingNotificationRequests() },
                addRequest: { try await center.add($0) },
                removeRequests: { center.removePendingNotificationRequests(withIdentifiers: $0) }
            )
        }
        operation = task
        await task.value
    }

    /// Reads the shared store after each suspension. Only reminder state matters:
    /// a concurrent UV/widget refresh must not invalidate a successfully added snooze.
    static func reconcile(
        now: Date,
        loadSnapshot: @MainActor () -> SunclubWidgetSnapshot,
        pendingRequests: @MainActor () async -> [UNNotificationRequest],
        addRequest: @MainActor (UNNotificationRequest) async throws -> Void,
        removeRequests: @MainActor ([String]) -> Void
    ) async {
        for _ in 0..<4 {
            let pending = await pendingRequests().filter { $0.identifier.hasPrefix(prefix) }
            let desired = desiredReminder(snapshot: loadSnapshot(), now: now)
            switch desired {
            case .none:
                removeRequests(pending.map(\.identifier))
                return
            case let .initial(id):
                // The monitor owns first delivery. Never replay it on foreground refresh.
                removeRequests(pending.filter { $0.identifier != prefix + id.uuidString }.map(\.identifier))
                return
            case let .snooze(id, deadline):
                let request = request(id: id, fireDate: deadline, now: now)
                let existing = pending.first { $0.identifier == request.identifier }
                let existingTrigger = existing?.trigger as? UNCalendarNotificationTrigger
                let desiredTrigger = request.trigger as? UNCalendarNotificationTrigger
                if existingTrigger?.dateComponents == desiredTrigger?.dateComponents,
                   existing?.content.categoryIdentifier == category {
                    removeRequests(pending.filter { $0.identifier != request.identifier }.map(\.identifier))
                    return
                }
                do {
                    try await addRequest(request)
                } catch {
                    // A newer resolution still needs cancellation even when this add failed.
                    if desiredReminder(snapshot: loadSnapshot(), now: now) != desired { continue }
                    return
                }
                guard desiredReminder(snapshot: loadSnapshot(), now: now) == desired else {
                    // A newer add may use the same identifier. Reconcile the latest desired
                    // deadline instead of deleting that identifier from a stale completion.
                    continue
                }
                removeRequests(pending.filter { $0.identifier != request.identifier }.map(\.identifier))
                return
            }
        }
        // Bound work if another process is continuously changing the state. Later
        // committed actions and foreground reconciliation make another pass.
    }

    private enum DesiredReminder: Equatable {
        case none
        case initial(UUID)
        case snooze(UUID, Date)
    }

    private static func desiredReminder(snapshot: SunclubWidgetSnapshot, now: Date) -> DesiredReminder {
        guard !snapshot.hasLoggedToday(now: now),
              let id = snapshot.pendingDepartureCheckInID,
              let departure = snapshot.pendingDepartureDate,
              Calendar.current.isDate(departure, inSameDayAs: now) else { return .none }
        guard let deadline = snapshot.pendingDepartureSnoozedUntil else { return .initial(id) }
        guard Calendar.current.isDate(deadline, inSameDayAs: now) else { return .none }
        return deadline > now ? .snooze(id, deadline) : .initial(id)
    }
}
