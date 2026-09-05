import Foundation
import UserNotifications

@MainActor
enum OnboardingNotificationManagerFactory {
    static func make() -> NotificationManager {
        #if DEBUG
        if RuntimeEnvironment.isUITesting {
            let mode = OnboardingTestNotificationCenter.Mode(
                rawValue: RuntimeEnvironment.argumentValue(withPrefix: "UITEST_ONBOARDING_NOTIFICATIONS=") ?? "success"
            ) ?? .success
            return NotificationManager(center: OnboardingTestNotificationCenter(mode: mode))
        }
        #endif
        return .shared
    }
}

#if DEBUG
@MainActor
private final class OnboardingTestNotificationCenter: UserNotificationCenterClient {
    enum Mode: String {
        case success
        case failOnce = "fail-once"
        case failAlways = "fail-always"
    }

    private enum SchedulingError: Error {
        case rejected
    }

    private let mode: Mode
    private var hasRejectedRequest = false
    private var authorization: NotificationAuthorizationState = .notDetermined
    private var pendingRequests: [UNNotificationRequest] = []

    init(mode: Mode) {
        self.mode = mode
    }

    func configure(
        categories: Set<UNNotificationCategory>,
        delegate: any UNUserNotificationCenterDelegate
    ) {}

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if mode != .success {
            // Suspend across the persisted-completion update to expose presentation loss.
            try await Task.sleep(for: .milliseconds(300))
        }
        authorization = .authorized
        return true
    }

    func authorizationState() async -> NotificationAuthorizationState {
        authorization
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pendingRequests
    }

    func add(_ request: UNNotificationRequest) async throws {
        if mode == .failAlways || (mode == .failOnce && !hasRejectedRequest) {
            hasRejectedRequest = true
            throw SchedulingError.rejected
        }
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        let identifierSet = Set(identifiers)
        pendingRequests.removeAll { identifierSet.contains($0.identifier) }
    }
}
#endif
