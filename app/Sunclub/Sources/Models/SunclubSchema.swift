import Foundation
import SwiftData

// Matches the persisted SwiftData schema shipped at commit
// 22ff481b7d43d86600a0a720bf7e09d775e3099f.
enum SunclubSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        Settings.self
    ]

    @Model
    final class DailyRecord {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var startOfDay: Date
        var verifiedAt: Date
        var methodRawValue: Int
        var verificationDuration: Double?
        var spfLevel: Int?
        var notes: String?

        init(
            id: UUID = UUID(),
            startOfDay: Date,
            verifiedAt: Date,
            methodRawValue: Int,
            verificationDuration: Double? = nil,
            spfLevel: Int? = nil,
            notes: String? = nil
        ) {
            self.id = id
            self.startOfDay = startOfDay
            self.verifiedAt = verifiedAt
            self.methodRawValue = methodRawValue
            self.verificationDuration = verificationDuration
            self.spfLevel = spfLevel
            self.notes = notes
        }
    }

    @Model
    final class Settings {
        @Attribute(.unique) var id: UUID
        var hasCompletedOnboarding: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var weeklyHour: Int
        var weeklyWeekday: Int
        var dailyPhraseState: Data?
        var weeklyPhraseState: Data?
        var longestStreak: Int
        var reapplyReminderEnabled: Bool
        var reapplyIntervalMinutes: Int

        init(
            id: UUID = UUID(),
            hasCompletedOnboarding: Bool = false,
            reminderHour: Int = 8,
            reminderMinute: Int = 0,
            weeklyHour: Int = 18,
            weeklyWeekday: Int = 1,
            dailyPhraseState: Data? = nil,
            weeklyPhraseState: Data? = nil,
            longestStreak: Int = 0,
            reapplyReminderEnabled: Bool = false,
            reapplyIntervalMinutes: Int = 120
        ) {
            self.id = id
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.reminderHour = reminderHour
            self.reminderMinute = reminderMinute
            self.weeklyHour = weeklyHour
            self.weeklyWeekday = weeklyWeekday
            self.dailyPhraseState = dailyPhraseState
            self.weeklyPhraseState = weeklyPhraseState
            self.longestStreak = longestStreak
            self.reapplyReminderEnabled = reapplyReminderEnabled
            self.reapplyIntervalMinutes = reapplyIntervalMinutes
        }
    }
}

// Matches the persisted SwiftData schema shipped at commit
// 3f6d2ef0fed82b4587d0a50ec4e92331f6ab6e1e.
enum SunclubSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        Settings.self
    ]

    @Model
    final class DailyRecord {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var startOfDay: Date
        var verifiedAt: Date
        var methodRawValue: Int
        var verificationDuration: Double?
        var spfLevel: Int?
        var notes: String?

        init(
            id: UUID = UUID(),
            startOfDay: Date,
            verifiedAt: Date,
            methodRawValue: Int,
            verificationDuration: Double? = nil,
            spfLevel: Int? = nil,
            notes: String? = nil
        ) {
            self.id = id
            self.startOfDay = startOfDay
            self.verifiedAt = verifiedAt
            self.methodRawValue = methodRawValue
            self.verificationDuration = verificationDuration
            self.spfLevel = spfLevel
            self.notes = notes
        }
    }

    @Model
    final class Settings {
        @Attribute(.unique) var id: UUID
        var hasCompletedOnboarding: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var weeklyHour: Int
        var weeklyWeekday: Int
        var dailyPhraseState: Data?
        var weeklyPhraseState: Data?
        var smartReminderSettingsData: Data?
        var longestStreak: Int
        var reapplyReminderEnabled: Bool
        var reapplyIntervalMinutes: Int

        init(
            id: UUID = UUID(),
            hasCompletedOnboarding: Bool = false,
            reminderHour: Int = 8,
            reminderMinute: Int = 0,
            weeklyHour: Int = 18,
            weeklyWeekday: Int = 1,
            dailyPhraseState: Data? = nil,
            weeklyPhraseState: Data? = nil,
            smartReminderSettingsData: Data? = nil,
            longestStreak: Int = 0,
            reapplyReminderEnabled: Bool = false,
            reapplyIntervalMinutes: Int = 120
        ) {
            self.id = id
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.reminderHour = reminderHour
            self.reminderMinute = reminderMinute
            self.weeklyHour = weeklyHour
            self.weeklyWeekday = weeklyWeekday
            self.dailyPhraseState = dailyPhraseState
            self.weeklyPhraseState = weeklyPhraseState
            self.smartReminderSettingsData = smartReminderSettingsData
            self.longestStreak = longestStreak
            self.reapplyReminderEnabled = reapplyReminderEnabled
            self.reapplyIntervalMinutes = reapplyIntervalMinutes
        }
    }
}

