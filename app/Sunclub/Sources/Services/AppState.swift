import Foundation
import Observation
import SwiftData

struct VerificationSuccessPresentation: Equatable {
    let streak: Int
    let isPersonalBest: Bool

    init(streak: Int, isPersonalBest: Bool = false) {
        self.streak = streak
        self.isPersonalBest = isPersonalBest
    }

    var detail: String {
        if streak == 1 {
            return "You're on a 1-day streak."
        }

        return "You're on a \(streak)-day streak."
    }
}

@MainActor
@Observable
final class AppState {
    private typealias VerificationValues = (
        method: VerificationMethod,
        duration: Double?,
        spfLevel: Int?,
        notes: String?
    )

    let modelContext: ModelContext
    var settings: Settings
    var verificationSuccessPresentation: VerificationSuccessPresentation?
    private let verificationStore: VerificationStore
    private let notificationManager: NotificationScheduling
    private(set) var records: [DailyRecord] = []
    private let calendar = Calendar.current

    convenience init(context: ModelContext) {
        self.init(context: context, notificationManager: NotificationManager.shared)
    }

    init(context: ModelContext, notificationManager: NotificationScheduling) {
        modelContext = context
        verificationStore = VerificationStore(context: context)
        self.notificationManager = notificationManager
        settings = Self.loadOrCreateSettings(from: context)
        refresh()
    }

    func refresh() {
        do {
            let fetchedRecords = try verificationStore.fetchRecords()
            let didNormalize = normalizeLegacyVerificationMethods(in: fetchedRecords)
            records = fetchedRecords
            if didNormalize {
                save()
            }
        } catch {
            records = []
        }

        syncLongestStreakIfNeeded()
    }

    private static func loadOrCreateSettings(from context: ModelContext) -> Settings {
        let descriptor = FetchDescriptor<Settings>()
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            return first
        }

