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

enum SunclubSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        Settings.self
    ]
}

enum SunclubMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        SunclubSchemaV1.self,
        SunclubSchemaV2.self
    ]

    static let stages: [MigrationStage] = [
        .custom(
            fromVersion: SunclubSchemaV1.self,
            toVersion: SunclubSchemaV2.self,
            willMigrate: nil,
            didMigrate: { context in
                let legacyCameraMethodRawValue = 0

                let settingsDescriptor = FetchDescriptor<Settings>()
                for settings in try context.fetch(settingsDescriptor) {
                    settings.smartReminderSettings = .legacyDefault(
                        hour: settings.reminderHour,
                        minute: settings.reminderMinute
                    )
                }

                let recordDescriptor = FetchDescriptor<DailyRecord>()
                for record in try context.fetch(recordDescriptor) where record.methodRawValue == legacyCameraMethodRawValue {
                    record.method = .manual
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        )
    ]
}

enum SunclubModelContainerFactory {
    static let currentSchema = Schema(versionedSchema: SunclubSchemaV2.self)

    static func makeSharedContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: currentSchema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            groupContainer: .automatic
        )
        return try makeContainer(configuration: configuration)
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: currentSchema, isStoredInMemoryOnly: true)
        return try makeContainer(configuration: configuration)
    }

    static func makeDiskBackedContainer(url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: currentSchema, url: url)
        return try makeContainer(configuration: configuration)
    }

    static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: currentSchema,
            migrationPlan: SunclubMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
