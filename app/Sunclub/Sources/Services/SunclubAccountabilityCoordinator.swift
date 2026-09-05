import Foundation

/// Relationship policy and transport work operate on explicit value inputs, never on AppState.
@MainActor
final class SunclubAccountabilityCoordinator {
    struct PokeResult {
        let poke: SunclubAccountabilityPoke
        let message: String
    }

    let service: SunclubAccountabilityServing
    private let clock: () -> Date
    private let calendar: Calendar

    init(service: SunclubAccountabilityServing, calendar: Calendar = .current, clock: @escaping () -> Date) {
        self.service = service
        self.calendar = calendar
        self.clock = clock
    }

    var supportsDirectDelivery: Bool { service.supportsDirectDelivery }

    func preparePoke(for friend: SunclubFriendSnapshot, connection: SunclubFriendConnection,
                     displayName: String, growthSettings: inout SunclubGrowthSettings) -> SunclubAccountabilityPokeEnvelope {
        let now = clock()
        let message = SunclubAccountabilityMessaging.outgoingPokeMessage(
            for: friend, friendProfileID: connection.friendProfileID,
            recentPokes: growthSettings.accountability.pokeHistory, now: now, calendar: calendar
        )
        let token = growthSettings.accountability.ensureInviteToken(now: now)
        return SunclubAccountabilityPokeEnvelope(
            senderProfileID: growthSettings.accountability.localProfileID, senderName: displayName,
            receiverProfileID: connection.friendProfileID, relationshipToken: token.token,
            message: message, createdAt: now
        )
    }

    func sendPoke(_ envelope: SunclubAccountabilityPokeEnvelope, to friend: SunclubFriendSnapshot) async -> PokeResult {
        do {
            try await service.sendPoke(envelope)
            return PokeResult(
                poke: outgoingPoke(envelope, friend: friend, status: .sent),
                message: SunclubAccountabilityMessaging.directPokeSuccessMessage(
                    friendName: friend.name, hasLoggedToday: friend.hasLoggedToday
                )
            )
        } catch {
            return PokeResult(
                poke: outgoingPoke(envelope, friend: friend, status: .failed),
                message: SunclubAccountabilityMessaging.directPokeFailureMessage(friendName: friend.name)
            )
        }
    }

    private func outgoingPoke(_ envelope: SunclubAccountabilityPokeEnvelope, friend: SunclubFriendSnapshot,
                              status: SunclubAccountabilityPoke.Status) -> SunclubAccountabilityPoke {
        SunclubAccountabilityPoke(
            friendProfileID: envelope.receiverProfileID, friendName: friend.name,
            direction: .sent, channel: .direct, status: status,
            message: envelope.message, createdAt: envelope.createdAt
        )
    }

    func upsertFriendSnapshot(_ snapshot: SunclubFriendSnapshot, growthSettings: inout SunclubGrowthSettings) {
        if let existingIndex = growthSettings.friends.firstIndex(where: { $0.id == snapshot.id || $0.name == snapshot.name }) {
            growthSettings.friends[existingIndex] = snapshot
        } else {
            growthSettings.friends.append(snapshot)
        }
    }

    func upsertConnection(_ connection: SunclubFriendConnection, growthSettings: inout SunclubGrowthSettings) {
        if let existingIndex = growthSettings.accountability.connections.firstIndex(where: { $0.friendProfileID == connection.friendProfileID }) {
            var existing = growthSettings.accountability.connections[existingIndex]
            existing.friendSnapshotID = connection.friendSnapshotID
            existing.friendDisplayName = connection.friendDisplayName
            existing.relationshipToken = connection.relationshipToken
            existing.canDirectPoke = connection.canDirectPoke
            growthSettings.accountability.connections[existingIndex] = existing
        } else {
            growthSettings.accountability.connections.append(connection)
        }
    }

    func updateConnection(
        _ friendProfileID: UUID,
        growthSettings: inout SunclubGrowthSettings,
        update: (inout SunclubFriendConnection) -> Void
    ) {
        guard let index = growthSettings.accountability.connections.firstIndex(where: { $0.friendProfileID == friendProfileID }) else {
            return
        }
        update(&growthSettings.accountability.connections[index])
    }

    func isValidRelationshipToken(_ token: String, for connection: SunclubFriendConnection, growthSettings: SunclubGrowthSettings) -> Bool {
        connection.relationshipToken == token || growthSettings.accountability.inviteTokens.contains { inviteToken in
            inviteToken.token == token
        }
    }

