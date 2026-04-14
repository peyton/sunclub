import Foundation

enum SunclubRuntimeConfiguration {
    private final class BundleMarker {}

    private static let bundle = Bundle(for: BundleMarker.self)
    private static let fallbackAppGroupID = "group.app.peyton.sunclub"
    private static let fallbackCloudKitContainerIdentifier = "iCloud.app.peyton.sunclub"
    private static let fallbackURLScheme = "sunclub"

    static var appGroupID: String {
        stringValue(for: "SunclubAppGroupID", fallback: fallbackAppGroupID)
    }

    static var cloudKitContainerIdentifier: String {
        stringValue(
            for: "SunclubICloudContainerIdentifier",
            fallback: fallbackCloudKitContainerIdentifier
        )
    }

    static var urlScheme: String {
        stringValue(for: "SunclubURLScheme", fallback: fallbackURLScheme)
    }

    static var isPublicAccountabilityTransportEnabled: Bool {
        boolValue(for: "SunclubPublicAccountabilityTransportEnabled", fallback: false)
    }

    static func supportsURLScheme(_ scheme: String?) -> Bool {
        guard let normalizedScheme = scheme?.lowercased() else {
            return false
        }
        return [urlScheme.lowercased(), "sunclub", "sunclub-dev"].contains(normalizedScheme)
    }

    static func widgetKind(_ base: String) -> String {
        "\(bundle.bundleIdentifier ?? fallbackAppGroupID).\(base)"
    }

    private static func stringValue(for key: String, fallback: String) -> String {
        (bundle.object(forInfoDictionaryKey: key) as? String)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    private static func boolValue(for key: String, fallback: Bool) -> Bool {
        if let value = bundle.object(forInfoDictionaryKey: key) as? Bool {
            return value
        }

        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return fallback
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return fallback
        }
    }
}
