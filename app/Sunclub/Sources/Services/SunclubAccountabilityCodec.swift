import Foundation

enum SunclubAccountabilityCodec {
    private static let backupCodePrefix = "SUNCLUB-ACCOUNTABILITY-"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func backupCode(for envelope: SunclubAccountabilityInviteEnvelope) throws -> String {
        let data = try encoder.encode(envelope)
        return backupCodePrefix + data.base64EncodedString()
    }

    static func envelope(from code: String) throws -> SunclubAccountabilityInviteEnvelope {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = trimmed.hasPrefix(backupCodePrefix)
            ? String(trimmed.dropFirst(backupCodePrefix.count))
            : trimmed

        guard let data = Data(base64Encoded: payload) else {
            throw SunclubFriendCodeError.invalidCode
        }

        do {
            return try decoder.decode(SunclubAccountabilityInviteEnvelope.self, from: data)
        } catch {
            throw SunclubFriendCodeError.invalidCode
        }
    }

    static func inviteURL(for envelope: SunclubAccountabilityInviteEnvelope) throws -> URL {
        let code = try backupCode(for: envelope)
        var components = URLComponents()
        components.scheme = SunclubRuntimeConfiguration.urlScheme
        components.host = "accountability"
        components.path = "/invite"
        components.queryItems = [
            URLQueryItem(name: "code", value: code)
        ]

        guard let url = components.url else {
            throw SunclubFriendCodeError.invalidCode
        }
        return url
    }

    static func pokeURL(profileID: UUID? = nil) -> URL {
        var components = URLComponents()
        components.scheme = SunclubRuntimeConfiguration.urlScheme
        components.host = "accountability"
        components.path = "/poke"
        if let profileID {
            components.queryItems = [URLQueryItem(name: "friend", value: profileID.uuidString)]
        }
        return components.url ?? URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://accountability/poke")!
    }

    static func inviteShareText(envelope: SunclubAccountabilityInviteEnvelope) throws -> String {
        let url = try inviteURL(for: envelope)
        let code = try backupCode(for: envelope)
        let name = envelope.displayName.isEmpty ? "I" : envelope.displayName
        return """
        \(name) wants to keep up with sunscreen in Sunclub.

        Add me for accountability:
        \(url.absoluteString)

        Backup code:
        \(code)
        """
    }

    static func pokeShareText(from senderName: String, to friendName: String) -> String {
        let sender = senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSender = sender.isEmpty ? "A Sunclub friend" : sender
        return "\(resolvedSender) says: sunscreen check? Open Sunclub to log today: \(SunclubShareArtifactService.appLinkDisplay)"
    }
}
