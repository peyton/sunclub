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

enum SunclubMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        SunclubSchemaV1.self,
        SunclubSchemaV2.self,
        SunclubSchemaV3.self,
        SunclubSchemaV4.self
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
                let settings = try context.fetch(FetchDescriptor<Settings>()).first ?? {
                    let settings = Settings()
                    context.insert(settings)
                    return settings
                }()

                let preference = try context.fetch(FetchDescriptor<CloudSyncPreference>()).first ?? {
                    let preference = CloudSyncPreference()
                    context.insert(preference)
                    return preference
                }()

                if try context.fetch(FetchDescriptor<CloudSyncState>()).isEmpty {
                    context.insert(CloudSyncState())
                }

                if try context.fetch(FetchDescriptor<SunclubChangeBatch>()).isEmpty {
                    let recordDescriptor = FetchDescriptor<DailyRecord>(
                        sortBy: [SortDescriptor(\.startOfDay, order: .forward)]
                    )
                    let records = try context.fetch(recordDescriptor)
                    let isEmptyDefaultSeed = settings.isDefaultRecoverySeedSettings && records.isEmpty
                    let batch = SunclubChangeBatch(
                        kind: .migrationSeed,
                        scope: .timeline,
                        scopeIdentifier: "timeline",
                        authorDeviceID: preference.deviceID,
                        summary: "Migrated the local store to revision history.",
                        isLocalOnly: isEmptyDefaultSeed
                    )
                    context.insert(batch)

                    context.insert(
                        SettingsRevision(
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
                            DailyRecordRevision(
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
        )
    ]
}

enum SunclubModelContainerFactory {
    static let currentSchema = Schema(versionedSchema: SunclubSchemaV4.self)
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
    }
}

private func encodedLegacySmartReminderSettings(hour: Int, minute: Int) -> Data? {
    try? JSONEncoder().encode(
        SmartReminderSettings.legacyDefault(hour: hour, minute: minute)
    )
}