enum SunclubSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        Settings.self
    ]

    @Model
    final class DailyRecord {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var startOfDay: Date
        var verifiedAt: Date
        var methodRawValue: Int
        var verificationDuration: Double?
        var spfLevel: Int?
        var notes: String?
        var reapplyCount: Int = 0
        var lastReappliedAt: Date?

        init(
            id: UUID = UUID(),
            startOfDay: Date,
            verifiedAt: Date,
            methodRawValue: Int,
            verificationDuration: Double? = nil,
            spfLevel: Int? = nil,
            notes: String? = nil,
            reapplyCount: Int = 0,
            lastReappliedAt: Date? = nil
        ) {
            self.id = id
            self.startOfDay = startOfDay
            self.verifiedAt = verifiedAt
            self.methodRawValue = methodRawValue
            self.verificationDuration = verificationDuration
            self.spfLevel = spfLevel
            self.notes = notes
            self.reapplyCount = reapplyCount
            self.lastReappliedAt = lastReappliedAt
        }
    }

    @Model
    final class Settings {
        @Attribute(.unique) var id: UUID
        var hasCompletedOnboarding: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var weeklyHour: Int
        var weeklyWeekday: Int
        var dailyPhraseState: Data?
        var weeklyPhraseState: Data?
        var smartReminderSettingsData: Data?
        var longestStreak: Int
        var reapplyReminderEnabled: Bool
        var reapplyIntervalMinutes: Int
        var lastReminderScheduleAt: Date?
        var usesLiveUV: Bool = false

        init(
            id: UUID = UUID(),
            hasCompletedOnboarding: Bool = false,
            reminderHour: Int = 8,
            reminderMinute: Int = 0,
            weeklyHour: Int = 18,
            weeklyWeekday: Int = 1,
            dailyPhraseState: Data? = nil,
            weeklyPhraseState: Data? = nil,
            smartReminderSettingsData: Data? = nil,
            longestStreak: Int = 0,
            reapplyReminderEnabled: Bool = false,
            reapplyIntervalMinutes: Int = 120,
            lastReminderScheduleAt: Date? = nil,
            usesLiveUV: Bool = false
        ) {
            self.id = id
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.reminderHour = reminderHour
            self.reminderMinute = reminderMinute
            self.weeklyHour = weeklyHour
            self.weeklyWeekday = weeklyWeekday
            self.dailyPhraseState = dailyPhraseState
            self.weeklyPhraseState = weeklyPhraseState
            self.smartReminderSettingsData = smartReminderSettingsData
            self.longestStreak = longestStreak
            self.reapplyReminderEnabled = reapplyReminderEnabled
            self.reapplyIntervalMinutes = reapplyIntervalMinutes
            self.lastReminderScheduleAt = lastReminderScheduleAt
            self.usesLiveUV = usesLiveUV
        }
    }
}

enum SunclubSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)
    static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        SunclubSchemaV4.Settings.self,
        SunclubSchemaV4.SunclubChangeBatch.self,
        SunclubSchemaV4.DailyRecordRevision.self,
        SunclubSchemaV4.SettingsRevision.self,
        CloudSyncPreference.self,
        SunclubSchemaV4.CloudSyncState.self,
        CloudSyncDiagnostic.self,
        SunclubConflictItem.self,
        SunclubImportSession.self
    ]

    // Matches the persisted settings models shipped at commit
    // 3e011f1318e678fe728f6b17d6f3e6036bcc0216.
    @Model
    final class Settings {
        @Attribute(.unique) var id: UUID
        var hasCompletedOnboarding: Bool
        var reminderHour: Int
        var reminderMinute: Int
        var weeklyHour: Int
        var weeklyWeekday: Int
        var dailyPhraseState: Data?
        var weeklyPhraseState: Data?
        var smartReminderSettingsData: Data?
        var longestStreak: Int
        var reapplyReminderEnabled: Bool
        var reapplyIntervalMinutes: Int
        var lastReminderScheduleAt: Date?
        var usesLiveUV: Bool

        init(
            id: UUID = UUID(),
            hasCompletedOnboarding: Bool = false,
            reminderHour: Int = 8,
            reminderMinute: Int = 0,
            weeklyHour: Int = 18,
            weeklyWeekday: Int = 1,
            dailyPhraseState: Data? = nil,
            weeklyPhraseState: Data? = nil,
            smartReminderSettingsData: Data? = nil,
            longestStreak: Int = 0,
            reapplyReminderEnabled: Bool = false,
            reapplyIntervalMinutes: Int = 120,
            lastReminderScheduleAt: Date? = nil,
            usesLiveUV: Bool = false
        ) {
            self.id = id
            self.hasCompletedOnboarding = hasCompletedOnboarding
            self.reminderHour = reminderHour
            self.reminderMinute = reminderMinute
            self.weeklyHour = weeklyHour
            self.weeklyWeekday = weeklyWeekday
            self.dailyPhraseState = dailyPhraseState
            self.weeklyPhraseState = weeklyPhraseState
            self.smartReminderSettingsData = smartReminderSettingsData
            self.longestStreak = longestStreak
            self.reapplyReminderEnabled = reapplyReminderEnabled
            self.reapplyIntervalMinutes = reapplyIntervalMinutes
            self.lastReminderScheduleAt = lastReminderScheduleAt
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
            batch: SunclubSchemaV4.SunclubChangeBatch,
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
}

enum SunclubSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)
    static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        Settings.self,
        SunclubChangeBatch.self,
        DailyRecordRevision.self,
        SettingsRevision.self,
        CloudSyncPreference.self,
        CloudSyncState.self,
        CloudSyncDiagnostic.self,
        SunclubConflictItem.self,
        SunclubImportSession.self
    ]
}

