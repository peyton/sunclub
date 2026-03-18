import Foundation
import SwiftData

@Model
final class DailyRecord {
    @Attribute(.unique) var id: UUID
    var startOfDay: Date
    var verifiedAt: Date
    var methodRawValue: Int
    var verificationDuration: Double?

    init(
        startOfDay: Date,
        verifiedAt: Date,
        method: VerificationMethod,
        verificationDuration: Double? = nil
    ) {
        self.id = UUID()
        self.startOfDay = startOfDay
        self.verifiedAt = verifiedAt
        self.methodRawValue = method.rawValue
        self.verificationDuration = verificationDuration
    }

    var method: VerificationMethod {
        get { VerificationMethod(rawValue: methodRawValue) ?? .camera }
        set { methodRawValue = newValue.rawValue }
    }
}
