import Foundation
import SwiftData
import XCTest
@testable import Sunclub

enum LegacyStoreFixture {
    static func seedCommit22ffStore(at storeURL: URL) throws -> (startOfDay: Date, verifiedAt: Date) {
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

extension Calendar {
    static var migrationTestCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
