import Foundation
import SwiftData

enum DepartureCheckInResolution: String, Codable, Sendable {
    case unconfirmed
    case confirmed
    case dismissed
}

/// A check-in is evidence of a departure, never evidence of sunscreen use.
struct DepartureCheckInSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let day: Date
    let departedAt: Date
    var resolution: DepartureCheckInResolution = .unconfirmed
    var snoozedUntil: Date?
    var linkedApplicationAt: Date?

    /// `day` remains the immutable revision key. Presentation follows the departure's
    /// actual timestamp so moving time zones cannot shift a midnight key to yesterday.
    func isOnDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(departedAt, inSameDayAs: date)
    }

    func isActive(at now: Date, calendar: Calendar = .current) -> Bool {
        resolution == .unconfirmed && isOnDay(now, calendar: calendar)
            && (snoozedUntil.map { $0 <= now } ?? true)
    }
}

/// Immutable revisions travel with their existing ChangeBatch cloud record. Keeping the
/// payload separate avoids changing any shipped persisted model or counting departures as logs.
@Model
final class DepartureCheckInRevision {
    @Attribute(.unique) var id: UUID
    var batchID: UUID
    var day: Date
    var snapshotData: Data?

    init(id: UUID = UUID(), batchID: UUID, day: Date, snapshot: DepartureCheckInSnapshot?) throws {
        self.id = id
        self.batchID = batchID
        self.day = day
        self.snapshotData = try snapshot.map { try JSONEncoder().encode($0) }
    }

    var snapshot: DepartureCheckInSnapshot? {
        get throws {
            try snapshotData.map { try JSONDecoder().decode(DepartureCheckInSnapshot.self, from: $0) }
        }
    }
}

struct DepartureCheckInRevisionWire: Codable {
    let id: UUID
    let batchID: UUID
    let day: Date
    let snapshot: DepartureCheckInSnapshot?

    init(revision: DepartureCheckInRevision) throws {
        id = revision.id
        batchID = revision.batchID
        day = revision.day
        snapshot = try revision.snapshot
    }
}

enum DepartureCheckInAction: Sendable {
    case dismiss
    case snooze(until: Date)
    case confirm(appliedAt: Date, spfLevel: Int?, notes: String?)
}
