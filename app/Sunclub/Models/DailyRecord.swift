import Foundation
import SwiftData

@Model
final class DailyRecord {
    @Attribute(.unique) var id: UUID
    var productID: UUID?
    var startOfDay: Date
    var verifiedAt: Date
    var methodRawValue: Int
    var barcode: String?
    var featureDistance: Double?
    var barcodeDistance: Double?
    var verificationDuration: Double?

    init(
        productID: UUID?,
        startOfDay: Date,
        verifiedAt: Date,
        method: VerificationMethod,
        barcode: String? = nil,
        featureDistance: Double? = nil,
        barcodeDistance: Double? = nil,
        verificationDuration: Double? = nil
    ) {
        self.id = UUID()
        self.productID = productID
        self.startOfDay = startOfDay
        self.verifiedAt = verifiedAt
        self.methodRawValue = method.rawValue
        self.barcode = barcode
        self.featureDistance = featureDistance
        self.barcodeDistance = barcodeDistance
        self.verificationDuration = verificationDuration
    }

    var method: VerificationMethod {
        get { VerificationMethod(rawValue: methodRawValue) ?? .barcode }
        set { methodRawValue = newValue.rawValue }
    }
}
