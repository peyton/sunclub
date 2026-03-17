import Foundation
import SwiftData
import Observation

struct VerificationSuccessPresentation: Equatable {
    let streak: Int
    let productName: String

    var detail: String {
        "\(productName) is now on a \(streak)-day streak"
    }
}

@MainActor
@Observable
final class AppState {
    let modelContext: ModelContext
    var settings: Settings
    var verificationSuccessPresentation: VerificationSuccessPresentation?
    private let subscriptionManager: SubscriptionManager
    private let productStore: ProductStore
    private let verificationStore: VerificationStore
    private let trainingStore: TrainingStore
    private(set) var products: [TrackedProduct] = []
    private(set) var records: [DailyRecord] = []
    private(set) var trainingAssets: [TrainingAsset] = []
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
        productStore = ProductStore(context: context)
        verificationStore = VerificationStore(context: context)
        trainingStore = TrainingStore(context: context)
        settings = Self.loadOrCreateSettings(from: context)

        subscriptionManager.onSnapshotChange = { [weak self] snapshot in
            self?.applySubscriptionSnapshot(snapshot)
        }
        subscriptionManager.start()
        refresh()
    }

    func refresh() {
        do {
            products = try productStore.fetchProducts()
            records = try verificationStore.fetchRecords()
            trainingAssets = try trainingStore.fetchAssets()
            ensureValidActiveProduct()
        } catch {
            products = []
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

    private func ensureValidActiveProduct() {
        guard !products.isEmpty else {
            settings.activeProductID = nil
            return
        }

        if let activeProductID = settings.activeProductID,
           products.contains(where: { $0.id == activeProductID }) {
            return
        }

        settings.activeProductID = products.first?.id
    }

    var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }

    var activeProduct: TrackedProduct? {
        guard let activeProductID = settings.activeProductID else { return nil }
        return products.first { $0.id == activeProductID }
    }

    var hasMultipleProducts: Bool {
        products.count > 1
    }

    var activeTrainingAssets: [TrainingAsset] {
        guard let productID = activeProduct?.id else { return [] }
        return trainingAssets.filter { $0.productID == productID }
    }

    private var activeProductRecords: [DailyRecord] {
        guard let productID = activeProduct?.id else { return [] }
        return records.filter { $0.productID == productID }
    }

    // MARK: - Onboarding and settings
    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        save()
    }

    @discardableResult
    func createProduct(name: String? = nil, barcode: String? = nil) -> TrackedProduct {
        let product = productStore.createProduct(
            name: name ?? defaultProductName(for: barcode),
            barcode: barcode
        )
        settings.activeProductID = product.id
        refreshAndSave()
        return product
    }

    func startNewProduct() {
        _ = createProduct(barcode: nil)
    }

    func setActiveProduct(_ product: TrackedProduct) {
        settings.activeProductID = product.id
        save()
    }

    func updateActiveProductBarcode(_ value: String?) {
        guard let product = activeProduct else {
            _ = createProduct(barcode: value)
            return
        }

        product.barcode = value
        product.updatedAt = Date()
        refreshAndSave()
    }

    func renameActiveProduct(_ name: String) {
        guard let product = activeProduct else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        product.name = trimmed
        product.updatedAt = Date()
        refreshAndSave()
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

    // MARK: - Subscription state
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

    // MARK: - Verification records
    func markAppliedToday(
        method: VerificationMethod,
        barcode: String?,
        featureDistance: Double?,
        barcodeConfidence: Double?,
        verificationDuration: Double? = nil
    ) {
        guard let product = activeProduct else { return }
        let now = Date()
        let today = calendar.startOfDay(for: now)
        if let existing = record(for: today, productID: product.id) {
            existing.verifiedAt = now
            existing.method = method
            existing.barcode = barcode
            existing.featureDistance = featureDistance
            existing.barcodeDistance = barcodeConfidence
            existing.verificationDuration = verificationDuration
            refreshAndSave()
            return
        }

        let record = DailyRecord(
            productID: product.id,
            startOfDay: today,
            verifiedAt: now,
            method: method,
            barcode: barcode,
            featureDistance: featureDistance,
            barcodeDistance: barcodeConfidence,
            verificationDuration: verificationDuration
        )
        modelContext.insert(record)
        refreshAndSave()
    }

    func recordVerificationSuccess(
        method: VerificationMethod,
        barcode: String?,
        featureDistance: Double?,
        barcodeConfidence: Double?,
        verificationDuration: Double? = nil
    ) {
        markAppliedToday(
            method: method,
            barcode: barcode,
            featureDistance: featureDistance,
            barcodeConfidence: barcodeConfidence,
            verificationDuration: verificationDuration
        )
        verificationSuccessPresentation = VerificationSuccessPresentation(
            streak: currentStreak,
            productName: activeProduct?.name ?? "This product"
        )
    }

    func clearVerificationSuccessPresentation() {
        verificationSuccessPresentation = nil
    }

    func record(for day: Date, productID: UUID? = nil) -> DailyRecord? {
        let target = calendar.startOfDay(for: day)
        return records.first {
            calendar.isDate($0.startOfDay, inSameDayAs: target) && $0.productID == productID
        }
    }

    // MARK: - Training assets
    func addTrainingFeature(_ data: Data, width: Int, height: Int) {
        guard let productID = activeProduct?.id else { return }
        let asset = TrainingAsset(productID: productID, featurePrintData: data, imageWidth: width, imageHeight: height)
        modelContext.insert(asset)
        refreshAndSave()
    }

    func clearTrainingDataForActiveProduct() {
        guard let productID = activeProduct?.id else { return }
        trainingAssets.filter { $0.productID == productID }.forEach(modelContext.delete)
        refreshAndSave()
    }

    func hasTrainingData() -> Bool { !activeTrainingAssets.isEmpty }

    func trainingFeatureData() -> [Data] { activeTrainingAssets.map(\.featurePrintData) }

    // MARK: - Calendar logic
    func dayStatus(for date: Date, now: Date = Date()) -> DayStatus {
        let set = Set(activeProductRecords.map { calendar.startOfDay(for: $0.startOfDay) })
        return CalendarAnalytics.status(for: date, with: set, now: now, calendar: calendar)
    }

    func monthGrid(for month: Date) -> [Date] {
        CalendarAnalytics.monthGridDays(for: month, calendar: calendar)
    }

    func isCurrentMonth(_ date: Date, month: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    var currentStreak: Int {
        CalendarAnalytics.currentStreak(records: activeProductRecords.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    func last7DaysReport() -> WeeklyReport {
        CalendarAnalytics.weeklyReport(records: activeProductRecords.map { $0.startOfDay }, now: Date(), calendar: calendar)
    }

    // MARK: - Testing helpers
    func recordStartsForTesting() -> [Date] {
        activeProductRecords.map { calendar.startOfDay(for: $0.startOfDay) }
    }

    private func defaultProductName(for barcode: String?) -> String {
        if let barcode, !barcode.isEmpty {
            return "Sunscreen \(String(barcode.suffix(4)))"
        }
        return "Sunscreen \(products.count + 1)"
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
