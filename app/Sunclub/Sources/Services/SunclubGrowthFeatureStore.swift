import Foundation

protocol SunclubGrowthFeatureStoring: AnyObject {
    func load() -> SunclubGrowthSettings
    func save(_ settings: SunclubGrowthSettings)
}

final class SunclubGrowthFeatureStore: SunclubGrowthFeatureStoring {
    static let shared = SunclubGrowthFeatureStore()

    private enum Keys {
        static let growthSettings = "sunclub.growth-settings"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: SunclubWidgetDefaults.appGroupID)) {
        self.userDefaults = userDefaults ?? .standard
    }

    func load() -> SunclubGrowthSettings {
        guard let data = userDefaults.data(forKey: Keys.growthSettings),
              let settings = try? decoder.decode(SunclubGrowthSettings.self, from: data) else {
            return SunclubGrowthSettings()
        }

        return settings
    }

    func save(_ settings: SunclubGrowthSettings) {
        guard let data = try? encoder.encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: Keys.growthSettings)
    }
}
