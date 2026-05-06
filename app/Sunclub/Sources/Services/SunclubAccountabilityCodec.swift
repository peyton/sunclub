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
        \(name) wants to share Sunclub activity with you.

        Add me to Activity sharing:
        \(url.absoluteString)

        Backup code:
        \(code)
        """
    }

    static func pokeShareText(from senderName: String, to friendName: String, hasLoggedToday: Bool) -> String {
        SunclubAccountabilityMessaging.sharePokeText(
            from: senderName,
            to: friendName,
            hasLoggedToday: hasLoggedToday
        )
    }
}

enum SunclubAccountabilityMessaging {
    static let openDayPokeMessages = [
        "Quick reminder to log today's sunscreen.",
        "Today's sunscreen log is still open.",
        "One quick Sunclub log when you have a moment.",
        "Your daily sunscreen log is still open.",
        "A friend shared a sunscreen reminder.",
        "Open Sunclub when you're ready to log.",
        "Don't forget today's sunscreen log.",
        "Your check-in is still open today.",
        "A simple reminder to apply and log sunscreen.",
        "Today's log helps keep the routine visible.",
        "Log sunscreen before the day gets away.",
        "Mark today logged when it is done."
    ]

    static let alreadyLoggedPokeMessages = [
        "Already logged today. Reapply if you're still outside.",
        "Nice work logging today. Reapply when needed.",
        "Today's log is already saved.",
        "You're logged today. Keep an eye on reapply time.",
        "Already saved for today.",
        "Today's sunscreen is recorded.",
        "Good job keeping the routine simple.",
        "Logged today. Reapply if the day runs long.",
        "Your Sunclub day is saved.",
        "Today's check-in is complete.",
        "Your sunscreen log is current.",
        "Logged already. Nothing else to do unless you need reapply."
    ]

    static let incomingOpenNotificationBodies = [
        "%@ sent a sunscreen reminder.",
        "%@ reminded you to log sunscreen.",
        "%@ shared a quick sunscreen check-in.",
        "%@ says today's Sunclub log is still open.",
        "%@ sent a reminder for today's log.",
        "%@ is checking whether sunscreen is logged.",
        "%@ shared a simple Sunclub reminder.",
        "%@ reminded you to apply and log sunscreen."
    ]

    static let incomingLoggedNotificationBodies = [
        "%@ sent a reminder. You're already logged today.",
        "%@ checked in. Your Sunclub log is already saved.",
        "%@ says nice log. Reapply if you're still outside.",
        "%@ sent a reminder, and today is already logged.",
        "%@ checked your shared activity. You're logged today.",
        "%@ sent a quick Sunclub reminder.",
        "%@ noticed today's log is complete.",
        "%@ sent a reminder. Nothing else to do unless you need reapply."
    ]

    static func outgoingPokeMessage(
        for friend: SunclubFriendSnapshot,
        friendProfileID: UUID,
        recentPokes: [SunclubAccountabilityPoke],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let catalog = friend.hasLoggedToday ? alreadyLoggedPokeMessages : openDayPokeMessages
        let recentMessages = recentPokes
            .filter { $0.friendProfileID == friendProfileID }
            .prefix(6)
            .map(\.message)
        return selectMessage(from: catalog, avoiding: recentMessages, seed: selectionSeed(friend.id.uuidString, now: now, calendar: calendar))
    }

    static func incomingNotificationBody(
        from senderName: String,
        recipientHasLoggedToday: Bool,
        recentPokes: [SunclubAccountabilityPoke],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let resolvedSender = resolvedName(senderName, fallback: "A Sunclub friend")
        let catalog = recipientHasLoggedToday ? incomingLoggedNotificationBodies : incomingOpenNotificationBodies
        let recentMessages = recentPokes
            .filter { $0.direction == .received && $0.friendName == resolvedSender }
            .prefix(6)
            .map(\.message)
        let format = selectMessage(
            from: catalog,
            avoiding: recentMessages,
            seed: selectionSeed(resolvedSender, now: now, calendar: calendar)
        )
        return String(format: format, resolvedSender)
    }

    static func sharePokeText(from senderName: String, to friendName: String, hasLoggedToday: Bool) -> String {
        let sender = resolvedName(senderName, fallback: "A Sunclub friend")
        let friend = resolvedName(friendName, fallback: "friend")
        let reminder = hasLoggedToday
            ? "Nice log today. Reapply if you're still outside."
            : "Time to log sunscreen in Sunclub."
        return """
        \(sender) sent \(friend) a Sunclub reminder: \(reminder) Open Sunclub: \(SunclubShareArtifactService.appLinkDisplay)
        """
    }

    static func directPokeSuccessMessage(friendName: String, hasLoggedToday: Bool) -> String {
        let friend = resolvedName(friendName, fallback: "your friend")
        return hasLoggedToday
            ? "Sent \(friend) a reminder."
            : "Sent \(friend) a sunscreen reminder."
    }

    static func directPokeFailureMessage(friendName: String) -> String {
        "Reminder did not send to \(resolvedName(friendName, fallback: "your friend")). Use Message instead."
    }

    static func directPokeUnavailableMessage(friendName: String) -> String {
        "Use Message to remind \(resolvedName(friendName, fallback: "this friend"))."
    }

    static func latestPokeText(_ poke: SunclubAccountabilityPoke?) -> String? {
        guard let poke else { return nil }
        switch (poke.direction, poke.status) {
        case (.sent, .sent):
            return "Last reminder: you reminded \(poke.friendName)."
        case (.sent, .failed):
            return "Last reminder to \(poke.friendName) needs Message."
        case (.received, .received):
            return "\(poke.friendName) reminded you: \(poke.message)"
        default:
            return nil
        }
    }

    private static func selectMessage(from catalog: [String], avoiding recentMessages: [String], seed: Int) -> String {
        guard let first = catalog.first else { return "" }
        let recent = Set(recentMessages)
        let startIndex = catalog.isEmpty ? 0 : seed % catalog.count

        for offset in 0..<catalog.count {
            let candidate = catalog[(startIndex + offset) % catalog.count]
            if !recent.contains(candidate) {
                return candidate
            }
        }

        return first
    }

    private static func selectionSeed(_ value: String, now: Date, calendar: Calendar) -> Int {
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let scalarTotal = value.unicodeScalars.reduce(0) { partial, scalar in
            (partial + Int(scalar.value)) % 10_000
        }
        return abs(day + scalarTotal)
    }

    private static func resolvedName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
