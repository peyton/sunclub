import Foundation

struct SunclubWeatherKitBudgetPolicy: Codable, Equatable, Sendable {
    var weatherKitEnabled: Bool
    var minFetchIntervalSeconds: TimeInterval
    var maxDailyFetchesPerDevice: Int
    var maxMonthlyFetchesPerDevice: Int
    var reason: String

    static let builtInDefault = SunclubWeatherKitBudgetPolicy(
        weatherKitEnabled: true,
        minFetchIntervalSeconds: 30 * 60,
        maxDailyFetchesPerDevice: 48,
        maxMonthlyFetchesPerDevice: 900,
        reason: ""
    )
}

enum SunclubWeatherKitBudgetDecision: Equatable {
    case allow
    case deny(reason: String)
}

/// Per-device rate limiter and kill-switch enforcer.
/// Backed by the shared App Group UserDefaults so widgets/Watch
/// read the same counters. Never hands out permission to fetch
/// without a live policy — if the policy can't be loaded, built-in
/// defaults enforce a conservative cap.
final class SunclubWeatherKitBudget: @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let calendar = Calendar(identifier: .gregorian)
    private let policyKey: String
    private let counterKey: String

    init(
        appGroupID: String = SunclubRuntimeConfiguration.appGroupID,
        policyKey: String = "sunclub.weatherKit.policy.v1",
        counterKey: String = "sunclub.weatherKit.counter.v1"
    ) {
        self.defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        self.policyKey = policyKey
        self.counterKey = counterKey
    }

    var currentPolicy: SunclubWeatherKitBudgetPolicy {
        lock.lock()
        defer { lock.unlock() }
        return loadPolicy() ?? .builtInDefault
    }

    func storePolicy(_ policy: SunclubWeatherKitBudgetPolicy) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(policy) else { return }
        defaults.set(data, forKey: policyKey)
    }

    /// Call BEFORE a WeatherKit fetch. Returns `.allow` with the caller
    /// expected to immediately record the fetch via `recordFetch(at:)`
    /// on success, or `.deny` with a user-surfaceable reason.
    func check(now: Date = Date()) -> SunclubWeatherKitBudgetDecision {
        lock.lock()
        defer { lock.unlock() }
        let policy = loadPolicy() ?? .builtInDefault
        let counter = loadCounter()

        guard policy.weatherKitEnabled else {
            let reason = policy.reason.isEmpty
                ? "Apple Weather temporarily paused by Sunclub."
                : policy.reason
            return .deny(reason: reason)
        }

        if let lastFetch = counter.lastFetchAt,
           now.timeIntervalSince(lastFetch) < policy.minFetchIntervalSeconds {
            let remaining = Int(policy.minFetchIntervalSeconds - now.timeIntervalSince(lastFetch))
            return .deny(reason: "Rate-limited: retry in \(max(remaining, 1)) s.")
        }

        if counter.fetchesToday(now: now, calendar: calendar) >= policy.maxDailyFetchesPerDevice {
            return .deny(reason: "Daily Apple Weather cap reached (\(policy.maxDailyFetchesPerDevice)).")
        }

        if counter.fetchesThisMonth(now: now, calendar: calendar) >= policy.maxMonthlyFetchesPerDevice {
            return .deny(reason: "Monthly Apple Weather cap reached (\(policy.maxMonthlyFetchesPerDevice)).")
        }

        return .allow
    }

    func recordFetch(at now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        var counter = loadCounter()
        counter.append(now, calendar: calendar)
        saveCounter(counter)
    }

    func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: policyKey)
        defaults.removeObject(forKey: counterKey)
    }

    private func loadPolicy() -> SunclubWeatherKitBudgetPolicy? {
        guard let data = defaults.data(forKey: policyKey) else { return nil }
        return try? JSONDecoder().decode(SunclubWeatherKitBudgetPolicy.self, from: data)
    }

    private func loadCounter() -> Counter {
        guard let data = defaults.data(forKey: counterKey) else {
            return Counter(fetches: [], lastFetchAt: nil)
        }
        return (try? JSONDecoder().decode(Counter.self, from: data)) ?? Counter(fetches: [], lastFetchAt: nil)
    }

    private func saveCounter(_ counter: Counter) {
        guard let data = try? JSONEncoder().encode(counter) else { return }
        defaults.set(data, forKey: counterKey)
    }

    private struct Counter: Codable {
        var fetches: [Date]
        var lastFetchAt: Date?

        mutating func append(_ date: Date, calendar: Calendar) {
            fetches.append(date)
            lastFetchAt = date
            if let cutoff = calendar.date(byAdding: .day, value: -35, to: date) {
                fetches.removeAll { $0 < cutoff }
            }
        }

        func fetchesToday(now: Date, calendar: Calendar) -> Int {
            let start = calendar.startOfDay(for: now)
            return fetches.filter { $0 >= start }.count
        }

        func fetchesThisMonth(now: Date, calendar: Calendar) -> Int {
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let start = calendar.date(from: components) else {
                return fetches.count
            }
            return fetches.filter { $0 >= start }.count
        }
    }
}
