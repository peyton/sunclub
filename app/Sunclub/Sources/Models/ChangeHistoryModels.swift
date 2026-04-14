import Foundation
import SwiftData

enum SunclubChangeKind: String, Codable, CaseIterable, Sendable {
    case migrationSeed
    case onboarding
    case manualLog
    case historyEdit
    case historyBackfill
    case deleteRecord
    case reapply
    case reminderSettings
    case weeklyReminder
    case reapplySettings
    case liveUVSettings
    case phraseRotation
    case importRestorePoint
    case importLocal
    case importPublish
    case conflictAutoMerge
    case undo
    case redo
    case restore
    case legacyStoreRecovery

    var displayTitle: String {
        switch self {
        case .migrationSeed:
            return "Migration Seed"
        case .onboarding:
            return "Completed Onboarding"
        case .manualLog:
            return "Logged Sunscreen"
        case .historyEdit:
            return "Edited Day"
        case .historyBackfill:
            return "Backfilled Day"
        case .deleteRecord:
            return "Deleted Day"
        case .reapply:
            return "Logged Reapply"
        case .reminderSettings:
            return "Updated Reminder Settings"
        case .weeklyReminder:
            return "Updated Weekly Reminder"
        case .reapplySettings:
            return "Updated Reapply Settings"
        case .liveUVSettings:
            return "Updated UV Settings"
        case .phraseRotation:
            return "Updated Phrase History"
        case .importRestorePoint:
            return "Saved Restore Point"
        case .importLocal:
            return "Imported Local Backup"
        case .importPublish:
            return "Published Imported Changes"
        case .conflictAutoMerge:
            return "Auto-Merged Conflict"
        case .undo:
            return "Undo"
        case .redo:
            return "Redo"
        case .restore:
            return "Restore"
        case .legacyStoreRecovery:
            return "Recovered Legacy Store"
        }
    }
}

enum SunclubBatchScope: String, Codable, Sendable {
    case settings
    case day
    case timeline
}

enum SunclubTrackedField: String, Codable, CaseIterable, Sendable {
    case isDeleted
    case verifiedAt
    case methodRawValue
    case verificationDuration
    case spfLevel
    case notes
    case reapplyCount
    case lastReappliedAt
    case hasCompletedOnboarding
    case reminderHour
    case reminderMinute
    case weeklyHour
    case weeklyWeekday
    case dailyPhraseState
    case weeklyPhraseState
    case smartReminderSettingsData
    case reapplyReminderEnabled
    case reapplyIntervalMinutes
    case usesLiveUV
}

enum CloudSyncStatus: String, Codable, Sendable {
    case idle
    case syncing
    case paused
    case error
}

enum SunclubConflictScope: String, Codable, Sendable {
    case settings
    case day
}

enum CloudSyncDiagnosticLevel: String, Codable, Sendable {
    case info
    case warning
    case error
}

struct DailyRecordProjectionSnapshot: Codable, Equatable, Sendable {
    var startOfDay: Date
    var verifiedAt: Date
    var methodRawValue: Int
    var verificationDuration: Double?
    var spfLevel: Int?
    var notes: String?
    var reapplyCount: Int
    var lastReappliedAt: Date?

    var method: VerificationMethod {
        VerificationMethod(rawValue: methodRawValue) ?? .manual
    }

    init(record: DailyRecord) {
        startOfDay = record.startOfDay
        verifiedAt = record.verifiedAt
        methodRawValue = record.methodRawValue
        verificationDuration = record.verificationDuration
        spfLevel = record.spfLevel
        notes = record.notes
        reapplyCount = record.reapplyCount
        lastReappliedAt = record.lastReappliedAt
    }

    init(
        startOfDay: Date,
        verifiedAt: Date,
        methodRawValue: Int,
        verificationDuration: Double?,
        spfLevel: Int?,
        notes: String?,
        reapplyCount: Int,
        lastReappliedAt: Date?
    ) {
        self.startOfDay = startOfDay
        self.verifiedAt = verifiedAt
        self.methodRawValue = methodRawValue
        self.verificationDuration = verificationDuration
        self.spfLevel = spfLevel
        self.notes = notes
        self.reapplyCount = reapplyCount
        self.lastReappliedAt = lastReappliedAt
    }