    func applyAccountabilityProfile(_ profile: SunclubAccountabilityProfile, growthSettings: inout SunclubGrowthSettings) {
        guard let connection = growthSettings.accountability.connections.first(where: { $0.friendProfileID == profile.profileID }) else {
            return
        }
        var snapshot = profile.snapshot
        snapshot.id = connection.friendSnapshotID
        snapshot.name = profile.displayName
        upsertFriendSnapshot(snapshot, growthSettings: &growthSettings)
        updateConnection(profile.profileID, growthSettings: &growthSettings) { connection in
            connection.friendDisplayName = profile.displayName
            connection.lastStatusRefreshAt = profile.updatedAt
        }
    }

    func recordPoke(_ poke: SunclubAccountabilityPoke, growthSettings: inout SunclubGrowthSettings) {
        growthSettings.accountability.pokeHistory.insert(poke, at: 0)
        growthSettings.accountability.pokeHistory = Array(growthSettings.accountability.pokeHistory.prefix(50))
        if poke.direction == .sent {
            updateConnection(poke.friendProfileID, growthSettings: &growthSettings) { connection in
                connection.lastPokeSentAt = poke.createdAt
            }
        }
    }

    func activate(displayName: String?, growthSettings: inout SunclubGrowthSettings) {
        let now = clock()
        let resolvedName = (displayName ?? growthSettings.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)).trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedName.isEmpty {
            growthSettings.preferredName = resolvedName
            growthSettings.accountability.displayName = resolvedName
        } else if growthSettings.accountability.displayName.isEmpty {
            growthSettings.accountability.displayName = "Sunclub Friend"
        }
        growthSettings.accountability.activatedAt = growthSettings.accountability.activatedAt ?? now
        _ = growthSettings.accountability.ensureInviteToken(now: now)
    }

    func importInvite(_ envelope: SunclubAccountabilityInviteEnvelope, growthSettings: inout SunclubGrowthSettings) -> SunclubFriendSnapshot {
        var importedSnapshot = envelope.snapshot
        importedSnapshot.name = envelope.displayName.isEmpty ? importedSnapshot.name : envelope.displayName
        if let existingConnection = growthSettings.accountability.connections.first(where: { $0.friendProfileID == envelope.profileID }) {
            importedSnapshot.id = existingConnection.friendSnapshotID
        }

        upsertFriendSnapshot(importedSnapshot, growthSettings: &growthSettings)
        upsertConnection(
            SunclubFriendConnection(
                friendProfileID: envelope.profileID,
                friendSnapshotID: importedSnapshot.id,
                friendDisplayName: importedSnapshot.name,
                relationshipToken: envelope.relationshipToken,
                acceptedAt: clock(),
                canDirectPoke: supportsDirectDelivery
            ),
            growthSettings: &growthSettings
        )
        return importedSnapshot
    }

    func acceptPoke(_ envelope: SunclubAccountabilityPokeEnvelope, recipientHasLoggedToday: Bool,
                    growthSettings: inout SunclubGrowthSettings) -> String? {
        guard supportsDirectDelivery else { return nil }

        guard envelope.receiverProfileID == growthSettings.accountability.localProfileID,
              let connection = growthSettings.accountability.connections.first(where: {
                $0.friendProfileID == envelope.senderProfileID
              }) else {
            return nil
        }
        guard isValidRelationshipToken(envelope.relationshipToken, for: connection, growthSettings: growthSettings) else {
            return nil
        }

        recordPoke(
            SunclubAccountabilityPoke(
                friendProfileID: envelope.senderProfileID,
                friendName: envelope.senderName,
                direction: .received,
                channel: .direct,
                status: .received,
                message: envelope.message,
                createdAt: envelope.createdAt
            ), growthSettings: &growthSettings
        )
        updateConnection(connection.friendProfileID, growthSettings: &growthSettings) { connection in
            connection.lastPokeReceivedAt = envelope.createdAt
        }

        let notificationMessage = SunclubAccountabilityMessaging.incomingNotificationBody(
            from: envelope.senderName,
            recipientHasLoggedToday: recipientHasLoggedToday,
            recentPokes: growthSettings.accountability.pokeHistory,
            now: clock(),
            calendar: calendar
        )

        return notificationMessage
    }

    func displayName(growthSettings: SunclubGrowthSettings) -> String {
        let accountabilityName = growthSettings.accountability.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !accountabilityName.isEmpty {
            return accountabilityName
        }

        let preferredName = growthSettings.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return preferredName.isEmpty ? "Sunclub Friend" : preferredName
    }

}
