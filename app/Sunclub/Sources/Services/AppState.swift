import Foundation
import Observation
import SwiftData

struct HomeTodayCardPresentation: Equatable {
    let title: String
    let detail: String
    let uvHeadline: String?
    let uvSymbolName: String?
}

struct ReapplyReminderPlan: Equatable {
    let baseIntervalMinutes: Int
    let intervalMinutes: Int
    let notificationTitle: String
    let notificationBody: String
    let confirmationText: String
    let isElevated: Bool

    init(baseIntervalMinutes: Int, uvReading: UVReading?) {
        let level = uvReading?.level ?? .unknown
        let adjustedInterval = max(30, baseIntervalMinutes - level.reapplyAdvanceMinutes)
        let isElevated = level.reapplyLabelPrefix != nil

        self.baseIntervalMinutes = baseIntervalMinutes
        self.intervalMinutes = adjustedInterval
        self.isElevated = isElevated
        self.notificationTitle = isElevated ? "Reapply sooner today" : "Time to reapply"

        if let strongerMessage = level.strongerReapplyMessage {
            self.notificationBody = "\(strongerMessage) It's been \(adjustedInterval) minutes — reapply sunscreen for continued protection."
        } else {
            self.notificationBody = "It's been \(adjustedInterval) minutes — reapply sunscreen for continued protection."
        }

        if let prefix = level.reapplyLabelPrefix {
            self.confirmationText = "\(prefix): reminder in \(Self.formattedInterval(adjustedInterval))"
        } else {
            self.confirmationText = "Reapply reminder in \(Self.formattedInterval(adjustedInterval))"
        }
    }