    func makeModel() -> DailyRecord {
        DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            method: method,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes,
            reapplyCount: reapplyCount,
            lastReappliedAt: lastReappliedAt
        )
    }
}

struct SettingsProjectionSnapshot: Codable, Equatable, Sendable {
    var hasCompletedOnboarding: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var weeklyHour: Int
    var weeklyWeekday: Int
    var dailyPhraseState: Data?
    var weeklyPhraseState: Data?
    var smartReminderSettingsData: Data?
    var reapplyReminderEnabled: Bool
    var reapplyIntervalMinutes: Int
    var usesLiveUV: Bool

    init(settings: Settings) {
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        reminderHour = settings.reminderHour
        reminderMinute = settings.reminderMinute
        weeklyHour = settings.weeklyHour
        weeklyWeekday = settings.weeklyWeekday
        dailyPhraseState = settings.dailyPhraseState
        weeklyPhraseState = settings.weeklyPhraseState
        smartReminderSettingsData = settings.smartReminderSettingsData
        reapplyReminderEnabled = settings.reapplyReminderEnabled
        reapplyIntervalMinutes = settings.reapplyIntervalMinutes
        usesLiveUV = settings.usesLiveUV
    }

    init(
        hasCompletedOnboarding: Bool,
        reminderHour: Int,
        reminderMinute: Int,
        weeklyHour: Int,
        weeklyWeekday: Int,
        dailyPhraseState: Data?,
        weeklyPhraseState: Data?,
        smartReminderSettingsData: Data?,
        reapplyReminderEnabled: Bool,
        reapplyIntervalMinutes: Int,
        usesLiveUV: Bool
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.weeklyHour = weeklyHour
        self.weeklyWeekday = weeklyWeekday
        self.dailyPhraseState = dailyPhraseState
        self.weeklyPhraseState = weeklyPhraseState
        self.smartReminderSettingsData = smartReminderSettingsData
        self.reapplyReminderEnabled = reapplyReminderEnabled
        self.reapplyIntervalMinutes = reapplyIntervalMinutes
        self.usesLiveUV = usesLiveUV
    }
}

@Model
final class SunclubChangeBatch {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var kindRawValue: String
    var scopeRawValue: String
    var scopeIdentifier: String
    var authorDeviceID: String
    var summary: String
    var isLocalOnly: Bool
    var isPublishedToCloud: Bool
    var cloudPublishedAt: Date?
    var inverseOfBatchID: UUID?
    var undoneByBatchID: UUID?
    var importSessionID: UUID?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: SunclubChangeKind,
        scope: SunclubBatchScope,
        scopeIdentifier: String,
        authorDeviceID: String,
        summary: String,
        isLocalOnly: Bool = false,
        isPublishedToCloud: Bool = false,
        cloudPublishedAt: Date? = nil,
        inverseOfBatchID: UUID? = nil,
        undoneByBatchID: UUID? = nil,
        importSessionID: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kindRawValue = kind.rawValue
        self.scopeRawValue = scope.rawValue
        self.scopeIdentifier = scopeIdentifier
        self.authorDeviceID = authorDeviceID
        self.summary = summary
        self.isLocalOnly = isLocalOnly
        self.isPublishedToCloud = isPublishedToCloud
        self.cloudPublishedAt = cloudPublishedAt
        self.inverseOfBatchID = inverseOfBatchID
        self.undoneByBatchID = undoneByBatchID
        self.importSessionID = importSessionID
    }

    var kind: SunclubChangeKind {
        get { SunclubChangeKind(rawValue: kindRawValue) ?? .manualLog }
        set { kindRawValue = newValue.rawValue }
    }

    var scope: SunclubBatchScope {
        get { SunclubBatchScope(rawValue: scopeRawValue) ?? .timeline }
        set { scopeRawValue = newValue.rawValue }
    }
}

