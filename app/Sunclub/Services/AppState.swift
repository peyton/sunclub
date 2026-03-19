import Foundation
import Observation
import SwiftData

struct VerificationSuccessPresentation: Equatable {
    let streak: Int

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
    private let subscriptionManager: SubscriptionManager
    private let verificationStore: VerificationStore
    private(set) var records: [DailyRecord] = []
    private(set) var subscriptionStatus: SubscriptionStatus = .unknown
    private(set) var subscriptionProducts: [SubscriptionProduct] = []
    private(set) var subscriptionEntitlement: SubscriptionEntitlement?
    private(set) var isSubscriptionLoading = false
    private(set) var isSubscriptionProcessing = false
    private(set) var subscriptionErrorDescription: String?
    private let calendar = Calendar.current

    init(context: ModelContext) {
        modelContext = context
        subscriptionManager = SubscriptionManager(productIDs: Self.subscriptionProductIDs())
        verificationStore = VerificationStore(context: context)
        settings = Self.loadOrCreateSettings(from: context)

        subscriptionManager.onSnapshotChange = { [weak self] snapshot in
            self?.applySubscriptionSnapshot(snapshot)
        }
        subscriptionManager.start()
        refresh()
    }

    func refresh() {
        do {
            records = try verificationStore.fetchRecords()
        } catch {
            records = []
        }
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
            await NotificationManager.shared.scheduleReminders(using: self)
        }
    }

    private func nextPhrase(catalog: [String], state: KeyPath<Settings, Data?>, setState: (Data) -> Void) -> String {
        let next = PhraseRotation.nextPhrase(from: settings[keyPath: state], catalog: catalog)
        setState(next.1)
        save()
        return next.0
    }

    private func refreshAndSave() {
        refresh()
        save()
    }

    var isUITesting: Bool {
        RuntimeEnvironment.isUITesting
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

    var hasActiveSubscription: Bool {
        subscriptionStatus == .active
    }

    func refreshSubscriptions() {
        Task {
            await subscriptionManager.refresh()
        }
    }

    func purchaseSubscription(productID: String) async throws -> SubscriptionPurchaseOutcome {
        try await subscriptionManager.purchase(productID: productID)
    }

    func restoreSubscriptions() async throws {
        try await subscriptionManager.restorePurchases()
    }

    func markAppliedToday(
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) {
        let now = Date()
        let today = calendar.startOfDay(for: now)

        if let existing = record(for: today) {
            existing.verifiedAt = now
            existing.method = method
            existing.verificationDuration = verificationDuration
            if let spfLevel { existing.spfLevel = spfLevel }
            if let notes { existing.notes = notes }
            refreshAndSave()
            updateLongestStreak()
            return
        }

        let record = DailyRecord(
            startOfDay: today,
            verifiedAt: now,
            method: method,
            verificationDuration: verificationDuration,
            spfLevel: spfLevel,
            notes: notes
        )
        modelContext.insert(record)
        refreshAndSave()
        updateLongestStreak()
    }

    func recordVerificationSuccess(
        method: VerificationMethod,
        verificationDuration: Double? = nil
    ) {
        markAppliedToday(
            method: method,
            verificationDuration: verificationDuration
        )
        verificationSuccessPresentation = VerificationSuccessPresentation(streak: currentStreak)
    }

    func clearVerificationSuccessPresentation() {
        verificationSuccessPresentation = nil
    }

    func deleteRecord(for day: Date) {
        let target = calendar.startOfDay(for: day)
        if let existing = records.first(where: { calendar.isDate($0.startOfDay, inSameDayAs: target) }) {
            modelContext.delete(existing)
            refreshAndSave()
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
            await NotificationManager.shared.scheduleReapplyReminder(
                intervalMinutes: settings.reapplyIntervalMinutes
            )
        }
    }

    func updateReapplySettings(enabled: Bool, intervalMinutes: Int) {
        settings.reapplyReminderEnabled = enabled
        settings.reapplyIntervalMinutes = max(30, min(480, intervalMinutes))
        save()
    }

    func record(for day: Date) -> DailyRecord? {
        let target = calendar.startOfDay(for: day)
        return records.first {
            calendar.isDate($0.startOfDay, inSameDayAs: target)
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
        CalendarAnalytics.currentStreak(records: records.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    func last7DaysReport() -> WeeklyReport {
        CalendarAnalytics.weeklyReport(records: records.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    func recordStartsForTesting() -> [Date] {
        records.map { calendar.startOfDay(for: $0.startOfDay) }
    }

    private static func subscriptionProductIDs() -> [String] {
        guard let configuredIDs = Bundle.main.object(forInfoDictionaryKey: "SunclubSubscriptionProductIDs") as? [String] else {
            return [
                "com.peyton.sunclub.subscription.monthly",
                "com.peyton.sunclub.subscription.annual"
            ]
        }

        return configuredIDs.filter { !$0.isEmpty }
    }

    private func applySubscriptionSnapshot(_ snapshot: SubscriptionSnapshot) {
        subscriptionStatus = snapshot.status
        subscriptionProducts = snapshot.products
        subscriptionEntitlement = snapshot.entitlement
        isSubscriptionLoading = snapshot.isLoadingProducts
        isSubscriptionProcessing = snapshot.isProcessingPurchase
        subscriptionErrorDescription = snapshot.lastErrorDescription
    }
}
