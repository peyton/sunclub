import CloudKit
import Foundation

struct SunclubAccountabilityProfile: Equatable, Sendable {
    var profileID: UUID
    var displayName: String
    var snapshot: SunclubFriendSnapshot
    var updatedAt: Date
}

struct SunclubAccountabilityInviteResponse: Equatable, Sendable {
    var recipientProfileID: UUID
    var envelope: SunclubAccountabilityInviteEnvelope
}

struct SunclubAccountabilityRemoteEvents: Equatable, Sendable {
    var inviteResponses: [SunclubAccountabilityInviteResponse]
    var pokes: [SunclubAccountabilityPokeEnvelope]
}

@MainActor
protocol SunclubAccountabilityServing: AnyObject {
    func publishProfile(_ profile: SunclubAccountabilityProfile) async throws
    func fetchProfiles(profileIDs: [UUID]) async throws -> [SunclubAccountabilityProfile]
    func sendInviteResponse(_ response: SunclubAccountabilityInviteResponse) async throws
    func sendPoke(_ poke: SunclubAccountabilityPokeEnvelope) async throws
    func fetchRemoteEvents(for profileID: UUID) async throws -> SunclubAccountabilityRemoteEvents
    func installSubscriptions(for profileID: UUID) async throws
}

@MainActor
final class NoopSunclubAccountabilityService: SunclubAccountabilityServing {
    func publishProfile(_ profile: SunclubAccountabilityProfile) async throws {}
    func fetchProfiles(profileIDs: [UUID]) async throws -> [SunclubAccountabilityProfile] { [] }
    func sendInviteResponse(_ response: SunclubAccountabilityInviteResponse) async throws {}
    func sendPoke(_ poke: SunclubAccountabilityPokeEnvelope) async throws {}
    func fetchRemoteEvents(for profileID: UUID) async throws -> SunclubAccountabilityRemoteEvents {
        SunclubAccountabilityRemoteEvents(inviteResponses: [], pokes: [])
    }
    func installSubscriptions(for profileID: UUID) async throws {}
}

enum SunclubAccountabilityServiceError: LocalizedError {
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Sunclub could not read that accountability update."
        }
    }
}

@MainActor
final class SunclubAccountabilityService: SunclubAccountabilityServing {
    private enum RecordType {
        static let profile = "AccountabilityProfile"
        static let inviteResponse = "AccountabilityInviteResponse"
        static let poke = "AccountabilityPoke"
    }

    private enum Field {
        static let profileID = "profileID"
        static let recipientProfileID = "recipientProfileID"
        static let receiverProfileID = "receiverProfileID"
        static let senderProfileID = "senderProfileID"
        static let displayName = "displayName"
        static let senderName = "senderName"
        static let relationshipToken = "relationshipToken"
        static let message = "message"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let hasLoggedToday = "hasLoggedToday"
        static let lastSharedAt = "lastSharedAt"
        static let seasonStyle = "seasonStyle"
        static let updatedAt = "updatedAt"
        static let issuedAt = "issuedAt"
        static let createdAt = "createdAt"
    }

    private let database: CKDatabase

    init(containerIdentifier: String = SunclubRuntimeConfiguration.cloudKitContainerIdentifier) {
        database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
    }

    func publishProfile(_ profile: SunclubAccountabilityProfile) async throws {
        let recordID = CKRecord.ID(recordName: profileRecordName(profile.profileID))
        let record = CKRecord(recordType: RecordType.profile, recordID: recordID)
        apply(profile: profile, to: record)
        _ = try await database.save(record)
    }

    func fetchProfiles(profileIDs: [UUID]) async throws -> [SunclubAccountabilityProfile] {
        var profiles: [SunclubAccountabilityProfile] = []
        for profileID in profileIDs {
            let recordID = CKRecord.ID(recordName: profileRecordName(profileID))
            let record = try await database.record(for: recordID)
            profiles.append(try profile(from: record))
        }
        return profiles
    }

    func sendInviteResponse(_ response: SunclubAccountabilityInviteResponse) async throws {
        let recordID = CKRecord.ID(
            recordName: "invite-\(response.recipientProfileID.uuidString)-\(response.envelope.profileID.uuidString)"
        )
        let record = CKRecord(recordType: RecordType.inviteResponse, recordID: recordID)
        record[Field.recipientProfileID] = response.recipientProfileID.uuidString as CKRecordValue
        apply(envelope: response.envelope, to: record)
        _ = try await database.save(record)
    }

