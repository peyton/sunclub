import Foundation

enum LogSource: String, Codable, Sendable {
    case timeline
    case manualLog
    case quickLog
    case widget
    case watch
    case automation
    case deepLink
    case history
    case legacy
}

struct AppLogContext: Equatable, Codable, Sendable {
    let date: Date
    let dayPart: DayPart
    let source: LogSource
}

struct SunclubHistoryMutationReceipt: Equatable, Sendable {
    let batchID: UUID?
    let day: Date
    let verifiedAt: Date?
    let kind: SunclubChangeKind
    let didChange: Bool
}

enum SunclubHistoryMutationError: Error, Equatable, Sendable, LocalizedError {
    case futureDate
    case futureTime
    case missingRecord
    case persistenceFailure

    var errorDescription: String? {
        switch self {
        case .futureDate:
            return "Cannot log future date."
        case .futureTime:
            return "Choose a time that is not in the future."
        case .missingRecord:
            return "Log sunscreen for this day before recording a reapplication."
        case .persistenceFailure:
            return "Sunclub couldn't save that change. Your edits are still here—please try again."
        }
    }
}

enum SunclubHistoryMutationResult: Equatable, Sendable {
    case success(SunclubHistoryMutationReceipt)
    case failure(SunclubHistoryMutationError)

    var succeeded: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var error: SunclubHistoryMutationError? {
        guard case let .failure(error) = self else {
            return nil
        }
        return error
    }
}