enum SunclubSchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)
    static let models: [any PersistentModel.Type] = SunclubSchemaV5.models + [DepartureCheckInRevision.self]
}

enum SunclubMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        SunclubSchemaV1.self,
        SunclubSchemaV2.self,
        SunclubSchemaV3.self,
        SunclubSchemaV4.self,
        SunclubSchemaV5.self,
        SunclubSchemaV6.self
    ]

    static let stages: [MigrationStage] = [
        .custom(
            fromVersion: SunclubSchemaV1.self,
            toVersion: SunclubSchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                let legacyCameraMethodRawValue = 0

                let settingsDescriptor = FetchDescriptor<SunclubSchemaV2.Settings>()
                for settings in try context.fetch(settingsDescriptor) {
                    settings.smartReminderSettingsData = encodedLegacySmartReminderSettings(
                        hour: settings.reminderHour,
                        minute: settings.reminderMinute
                    )
                }

                let recordDescriptor = FetchDescriptor<SunclubSchemaV2.DailyRecord>()
                for record in try context.fetch(recordDescriptor) where record.methodRawValue == legacyCameraMethodRawValue {
                    record.methodRawValue = VerificationMethod.manual.rawValue
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        ),
        .custom(
            fromVersion: SunclubSchemaV2.self,
            toVersion: SunclubSchemaV3.self,
            willMigrate: nil,
            didMigrate: { context in
                let settingsDescriptor = FetchDescriptor<SunclubSchemaV3.Settings>()
                for settings in try context.fetch(settingsDescriptor) {
                    settings.lastReminderScheduleAt = nil
                    settings.usesLiveUV = false
                }

                let recordDescriptor = FetchDescriptor<SunclubSchemaV3.DailyRecord>()
                for record in try context.fetch(recordDescriptor) {
                    record.reapplyCount = 0
                    record.lastReappliedAt = nil
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        ),
        .custom(
            fromVersion: SunclubSchemaV3.self,
            toVersion: SunclubSchemaV4.self,
            willMigrate: nil,
            didMigrate: { context in
                let settings = try context.fetch(FetchDescriptor<SunclubSchemaV4.Settings>()).first ?? {
                    let settings = SunclubSchemaV4.Settings()
                    context.insert(settings)
                    return settings
                }()

                let preference = try context.fetch(FetchDescriptor<CloudSyncPreference>()).first ?? {
                    let preference = CloudSyncPreference()
                    context.insert(preference)
                    return preference
                }()

                if try context.fetch(FetchDescriptor<SunclubSchemaV4.CloudSyncState>()).isEmpty {
                    context.insert(SunclubSchemaV4.CloudSyncState())
                }

                if try context.fetch(FetchDescriptor<SunclubSchemaV4.SunclubChangeBatch>()).isEmpty {
                    let recordDescriptor = FetchDescriptor<DailyRecord>(
                        sortBy: [SortDescriptor(\.startOfDay, order: .forward)]
                    )
                    let records = try context.fetch(recordDescriptor)
                    let isEmptyDefaultSeed = settings.isDefaultRecoverySeedSettings && records.isEmpty
                    let batch = SunclubSchemaV4.SunclubChangeBatch(
                        kind: .migrationSeed,
                        scope: .timeline,
                        scopeIdentifier: "timeline",
                        authorDeviceID: preference.deviceID,
                        summary: "Migrated the local store to revision history.",
                        isLocalOnly: isEmptyDefaultSeed
                    )
                    context.insert(batch)

                    context.insert(
                        SunclubSchemaV4.SettingsRevision(
                            batch: batch,
                            snapshot: settings.projectionSnapshot,
                            changedFields: [
                                .hasCompletedOnboarding,
                                .reminderHour,
                                .reminderMinute,
                                .weeklyHour,
                                .weeklyWeekday,
                                .dailyPhraseState,
                                .weeklyPhraseState,
                                .smartReminderSettingsData,
                                .reapplyReminderEnabled,
                                .reapplyIntervalMinutes,
                                .usesLiveUV
                            ]
                        )
                    )

                    for record in records {
                        context.insert(
                            SunclubSchemaV4.DailyRecordRevision(
                                batch: batch,
                                snapshot: record.projectionSnapshot,
                                changedFields: [
                                    .verifiedAt,
                                    .methodRawValue,
                                    .verificationDuration,
                                    .spfLevel,
                                    .notes,
                                    .reapplyCount,
                                    .lastReappliedAt
                                ]
                            )
                        )
                    }
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        ),
        .custom(
            fromVersion: SunclubSchemaV4.self,
            toVersion: SunclubSchemaV5.self,
            willMigrate: nil,
            didMigrate: { context in
                let batches = try context.fetch(FetchDescriptor<SunclubChangeBatch>())
                let recordRevisions = try context.fetch(FetchDescriptor<DailyRecordRevision>())
                let settingsRevisions = try context.fetch(FetchDescriptor<SettingsRevision>())
                var orderDateByBatchID = Dictionary(uniqueKeysWithValues: batches.map { ($0.id, $0.createdAt) })
                let persistedBatchIDs = Set(batches.map(\.id))
                let revisionOrderDates = recordRevisions.map { ($0.batchID, $0.createdAt) }
                    + settingsRevisions.map { ($0.batchID, $0.createdAt) }
                for (batchID, createdAt) in revisionOrderDates {
                    if orderDateByBatchID[batchID] == nil {
                        orderDateByBatchID[batchID] = createdAt
                    } else if persistedBatchIDs.contains(batchID) == false,
                              let existingDate = orderDateByBatchID[batchID] {
                        orderDateByBatchID[batchID] = min(existingDate, createdAt)
                    }
                }
                let orderedBatchIDs = orderDateByBatchID.keys.sorted { lhs, rhs in
                    let lhsDate = orderDateByBatchID[lhs] ?? .distantPast
                    let rhsDate = orderDateByBatchID[rhs] ?? .distantPast
                    if lhsDate != rhsDate {
                        return lhsDate < rhsDate
                    }
                    return lhs.uuidString < rhs.uuidString
                }
                let logicalOrderByBatchID = Dictionary(uniqueKeysWithValues: orderedBatchIDs.enumerated().map {
                    ($0.element, Int64($0.offset + 1))
                })

                for batch in batches {
                    batch.logicalOrder = logicalOrderByBatchID[batch.id]
                    batch.serverReceivedAt = nil
                }

                for revision in recordRevisions {
                    revision.logicalOrder = logicalOrderByBatchID[revision.batchID]
                    revision.serverReceivedAt = nil
                }

                for settings in try context.fetch(FetchDescriptor<Settings>()) {
                    settings.selectedUVPlaceData = nil
                    settings.sunscreenProfileData = nil
                    settings.restorablePreferencesData = nil
                }

                for revision in settingsRevisions {
                    revision.logicalOrder = logicalOrderByBatchID[revision.batchID]
                    revision.serverReceivedAt = nil
                    revision.selectedUVPlaceData = nil
                    revision.sunscreenProfileData = nil
                    revision.restorablePreferencesData = nil
                }

                for state in try context.fetch(FetchDescriptor<CloudSyncState>()) {
                    state.unresolvedCloudRecordFailuresData = nil
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        ),
        .lightweight(fromVersion: SunclubSchemaV5.self, toVersion: SunclubSchemaV6.self)
    ]
}

enum SunclubModelContainerFactory {
    static let currentSchema = Schema(versionedSchema: SunclubSchemaV6.self)
    static let sharedStoreFilename = "default.store"

    static func makeSharedContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        if isStoredInMemoryOnly {
            return try makeInMemoryContainer()
        }

        return try makeSharedContainer(storeLocation: sharedStoreLocation())
    }

    static func makeSharedContainer(storeLocation: SunclubStoreLocation) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: currentSchema,
            url: storeLocation.currentStoreURL,
            cloudKitDatabase: .none
        )
        return try makeContainer(configuration: configuration)
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: currentSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try makeContainer(configuration: configuration)
    }

    static func makeDiskBackedContainer(url: URL) throws -> ModelContainer {
        try ensureParentDirectoryExists(for: url)
        let configuration = ModelConfiguration(
            schema: currentSchema,
            url: url,
            cloudKitDatabase: .none
        )
        return try makeContainer(configuration: configuration)
    }

    static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: currentSchema,
            migrationPlan: SunclubMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func sharedStoreLocation(fileManager: FileManager = .default) throws -> SunclubStoreLocation {
        try SunclubStoreLocator(fileManager: fileManager).sharedStoreLocation()
    }

    private static func ensureParentDirectoryExists(for fileURL: URL, fileManager: FileManager = .default) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}

struct SunclubStoreLocation: Equatable {
    let currentStoreURL: URL
    let legacyApplicationSupportStoreURL: URL
    let isUsingAppGroupContainer: Bool
}

struct SunclubStoreLocator {
    private let fileManager: FileManager
    private let appGroupContainerURLProvider: () -> URL?
    private let applicationSupportURLProvider: () throws -> URL

    init(
        fileManager: FileManager = .default,
        appGroupContainerURLProvider: (() -> URL?)? = nil,
        applicationSupportURLProvider: (() throws -> URL)? = nil
    ) {
        self.fileManager = fileManager
        self.appGroupContainerURLProvider = appGroupContainerURLProvider ?? {
            fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: SunclubRuntimeConfiguration.appGroupID
            )
        }
        self.applicationSupportURLProvider = applicationSupportURLProvider ?? {
            try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
    }

    func sharedStoreLocation() throws -> SunclubStoreLocation {
        let applicationSupportURL = try applicationSupportURLProvider()
        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)

        if let groupContainerURL = appGroupContainerURLProvider() {
            try fileManager.createDirectory(at: groupContainerURL, withIntermediateDirectories: true)
            return SunclubStoreLocation(
                currentStoreURL: groupContainerURL.appendingPathComponent(
                    SunclubModelContainerFactory.sharedStoreFilename,
                    isDirectory: false
                ),
                legacyApplicationSupportStoreURL: applicationSupportURL.appendingPathComponent(
                    SunclubModelContainerFactory.sharedStoreFilename,
                    isDirectory: false
                ),
                isUsingAppGroupContainer: true
            )
        }

        let fallbackStoreURL = applicationSupportURL.appendingPathComponent(
            SunclubModelContainerFactory.sharedStoreFilename,
            isDirectory: false
        )
        return SunclubStoreLocation(
            currentStoreURL: fallbackStoreURL,
            legacyApplicationSupportStoreURL: fallbackStoreURL,
            isUsingAppGroupContainer: false
        )
    }
}

private extension Settings {
    var isDefaultRecoverySeedSettings: Bool {
        hasCompletedOnboarding == false
            && reminderHour == 8
            && reminderMinute == 0
            && weeklyHour == 18
            && weeklyWeekday == 1
            && dailyPhraseState == nil
            && weeklyPhraseState == nil
            && smartReminderSettingsData == nil
            && longestStreak == 0
            && reapplyReminderEnabled == false
            && reapplyIntervalMinutes == 120
            && usesLiveUV == false
            && selectedUVPlace == nil
            && sunscreenProfile == nil
            && restorablePreferences == nil
    }
}

private extension SunclubSchemaV4.Settings {
    var projectionSnapshot: SettingsProjectionSnapshot {
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

    var isDefaultRecoverySeedSettings: Bool {
        hasCompletedOnboarding == false
            && reminderHour == 8
            && reminderMinute == 0
            && weeklyHour == 18
            && weeklyWeekday == 1
            && dailyPhraseState == nil
            && weeklyPhraseState == nil
            && smartReminderSettingsData == nil
            && longestStreak == 0
            && reapplyReminderEnabled == false
            && reapplyIntervalMinutes == 120
            && usesLiveUV == false
    }
}

private func encodedLegacySmartReminderSettings(hour: Int, minute: Int) -> Data? {
    try? JSONEncoder().encode(
        SmartReminderSettings.legacyDefault(hour: hour, minute: minute)
    )
}
