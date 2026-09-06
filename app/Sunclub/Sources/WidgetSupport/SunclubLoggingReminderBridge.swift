import Foundation
import UserNotifications

/// Resets the existing reminder after an app-owned background logging action.
@MainActor
enum SunclubLoggingReminderBridge {
    static func sync(snapshot: SunclubWidgetSnapshot, now: Date) async {
        guard !RuntimeEnvironment.isRunningTests else { return }
        let center = UNUserNotificationCenter.current()
        await sync(
            snapshot: snapshot, now: now,
            loadSnapshot: { SunclubWidgetSnapshotStore().load() },
            pendingRequests: { await center.pendingNotificationRequests() },
            removeRequests: { center.removePendingNotificationRequests(withIdentifiers: $0) },
            addRequest: { try await center.add($0) }
        )
    }

    static func sync(
        snapshot: SunclubWidgetSnapshot,
        now: Date,
        loadSnapshot: () -> SunclubWidgetSnapshot,
        pendingRequests: () async -> [UNNotificationRequest],
        removeRequests: ([String]) -> Void,
        addRequest: (UNNotificationRequest) async throws -> Void
    ) async {
        let pending = await pendingRequests()
        // A newer application or setting change owns the reminder after suspension.
        guard loadSnapshot() == snapshot else { return }
        let replacedIDs = pending.filter { $0.identifier.hasPrefix("sunscreen.reapply.") }.map(\.identifier)
        removeRequests(replacedIDs)
        guard let request = request(snapshot: snapshot, now: now),
              pending.count - replacedIDs.count < 64 else { return }
        // Logging remains successful if the system declines an optional reminder.
        try? await addRequest(request)
        if loadSnapshot() != snapshot {
            // The per-request suffix prevents cleanup from deleting a newer reminder.
            removeRequests([request.identifier])
        }
    }

    static func request(snapshot: SunclubWidgetSnapshot, now: Date) -> UNNotificationRequest? {
        guard snapshot.reapplyReminderEnabled,
              snapshot.hasLoggedToday(now: now),
              let lastApplied = snapshot.lastApplicationDate(now: now),
              lastApplied <= now,
              Calendar.current.isDate(lastApplied, inSameDayAs: now),
              let deadline = ReminderPlanner.reapplyFireDate(
                from: lastApplied, intervalMinutes: snapshot.reapplyIntervalMinutes
              ), deadline > now else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "Time to check your sunscreen"
        content.body = "Follow your sunscreen label, and reapply after swimming, sweating, or toweling off."
        content.categoryIdentifier = "SUNSCREEN_REAPPLY"
        content.userInfo = ["targetRoute": "reapply", "type": "reapply"]
        content.sound = .default
        return UNNotificationRequest(
            identifier: "sunscreen.reapply.\(lastApplied.timeIntervalSince1970).\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSince(now)), repeats: false)
        )
    }
}
