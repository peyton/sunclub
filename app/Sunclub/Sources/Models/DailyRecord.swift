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
    var reapplyCount: Int = 0
    var lastReappliedAt: Date? = nil

    init(
        startOfDay: Date,
        verifiedAt: Date,
        method: VerificationMethod,
        verificationDuration: Double? = nil,
        spfLevel: Int? = nil,
        notes: String? = nil,
        reapplyCount: Int = 0,
        lastReappliedAt: Date? = nil
    ) {
        self.id = UUID()
        self.startOfDay = startOfDay
        self.verifiedAt = verifiedAt
        self.methodRawValue = method.rawValue
        self.verificationDuration = verificationDuration
        self.spfLevel = spfLevel
        self.notes = notes
        self.reapplyCount = reapplyCount
        self.lastReappliedAt = lastReappliedAt
    }

    var method: VerificationMethod {
        get { VerificationMethod(rawValue: methodRawValue) ?? .manual }
        set { methodRawValue = newValue.rawValue }
    }

    var trimmedNotes: String? {
        guard let notes else {
            return nil
        }

        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var hasReapplied: Bool {
        reapplyCount > 0
    }

    func loggedDayPart(calendar: Calendar = .current) -> DayPart {
        DayPart.resolve(for: verifiedAt, calendar: calendar)
    }

    func isLogged(in part: DayPart, calendar: Calendar = .current) -> Bool {
        loggedDayPart(calendar: calendar) == part
    }
}
