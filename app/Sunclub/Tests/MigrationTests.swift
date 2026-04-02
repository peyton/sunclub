import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class MigrationTests: XCTestCase {
    func testMigrationFromCommit22ffSchemaBackfillsSmartReminderSettingsAndNormalizesLegacyMethods() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let storeURL = storeDirectory.appendingPathComponent("Sunclub.store")
        let seededDates = try seedCommit22ffStore(at: storeURL)

        let container = try SunclubModelContainerFactory.makeDiskBackedContainer(url: storeURL)
        let context = ModelContext(container)

        let settings = try XCTUnwrap(try context.fetch(FetchDescriptor<Settings>()).first)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.reminderHour, 7)
        XCTAssertEqual(settings.reminderMinute, 45)
        XCTAssertEqual(settings.weeklyHour, 20)
        XCTAssertEqual(settings.weeklyWeekday, 6)
        XCTAssertEqual(settings.dailyPhraseState, Data("daily".utf8))
        XCTAssertEqual(settings.weeklyPhraseState, Data("weekly".utf8))
        XCTAssertEqual(settings.longestStreak, 4)
        XCTAssertTrue(settings.reapplyReminderEnabled)
        XCTAssertEqual(settings.reapplyIntervalMinutes, 90)
        XCTAssertNotNil(settings.smartReminderSettingsData)
        XCTAssertEqual(settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertEqual(settings.smartReminderSettings.weekendTime, ReminderTime(hour: 7, minute: 45))
        XCTAssertTrue(settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertTrue(settings.smartReminderSettings.streakRiskEnabled)
        XCTAssertFalse(settings.smartReminderSettings.anchoredTimeZoneIdentifier.isEmpty)

        let records = try context.fetch(
            FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .forward)])
        )
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(record.startOfDay, seededDates.startOfDay)
        XCTAssertEqual(record.verifiedAt, seededDates.verifiedAt)
        XCTAssertEqual(record.methodRawValue, VerificationMethod.manual.rawValue)
        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.verificationDuration, 1.5)
        XCTAssertEqual(record.spfLevel, 50)
        XCTAssertEqual(record.notes, "Beach day")
    }

    private func seedCommit22ffStore(at storeURL: URL) throws -> (startOfDay: Date, verifiedAt: Date) {
        let schema = Schema(versionedSchema: SunclubSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let settings = SunclubSchemaV1.Settings(
            hasCompletedOnboarding: true,
            reminderHour: 7,
            reminderMinute: 45,
            weeklyHour: 20,
            weeklyWeekday: 6,
            dailyPhraseState: Data("daily".utf8),
            weeklyPhraseState: Data("weekly".utf8),
            longestStreak: 4,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )

        let calendar = Calendar.migrationTestCalendar
        let startOfDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 27, hour: 0, minute: 0, second: 0))
        )
        let verifiedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 27, hour: 10, minute: 15, second: 0))
        )

        let record = SunclubSchemaV1.DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            methodRawValue: 0,
            verificationDuration: 1.5,
            spfLevel: 50,
            notes: "Beach day"
        )

        context.insert(settings)
        context.insert(record)
        try context.save()

        return (startOfDay, verifiedAt)
    }
}

private extension Calendar {
    static var migrationTestCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
