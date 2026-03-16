import Foundation
import SwiftData

@Model
final class TrackedProduct: Identifiable {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var name: String
    var barcode: String?
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        name: String,
        barcode: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.barcode = barcode
        self.isArchived = isArchived
    }
}
