import Combine
import Foundation
import Observation
import OSLog
import UIKit

/// Keeps the app and its side effects unavailable until the existing store opens.
@MainActor
@Observable
final class SunclubStartup<Value> {
    private(set) var value: Value?
    private(set) var isWaitingForProtectedData = false
    private(set) var failureDescription: String?
    private let isProtectedDataAvailable: () -> Bool
    @ObservationIgnored private var protectedDataSubscription: AnyCancellable?
    private let load: () throws -> Value

    init(
        isProtectedDataAvailable: @escaping () -> Bool,
        load: @escaping () throws -> Value
    ) {
        self.isProtectedDataAvailable = isProtectedDataAvailable
        self.load = load
    }

    func observeProtectedDataAvailability(notificationCenter: NotificationCenter = .default) {
        protectedDataSubscription = notificationCenter.publisher(
            for: UIApplication.protectedDataDidBecomeAvailableNotification
        ).sink { [weak self] _ in
            Task { @MainActor in self?.retry() }
        }
    }

    func retryUntilReady(
        wait: (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async {
        var delaySeconds = 1
        while value == nil, !Task.isCancelled {
            retry()
            guard value == nil else { return }
            do {
                try await wait(.seconds(delaySeconds))
            } catch {
                return
            }
            delaySeconds = min(delaySeconds * 2, 30)
        }
    }

    func retry() {
        guard value == nil else { return }
        isWaitingForProtectedData = false
        do {
            value = try load()
            failureDescription = nil
        } catch {
            isWaitingForProtectedData = !isProtectedDataAvailable()
            failureDescription = String(reflecting: error)
            let logger = Logger(subsystem: "com.peyton.sunclub", category: "Startup")
            logger.error("Failed to open existing store: \(String(reflecting: error), privacy: .private)")
        }
    }
}
