import Foundation
import SwiftData

@Model
final class TrainingAsset {
    @Attribute(.unique) var id: UUID
    var productID: UUID
    var capturedAt: Date
    var featurePrintData: Data
    var imageWidth: Int
    var imageHeight: Int

    init(productID: UUID, featurePrintData: Data, imageWidth: Int = 0, imageHeight: Int = 0) {
        self.id = UUID()
        self.productID = productID
        self.capturedAt = Date()
        self.featurePrintData = featurePrintData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}
