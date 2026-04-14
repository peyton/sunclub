import Foundation
import SwiftData
import XCTest
@testable import Sunclub

enum LegacyStoreFixture {
    static func seedCommit22ffStore(at storeURL: URL) throws -> (startOfDay: Date, verifiedAt: Date) {
        let schema = Schema(versionedSchema: SunclubSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
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

    static func seedCurrentV2Store(at storeURL: URL) throws -> (startOfDay: Date, verifiedAt: Date) {
        let schema = Schema(versionedSchema: SunclubSchemaV2.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let settings = SunclubSchemaV2.Settings(
            hasCompletedOnboarding: true,
            reminderHour: 7,
            reminderMinute: 45,
            weeklyHour: 20,
            weeklyWeekday: 6,
            dailyPhraseState: Data("daily".utf8),
            weeklyPhraseState: Data("weekly".utf8),
            smartReminderSettingsData: try JSONEncoder().encode(
                SmartReminderSettings(
                    weekdayTime: ReminderTime(hour: 7, minute: 45),
                    weekendTime: ReminderTime(hour: 8, minute: 30),
                    followsTravelTimeZone: false,
                    anchoredTimeZoneIdentifier: "America/Los_Angeles",
                    streakRiskEnabled: true
                )
            ),
            longestStreak: 4,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90
        )

        let calendar = Calendar.migrationTestCalendar
        let startOfDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 0, minute: 0, second: 0))
        )
        let verifiedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 8, minute: 35, second: 0))
        )

        let record = SunclubSchemaV2.DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            methodRawValue: VerificationMethod.manual.rawValue,
            verificationDuration: nil,
            spfLevel: 50,
            notes: "Morning beach walk"
        )

        context.insert(settings)
        context.insert(record)
        try context.save()

        return (startOfDay, verifiedAt)
    }

    static func seedCurrentV3Store(at storeURL: URL) throws -> (startOfDay: Date, verifiedAt: Date) {
        let schema = Schema(versionedSchema: SunclubSchemaV3.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let settings = SunclubSchemaV3.Settings(
            hasCompletedOnboarding: true,
            reminderHour: 7,
            reminderMinute: 45,
            weeklyHour: 20,
            weeklyWeekday: 6,
            dailyPhraseState: Data("daily".utf8),
            weeklyPhraseState: Data("weekly".utf8),
            smartReminderSettingsData: try JSONEncoder().encode(
                SmartReminderSettings(
                    weekdayTime: ReminderTime(hour: 7, minute: 45),
                    weekendTime: ReminderTime(hour: 8, minute: 30),
                    followsTravelTimeZone: false,
                    anchoredTimeZoneIdentifier: "America/Los_Angeles",
                    streakRiskEnabled: true
                )
            ),
            longestStreak: 4,
            reapplyReminderEnabled: true,
            reapplyIntervalMinutes: 90,
            lastReminderScheduleAt: Date(timeIntervalSince1970: 1_743_199_200),
            usesLiveUV: true
        )

        let calendar = Calendar.migrationTestCalendar
        let startOfDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 0, minute: 0, second: 0))
        )
        let verifiedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 8, minute: 35, second: 0))
        )

        let record = SunclubSchemaV3.DailyRecord(
            startOfDay: startOfDay,
            verifiedAt: verifiedAt,
            methodRawValue: VerificationMethod.manual.rawValue,
            verificationDuration: nil,
            spfLevel: 50,
            notes: "Morning beach walk",
            reapplyCount: 1,
            lastReappliedAt: calendar.date(byAdding: .hour, value: 2, to: verifiedAt)
        )

        context.insert(settings)
        context.insert(record)
        try context.save()

        return (startOfDay, verifiedAt)
    }

    static func seedEmptyCurrentV3Store(at storeURL: URL) throws {
        let schema = Schema(versionedSchema: SunclubSchemaV3.self)
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        context.insert(SunclubSchemaV3.Settings())
        try context.save()
    }
}

extension Calendar {
    static var migrationTestCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