@Model
final class DailyRecordRevision {
    @Attribute(.unique) var id: UUID
    var batchID: UUID
    var createdAt: Date
    var authorDeviceID: String
    var startOfDay: Date
    var isDeleted: Bool
    var verifiedAt: Date?
    var methodRawValue: Int?
    var verificationDuration: Double?
    var spfLevel: Int?
    var notes: String?
    var reapplyCount: Int
    var lastReappliedAt: Date?
    var changedFieldsData: Data?
    var batchKindRawValue: String

    init(
        id: UUID = UUID(),
        batchID: UUID,
        createdAt: Date,
        authorDeviceID: String,
        startOfDay: Date,
        isDeleted: Bool,
        verifiedAt: Date?,
        methodRawValue: Int?,
        verificationDuration: Double?,
        spfLevel: Int?,
        notes: String?,
        reapplyCount: Int,
        lastReappliedAt: Date?,
        changedFields: Set<SunclubTrackedField>,
        batchKind: SunclubChangeKind
    ) {
        self.id = id
        self.batchID = batchID
        self.createdAt = createdAt
        self.authorDeviceID = authorDeviceID
        self.startOfDay = startOfDay
        self.isDeleted = isDeleted
        self.verifiedAt = verifiedAt
        self.methodRawValue = methodRawValue
        self.verificationDuration = verificationDuration
        self.spfLevel = spfLevel
        self.notes = notes
        self.reapplyCount = reapplyCount
        self.lastReappliedAt = lastReappliedAt
        self.changedFieldsData = try? JSONEncoder().encode(Array(changedFields).map(\.rawValue).sorted())
        self.batchKindRawValue = batchKind.rawValue
    }

    convenience init(
        batch: SunclubChangeBatch,
        snapshot: DailyRecordProjectionSnapshot,
        changedFields: Set<SunclubTrackedField>
    ) {
        self.init(
            batchID: batch.id,
            createdAt: batch.createdAt,
            authorDeviceID: batch.authorDeviceID,
            startOfDay: snapshot.startOfDay,
            isDeleted: false,
            verifiedAt: snapshot.verifiedAt,
            methodRawValue: snapshot.methodRawValue,
            verificationDuration: snapshot.verificationDuration,
            spfLevel: snapshot.spfLevel,
            notes: snapshot.notes,
            reapplyCount: snapshot.reapplyCount,
            lastReappliedAt: snapshot.lastReappliedAt,
            changedFields: changedFields,
            batchKind: batch.kind
        )
    }

    convenience init(
        deletedDay startOfDay: Date,
        batch: SunclubChangeBatch,
        changedFields: Set<SunclubTrackedField> = [.isDeleted]
    ) {
        self.init(
            batchID: batch.id,
            createdAt: batch.createdAt,
            authorDeviceID: batch.authorDeviceID,
            startOfDay: startOfDay,
            isDeleted: true,
            verifiedAt: nil,
            methodRawValue: nil,
            verificationDuration: nil,
            spfLevel: nil,
            notes: nil,
            reapplyCount: 0,
            lastReappliedAt: nil,
            changedFields: changedFields,
            batchKind: batch.kind
        )
    }

    var changedFields: Set<SunclubTrackedField> {
        guard let changedFieldsData,
              let decoded = try? JSONDecoder().decode([String].self, from: changedFieldsData) else {
            return []
        }

        return Set(decoded.compactMap(SunclubTrackedField.init(rawValue:)))
    }

    var batchKind: SunclubChangeKind {
        SunclubChangeKind(rawValue: batchKindRawValue) ?? .manualLog
    }

    var snapshot: DailyRecordProjectionSnapshot? {
        guard !isDeleted,
              let verifiedAt,
              let methodRawValue else {
            return nil
        }

        return DailyRecordProjectionSnapshot(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            methodRawValue: methodRawValue,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes,
            reapplyCount: reapplyCount,
            lastReappliedAt: lastReappliedAt
        )
    }
}

@Model
final class SettingsRevision {
    @Attribute(.unique) var id: UUID
    var batchID: UUID
    var createdAt: Date
    var authorDeviceID: String
    var hasCompletedOnboarding: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var weeklyHour: Int
    var weeklyWeekday: Int
    var dailyPhraseState: Data?
    var weeklyPhraseState: Data?
    var smartReminderSettingsData: Data?
    var reapplyReminderEnabled: Bool
    var reapplyIntervalMinutes: Int
    var usesLiveUV: Bool
    var changedFieldsData: Data?
    var batchKindRawValue: String

