import Foundation
import SwiftUI

struct RuntimeEnvironmentSnapshot: Equatable {
    let isRunningTests: Bool
    let isPreviewing: Bool
    let hasAppGroupContainer: Bool
    let isPublicAccountabilityTransportEnabled: Bool

    static var current: Self {
        Self(
            isRunningTests: RuntimeEnvironment.isRunningTests,
            isPreviewing: RuntimeEnvironment.isPreviewing,
            hasAppGroupContainer: RuntimeEnvironment.hasAppGroupContainer,
            isPublicAccountabilityTransportEnabled: RuntimeEnvironment.isPublicAccountabilityTransportEnabled
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

    static var preferredColorSchemeOverride: ColorScheme? {
        guard isUITesting else {
            return nil
        }

        if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_DARK_MODE") {
            return .dark
        }

        if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_LIGHT_MODE") {
            return .light
        }

        return nil
    }

    static var dynamicTypeSizeOverride: DynamicTypeSize? {
        guard isUITesting else {
            return nil
        }

        if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_ACCESSIBILITY_TEXT") {
            return .accessibility3
        }

        if ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_LARGER_TEXT") {
            return .xxLarge
        }

        return nil
    }

    static var accessibilityReduceMotionOverride: Bool? {
        guard isUITesting,
              ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_REDUCE_MOTION") else {
            return nil
        }

        return true
    }

    static var differentiateWithoutColorOverride: Bool? {
        guard isUITesting,
              ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_DIFFERENTIATE_WITHOUT_COLOR") else {
            return nil
        }

        return true
    }

    static var shouldUseIncreasedAccessibilityContrast: Bool {
        guard isUITesting,
              ProcessInfo.processInfo.arguments.contains("UITEST_FORCE_INCREASE_CONTRAST") else {
            return false
        }

        return true
    }

    static var currentDateOverride: Date? {
        guard isUITesting,
              let rawTime = argumentValue(withPrefix: "UITEST_CURRENT_TIME=") else {
            return nil
        }

        let components = rawTime
            .split(separator: ":")
            .compactMap { Int($0) }
        guard components.count == 2 || components.count == 3 else {
            return nil
        }

        let hour = components[0]
        let minute = components[1]
        let second = components.count == 3 ? components[2] : 0

        guard (0..<24).contains(hour),
              (0..<60).contains(minute),
              (0..<60).contains(second) else {
            return nil
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: second,
            of: today
        )
    }

    static var cameraAuthorizationOverride: String? {
        guard isUITesting else {
            return nil
        }

        return argumentValue(withPrefix: "UITEST_CAMERA_AUTH=")?.lowercased()
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

    static var isPublicAccountabilityTransportEnabled: Bool {
        let override = ProcessInfo.processInfo.environment["SUNCLUB_PUBLIC_ACCOUNTABILITY_TRANSPORT_ENABLED"]
        if override == "1" || override?.lowercased() == "true" {
            return true
        }
        if override == "0" || override?.lowercased() == "false" {
            return false
        }
        return SunclubRuntimeConfiguration.isPublicAccountabilityTransportEnabled
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
