import Foundation
import SwiftData

struct ProductStore {
    let context: ModelContext

    func fetchProducts() throws -> [TrackedProduct] {
        let descriptor = FetchDescriptor<TrackedProduct>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).filter { !$0.isArchived }
    }

    @discardableResult
    func createProduct(name: String, barcode: String?) -> TrackedProduct {
        let product = TrackedProduct(name: name, barcode: barcode)
        context.insert(product)
        return product
    }
}
