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
        "The SPF council requests your presence. Log today before the sun gets smug.",
        "Unapplied SPF detected. Please report to your nearest bottle.",
        "Your sunscreen bottle asked if you two are still friends.",
        "UV is outside acting confident. Time to humble it.",
        "Tiny sunscreen desk check: did you log today?",
        "The sun is doing side quests. Please equip SPF.",
        "This is your official lotion summons.",
        "The streak auditors are circling. Log today and scare them off.",
        "Your face called. It would like SPF backup.",
        "SPF roll call. You are currently marked mysteriously absent.",
        "A polite poke from the sunscreen desk: clock in, shine less.",
        "The bottle is emotionally available. Are you?",
        "Apply now, brag later.",
        "Your future skin sent a calendar invite called please log sunscreen."
    ]

    static let alreadyLoggedPokeMessages = [
        "Already logged? Suspiciously responsible. Reapply if the sun is still loitering.",
        "You are on the SPF board today. Consider this a tiny victory poke.",
        "Logged already. Show-off behavior detected.",
        "Your sunscreen paperwork is in order. The committee applauds, quietly.",
        "Logged today. If you are still outside, the bottle wants an encore.",
        "You logged. The sun has been informed and is taking it poorly.",
        "SPF elite status confirmed. Reapply if the day keeps day-ing.",
        "Your streak is behaving. Very mature. Almost alarming.",
        "The friend audit says your SPF is logged. Carry on.",
        "You beat the poke. This poke is now ceremonial.",
        "Logged today. Please accept this unnecessary but affectionate SPF ping.",
        "The bottle says nice work and also maybe do not abandon it.",
        "Already protected. The sunscreen bureaucracy has no notes.",
        "Your sunscreen log is looking smug. It earned it."
    ]

    static let incomingOpenNotificationBodies = [
        "%@ says the SPF council is taking attendance.",
        "%@ poked you. The bottle is waiting by the door.",
        "%@ spotted an open sunscreen day and chose light chaos.",
        "%@ sent a tiny lotion summons.",
        "%@ says the sun is getting too confident.",
        "%@ has requested one logged day, extra SPF.",
        "%@ is tapping the sunscreen sign.",
        "%@ says your streak auditors are restless.",
        "%@ would like one sunscreen log on the board.",
        "%@ sent a friendly poke from the shade."
    ]

    static let incomingLoggedNotificationBodies = [
        "%@ poked you anyway. Your logged day is causing envy.",
        "%@ sent a ceremonial poke. You already did the SPF thing.",
        "%@ says nice log. Reapply if the sun is still loitering.",
        "%@ noticed your log and chose applause by notification.",
        "%@ says your sunscreen paperwork is suspiciously tidy.",
        "%@ sent a victory tap for your already-logged day.",
        "%@ says the SPF committee has no notes.",
        "%@ poked the overachiever. That is you.",
        "%@ says your streak looks smug today.",
        "%@ approves this sunscreen discipline."
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
        let nudge = hasLoggedToday
            ? "Nice log today. Reapply if the sun is still loitering."
            : "Time to log sunscreen in Sunclub."
        return "\(sender) says to \(friend): \(nudge) Open Sunclub: \(SunclubShareArtifactService.appLinkDisplay)"
    }

    static func directPokeSuccessMessage(friendName: String, hasLoggedToday: Bool) -> String {
        let friend = resolvedName(friendName, fallback: "your friend")
        return hasLoggedToday
            ? "Sent \(friend) a nice-work tap."
            : "Sent \(friend) a sunscreen nudge."
    }

    static func directPokeFailureMessage(friendName: String) -> String {
        "Direct poke did not send to \(resolvedName(friendName, fallback: "your friend")). Use Message instead."
    }

    static func directPokeUnavailableMessage(friendName: String) -> String {
        "Add \(resolvedName(friendName, fallback: "this friend")) again before direct pokes work."
    }

    static func latestPokeText(_ poke: SunclubAccountabilityPoke?) -> String? {
        guard let poke else { return nil }
        switch (poke.direction, poke.status) {
        case (.sent, .sent):
            return "Last poke: you nudged \(poke.friendName)."
        case (.sent, .failed):
            return "Last poke to \(poke.friendName) needs a message fallback."
        case (.received, .received):
            return "\(poke.friendName) poked you: \(poke.message)"
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
