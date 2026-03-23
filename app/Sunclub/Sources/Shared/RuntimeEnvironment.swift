import Foundation

enum RuntimeEnvironment {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }

    static var isRunningTests: Bool {
        isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
