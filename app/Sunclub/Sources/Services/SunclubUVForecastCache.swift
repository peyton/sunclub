import CoreLocation
import Foundation

struct SunclubUVForecastCachePolicy: Sendable {
    /// After this many seconds we consider the whole bundle stale and refetch.
    let maxAge: TimeInterval
    /// Within this radius we treat a new location as "same" and reuse the cached bundle.
    let locationRadiusMeters: CLLocationDistance

    static let `default` = SunclubUVForecastCachePolicy(
        maxAge: 60 * 60 * 3,
        locationRadiusMeters: 5_000
    )
}

final class SunclubUVForecastCache: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()
    private let policy: SunclubUVForecastCachePolicy

    init(
        appGroupID: String = SunclubRuntimeConfiguration.appGroupID,
        key: String = "sunclub.uvForecastBundle.v1",
        policy: SunclubUVForecastCachePolicy = .default
    ) {
        self.defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        self.key = key
        self.policy = policy
    }

    func freshBundle(for location: CLLocation, now: Date = Date()) -> SunclubUVForecastBundle? {
        guard let bundle = loadBundle() else {
            return nil
        }

        guard bundle.isFresh(now: now, ttl: policy.maxAge) else {
            return nil
        }

        let cachedLocation = CLLocation(latitude: bundle.latitude, longitude: bundle.longitude)
        guard cachedLocation.distance(from: location) <= policy.locationRadiusMeters else {
            return nil
        }

        return bundle
    }

    func lastBundle() -> SunclubUVForecastBundle? {
        loadBundle()
    }

    func store(_ bundle: SunclubUVForecastBundle) {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? JSONEncoder().encode(bundle) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }

    private func loadBundle() -> SunclubUVForecastBundle? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(SunclubUVForecastBundle.self, from: data)
    }
}
