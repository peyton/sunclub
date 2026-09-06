import Foundation
import UserNotifications

/// Resets the existing reminder after an app-owned background logging action.
@MainActor
enum SunclubLoggingReminderBridge {
    static func syncAfterMutation(didChange: Bool, mayStartLiveActivity: Bool = false) async {
        guard didChange else { return }
        let now = Date()
        await sync(snapshot: SunclubWidgetSnapshotStore().load(), now: now)
        await SunclubDepartureReminderBridge.sync(snapshot: SunclubWidgetSnapshotStore().load(), now: now)
        await SunclubLiveActivitySnapshotBridge.updateExisting(
            snapshot: SunclubWidgetSnapshotStore().load(), now: Date(), mayStart: mayStartLiveActivity
        )
    }

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
        snapshot _: SunclubWidgetSnapshot,
        now: Date,
        loadSnapshot: () -> SunclubWidgetSnapshot,
        pendingRequests: () async -> [UNNotificationRequest],
        removeRequests: ([String]) -> Void,
        addRequest: (UNNotificationRequest) async throws -> Void
    ) async {
        let pending = await pendingRequests()
        // The shared store is authoritative after suspension. UV and other presentation
        // refreshes must not discard reminder work for the same committed application.
        let snapshot = loadSnapshot()
        let replacedIDs = pending.filter { $0.identifier.hasPrefix("sunscreen.reapply.") }.map(\.identifier)
        if snapshot.hasLoggedToday(now: now) {
            let todayIDs = pending.filter { request in
                guard request.identifier.hasPrefix("sunscreen.daily."),
                      let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      !trigger.repeats,
                      let date = Calendar.current.date(from: trigger.dateComponents) else { return false }
                return Calendar.current.isDate(date, inSameDayAs: now)
            }.map(\.identifier)
            let departureIDs = pending.filter { $0.identifier.hasPrefix(SunclubDepartureReminderBridge.prefix) }.map(\.identifier)
            removeRequests(todayIDs + departureIDs)
        }
        guard let request = request(snapshot: snapshot, now: now) else {
            removeRequests(replacedIDs)
            return
        }
        guard pending.contains(where: { $0.identifier == request.identifier }) || pending.count < 64 else { return }
        // Adding the replacement first keeps an accepted reminder intact on failure.
        do {
            if !pending.contains(where: { $0.identifier == request.identifier }) {
                try await addRequest(request)
            }
        } catch { return }
        let current = loadSnapshot()
        // Snooze state can change independently of the persisted widget snapshot.
        if Self.request(snapshot: current, now: now)?.identifier != request.identifier {
            removeRequests([request.identifier])
            return
        }
        removeRequests(replacedIDs.filter { $0 != request.identifier })
    }

    static func request(snapshot: SunclubWidgetSnapshot, now: Date) -> UNNotificationRequest? {
        guard snapshot.reapplyReminderEnabled,
              snapshot.hasLoggedToday(now: now),
              let lastApplied = snapshot.lastApplicationDate(now: now),
              lastApplied <= now,
              Calendar.current.isDate(lastApplied, inSameDayAs: now),
              let baseline = ReminderPlanner.reapplyFireDate(
                from: lastApplied, intervalMinutes: snapshot.reapplyIntervalMinutes
              ) else { return nil }
        let deadline = SunclubLiveActivitySessionStore.deadline(
            applicationDate: lastApplied, baseline: baseline, now: now
        )
        guard deadline > now, Calendar.current.isDate(deadline, inSameDayAs: now) else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "Time to check your sunscreen"
        content.body = "Follow your sunscreen label, and reapply after swimming, sweating, or toweling off."
        content.categoryIdentifier = "SUNSCREEN_REAPPLY"
        content.userInfo = ["targetRoute": "reapply", "type": "reapply", "applicationDate": lastApplied.timeIntervalSince1970]
        content.sound = .default
        return UNNotificationRequest(
            identifier: "sunscreen.reapply.\(lastApplied.timeIntervalSince1970).\(deadline.timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSince(now)), repeats: false)
        )
    }
}