        let created = Settings()
        context.insert(created)
        try? context.save()
        return created
    }

    func save() {
        try? modelContext.save()
    }

    private func saveAndRescheduleReminders() {
        save()
        Task {
            await notificationManager.scheduleReminders(using: self)
        }
    }

    private func nextPhrase(catalog: [String], state: KeyPath<Settings, Data?>, setState: (Data) -> Void) -> String {
        let next = PhraseRotation.nextPhrase(from: settings[keyPath: state], catalog: catalog)
        setState(next.1)
        save()
        return next.0
    }

    var isUITesting: Bool {
        RuntimeEnvironment.isUITesting
    }

    var preferredCheckInRoute: AppRoute {
        .manualLog
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        save()
    }

    func updateDailyReminder(hour: Int, minute: Int) {
        settings.reminderHour = hour
        settings.reminderMinute = minute
        saveAndRescheduleReminders()
    }

    func updateWeeklyReminder(hour: Int, weekday: Int) {
        settings.weeklyHour = hour
        settings.weeklyWeekday = max(1, min(7, weekday))
        saveAndRescheduleReminders()
    }

    var reminderDate: Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: settings.reminderHour, minute: settings.reminderMinute, second: 0, of: today) ?? today
    }

    func nextDailyPhrase() -> String {
        nextPhrase(catalog: PhraseBank.dailyPhrases, state: \.dailyPhraseState) {
            settings.dailyPhraseState = $0
        }
    }

    func nextWeeklyPhrase() -> String {
        nextPhrase(catalog: PhraseBank.weeklyPhrases, state: \.weeklyPhraseState) {
            settings.weeklyPhraseState = $0
        }
    }

    func markAppliedToday(
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) {
        let now = Date()
        upsertRecord(
            for: now,
            verifiedAt: now,
            verificationValues: (method, verificationDuration, spfLevel, notes),
            replaceOptionalFields: false,
            preserveExistingDuration: false
        )
    }

    func saveManualRecord(
        for day: Date,
        verifiedAt: Date? = nil,
        spfLevel: Int?,
        notes: String?
    ) {
        let existingTimestamp = (try? verificationStore.record(for: day))?.verifiedAt
        let timestamp = verifiedAt ?? existingTimestamp ?? defaultVerifiedAt(for: day)
        upsertRecord(
            for: day,
            verifiedAt: timestamp,
            verificationValues: (.manual, nil, spfLevel, notes),
            replaceOptionalFields: true,
            preserveExistingDuration: true
        )
    }

    func recordVerificationSuccess(
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) {
        let previousLongestStreak = settings.longestStreak
        markAppliedToday(
            method: method,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes
        )
        verificationSuccessPresentation = VerificationSuccessPresentation(
            streak: currentStreak,
            isPersonalBest: currentStreak > previousLongestStreak
        )
    }

    func clearVerificationSuccessPresentation() {
        verificationSuccessPresentation = nil
    }

    func deleteRecord(for day: Date) {
        let target = calendar.startOfDay(for: day)

        if let existing = try? verificationStore.record(for: target) {
            modelContext.delete(existing)
            try? modelContext.save()
            refresh()

            if calendar.isDateInToday(target), (try? verificationStore.record(for: target)) == nil {
                cancelReapplyRemindersIfNeeded()
            }
            updateLongestStreak()
        }
    }

    var longestStreak: Int {
        settings.longestStreak
    }

    private func updateLongestStreak() {
        let streak = currentStreak
        if streak > settings.longestStreak {
            settings.longestStreak = streak
            save()
        }
    }

    func scheduleReapplyReminder() {
        guard settings.reapplyReminderEnabled else { return }
        Task {
            await notificationManager.scheduleReapplyReminder(
                intervalMinutes: settings.reapplyIntervalMinutes,
                route: preferredCheckInRoute
            )
        }
    }

    func updateReapplySettings(enabled: Bool, intervalMinutes: Int) {
        settings.reapplyReminderEnabled = enabled
        settings.reapplyIntervalMinutes = max(30, min(480, intervalMinutes))
        save()

        if !enabled {
            cancelReapplyRemindersIfNeeded()
        }
    }

    func record(for day: Date) -> DailyRecord? {
        (try? verificationStore.record(for: day)).flatMap { $0 }
    }

    private func normalizeLegacyVerificationMethods(in fetchedRecords: [DailyRecord]) -> Bool {
        let legacyMethodRawValue = 0
        var didNormalize = false

        for record in fetchedRecords where record.methodRawValue == legacyMethodRawValue {
            record.method = .manual
            didNormalize = true
        }

        return didNormalize
    }

    private func apply(
        verificationValues: VerificationValues,
        to record: DailyRecord,
        verifiedAt: Date,
        replaceOptionalFields: Bool
    ) {
        record.verifiedAt = verifiedAt
        record.method = verificationValues.method
        record.verificationDuration = verificationValues.duration
        if replaceOptionalFields {
            record.spfLevel = verificationValues.spfLevel
            record.notes = Self.normalizedNotes(verificationValues.notes)
            return
        }

        if let spfLevel = verificationValues.spfLevel {
            record.spfLevel = spfLevel
        }
        if let notes = Self.normalizedNotes(verificationValues.notes) {
            record.notes = notes
        }
    }

    private func upsertRecord(
        for day: Date,
        verifiedAt: Date,
        verificationValues: VerificationValues,
        replaceOptionalFields: Bool,
        preserveExistingDuration: Bool
    ) {
        let targetDay = calendar.startOfDay(for: day)

        do {
            if let existing = try verificationStore.record(for: targetDay) {
                let values = resolvedVerificationValues(
                    from: verificationValues,
                    existingRecord: existing,
                    preserveExistingDuration: preserveExistingDuration
                )
                apply(
                    verificationValues: values,
                    to: existing,
                    verifiedAt: verifiedAt,
                    replaceOptionalFields: replaceOptionalFields
                )
                try modelContext.save()
            } else {
                let record = DailyRecord(
                    startOfDay: targetDay,
                    verifiedAt: verifiedAt,
                    method: verificationValues.method,
                    verificationDuration: verificationValues.duration,
                    spfLevel: verificationValues.spfLevel,
                    notes: Self.normalizedNotes(verificationValues.notes)
                )
                modelContext.insert(record)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    if let existing = try verificationStore.record(for: targetDay) {
                        let values = resolvedVerificationValues(
                            from: verificationValues,
                            existingRecord: existing,
                            preserveExistingDuration: preserveExistingDuration
                        )
                        apply(
                            verificationValues: values,
                            to: existing,
                            verifiedAt: verifiedAt,
                            replaceOptionalFields: replaceOptionalFields
                        )
                        try modelContext.save()
                    } else {
                        throw error
                    }
                }
            }
            refresh()
            updateLongestStreak()
        } catch {
            modelContext.rollback()
        }
    }

    private func resolvedVerificationValues(
        from values: VerificationValues,
        existingRecord: DailyRecord,
        preserveExistingDuration: Bool
    ) -> VerificationValues {
        (
            method: values.method,
            duration: preserveExistingDuration ? (values.duration ?? existingRecord.verificationDuration) : values.duration,
            spfLevel: values.spfLevel,
            notes: values.notes
        )
    }

    private func defaultVerifiedAt(for day: Date) -> Date {
        let targetDay = calendar.startOfDay(for: day)
        let nowComponents = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)

        return calendar.date(
            from: DateComponents(
                year: dayComponents.year,
                month: dayComponents.month,
                day: dayComponents.day,
                hour: nowComponents.hour,
                minute: nowComponents.minute,
                second: nowComponents.second
            )
        ) ?? targetDay
    }

    private static func normalizedNotes(_ notes: String?) -> String? {
        guard let notes else { return nil }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func dayStatus(for date: Date, now: Date = Date()) -> DayStatus {
        let set = Set(records.map { calendar.startOfDay(for: $0.startOfDay) })
        return CalendarAnalytics.status(for: date, with: set, now: now, calendar: calendar)
    }

    func monthGrid(for month: Date) -> [Date] {
        CalendarAnalytics.monthGridDays(for: month, calendar: calendar)
    }

    func isCurrentMonth(_ date: Date, month: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    var currentStreak: Int {
        CalendarAnalytics.currentStreak(records: records.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    func last7DaysReport() -> WeeklyReport {
        CalendarAnalytics.weeklyReport(records: records.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    func recordStartsForTesting() -> [Date] {
        records.map { calendar.startOfDay(for: $0.startOfDay) }
    }

    private func syncLongestStreakIfNeeded() {
        let computed = CalendarAnalytics.longestStreak(records: records.map { $0.startOfDay }, calendar: calendar)
        if computed > settings.longestStreak {
            settings.longestStreak = computed
            save()
        }
    }

    private func cancelReapplyRemindersIfNeeded() {
        Task {
            await notificationManager.cancelReapplyReminders()
        }
    }
}
