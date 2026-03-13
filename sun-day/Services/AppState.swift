import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class AppState {
    let modelContext: ModelContext
    var settings: Settings
    private(set) var records: [DailyRecord] = []
    private(set) var trainingAssets: [TrainingAsset] = []
    private let calendar = Calendar.current

    init(context: ModelContext) {
        modelContext = context
        settings = Self.loadOrCreateSettings(from: context)
        refresh()
    }

    func refresh() {
        do {
            let recordDescriptor = FetchDescriptor<DailyRecord>(sortBy: [SortDescriptor(\.startOfDay, order: .reverse)])
            records = try modelContext.fetch(recordDescriptor)

            let assetDescriptor = FetchDescriptor<TrainingAsset>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
            trainingAssets = try modelContext.fetch(assetDescriptor)
        } catch {
            records = []
            trainingAssets = []
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

    // MARK: - Onboarding and settings
    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        save()
    }

    func setExpectedBarcode(_ value: String) {
        settings.expectedBarcode = value
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

    // MARK: - Phrase bag rotation
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

    // MARK: - Verification records
    func markAppliedToday(method: VerificationMethod, barcode: String?, featureDistance: Double?, barcodeConfidence: Double?) {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        if let existing = record(for: today) {
            existing.verifiedAt = now
            existing.method = method
            existing.barcode = barcode
            existing.featureDistance = featureDistance
            existing.barcodeDistance = barcodeConfidence
            refreshAndSave()
            return
        }

        let record = DailyRecord(
            startOfDay: today,
            verifiedAt: now,
            method: method,
            barcode: barcode,
            featureDistance: featureDistance,
            barcodeDistance: barcodeConfidence
        )
        modelContext.insert(record)
        refreshAndSave()
    }

    func record(for day: Date) -> DailyRecord? {
        let target = calendar.startOfDay(for: day)
        return records.first { calendar.isDate($0.startOfDay, inSameDayAs: target) }
    }

    // MARK: - Training assets
    func addTrainingFeature(_ data: Data, width: Int, height: Int) {
        let asset = TrainingAsset(featurePrintData: data, imageWidth: width, imageHeight: height)
        modelContext.insert(asset)
        refreshAndSave()
    }

    func clearTrainingData() {
        trainingAssets.forEach(modelContext.delete)
        refreshAndSave()
    }

    func hasTrainingData() -> Bool { !trainingAssets.isEmpty }

    func trainingFeatureData() -> [Data] { trainingAssets.map(\.featurePrintData) }

    // MARK: - Calendar logic
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

    // MARK: - Testing helpers
    func recordStartsForTesting() -> [Date] {
        records.map { calendar.startOfDay(for: $0.startOfDay) }
    }
}
