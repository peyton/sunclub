import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif
#if os(watchOS)
import Observation
#endif

enum SunclubWatchSyncPayload {
    static let commandKey = "command"
    static let snapshotKey = "snapshot"
    static let successKey = "success"
    static let messageKey = "message"
    static let requestSnapshotCommand = "requestSnapshot"
    static let logTodayCommand = "logToday"

    static func context(snapshot: SunclubWidgetSnapshot, message: String? = nil) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return nil
        }

        var context: [String: Any] = [
            snapshotKey: data,
            successKey: true
        ]
        if let message {
            context[messageKey] = message
        }
        return context
    }

    static func successReply(
        snapshot: SunclubWidgetSnapshot,
        message: String
    ) -> [String: Any] {
        context(snapshot: snapshot, message: message) ?? [
            successKey: true,
            messageKey: message
        ]
    }

    static func errorReply(_ message: String) -> [String: Any] {
        [
            successKey: false,
            messageKey: message
        ]
    }

    static func decodeSnapshot(from payload: [String: Any]) -> SunclubWidgetSnapshot? {
        guard let data = payload[snapshotKey] as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(SunclubWidgetSnapshot.self, from: data)
    }
}

#if os(iOS) && canImport(WatchConnectivity)
@MainActor
final class SunclubWatchSyncCoordinator: NSObject {
    static let shared = SunclubWatchSyncCoordinator()

    private let session: WCSession?
    private var logTodayHandler: (() throws -> SunclubWidgetSnapshot)?

    private override init() {
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }
        super.init()
    }

    func activate() {
        guard let session else {
            return
        }

        session.delegate = self
        if session.activationState == .activated {
            pushCurrentSnapshot()
        } else {
            session.activate()
        }
    }

    func setLogTodayHandler(_ handler: @escaping () throws -> SunclubWidgetSnapshot) {
        logTodayHandler = handler
    }

    func push(snapshot: SunclubWidgetSnapshot) {
        guard let session,
              session.isPaired,
              session.isWatchAppInstalled,
              let context = SunclubWatchSyncPayload.context(snapshot: snapshot) else {
            return
        }

        do {
            try session.updateApplicationContext(context)
        } catch {
            return
        }

        session.transferCurrentComplicationUserInfo(context)

        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    private func pushCurrentSnapshot() {
        push(snapshot: SunclubWidgetSnapshotStore().load())
    }

    private func handleMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        guard let command = message[SunclubWatchSyncPayload.commandKey] as? String else {
            replyHandler?(SunclubWatchSyncPayload.errorReply("Unknown watch request."))
            return
        }

        switch command {
        case SunclubWatchSyncPayload.requestSnapshotCommand:
            let snapshot = SunclubWidgetSnapshotStore().load()
            replyHandler?(SunclubWatchSyncPayload.successReply(snapshot: snapshot, message: "Snapshot refreshed."))
        case SunclubWatchSyncPayload.logTodayCommand:
            Task { @MainActor in
                do {
                    let snapshot = try logTodaySnapshot()
                    push(snapshot: snapshot)
                    replyHandler?(SunclubWatchSyncPayload.successReply(snapshot: snapshot, message: "Logged from your wrist."))
                } catch let error as LocalizedError {
                    replyHandler?(SunclubWatchSyncPayload.errorReply(error.errorDescription ?? "Sunclub could not log sunscreen right now."))
                } catch {
                    replyHandler?(SunclubWatchSyncPayload.errorReply("Sunclub could not log sunscreen right now."))
                }
            }
        default:
            replyHandler?(SunclubWatchSyncPayload.errorReply("Unknown watch request."))
        }
    }

    private func logTodaySnapshot() throws -> SunclubWidgetSnapshot {
        if let logTodayHandler {
            return try logTodayHandler()
        }

        _ = try SunclubQuickLogAction.performStandalone()
        return SunclubWidgetSnapshotStore().load()
    }
}

extension SunclubWatchSyncCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else {
            return
        }

        Task { @MainActor in
            pushCurrentSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            handleMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            handleMessage(message, replyHandler: replyHandler)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            handleMessage(userInfo)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else {
            return
        }

        Task { @MainActor in
            pushCurrentSnapshot()
        }
    }
}
#elseif os(watchOS) && canImport(WatchConnectivity)
@MainActor
@Observable
final class SunclubWatchSyncCoordinator: NSObject {
    static let shared = SunclubWatchSyncCoordinator()

    private let snapshotStore = SunclubWidgetSnapshotStore()
    private let session: WCSession?
    #if canImport(UserNotifications)
    private let notificationCenter = UNUserNotificationCenter.current()
    #endif

    private(set) var snapshot: SunclubWidgetSnapshot
    private(set) var syncStatus: String?

