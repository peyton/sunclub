import Foundation

struct SunclubAccountabilitySettings: Codable, Equatable, Sendable {
    var localProfileID: UUID
    var displayName: String
    var inviteTokens: [SunclubAccountabilityInviteToken]
    var activatedAt: Date?
    var dismissedAt: Date?
    var pendingInvites: [SunclubAccountabilityPendingInvite]
    var connections: [SunclubFriendConnection]
    var pokeHistory: [SunclubAccountabilityPoke]
    var lastPublishedAt: Date?
    var subscriptionsInstalledAt: Date?

    init(
        localProfileID: UUID = UUID(),
        displayName: String = "",
        inviteTokens: [SunclubAccountabilityInviteToken] = [],
        activatedAt: Date? = nil,
        dismissedAt: Date? = nil,
        pendingInvites: [SunclubAccountabilityPendingInvite] = [],
        connections: [SunclubFriendConnection] = [],
        pokeHistory: [SunclubAccountabilityPoke] = [],
        lastPublishedAt: Date? = nil,
        subscriptionsInstalledAt: Date? = nil
    ) {
        self.localProfileID = localProfileID
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.inviteTokens = inviteTokens
        self.activatedAt = activatedAt
        self.dismissedAt = dismissedAt
        self.pendingInvites = pendingInvites
        self.connections = connections
        self.pokeHistory = Array(pokeHistory.sorted { $0.createdAt > $1.createdAt }.prefix(50))
        self.lastPublishedAt = lastPublishedAt
        self.subscriptionsInstalledAt = subscriptionsInstalledAt
    }

    private enum CodingKeys: String, CodingKey {
        case localProfileID
        case displayName
        case inviteTokens
        case activatedAt
        case dismissedAt
        case pendingInvites
        case connections
        case pokeHistory
        case lastPublishedAt
        case subscriptionsInstalledAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localProfileID = try container.decodeIfPresent(UUID.self, forKey: .localProfileID) ?? UUID()
        displayName = (try container.decodeIfPresent(String.self, forKey: .displayName) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        inviteTokens = try container.decodeIfPresent([SunclubAccountabilityInviteToken].self, forKey: .inviteTokens) ?? []
        activatedAt = try container.decodeIfPresent(Date.self, forKey: .activatedAt)
        dismissedAt = try container.decodeIfPresent(Date.self, forKey: .dismissedAt)
        pendingInvites = try container.decodeIfPresent(
            [SunclubAccountabilityPendingInvite].self,
            forKey: .pendingInvites
        ) ?? []
        connections = try container.decodeIfPresent([SunclubFriendConnection].self, forKey: .connections) ?? []
        let decodedPokes = try container.decodeIfPresent([SunclubAccountabilityPoke].self, forKey: .pokeHistory) ?? []
        pokeHistory = Array(decodedPokes.sorted { $0.createdAt > $1.createdAt }.prefix(50))
        lastPublishedAt = try container.decodeIfPresent(Date.self, forKey: .lastPublishedAt)
        subscriptionsInstalledAt = try container.decodeIfPresent(Date.self, forKey: .subscriptionsInstalledAt)
    }

    var isActive: Bool {
        activatedAt != nil
    }

    var activeInviteToken: SunclubAccountabilityInviteToken? {
        inviteTokens.sorted { $0.createdAt > $1.createdAt }.first
    }

    mutating func ensureInviteToken(now: Date) -> SunclubAccountabilityInviteToken {
        if let activeInviteToken {
            return activeInviteToken
        }

        let token = SunclubAccountabilityInviteToken(createdAt: now)
        inviteTokens = [token]
        return token
    }
}

struct SunclubAccountabilityInviteToken: Codable, Equatable, Identifiable, Sendable {
    var id: String { token }
    var token: String
    var createdAt: Date

    init(token: String = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased(), createdAt: Date) {
        self.token = token
        self.createdAt = createdAt
    }
}

struct SunclubAccountabilityPendingInvite: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var envelope: SunclubAccountabilityInviteEnvelope
    var receivedAt: Date

    init(id: UUID = UUID(), envelope: SunclubAccountabilityInviteEnvelope, receivedAt: Date) {
        self.id = id
        self.envelope = envelope
        self.receivedAt = receivedAt
    }
}

