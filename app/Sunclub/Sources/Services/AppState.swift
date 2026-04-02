import Foundation
import Observation
import SwiftData
import WidgetKit

struct HomeTodayCardPresentation: Equatable {
    let title: String
    let detail: String
    let uvHeadline: String?
    let uvSymbolName: String?
}

struct HomeRecoveryAction: Equatable, Identifiable {
    enum Kind: String {
        case logToday
        case backfillYesterday
    }

    let kind: Kind
    let title: String
    let detail: String
    let buttonTitle: String

    var id: Kind { kind }
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

struct ReapplyCheckInPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String
}

enum LiveUVActionKind: Equatable {
    case requestPermission
    case openSettings
    case refresh
}

struct LiveUVStatusPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String?
    let actionKind: LiveUVActionKind?
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
    private let uvIndexService: UVIndexService
    private let backupService: SunclubBackupService
    private let widgetSnapshotStore: SunclubWidgetSnapshotStore
    private(set) var records: [DailyRecord] = []
    private(set) var uvReading: UVReading?
    private(set) var notificationHealthSnapshot: NotificationHealthSnapshot = .unknown
    private let calendar = Calendar.current
    private var uvReadingOverride: UVReading?
    private var notificationHealthOverride: NotificationHealthSnapshot?

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
        uvIndexService: UVIndexService,
        backupService: SunclubBackupService = SunclubBackupService(),
        widgetSnapshotStore: SunclubWidgetSnapshotStore = SunclubWidgetSnapshotStore()
    ) {
        modelContext = context
        verificationStore = VerificationStore(context: context)
        self.notificationManager = notificationManager
        self.uvIndexService = uvIndexService
        self.backupService = backupService
        self.widgetSnapshotStore = widgetSnapshotStore
        settings = Self.loadOrCreateSettings(from: context)
        refresh()
        refreshUVReadingIfNeeded()
        refreshNotificationHealth()
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
        syncWidgetSnapshot()
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
        .reapplyCheckIn
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        save()
        syncWidgetSnapshot()
        reloadWidgetTimelines()
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

    var homeRecoveryActions: [HomeRecoveryAction] {
        var actions: [HomeRecoveryAction] = []

        if record(for: Date()) == nil {
            actions.append(
                HomeRecoveryAction(
                    kind: .logToday,
                    title: "Today is still open",
                    detail: "Log today from Home so the streak keeps moving.",
                    buttonTitle: "Log Today"
                )
            )
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        if record(for: yesterday) == nil {
            actions.append(
                HomeRecoveryAction(
                    kind: .backfillYesterday,
                    title: "Yesterday is missing",
                    detail: "Backfill yesterday without digging into History first.",
                    buttonTitle: "Backfill Yesterday"
                )
            )
        }

        return actions
    }

    var reapplyCheckInPresentation: ReapplyCheckInPresentation? {
        guard settings.reapplyReminderEnabled,
              let todayRecord = record(for: Date()) else {
            return nil
        }

        if todayRecord.reapplyCount > 0 {
            let detail: String
            if let lastReappliedAt = todayRecord.lastReappliedAt {
                detail = "Checked in \(todayRecord.reapplyCount)x today. Last reapply: \(lastReappliedAt.formatted(date: .omitted, time: .shortened))."
            } else {
                detail = "Checked in \(todayRecord.reapplyCount)x today."
            }

            return ReapplyCheckInPresentation(
                title: "Reapply follow-through",
                detail: detail,
                actionTitle: "Log Another Reapply"
            )
        }

        return ReapplyCheckInPresentation(
            title: "Reapply follow-through",
            detail: "When you reapply, check it in here so the reminder loop reflects what actually happened.",
            actionTitle: "Log Reapply"
        )
    }

    var reminderCoachingSuggestions: [ReminderCoachingSuggestion] {
        ReminderCoachingEngine.suggestions(
            from: records,
            settings: settings.smartReminderSettings,
            now: Date(),
            calendar: calendar
        )
    }

    var notificationHealthPresentation: NotificationHealthPresentation? {
        NotificationHealthEvaluator.presentation(
            from: notificationHealthSnapshot,
            onboardingComplete: settings.hasCompletedOnboarding
        )
    }

    var liveUVStatusPresentation: LiveUVStatusPresentation {
        guard settings.usesLiveUV else {
            return LiveUVStatusPresentation(
                title: "Estimated UV",
                detail: "Sunclub is using a local UV estimate and stays fully offline.",
                actionTitle: nil,
                actionKind: nil
            )
        }

        switch uvIndexService.liveUVAccessState {
        case .live:
            return LiveUVStatusPresentation(
                title: "Live UV is on",
                detail: uvReading?.source.statusLabel ?? "Using live WeatherKit UV for the current reading.",
                actionTitle: nil,
                actionKind: nil
            )
        case .needsPermission:
            return LiveUVStatusPresentation(
                title: "Location permission needed",
                detail: "Turn on location access to use WeatherKit when live UV is available. Sunclub will keep using an estimate until then.",
                actionTitle: "Allow Location",
                actionKind: .requestPermission
            )
        case .denied:
            return LiveUVStatusPresentation(
                title: "Location access is off",
                detail: "Open the system Settings app to re-enable location access for live UV. Sunclub is using an estimate right now.",
                actionTitle: "Open Settings",
                actionKind: .openSettings
            )
        case .unavailable:
            return LiveUVStatusPresentation(
                title: "Using estimated UV",
                detail: "WeatherKit or your current location was unavailable, so Sunclub fell back to the local estimate.",
                actionTitle: "Try Again",
                actionKind: .refresh
            )
        case .disabled:
            return LiveUVStatusPresentation(
                title: "Estimated UV",
                detail: "Sunclub is using a local UV estimate and stays fully offline.",
                actionTitle: nil,
                actionKind: nil
            )
        }
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
            refreshStreakRiskReminder()
            reloadWidgetTimelines()
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
            syncWidgetSnapshot()
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

    func recordReapplication(for day: Date = Date()) {
        let targetDay = calendar.startOfDay(for: day)

        guard let existing = try? verificationStore.record(for: targetDay) else {
            return
        }

        existing.reapplyCount += 1
        existing.lastReappliedAt = Date()
        try? modelContext.save()
        refresh()

        if calendar.isDateInToday(targetDay) {
            cancelReapplyRemindersIfNeeded()
        }
        reloadWidgetTimelines()
    }

    func updateLiveUVPreference(enabled: Bool, allowPermissionPrompt: Bool = true) {
        settings.usesLiveUV = enabled
        save()
        refreshUVReadingIfNeeded(allowPermissionPrompt: allowPermissionPrompt)
    }

    func performLiveUVAction(_ action: LiveUVActionKind) {
        switch action {
        case .requestPermission:
            refreshUVReadingIfNeeded(allowPermissionPrompt: true)
        case .openSettings:
            break
        case .refresh:
            refreshUVReadingIfNeeded()
        }
    }

    func applyReminderCoachingSuggestion(_ suggestion: ReminderCoachingSuggestion) {
        updateReminderTime(
            for: suggestion.kind,
            hour: suggestion.suggestedTime.hour,
            minute: suggestion.suggestedTime.minute
        )
    }

    func exportBackupDocument() throws -> SunclubBackupDocument {
        try backupService.exportDocument(from: modelContext)
    }

    @discardableResult
    func exportBackup(to url: URL) throws -> SunclubBackupDocument {
        try backupService.exportBackup(from: modelContext, to: url)
    }

    @discardableResult
    func importBackupDocument(_ document: SunclubBackupDocument) throws -> SunclubBackupImportSummary {
        let summary = try backupService.importBackupDocument(document, into: modelContext)
        finalizeImportedBackup()
        return summary
    }

    @discardableResult
    func importBackup(from url: URL) throws -> SunclubBackupImportSummary {
        let summary = try backupService.importBackup(from: url, into: modelContext)
        finalizeImportedBackup()
        return summary
    }

    func record(for day: Date) -> DailyRecord? {
        (try? verificationStore.record(for: day)).flatMap { $0 }
    }

    func refreshUVReadingIfNeeded(allowPermissionPrompt: Bool = false) {
        if let uvReadingOverride {
            uvReading = uvReadingOverride
            return
        }

        Task {
            await uvIndexService.fetchUVIndex(
                prefersLiveData: settings.usesLiveUV,
                allowPermissionPrompt: allowPermissionPrompt
            )
            guard uvReadingOverride == nil else {
                return
            }
            uvReading = uvIndexService.currentReading
        }
    }

    func setUVReadingForTesting(_ reading: UVReading?) {
        uvReadingOverride = reading
        uvReading = reading
    }

    func refreshNotificationHealth() {
        if let notificationHealthOverride {
            notificationHealthSnapshot = notificationHealthOverride
            return
        }

        Task {
            let snapshot = await notificationManager.notificationHealthSnapshot(using: self)
            guard notificationHealthOverride == nil else {
                return
            }
            notificationHealthSnapshot = snapshot
        }
    }

    func setNotificationHealthSnapshotForTesting(_ snapshot: NotificationHealthSnapshot?) {
        notificationHealthOverride = snapshot
        notificationHealthSnapshot = snapshot ?? .unknown
    }

    func repairReminderSchedule() {
        Task {
            _ = await notificationManager.requestAuthorizationIfNeeded()
            await notificationManager.scheduleReminders(using: self)
            notificationHealthSnapshot = await notificationManager.notificationHealthSnapshot(using: self)
        }
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
                try updateRecord(
                    existing,
                    verifiedAt: verifiedAt,
                    verificationValues: verificationValues,
                    replaceOptionalFields: replaceOptionalFields,
                    preserveExistingDuration: preserveExistingDuration
                )
            } else {
                try insertRecord(
                    for: targetDay,
                    verifiedAt: verifiedAt,
                    verificationValues: verificationValues,
                    replaceOptionalFields: replaceOptionalFields,
                    preserveExistingDuration: preserveExistingDuration
                )
            }
            refresh()
            updateLongestStreak()
            refreshStreakRiskReminder()
            reloadWidgetTimelines()
        } catch {
            modelContext.rollback()
        }
    }

    private func updateRecord(
        _ record: DailyRecord,
        verifiedAt: Date,
        verificationValues: VerificationValues,
        replaceOptionalFields: Bool,
        preserveExistingDuration: Bool
    ) throws {
        let values = resolvedVerificationValues(
            from: verificationValues,
            existingRecord: record,
            preserveExistingDuration: preserveExistingDuration
        )
        apply(
            verificationValues: values,
            to: record,
            verifiedAt: verifiedAt,
            replaceOptionalFields: replaceOptionalFields
        )
        try modelContext.save()
    }

    private func insertRecord(
        for day: Date,
        verifiedAt: Date,
        verificationValues: VerificationValues,
        replaceOptionalFields: Bool,
        preserveExistingDuration: Bool
    ) throws {
        let record = DailyRecord(
            startOfDay: day,
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
            if let existing = try verificationStore.record(for: day) {
                try updateRecord(
                    existing,
                    verifiedAt: verifiedAt,
                    verificationValues: verificationValues,
                    replaceOptionalFields: replaceOptionalFields,
                    preserveExistingDuration: preserveExistingDuration
                )
            } else {
                throw error
            }
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
        CalendarAnalytics.currentStreak(records: recordedDays, now: Date(), calendar: calendar)
    }

    func last7DaysReport() -> WeeklyReport {
        CalendarAnalytics.weeklyReport(records: records.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    func sunscreenUsageInsights(recentNotesLimit: Int = 3) -> SunscreenUsageInsights {
        SunscreenUsageAnalytics.insights(from: records, recentNotesLimit: recentNotesLimit)
    }

    func manualLogSuggestionState(for day: Date) -> ManualLogSuggestionState {
        ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: day,
            calendar: calendar
        )
    }

    func monthlyReviewInsights(for month: Date) -> MonthlyReviewInsights {
        MonthlyReviewAnalytics.insights(
            from: records,
            month: month,
            now: Date(),
            calendar: calendar
        )
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

    var recordedDays: [Date] {
        records.map { calendar.startOfDay(for: $0.startOfDay) }
    }

    private func finalizeImportedBackup() {
        clearVerificationSuccessPresentation()
        refresh()
        cancelReapplyRemindersIfNeeded()
        scheduleReminders()
        refreshStreakRiskReminder()
        refreshNotificationHealth()
        refreshUVReadingIfNeeded()
        reloadWidgetTimelines()
    }

    private func syncWidgetSnapshot() {
        let snapshot = SunclubWidgetSnapshotBuilder.make(
            settings: settings,
            records: records,
            now: Date(),
            calendar: calendar
        )
        widgetSnapshotStore.save(snapshot)
    }

    private func reloadWidgetTimelines() {
        guard !RuntimeEnvironment.isRunningTests else {
            return
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
