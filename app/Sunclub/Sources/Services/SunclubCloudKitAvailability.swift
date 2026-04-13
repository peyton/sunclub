import Foundation

enum SunclubCloudKitAvailability {
    static func validate(containerIdentifier: String) throws {
        let normalizedIdentifier = containerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidContainerIdentifier(normalizedIdentifier) else {
            throw SunclubCloudKitConfigurationError.invalidContainerIdentifier
        }
    }

    private static func isValidContainerIdentifier(_ containerIdentifier: String) -> Bool {
        containerIdentifier.hasPrefix("iCloud.")
            && containerIdentifier.count > "iCloud.".count
            && !containerIdentifier.contains("$(")
    }
}

enum SunclubCloudKitConfigurationError: LocalizedError, Equatable, Sendable {
    case invalidContainerIdentifier

    var errorDescription: String? {
        switch self {
        case .invalidContainerIdentifier:
            return "Sunclub couldn't start iCloud because the CloudKit container is invalid."
        }
    }
}