    init(
        id: UUID = UUID(),
        batchID: UUID,
        createdAt: Date,
        authorDeviceID: String,
        snapshot: SettingsProjectionSnapshot,
        changedFields: Set<SunclubTrackedField>,
        batchKind: SunclubChangeKind
    ) {
        self.id = id
        self.batchID = batchID
        self.createdAt = createdAt
        self.authorDeviceID = authorDeviceID
        self.hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        self.reminderHour = snapshot.reminderHour
        self.reminderMinute = snapshot.reminderMinute
        self.weeklyHour = snapshot.weeklyHour
        self.weeklyWeekday = snapshot.weeklyWeekday
        self.dailyPhraseState = snapshot.dailyPhraseState
        self.weeklyPhraseState = snapshot.weeklyPhraseState
        self.smartReminderSettingsData = snapshot.smartReminderSettingsData
        self.reapplyReminderEnabled = snapshot.reapplyReminderEnabled
        self.reapplyIntervalMinutes = snapshot.reapplyIntervalMinutes
        self.usesLiveUV = snapshot.usesLiveUV
        self.changedFieldsData = try? JSONEncoder().encode(Array(changedFields).map(\.rawValue).sorted())
        self.batchKindRawValue = batchKind.rawValue
    }

    convenience init(
        batch: SunclubChangeBatch,
        snapshot: SettingsProjectionSnapshot,
        changedFields: Set<SunclubTrackedField>
    ) {
        self.init(
            batchID: batch.id,
            createdAt: batch.createdAt,
            authorDeviceID: batch.authorDeviceID,
            snapshot: snapshot,
            changedFields: changedFields,
            batchKind: batch.kind
        )
    }

    var changedFields: Set<SunclubTrackedField> {
        guard let changedFieldsData,
              let decoded = try? JSONDecoder().decode([String].self, from: changedFieldsData) else {
            return []
        }

        return Set(decoded.compactMap(SunclubTrackedField.init(rawValue:)))
    }

    var batchKind: SunclubChangeKind {
        SunclubChangeKind(rawValue: batchKindRawValue) ?? .reminderSettings
    }

    var snapshot: SettingsProjectionSnapshot {
        SettingsProjectionSnapshot(
            hasCompletedOnboarding: hasCompletedOnboarding,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            weeklyHour: weeklyHour,
            weeklyWeekday: weeklyWeekday,
            dailyPhraseState: dailyPhraseState,
            weeklyPhraseState: weeklyPhraseState,
            smartReminderSettingsData: smartReminderSettingsData,
            reapplyReminderEnabled: reapplyReminderEnabled,
            reapplyIntervalMinutes: reapplyIntervalMinutes,
            usesLiveUV: usesLiveUV
        )
    }
}

@Model
final class CloudSyncPreference {
    @Attribute(.unique) var id: UUID
    var isICloudSyncEnabled: Bool
    var deviceID: String
    var lastSyncAt: Date?
    var lastSyncErrorDescription: String?
    var statusRawValue: String

    init(
        id: UUID = UUID(),
        isICloudSyncEnabled: Bool = true,
        deviceID: String = UUID().uuidString,
        lastSyncAt: Date? = nil,
        lastSyncErrorDescription: String? = nil,
        status: CloudSyncStatus = .idle
    ) {
        self.id = id
        self.isICloudSyncEnabled = isICloudSyncEnabled
        self.deviceID = deviceID
        self.lastSyncAt = lastSyncAt
        self.lastSyncErrorDescription = lastSyncErrorDescription
        self.statusRawValue = status.rawValue
    }

    var status: CloudSyncStatus {
        get { CloudSyncStatus(rawValue: statusRawValue) ?? .idle }
        set { statusRawValue = newValue.rawValue }
    }
}

@Model
final class CloudSyncState {
    @Attribute(.unique) var id: UUID
    var stateSerializationData: Data?

    init(id: UUID = UUID(), stateSerializationData: Data? = nil) {
        self.id = id
        self.stateSerializationData = stateSerializationData
    }
}

