import Foundation

struct RuntimeEnvironmentSnapshot: Equatable {
    let isRunningTests: Bool
    let isPreviewing: Bool
    let hasAppGroupContainer: Bool

    static var current: Self {
        Self(
            isRunningTests: RuntimeEnvironment.isRunningTests,
            isPreviewing: RuntimeEnvironment.isPreviewing,
            hasAppGroupContainer: RuntimeEnvironment.hasAppGroupContainer
        )
    }

    var shouldUseNoopCloudSyncCoordinator: Bool {
        isRunningTests || isPreviewing
    }

    var shouldStartCloudSyncOnLaunch: Bool {
        !shouldUseNoopCloudSyncCoordinator
    }
}

enum RuntimeEnvironment {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }

    static var isRunningTests: Bool {
        isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var isPreviewing: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static var hasAppGroupContainer: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SunclubRuntimeConfiguration.appGroupID
        ) != nil
    }

    static func argumentValue(withPrefix prefix: String) -> String? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }

        return String(argument.dropFirst(prefix.count))
    }

    static func fileURLArgument(withPrefix prefix: String) -> URL? {
        guard let path = argumentValue(withPrefix: prefix), !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }
}
