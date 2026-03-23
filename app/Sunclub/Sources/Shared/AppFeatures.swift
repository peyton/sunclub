import Foundation

struct AppFeatures: Equatable {
    private enum Constants {
        static let bottleScanInfoKey = "FeatureBottleScanEnabled"
        static let bottleScanLaunchArgument = "FEATURE_ENABLE_BOTTLE_SCAN"
    }

    let isBottleScanEnabled: Bool

    init(isBottleScanEnabled: Bool) {
        self.isBottleScanEnabled = isBottleScanEnabled
    }

    init(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        launchArguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        let infoDictionaryValue = infoDictionary?[Constants.bottleScanInfoKey] as? Bool ?? false
        let launchArgumentOverride = launchArguments.contains(Constants.bottleScanLaunchArgument)
        self.init(isBottleScanEnabled: launchArgumentOverride || infoDictionaryValue)
    }

    static var current: Self {
        Self()
    }
}