    private override init() {
        let initialSnapshot = SunclubWidgetSnapshotStore().load()
        snapshot = initialSnapshot
        if WCSession.isSupported() {
            session = WCSession.default
        } else {
            session = nil
        }
        syncStatus = initialSnapshot.isOnboardingComplete ? nil : "Open Sunclub on iPhone to finish setup."
        super.init()
        activate()
        requestNotificationAuthorizationIfNeeded()
    }

    func activate() {
        guard let session else {
            return
        }

        session.delegate = self
        session.activate()
    }

    func refreshSnapshot() {
        guard let session else {
            syncStatus = "Watch sync is unavailable."
            return
        }

        guard session.activationState == .activated else {
            session.activate()
            _ = applyReceivedApplicationContextIfAvailable()
            return
        }

        guard session.isReachable else {
            if !applyReceivedApplicationContextIfAvailable() {
                syncStatus = snapshot.isOnboardingComplete
                    ? "Open Sunclub on iPhone to sync live status."
                    : "Open Sunclub on iPhone to finish setup."
            }
            return
        }

        session.sendMessage(
            [SunclubWatchSyncPayload.commandKey: SunclubWatchSyncPayload.requestSnapshotCommand],
            replyHandler: { [weak self] reply in
                Task { @MainActor in
                    self?.consume(payload: reply, fallbackMessage: "Snapshot refreshed.")
                }
            },
            errorHandler: nil
        )
    }

    func logToday() async -> String {
        guard let session else {
            syncStatus = "Watch sync is unavailable."
            return syncStatus ?? "Watch sync is unavailable."
        }

        guard session.activationState == .activated else {
            session.activate()
            syncStatus = "Open Sunclub on iPhone to finish syncing."
            return syncStatus ?? "Open Sunclub on iPhone to finish syncing."
        }

        if session.activationState == .activated, session.isReachable {
            return await withCheckedContinuation { continuation in
                session.sendMessage(
                    [SunclubWatchSyncPayload.commandKey: SunclubWatchSyncPayload.logTodayCommand],
                    replyHandler: { [weak self] reply in
                        Task { @MainActor in
                            let message = self?.consume(payload: reply, fallbackMessage: "Logged from your wrist.")
                                ?? "Logged from your wrist."
                            continuation.resume(returning: message)
                        }
                    },
                    errorHandler: { [weak self] _ in
                        Task { @MainActor in
                            let message = self?.queueLogToday(on: session) ?? "Queued for your iPhone."
                            continuation.resume(returning: message)
                        }
                    }
                )
            }
        }

        return queueLogToday(on: session)
    }

    private func consume(
        payload: [String: Any],
        fallbackMessage: String
    ) -> String {
        if let snapshot = SunclubWatchSyncPayload.decodeSnapshot(from: payload) {
            apply(snapshot: snapshot)
        }

        let message = (payload[SunclubWatchSyncPayload.messageKey] as? String) ?? fallbackMessage
        syncStatus = message
        return message
    }

    private func applyReceivedApplicationContextIfAvailable() -> Bool {
        guard let session,
              !session.receivedApplicationContext.isEmpty else {
            return false
        }

        _ = consume(payload: session.receivedApplicationContext, fallbackMessage: "Status updated.")
        return true
    }

    private func apply(snapshot: SunclubWidgetSnapshot) {
        snapshotStore.save(snapshot)
        self.snapshot = snapshot
        scheduleReapplyNotification(for: snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func requestNotificationAuthorizationIfNeeded() {
        #if canImport(UserNotifications)
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        #endif
    }

    private func queueLogToday(on session: WCSession) -> String {
        session.transferUserInfo([
            SunclubWatchSyncPayload.commandKey: SunclubWatchSyncPayload.logTodayCommand
        ])
        syncStatus = "Queued for your iPhone."
        return syncStatus ?? "Queued for your iPhone."
    }

    private func scheduleReapplyNotification(for snapshot: SunclubWidgetSnapshot) {
        #if canImport(UserNotifications)
        let identifier = "sunclub.watch.reapply"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let fireDate = snapshot.reapplyDeadline(),
              fireDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Time to reapply"
        content.body = "Your Sunclub reapply timer is up."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        notificationCenter.add(request)
        #endif
    }
}

extension SunclubWatchSyncCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else {
            return
        }

        Task { @MainActor in
            _ = applyReceivedApplicationContextIfAvailable()
            refreshSnapshot()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else {
            return
        }

        Task { @MainActor in
            refreshSnapshot()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            _ = consume(payload: applicationContext, fallbackMessage: "Status updated.")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            _ = consume(payload: userInfo, fallbackMessage: "Status updated.")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            _ = consume(payload: message, fallbackMessage: "Status updated.")
        }
    }
}
#endif
