import Foundation
import StoreKit

enum SubscriptionStatus: String, Codable, Equatable {
    case unknown
    case inactive
    case active
}

enum SubscriptionPurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
}

enum SubscriptionManagerError: LocalizedError {
    case missingProductIDs
    case productUnavailable(String)
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .missingProductIDs:
            return "No subscription product identifiers are configured."
        case .productUnavailable(let productID):
            return "Subscription product \(productID) is unavailable."
        case .failedVerification:
            return "StoreKit could not verify the transaction."
        }
    }
}

struct SubscriptionProduct: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
    let periodLabel: String?
    let isFamilyShareable: Bool
}

struct SubscriptionEntitlement: Equatable {
    let productID: String
    let expirationDate: Date?
    let renewalState: String?
    let willAutoRenew: Bool
    let environment: String
}

struct SubscriptionSnapshot: Equatable {
    var status: SubscriptionStatus
    var products: [SubscriptionProduct]
    var entitlement: SubscriptionEntitlement?
    var isLoadingProducts: Bool
    var isProcessingPurchase: Bool
    var lastErrorDescription: String?

    static let empty = SubscriptionSnapshot(
        status: .unknown,
        products: [],
        entitlement: nil,
        isLoadingProducts: false,
        isProcessingPurchase: false,
        lastErrorDescription: nil
    )
}

@MainActor
final class SubscriptionManager {
    private(set) var snapshot = SubscriptionSnapshot.empty {
        didSet {
            onSnapshotChange?(snapshot)
        }
    }

    var onSnapshotChange: ((SubscriptionSnapshot) -> Void)?

    private let productIDs: [String]
    private var productsByID: [String: Product] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?

    init(productIDs: [String]) {
        self.productIDs = productIDs
    }

    func start() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = verificationResult {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }

        Task {
            await refresh()
        }
    }

    func refresh() async {
        await refreshProducts()
        await refreshEntitlements()
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard !productIDs.isEmpty else {
            throw SubscriptionManagerError.missingProductIDs
        }

        if productsByID[productID] == nil {
            await refreshProducts()
        }

        guard let product = productsByID[productID] else {
            throw SubscriptionManagerError.productUnavailable(productID)
        }

        snapshot.isProcessingPurchase = true
        snapshot.lastErrorDescription = nil
        defer {
            snapshot.isProcessingPurchase = false
        }

        let purchaseResult = try await product.purchase()
        switch purchaseResult {
        case .success(let verificationResult):
            let transaction = try checkVerified(verificationResult)
            await transaction.finish()
            await refreshEntitlements()
            return .purchased
        case .pending:
            await refreshEntitlements()
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .pending
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func refreshProducts() async {
        guard !productIDs.isEmpty else {
            productsByID = [:]
            snapshot.products = []
            snapshot.status = .inactive
            snapshot.lastErrorDescription = SubscriptionManagerError.missingProductIDs.localizedDescription
            return
        }

        snapshot.isLoadingProducts = true
        defer {
            snapshot.isLoadingProducts = false
        }

        do {
            let loadedProducts = try await Product.products(for: productIDs)
            let order = Dictionary(uniqueKeysWithValues: productIDs.enumerated().map { ($1, $0) })
            let sortedProducts = loadedProducts.sorted {
                (order[$0.id] ?? .max) < (order[$1.id] ?? .max)
            }

            productsByID = Dictionary(uniqueKeysWithValues: sortedProducts.map { ($0.id, $0) })
            snapshot.products = sortedProducts.map(Self.describeProduct)
            snapshot.lastErrorDescription = nil
        } catch {
            snapshot.products = []
            snapshot.lastErrorDescription = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var entitlements: [SubscriptionEntitlement] = []
        let now = Date()

        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < now {
                continue
            }

            let renewalDetails = await renewalDetails(for: transaction.productID)
            entitlements.append(
                SubscriptionEntitlement(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    renewalState: renewalDetails.state,
                    willAutoRenew: renewalDetails.willAutoRenew,
                    environment: String(describing: transaction.environment)
                )
            )
        }

        let activeEntitlement = entitlements.sorted { lhs, rhs in
            switch (lhs.expirationDate, rhs.expirationDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate > rhsDate
            case (.some, .none):
                return true
            default:
                return lhs.productID < rhs.productID
            }
        }.first

        snapshot.entitlement = activeEntitlement
        snapshot.status = activeEntitlement == nil ? .inactive : .active
    }

    private func renewalDetails(for productID: String) async -> (state: String?, willAutoRenew: Bool) {
        guard let product = productsByID[productID],
              let subscription = product.subscription else {
            return (nil, false)
        }

        do {
            let statuses = try await subscription.status
            for status in statuses {
                guard case .verified(let renewalInfo) = status.renewalInfo else { continue }
                if renewalInfo.currentProductID == productID {
                    return (String(describing: status.state), renewalInfo.willAutoRenew)
                }
            }
        } catch {
            snapshot.lastErrorDescription = error.localizedDescription
        }

        return (nil, false)
    }

    private static func describeProduct(_ product: Product) -> SubscriptionProduct {
        SubscriptionProduct(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            periodLabel: product.subscription.map(periodDescription),
            isFamilyShareable: product.isFamilyShareable
        )
    }

    private static func periodDescription(_ info: Product.SubscriptionInfo) -> String? {
        let unitLabel: String
        switch info.subscriptionPeriod.unit {
        case .day:
            unitLabel = info.subscriptionPeriod.value == 1 ? "day" : "days"
        case .week:
            unitLabel = info.subscriptionPeriod.value == 1 ? "week" : "weeks"
        case .month:
            unitLabel = info.subscriptionPeriod.value == 1 ? "month" : "months"
        case .year:
            unitLabel = info.subscriptionPeriod.value == 1 ? "year" : "years"
        @unknown default:
            unitLabel = "period"
        }

        return "Every \(info.subscriptionPeriod.value) \(unitLabel)"
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            snapshot.lastErrorDescription = SubscriptionManagerError.failedVerification.localizedDescription
            throw SubscriptionManagerError.failedVerification
        }
    }
}
