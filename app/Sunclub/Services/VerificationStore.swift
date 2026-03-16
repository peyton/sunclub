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
}
