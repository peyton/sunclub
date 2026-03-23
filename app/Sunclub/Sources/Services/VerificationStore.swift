import Foundation
import SwiftData

struct VerificationStore {
    let context: ModelContext

    func fetchRecords() throws -> [DailyRecord] {
        let descriptor = FetchDescriptor<DailyRecord>(
            sortBy: [SortDescriptor(\.startOfDay, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func record(for day: Date) throws -> DailyRecord? {
        let startOfDay = Calendar.current.startOfDay(for: day)
        let predicate = #Predicate<DailyRecord> { $0.startOfDay == startOfDay }
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startOfDay, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }
}
