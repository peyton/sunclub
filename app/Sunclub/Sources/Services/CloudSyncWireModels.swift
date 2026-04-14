import Foundation

struct BatchWire: Codable {
    let id: UUID
    let createdAt: Date
    let kindRawValue: String
    let scopeRawValue: String
    let scopeIdentifier: String
    let authorDeviceID: String
    let summary: String
    let inverseOfBatchID: UUID?
    let undoneByBatchID: UUID?

    init(batch: SunclubChangeBatch) {
        id = batch.id
        createdAt = batch.createdAt
        kindRawValue = batch.kindRawValue
        scopeRawValue = batch.scopeRawValue
        scopeIdentifier = batch.scopeIdentifier
        authorDeviceID = batch.authorDeviceID
        summary = batch.summary
        inverseOfBatchID = batch.inverseOfBatchID
        undoneByBatchID = batch.undoneByBatchID
    }
}

struct RecordRevisionWire: Codable {
    let id: UUID
    let batchID: UUID
    let createdAt: Date
    let authorDeviceID: String
    let startOfDay: Date
    let isDeleted: Bool
    let verifiedAt: Date?
    let methodRawValue: Int?
    let verificationDuration: Double?
    let spfLevel: Int?
    let notes: String?
    let reapplyCount: Int
    let lastReappliedAt: Date?
    let changedFields: [String]
    let batchKindRawValue: String

    init(revision: DailyRecordRevision) {
        id = revision.id
        batchID = revision.batchID
        createdAt = revision.createdAt
        authorDeviceID = revision.authorDeviceID
        startOfDay = revision.startOfDay
        isDeleted = revision.isDeleted
        verifiedAt = revision.verifiedAt
        methodRawValue = revision.methodRawValue
        verificationDuration = revision.verificationDuration
        spfLevel = revision.spfLevel
        notes = revision.notes
        reapplyCount = revision.reapplyCount
        lastReappliedAt = revision.lastReappliedAt
        changedFields = revision.changedFields.map(\.rawValue).sorted()
        batchKindRawValue = revision.batchKindRawValue
    }
}

struct SettingsRevisionWire: Codable {
    let id: UUID
    let batchID: UUID
    let createdAt: Date
    let authorDeviceID: String
    let snapshot: SettingsProjectionSnapshot
    let changedFields: [String]
    let batchKindRawValue: String

    init(revision: SettingsRevision) {
        id = revision.id
        batchID = revision.batchID
        createdAt = revision.createdAt
        authorDeviceID = revision.authorDeviceID
        snapshot = revision.snapshot
        changedFields = revision.changedFields.map(\.rawValue).sorted()
        batchKindRawValue = revision.batchKindRawValue
    }
}
