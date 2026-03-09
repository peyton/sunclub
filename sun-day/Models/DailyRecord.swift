import Foundation
import SwiftData

@Model
final class DailyRecord {
    @Attribute(.unique) var id: UUID
    var startOfDay: Date
    var verifiedAt: Date
    var methodRawValue: Int
    var barcode: String?
    var featureDistance: Double?
    var barcodeDistance: Double?

    init(
        startOfDay: Date,
        verifiedAt: Date,
        method: VerificationMethod,
        barcode: String? = nil,
        featureDistance: Double? = nil,
        barcodeDistance: Double? = nil
    ) {
        self.id = UUID()
        self.startOfDay = startOfDay
        self.verifiedAt = verifiedAt
        self.methodRawValue = method.rawValue
        self.barcode = barcode
        self.featureDistance = featureDistance
        self.barcodeDistance = barcodeDistance
    }

    var method: VerificationMethod {
        get { VerificationMethod(rawValue: methodRawValue) ?? .barcode }
        set { methodRawValue = newValue.rawValue }
    }
}