struct SunclubFriendConnection: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { friendProfileID }
    var friendProfileID: UUID
    var friendSnapshotID: UUID
    var friendDisplayName: String
    var relationshipToken: String
    var acceptedAt: Date
    var lastStatusRefreshAt: Date?
    var lastPokeSentAt: Date?
    var lastPokeReceivedAt: Date?
    var canDirectPoke: Bool

    init(
        friendProfileID: UUID,
        friendSnapshotID: UUID,
        friendDisplayName: String,
        relationshipToken: String,
        acceptedAt: Date,
        lastStatusRefreshAt: Date? = nil,
        lastPokeSentAt: Date? = nil,
        lastPokeReceivedAt: Date? = nil,
        canDirectPoke: Bool = true
    ) {
        self.friendProfileID = friendProfileID
        self.friendSnapshotID = friendSnapshotID
        self.friendDisplayName = friendDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.relationshipToken = relationshipToken
        self.acceptedAt = acceptedAt
        self.lastStatusRefreshAt = lastStatusRefreshAt
        self.lastPokeSentAt = lastPokeSentAt
        self.lastPokeReceivedAt = lastPokeReceivedAt
        self.canDirectPoke = canDirectPoke
    }
}

struct SunclubAccountabilityPoke: Codable, Equatable, Identifiable, Sendable {
    enum Direction: String, Codable, Sendable {
        case sent
        case received
    }

    enum Channel: String, Codable, Sendable {
        case direct
        case shareSheet
    }

    enum Status: String, Codable, Sendable {
        case sent
        case received
        case failed
    }

    var id: UUID
    var friendProfileID: UUID
    var friendName: String
    var direction: Direction
    var channel: Channel
    var status: Status
    var message: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        friendProfileID: UUID,
        friendName: String,
        direction: Direction,
        channel: Channel,
        status: Status,
        message: String,
        createdAt: Date
    ) {
        self.id = id
        self.friendProfileID = friendProfileID
        self.friendName = friendName
        self.direction = direction
        self.channel = channel
        self.status = status
        self.message = message
        self.createdAt = createdAt
    }
}

struct SunclubAccountabilityInviteEnvelope: Codable, Equatable, Sendable {
    var profileID: UUID
    var displayName: String
    var relationshipToken: String
    var issuedAt: Date
    var snapshot: SunclubFriendSnapshot

    init(
        profileID: UUID,
        displayName: String,
        relationshipToken: String,
        issuedAt: Date,
        snapshot: SunclubFriendSnapshot
    ) {
        self.profileID = profileID
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.relationshipToken = relationshipToken
        self.issuedAt = issuedAt
        self.snapshot = snapshot
    }
}

struct SunclubAccountabilityPokeEnvelope: Codable, Equatable, Sendable {
    var senderProfileID: UUID
    var senderName: String
    var receiverProfileID: UUID
    var relationshipToken: String
    var message: String
    var createdAt: Date
}

struct SunclubAccountabilitySummary: Codable, Equatable, Sendable {
    var isActive: Bool
    var friendCount: Int
    var loggedCount: Int
    var openCount: Int
    var topFriends: [SunclubFriendSnapshot]
    var latestPoke: SunclubAccountabilityPoke?
    var primaryPokeFriendID: UUID?
    var latestPokeText: String

    init(
        isActive: Bool = false,
        friendCount: Int = 0,
        loggedCount: Int = 0,
        openCount: Int = 0,
        topFriends: [SunclubFriendSnapshot] = [],
        latestPoke: SunclubAccountabilityPoke? = nil,
        primaryPokeFriendID: UUID? = nil,
        latestPokeText: String = ""
    ) {
        self.isActive = isActive
        self.friendCount = max(0, friendCount)
        self.loggedCount = max(0, loggedCount)
        self.openCount = max(0, openCount)
        self.topFriends = topFriends
        self.latestPoke = latestPoke
        self.primaryPokeFriendID = primaryPokeFriendID
        self.latestPokeText = latestPokeText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let empty = SunclubAccountabilitySummary(
        isActive: false,
        friendCount: 0,
        loggedCount: 0,
        openCount: 0,
        topFriends: [],
        latestPoke: nil,
        primaryPokeFriendID: nil,
        latestPokeText: ""
    )

    private enum CodingKeys: String, CodingKey {
        case isActive
        case friendCount
        case loggedCount
        case openCount
        case topFriends
        case latestPoke
        case primaryPokeFriendID
        case latestPokeText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isActive: try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false,
            friendCount: try container.decodeIfPresent(Int.self, forKey: .friendCount) ?? 0,
            loggedCount: try container.decodeIfPresent(Int.self, forKey: .loggedCount) ?? 0,
            openCount: try container.decodeIfPresent(Int.self, forKey: .openCount) ?? 0,
            topFriends: try container.decodeIfPresent([SunclubFriendSnapshot].self, forKey: .topFriends) ?? [],
            latestPoke: try container.decodeIfPresent(SunclubAccountabilityPoke.self, forKey: .latestPoke),
            primaryPokeFriendID: try container.decodeIfPresent(UUID.self, forKey: .primaryPokeFriendID),
            latestPokeText: try container.decodeIfPresent(String.self, forKey: .latestPokeText) ?? ""
        )
    }
}
