import Foundation
import SwiftData

struct SunclubBackupImportSummary: Equatable {
    let restoredRecordCount: Int
    let exportedAt: Date

    var statusMessage: String {
        let noun = restoredRecordCount == 1 ? "day" : "days"
        return "Imported \(restoredRecordCount) \(noun) from backup."
    }
}

struct SunclubBackupService {
    static let storeFilename = "Sunclub.store"
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func exportDocument(from context: ModelContext) throws -> SunclubBackupDocument {
        let snapshot = try snapshot(from: context)
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { removeItemIfPresent(at: temporaryDirectory) }

        let storeURL = temporaryDirectory.appendingPathComponent(Self.storeFilename)
        try write(snapshot: snapshot, toStoreAt: storeURL)
        let storeFiles = try Self.storeFiles(at: storeURL, fileManager: fileManager)

        return SunclubBackupDocument(
            payload: SunclubBackupPayload(
                createdAt: Date(),
                schemaVersion: "2.0.0",
                storeFiles: storeFiles
            )
        )
    }

    @discardableResult
    func exportBackup(from context: ModelContext, to url: URL) throws -> SunclubBackupDocument {
        let document = try exportDocument(from: context)
        let data = try document.serializedData()
        try data.write(to: url, options: .atomic)
        return document
    }

    func importBackupDocument(_ document: SunclubBackupDocument, into context: ModelContext) throws -> SunclubBackupImportSummary {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { removeItemIfPresent(at: temporaryDirectory) }

        let storeURL = temporaryDirectory.appendingPathComponent(Self.storeFilename)
        try writeStoreFiles(document.payload.storeFiles, toStoreAt: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let importedContext = ModelContext(container)
        let importedSnapshot = try snapshot(from: importedContext)
        try apply(snapshot: importedSnapshot, to: context)

        return SunclubBackupImportSummary(
            restoredRecordCount: importedSnapshot.records.count,
            exportedAt: document.payload.createdAt
        )
    }

    func importBackup(from url: URL, into context: ModelContext) throws -> SunclubBackupImportSummary {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let document = try SunclubBackupDocument(data: data)
        return try importBackupDocument(document, into: context)
    }

    static func storeFiles(at storeURL: URL, fileManager: FileManager = .default) throws -> [SunclubBackupStoreFile] {
        let directoryURL = storeURL.deletingLastPathComponent()
        let prefix = storeURL.lastPathComponent

        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let storeFileURLs = urls
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !storeFileURLs.isEmpty else {
            throw SunclubBackupError.missingStoreFiles
        }

        return try storeFileURLs.map { url in
            SunclubBackupStoreFile(
                filename: url.lastPathComponent,
                data: try Data(contentsOf: url)
            )
        }
    }

    private func snapshot(from context: ModelContext) throws -> SunclubBackupSnapshot {
        let settings = try loadOrCreateSettings(from: context)
        let records = try context.fetch(
            FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .forward)])
        )

        return SunclubBackupSnapshot(
            settings: SunclubBackupSettingsSnapshot(settings: settings),
            records: records.map(SunclubBackupRecordSnapshot.init(record:))
        )
    }

    private func loadOrCreateSettings(from context: ModelContext) throws -> Settings {
        if let existing = try context.fetch(FetchDescriptor<Settings>()).first {
            return existing
        }

        let created = Settings()
        context.insert(created)
        try context.save()
        return created
    }

    private func apply(snapshot: SunclubBackupSnapshot, to context: ModelContext) throws {
        do {
            let settings = try loadOrCreateSettings(from: context)
            snapshot.settings.apply(to: settings)

            let existingRecords = try context.fetch(FetchDescriptor<DailyRecord>())
            for record in existingRecords {
                context.delete(record)
            }

            for record in snapshot.records {
                context.insert(record.makeModel())
            }

            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func write(snapshot: SunclubBackupSnapshot, toStoreAt storeURL: URL) throws {
        do {
            let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
            let context = ModelContext(container)
            try apply(snapshot: snapshot, to: context)
        }
    }

    private func writeStoreFiles(_ storeFiles: [SunclubBackupStoreFile], toStoreAt storeURL: URL) throws {
        let directoryURL = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        for storeFile in storeFiles {
            guard isValid(storeFilename: storeFile.filename) else {
                throw SunclubBackupError.invalidStoreFilename
            }

            let destinationURL = directoryURL.appendingPathComponent(storeFile.filename, isDirectory: false)
            try storeFile.data.write(to: destinationURL, options: .atomic)
        }
    }

    private func isValid(storeFilename: String) -> Bool {
        !storeFilename.isEmpty && storeFilename == URL(fileURLWithPath: storeFilename).lastPathComponent
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeItemIfPresent(at url: URL) {
        try? fileManager.removeItem(at: url)
    }
}

private struct SunclubBackupSnapshot: Equatable {
    let settings: SunclubBackupSettingsSnapshot
    let records: [SunclubBackupRecordSnapshot]
}

private struct SunclubBackupSettingsSnapshot: Equatable {
    let hasCompletedOnboarding: Bool
    let reminderHour: Int
    let reminderMinute: Int
    let weeklyHour: Int
    let weeklyWeekday: Int
    let dailyPhraseState: Data?
    let weeklyPhraseState: Data?
    let smartReminderSettingsData: Data?
    let longestStreak: Int
    let reapplyReminderEnabled: Bool
    let reapplyIntervalMinutes: Int

    init(settings: Settings) {
        hasCompletedOnboarding = settings.hasCompletedOnboarding
        reminderHour = settings.reminderHour
        reminderMinute = settings.reminderMinute
        weeklyHour = settings.weeklyHour
        weeklyWeekday = settings.weeklyWeekday
        dailyPhraseState = settings.dailyPhraseState
        weeklyPhraseState = settings.weeklyPhraseState
        smartReminderSettingsData = settings.smartReminderSettingsData
        longestStreak = settings.longestStreak
        reapplyReminderEnabled = settings.reapplyReminderEnabled
        reapplyIntervalMinutes = settings.reapplyIntervalMinutes
    }

    func apply(to settings: Settings) {
        settings.hasCompletedOnboarding = hasCompletedOnboarding
        settings.reminderHour = reminderHour
        settings.reminderMinute = reminderMinute
        settings.weeklyHour = weeklyHour
        settings.weeklyWeekday = weeklyWeekday
        settings.dailyPhraseState = dailyPhraseState
        settings.weeklyPhraseState = weeklyPhraseState
        settings.smartReminderSettingsData = smartReminderSettingsData
        settings.longestStreak = longestStreak
        settings.reapplyReminderEnabled = reapplyReminderEnabled
        settings.reapplyIntervalMinutes = reapplyIntervalMinutes
    }
}

private struct SunclubBackupRecordSnapshot: Equatable {
    let id: UUID
    let startOfDay: Date
    let verifiedAt: Date
    let methodRawValue: Int
    let verificationDuration: Double?
    let spfLevel: Int?
    let notes: String?

    init(record: DailyRecord) {
        id = record.id
        startOfDay = record.startOfDay
        verifiedAt = record.verifiedAt
        methodRawValue = record.methodRawValue
        verificationDuration = record.verificationDuration
        spfLevel = record.spfLevel
        notes = record.notes
    }

    func makeModel() -> DailyRecord {
        let record = DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            method: VerificationMethod(rawValue: methodRawValue) ?? .manual,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes
        )
        record.id = id
        record.methodRawValue = methodRawValue
        return record
    }
}
