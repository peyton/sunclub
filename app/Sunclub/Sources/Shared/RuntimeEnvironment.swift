import Foundation

enum RuntimeEnvironment {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }

    static var isRunningTests: Bool {
        isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