    func sendPoke(_ poke: SunclubAccountabilityPokeEnvelope) async throws {
        let record = CKRecord(recordType: RecordType.poke, recordID: CKRecord.ID(recordName: "poke-\(UUID().uuidString)"))
        record[Field.senderProfileID] = poke.senderProfileID.uuidString as CKRecordValue
        record[Field.senderName] = poke.senderName as CKRecordValue
        record[Field.receiverProfileID] = poke.receiverProfileID.uuidString as CKRecordValue
        record[Field.relationshipToken] = poke.relationshipToken as CKRecordValue
        record[Field.message] = poke.message as CKRecordValue
        record[Field.createdAt] = poke.createdAt as CKRecordValue
        _ = try await database.save(record)
    }

    func fetchRemoteEvents(for profileID: UUID) async throws -> SunclubAccountabilityRemoteEvents {
        async let inviteResponses = fetchInviteResponses(for: profileID)
        async let pokes = fetchPokes(for: profileID)
        return try await SunclubAccountabilityRemoteEvents(
            inviteResponses: inviteResponses,
            pokes: pokes
        )
    }

    func installSubscriptions(for profileID: UUID) async throws {
        let invitePredicate = NSPredicate(format: "%K == %@", Field.recipientProfileID, profileID.uuidString)
        let inviteSubscription = CKQuerySubscription(
            recordType: RecordType.inviteResponse,
            predicate: invitePredicate,
            subscriptionID: "sunclub-accountability-invites-\(profileID.uuidString)",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        inviteSubscription.notificationInfo = notificationInfo(
            title: "Sunclub friend added",
            body: "Open Sunclub to refresh accountability."
        )

        let pokePredicate = NSPredicate(format: "%K == %@", Field.receiverProfileID, profileID.uuidString)
        let pokeSubscription = CKQuerySubscription(
            recordType: RecordType.poke,
            predicate: pokePredicate,
            subscriptionID: "sunclub-accountability-pokes-\(profileID.uuidString)",
            options: [.firesOnRecordCreation]
        )
        pokeSubscription.notificationInfo = notificationInfo(
            title: "Sunclub accountability",
            body: "A friend sent a sunscreen poke."
        )

        _ = try await database.save(inviteSubscription)
        _ = try await database.save(pokeSubscription)
    }

    private func fetchInviteResponses(for profileID: UUID) async throws -> [SunclubAccountabilityInviteResponse] {
        let query = CKQuery(
            recordType: RecordType.inviteResponse,
            predicate: NSPredicate(format: "%K == %@", Field.recipientProfileID, profileID.uuidString)
        )
        let records = try await records(matching: query, limit: 50)
        let responses = try records.map { record in
            let envelope = try envelope(from: record)
            return SunclubAccountabilityInviteResponse(recipientProfileID: profileID, envelope: envelope)
        }
        await delete(records)
        return responses
    }

    private func fetchPokes(for profileID: UUID) async throws -> [SunclubAccountabilityPokeEnvelope] {
        let query = CKQuery(
            recordType: RecordType.poke,
            predicate: NSPredicate(format: "%K == %@", Field.receiverProfileID, profileID.uuidString)
        )
        let records = try await records(matching: query, limit: 50)
        let pokes = try records.map(pokeEnvelope(from:))
        await delete(records)
        return pokes
    }

    private func records(matching query: CKQuery, limit: Int) async throws -> [CKRecord] {
        let response = try await database.records(matching: query, resultsLimit: limit)
        return try response.matchResults.map { _, result in
            try result.get()
        }
    }

    private func delete(_ records: [CKRecord]) async {
        for record in records {
            _ = try? await database.deleteRecord(withID: record.recordID)
        }
    }

    private func apply(profile: SunclubAccountabilityProfile, to record: CKRecord) {
        record[Field.profileID] = profile.profileID.uuidString as CKRecordValue
        record[Field.updatedAt] = profile.updatedAt as CKRecordValue
        apply(snapshot: profile.snapshot, displayName: profile.displayName, to: record)
    }

    private func apply(envelope: SunclubAccountabilityInviteEnvelope, to record: CKRecord) {
        record[Field.profileID] = envelope.profileID.uuidString as CKRecordValue
        record[Field.displayName] = envelope.displayName as CKRecordValue
        record[Field.relationshipToken] = envelope.relationshipToken as CKRecordValue
        record[Field.issuedAt] = envelope.issuedAt as CKRecordValue
        apply(snapshot: envelope.snapshot, displayName: envelope.displayName, to: record)
    }

    private func apply(snapshot: SunclubFriendSnapshot, displayName: String, to record: CKRecord) {
        record[Field.displayName] = displayName as CKRecordValue
        record[Field.currentStreak] = snapshot.currentStreak as CKRecordValue
        record[Field.longestStreak] = snapshot.longestStreak as CKRecordValue
        record[Field.hasLoggedToday] = (snapshot.hasLoggedToday ? 1 : 0) as CKRecordValue
        record[Field.lastSharedAt] = snapshot.lastSharedAt as CKRecordValue
        record[Field.seasonStyle] = snapshot.seasonStyleRawValue as CKRecordValue
    }

    private func profile(from record: CKRecord) throws -> SunclubAccountabilityProfile {
        guard let profileID = uuid(record[Field.profileID]),
              let displayName = record[Field.displayName] as? String else {
            throw SunclubAccountabilityServiceError.invalidRecord
        }

        return SunclubAccountabilityProfile(
            profileID: profileID,
            displayName: displayName,
            snapshot: try snapshot(from: record, fallbackName: displayName),
            updatedAt: (record[Field.updatedAt] as? Date) ?? Date()
        )
    }

    private func envelope(from record: CKRecord) throws -> SunclubAccountabilityInviteEnvelope {
        guard let profileID = uuid(record[Field.profileID]),
              let displayName = record[Field.displayName] as? String,
              let relationshipToken = record[Field.relationshipToken] as? String else {
            throw SunclubAccountabilityServiceError.invalidRecord
        }

        return SunclubAccountabilityInviteEnvelope(
            profileID: profileID,
            displayName: displayName,
            relationshipToken: relationshipToken,
            issuedAt: (record[Field.issuedAt] as? Date) ?? Date(),
            snapshot: try snapshot(from: record, fallbackName: displayName)
        )
    }

    private func pokeEnvelope(from record: CKRecord) throws -> SunclubAccountabilityPokeEnvelope {
        guard let senderProfileID = uuid(record[Field.senderProfileID]),
              let receiverProfileID = uuid(record[Field.receiverProfileID]),
              let senderName = record[Field.senderName] as? String,
              let relationshipToken = record[Field.relationshipToken] as? String,
              let message = record[Field.message] as? String else {
            throw SunclubAccountabilityServiceError.invalidRecord
        }

        return SunclubAccountabilityPokeEnvelope(
            senderProfileID: senderProfileID,
            senderName: senderName,
            receiverProfileID: receiverProfileID,
            relationshipToken: relationshipToken,
            message: message,
            createdAt: (record[Field.createdAt] as? Date) ?? Date()
        )
    }

    private func snapshot(from record: CKRecord, fallbackName: String) throws -> SunclubFriendSnapshot {
        guard let currentStreak = record[Field.currentStreak] as? Int64,
              let longestStreak = record[Field.longestStreak] as? Int64,
              let hasLoggedToday = record[Field.hasLoggedToday] as? Int64,
              let lastSharedAt = record[Field.lastSharedAt] as? Date else {
            throw SunclubAccountabilityServiceError.invalidRecord
        }

        let seasonStyleRawValue = record[Field.seasonStyle] as? String
        let seasonStyle = seasonStyleRawValue.flatMap(SunclubSeasonStyle.init(rawValue:)) ?? .summerGlow
        return SunclubFriendSnapshot(
            name: fallbackName,
            currentStreak: Int(currentStreak),
            longestStreak: Int(longestStreak),
            hasLoggedToday: hasLoggedToday == 1,
            lastSharedAt: lastSharedAt,
            seasonStyle: seasonStyle
        )
    }

    private func uuid(_ value: CKRecordValue?) -> UUID? {
        guard let string = value as? String else { return nil }
        return UUID(uuidString: string)
    }

    private func notificationInfo(title: String, body: String) -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.title = title
        info.alertBody = body
        info.shouldSendContentAvailable = true
        info.soundName = "default"
        return info
    }

    private func profileRecordName(_ profileID: UUID) -> String {
        "profile-\(profileID.uuidString)"
    }
}
