import Foundation
import SwiftData
import WidgetKit

struct SunclubQuickLogResult: Equatable {
    let streak: Int
}

enum SunclubQuickLogError: LocalizedError {
    case onboardingRequired
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .onboardingRequired:
            return "Open Sunclub once to finish setup before using outside-app logging."
        case let .unavailable(message):
            return message
        }
    }
}

@MainActor
enum SunclubQuickLogAction {
    static func performStandalone() throws -> SunclubQuickLogResult {
        do {
            let container = try SunclubModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: false)
            let context = ModelContext(container)
            let calendar = Calendar.current
            let now = Date()
            let today = calendar.startOfDay(for: now)
            let settings = try loadOrCreateSettings(from: context)

            guard settings.hasCompletedOnboarding else {
                throw SunclubQuickLogError.onboardingRequired
            }

            let input = try oneTapInput(for: today, calendar: calendar, in: context)

            try upsertQuickLogRecord(
                for: today,
                verifiedAt: now,
                spfLevel: input.spfLevel,
                notes: input.oneTapNotes,
                in: context
            )

            let records = try fetchRecords(in: context)
            let currentStreak = CalendarAnalytics.currentStreak(
                records: records.map(\.startOfDay),
                now: now,
                calendar: calendar
            )
            settings.longestStreak = max(
                settings.longestStreak,
                CalendarAnalytics.longestStreak(
                    records: records.map(\.startOfDay),
                    calendar: calendar
                )
            )
            try context.save()

            let snapshot = SunclubWidgetSnapshotBuilder.make(
                settings: settings,
                records: records,
                now: now,
                calendar: calendar
            )
            SunclubWidgetSnapshotStore().save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()

            return SunclubQuickLogResult(streak: currentStreak)
        } catch let error as SunclubQuickLogError {
            throw error
        } catch {
            throw SunclubQuickLogError.unavailable(error.localizedDescription)
        }
    }

    private static func loadOrCreateSettings(from context: ModelContext) throws -> Settings {
        let descriptor = FetchDescriptor<Settings>()
        if let settings = try context.fetch(descriptor).first {
            return settings
        }

        let created = Settings()
        context.insert(created)
        try context.save()
        return created
    }

    private static func fetchRecords(in context: ModelContext) throws -> [DailyRecord] {
        let descriptor = FetchDescriptor<DailyRecord>(
            sortBy: [SortDescriptor(\.startOfDay, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private static func oneTapInput(
        for day: Date,
        calendar: Calendar,
        in context: ModelContext
    ) throws -> SunManualLogResolvedDefaults {
        guard try record(for: day, in: context) == nil else {
            return .empty
        }
        return SunManualLogDefaultResolver.oneTapDefaults(
            from: try fetchRecords(in: context),
            excluding: day,
            calendar: calendar
        )
    }

    private static func upsertQuickLogRecord(
        for day: Date,
        verifiedAt: Date,
        spfLevel: Int?,
        notes: String?,
        in context: ModelContext
    ) throws {
        if let existingRecord = try record(for: day, in: context) {
            existingRecord.verifiedAt = verifiedAt
            existingRecord.method = .quickLog
            existingRecord.verificationDuration = nil
        } else {
            context.insert(
                DailyRecord(
                    startOfDay: day,
                    verifiedAt: verifiedAt,
                    method: .quickLog,
                    spfLevel: spfLevel,
                    notes: notes
                )
            )
        }
    }

    private static func record(for day: Date, in context: ModelContext) throws -> DailyRecord? {
        let predicate = #Predicate<DailyRecord> { $0.startOfDay == day }
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startOfDay, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }
}
