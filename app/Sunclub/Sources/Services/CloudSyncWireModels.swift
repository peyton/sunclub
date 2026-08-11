import Foundation

struct BatchWire: Codable {
    let id: UUID
    let createdAt: Date
    let logicalOrder: Int64?
    let kindRawValue: String
    let scopeRawValue: String
    let scopeIdentifier: String
    let authorDeviceID: String
    let summary: String
    let inverseOfBatchID: UUID?
    let undoneByBatchID: UUID?
    var serverReceivedAt: Date?

    init(batch: SunclubChangeBatch) {
        id = batch.id
        createdAt = batch.createdAt
        logicalOrder = batch.logicalOrder
        kindRawValue = batch.kindRawValue
        scopeRawValue = batch.scopeRawValue
        scopeIdentifier = batch.scopeIdentifier
        authorDeviceID = batch.authorDeviceID
        summary = batch.summary
        inverseOfBatchID = batch.inverseOfBatchID
        undoneByBatchID = batch.undoneByBatchID
        serverReceivedAt = batch.serverReceivedAt
    }
}

struct RecordRevisionWire: Codable {
    let id: UUID
    let batchID: UUID
    let createdAt: Date
    let logicalOrder: Int64?
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
    var serverReceivedAt: Date?

    init(revision: DailyRecordRevision) {
        id = revision.id
        batchID = revision.batchID
        createdAt = revision.createdAt
        logicalOrder = revision.logicalOrder
        authorDeviceID = revision.authorDeviceID
        startOfDay = revision.startOfDay
        isDeleted = revision.snapshot == nil
        verifiedAt = revision.verifiedAt
        methodRawValue = revision.methodRawValue
        verificationDuration = revision.verificationDuration
        spfLevel = revision.spfLevel
        notes = revision.notes
        reapplyCount = revision.reapplyCount
        lastReappliedAt = revision.lastReappliedAt
        changedFields = revision.changedFields.map(\.rawValue).sorted()
        batchKindRawValue = revision.batchKindRawValue
        serverReceivedAt = revision.serverReceivedAt
    }
}

struct SettingsRevisionWire: Codable {
    let id: UUID
    let batchID: UUID
    let createdAt: Date
    let logicalOrder: Int64?
    let authorDeviceID: String
    let snapshot: SettingsProjectionSnapshot
    let changedFields: [String]
    let batchKindRawValue: String
    var serverReceivedAt: Date?

    init(revision: SettingsRevision) {
        id = revision.id
        batchID = revision.batchID
        createdAt = revision.createdAt
        logicalOrder = revision.logicalOrder
        authorDeviceID = revision.authorDeviceID
        snapshot = revision.snapshot
        changedFields = revision.changedFields.map(\.rawValue).sorted()
        batchKindRawValue = revision.batchKindRawValue
        serverReceivedAt = revision.serverReceivedAt
    }
}