    private static func formattedInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
    }
}

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
    let modelContext: ModelContext
    var settings: Settings
    var verificationSuccessPresentation: VerificationSuccessPresentation?
    private let verificationStore: VerificationStore
    private let notificationManager: NotificationScheduling
    private let uvIndexService: UVIndexService
    private(set) var records: [DailyRecord] = []
    private(set) var uvReading: UVReading?
    private let calendar = Calendar.current
    private var uvReadingOverride: UVReading?

    convenience init(context: ModelContext) {
        self.init(
            context: context,
            notificationManager: NotificationManager.shared,
            uvIndexService: UVIndexService()
        )
    }

    convenience init(
        context: ModelContext,
        notificationManager: NotificationScheduling
    ) {
        self.init(
            context: context,
            notificationManager: notificationManager,
            uvIndexService: UVIndexService()
        )
    }

    init(
        context: ModelContext,
        notificationManager: NotificationScheduling,
        uvIndexService: UVIndexService
    ) {
        modelContext = context
        verificationStore = VerificationStore(context: context)
        self.notificationManager = notificationManager
        self.uvIndexService = uvIndexService
        settings = Self.loadOrCreateSettings(from: context)
        refresh()
        refreshUVReadingIfNeeded()
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
        scheduleReminders()
    }

    func scheduleReminders() {
        Task {
            await notificationManager.scheduleReminders(using: self)
        }
    }

    private func refreshStreakRiskReminder() {
        Task {
            await notificationManager.refreshStreakRiskReminder(using: self)
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
        var reminderSettings = settings.smartReminderSettings
        let reminderTime = ReminderTime(hour: hour, minute: minute)
        reminderSettings.weekdayTime = reminderTime
        reminderSettings.weekendTime = reminderTime
        settings.smartReminderSettings = reminderSettings
        saveAndRescheduleReminders()
    }

    func updateReminderTime(for kind: ReminderScheduleKind, hour: Int, minute: Int) {
        var reminderSettings = settings.smartReminderSettings
        let reminderTime = ReminderTime(hour: hour, minute: minute)

        switch kind {
        case .weekday:
            reminderSettings.weekdayTime = reminderTime
        case .weekend:
            reminderSettings.weekendTime = reminderTime
        }

        settings.smartReminderSettings = reminderSettings
        saveAndRescheduleReminders()
    }

    func updateTravelTimeZoneHandling(followsTravelTimeZone: Bool) {
        var reminderSettings = settings.smartReminderSettings
        reminderSettings.followsTravelTimeZone = followsTravelTimeZone
        if !followsTravelTimeZone {
            reminderSettings.anchoredTimeZoneIdentifier = TimeZone.autoupdatingCurrent.identifier
        }
        settings.smartReminderSettings = reminderSettings
        saveAndRescheduleReminders()
    }

    func updateStreakRiskReminder(enabled: Bool) {
        var reminderSettings = settings.smartReminderSettings
        reminderSettings.streakRiskEnabled = enabled
        settings.smartReminderSettings = reminderSettings
        saveAndRescheduleReminders()
    }

    func updateWeeklyReminder(hour: Int, weekday: Int) {
        settings.weeklyHour = hour
        settings.weeklyWeekday = max(1, min(7, weekday))
        saveAndRescheduleReminders()
    }

    var reminderDate: Date {
        reminderDate(for: ReminderPlanner.scheduleKind(for: Date(), calendar: calendar))
    }

    func reminderDate(for kind: ReminderScheduleKind) -> Date {
        let reminderTime = settings.smartReminderSettings.time(for: kind)
        let today = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: reminderTime.hour, minute: reminderTime.minute, second: 0, of: today) ?? today
    }

    var todayCardPresentation: HomeTodayCardPresentation {
        let hasLoggedToday = record(for: Date()) != nil
        let title = hasLoggedToday ? "Already logged today" : "Ready to log today"
        let defaultDetail = hasLoggedToday
            ? "You can update today's check-in any time. Sunclub will keep just one record for today."
            : "Log today manually to keep your sunscreen routine moving."

        guard let level = uvReading?.level,
              let uvHeadline = level.homeHeadline else {
            return HomeTodayCardPresentation(
                title: title,
                detail: defaultDetail,
                uvHeadline: nil,
                uvSymbolName: nil
            )
        }

        let detail: String
        if reapplyReminderPlan.isElevated {
            detail = hasLoggedToday
                ? "You've logged today. Reapply sooner if you're spending time outside."
                : "Log today manually, then plan to reapply sooner while UV stays elevated."
        } else {
            detail = defaultDetail
        }

        return HomeTodayCardPresentation(
            title: title,
            detail: detail,
            uvHeadline: uvHeadline,
            uvSymbolName: level.symbolName
        )
    }

    var reapplyReminderPlan: ReapplyReminderPlan {
        ReapplyReminderPlan(
            baseIntervalMinutes: settings.reapplyIntervalMinutes,
            uvReading: uvReading
        )
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
        let today = calendar.startOfDay(for: now)
        let normalizedNotes = Self.normalizedNotes(notes)

        do {
            if let existing = try verificationStore.record(for: today) {
                apply(verificationValues: (method, verificationDuration, spfLevel, normalizedNotes), to: existing, verifiedAt: now)
                try modelContext.save()
            } else {
                let record = DailyRecord(
                    startOfDay: today,
                    verifiedAt: now,
                    method: method,
                    verificationDuration: verificationDuration,
                    spfLevel: spfLevel,
                    notes: normalizedNotes
                )
                modelContext.insert(record)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    if let existing = try verificationStore.record(for: today) {
                        apply(verificationValues: (method, verificationDuration, spfLevel, normalizedNotes), to: existing, verifiedAt: now)
                        try modelContext.save()
                    }
                }
            }
            refresh()
            updateLongestStreak()
            refreshStreakRiskReminder()
        } catch {
            modelContext.rollback()
        }
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
            refreshStreakRiskReminder()
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
                plan: reapplyReminderPlan,
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

    func refreshUVReadingIfNeeded() {
        if let uvReadingOverride {
            uvReading = uvReadingOverride
            return
        }

        uvIndexService.fetchUVIndex()
        uvReading = uvIndexService.currentReading
    }

    func setUVReadingForTesting(_ reading: UVReading?) {
        uvReadingOverride = reading
        uvReading = reading
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
        verificationValues: (method: VerificationMethod, duration: Double?, spfLevel: Int?, notes: String?),
        to record: DailyRecord,
        verifiedAt: Date
    ) {
        record.verifiedAt = verifiedAt
        record.method = verificationValues.method
        record.verificationDuration = verificationValues.duration
        if let spfLevel = verificationValues.spfLevel {
            record.spfLevel = spfLevel
        }
        if let notes = verificationValues.notes {
            record.notes = notes
        }
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
        CalendarAnalytics.currentStreak(records: recordedDays, now: Date(), calendar: calendar)
    }

    func last7DaysReport() -> WeeklyReport {
        CalendarAnalytics.weeklyReport(records: records.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    func sunscreenUsageInsights(recentNotesLimit: Int = 3) -> SunscreenUsageInsights {
        SunscreenUsageAnalytics.insights(from: records, recentNotesLimit: recentNotesLimit)
    }

    func recordStartsForTesting() -> [Date] {
        recordedDays
    }

    private func syncLongestStreakIfNeeded() {
        let computed = CalendarAnalytics.longestStreak(records: recordedDays, calendar: calendar)
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

    private static func normalizedNotes(_ notes: String?) -> String? {
        guard let notes else {
            return nil
        }

        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var recordedDays: [Date] {
        records.map { calendar.startOfDay(for: $0.startOfDay) }
    }
}
