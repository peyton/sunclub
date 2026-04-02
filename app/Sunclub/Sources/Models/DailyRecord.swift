import Foundation
import SwiftData

@Model
final class DailyRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var startOfDay: Date
    var verifiedAt: Date
    var methodRawValue: Int
    var verificationDuration: Double?
    var spfLevel: Int?
    var notes: String?

    init(
        startOfDay: Date,
        verifiedAt: Date,
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.startOfDay = startOfDay
        self.verifiedAt = verifiedAt
        self.methodRawValue = method.rawValue
        self.verificationDuration = verificationDuration
        self.spfLevel = spfLevel
        self.notes = notes
    }

    var method: VerificationMethod {
        get { VerificationMethod(rawValue: methodRawValue) ?? .manual }
        set { methodRawValue = newValue.rawValue }
    }
}