@Model
final class CloudSyncDiagnostic {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var levelRawValue: String
    var message: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        level: CloudSyncDiagnosticLevel,
        message: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.levelRawValue = level.rawValue
        self.message = message
    }

    var level: CloudSyncDiagnosticLevel {
        CloudSyncDiagnosticLevel(rawValue: levelRawValue) ?? .info
    }
}

@Model
final class SunclubConflictItem {
    @Attribute(.unique) var id: UUID
    var scopeRawValue: String
    var scopeIdentifier: String
    var createdAt: Date
    var resolvedAt: Date?
    var summary: String
    var mergedBatchID: UUID
    var competingBatchIDsData: Data?

    init(
        id: UUID = UUID(),
        scope: SunclubConflictScope,
        scopeIdentifier: String,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil,
        summary: String,
        mergedBatchID: UUID,
        competingBatchIDs: [UUID]
    ) {
        self.id = id
        self.scopeRawValue = scope.rawValue
        self.scopeIdentifier = scopeIdentifier
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.summary = summary
        self.mergedBatchID = mergedBatchID
        self.competingBatchIDsData = try? JSONEncoder().encode(competingBatchIDs)
    }

    var scope: SunclubConflictScope {
        SunclubConflictScope(rawValue: scopeRawValue) ?? .day
    }

    var competingBatchIDs: [UUID] {
        guard let competingBatchIDsData,
              let decoded = try? JSONDecoder().decode([UUID].self, from: competingBatchIDsData) else {
            return []
        }

        return decoded
    }

    var isResolved: Bool {
        resolvedAt != nil
    }
}

@Model
final class SunclubImportSession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var sourceDescription: String
    var restorePointBatchID: UUID
    var importedBatchIDsData: Data?
    var publishRequestedAt: Date?
    var publishedAt: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceDescription: String,
        restorePointBatchID: UUID,
        importedBatchIDs: [UUID] = [],
        publishRequestedAt: Date? = nil,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceDescription = sourceDescription
        self.restorePointBatchID = restorePointBatchID
        self.importedBatchIDsData = try? JSONEncoder().encode(importedBatchIDs)
        self.publishRequestedAt = publishRequestedAt
        self.publishedAt = publishedAt
    }

    var importedBatchIDs: [UUID] {
        guard let importedBatchIDsData,
              let decoded = try? JSONDecoder().decode([UUID].self, from: importedBatchIDsData) else {
            return []
        }

        return decoded
    }

    func setImportedBatchIDs(_ batchIDs: [UUID]) {
        importedBatchIDsData = try? JSONEncoder().encode(batchIDs)
    }
}

extension DailyRecord {
    var projectionSnapshot: DailyRecordProjectionSnapshot {
        DailyRecordProjectionSnapshot(record: self)
    }

    func apply(snapshot: DailyRecordProjectionSnapshot) {
        startOfDay = snapshot.startOfDay
        verifiedAt = snapshot.verifiedAt
        methodRawValue = snapshot.methodRawValue
        verificationDuration = snapshot.verificationDuration
        spfLevel = snapshot.spfLevel
        notes = snapshot.notes
        reapplyCount = snapshot.reapplyCount
        lastReappliedAt = snapshot.lastReappliedAt
    }
}

extension Settings {
    var projectionSnapshot: SettingsProjectionSnapshot {
        SettingsProjectionSnapshot(settings: self)
    }

    func apply(snapshot: SettingsProjectionSnapshot) {
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        reminderHour = snapshot.reminderHour
        reminderMinute = snapshot.reminderMinute
        weeklyHour = snapshot.weeklyHour
        weeklyWeekday = snapshot.weeklyWeekday
        dailyPhraseState = snapshot.dailyPhraseState
        weeklyPhraseState = snapshot.weeklyPhraseState
        smartReminderSettingsData = snapshot.smartReminderSettingsData
        reapplyReminderEnabled = snapshot.reapplyReminderEnabled
        reapplyIntervalMinutes = snapshot.reapplyIntervalMinutes
        usesLiveUV = snapshot.usesLiveUV
    }
}
