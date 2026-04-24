import Foundation
import os

/// Fetches a remote policy JSON at most once per day and hands it to
/// `SunclubWeatherKitBudget`. The policy ships at a public URL you
/// control (see `web/config/weatherkit.json` for the default schema).
///
/// Rationale:
/// - Apple's WeatherKit dashboard does not expose a developer-side
///   API to remotely throttle calls. A self-hosted policy file lets
///   you flip a kill switch or tighten caps without releasing a new
///   build.
/// - The fetch itself is cheap (tiny JSON, cached 24 h) and completely
///   skipped if the last update is still fresh.
@MainActor
final class SunclubWeatherKitKillSwitch {
    static let configURLKey = "SunclubWeatherKitConfigURL"
    static let defaultConfigURL = URL(
        string: "https://sunclub.peyton.app/config/weatherkit.json"
    )!

    private let budget: SunclubWeatherKitBudget
    private let configURL: URL
    private let session: URLSession
    private let minRefreshInterval: TimeInterval
    private let storage: UserDefaults
    private let storageKey = "sunclub.weatherKit.killSwitch.lastRefreshAt.v1"
    private let logger = Logger(subsystem: "com.sunclub", category: "WeatherKitKillSwitch")

    private var inFlightTask: Task<Void, Never>?

    init(
        budget: SunclubWeatherKitBudget,
        configURL: URL? = nil,
        session: URLSession? = nil,
        minRefreshInterval: TimeInterval = 24 * 60 * 60,
        appGroupID: String = SunclubRuntimeConfiguration.appGroupID
    ) {
        self.budget = budget
        self.configURL = configURL
            ?? (Bundle.main.object(forInfoDictionaryKey: Self.configURLKey) as? String)
                .flatMap(URL.init(string:))
            ?? Self.defaultConfigURL

        let sessionConfiguration: URLSessionConfiguration = .ephemeral
        sessionConfiguration.allowsExpensiveNetworkAccess = true
        sessionConfiguration.allowsConstrainedNetworkAccess = false
        sessionConfiguration.timeoutIntervalForRequest = 10
        sessionConfiguration.timeoutIntervalForResource = 10
        self.session = session ?? URLSession(configuration: sessionConfiguration)
        self.minRefreshInterval = minRefreshInterval
        self.storage = UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Opportunistically refresh the policy. Safe to call on every
    /// foreground activation — short-circuits if the last refresh is
    /// still fresh or another refresh is in flight.
    func refreshIfStale(now: Date = Date()) {
        if let lastRefresh = lastRefreshAt(), now.timeIntervalSince(lastRefresh) < minRefreshInterval {
            return
        }
        guard inFlightTask == nil else { return }

        inFlightTask = Task { [weak self] in
            await self?.performRefresh(now: now)
        }
    }

    private func performRefresh(now: Date) async {
        defer { inFlightTask = nil }

        do {
            var request = URLRequest(url: configURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                logger.notice("WeatherKit kill switch fetch returned non-200")
                return
            }
            let policy = try JSONDecoder().decode(SunclubWeatherKitBudgetPolicy.self, from: data)
            budget.storePolicy(policy)
            setLastRefreshAt(now)
            logger.info("WeatherKit kill switch policy refreshed: enabled=\(policy.weatherKitEnabled, privacy: .public), dailyCap=\(policy.maxDailyFetchesPerDevice, privacy: .public)")
        } catch {
            logger.notice("WeatherKit kill switch fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func lastRefreshAt() -> Date? {
        let value = storage.double(forKey: storageKey)
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    private func setLastRefreshAt(_ date: Date) {
        storage.set(date.timeIntervalSince1970, forKey: storageKey)
    }
}
