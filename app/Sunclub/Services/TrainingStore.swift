import Foundation
import SwiftData

struct TrainingStore {
    let context: ModelContext

    func fetchAssets() throws -> [TrainingAsset] {
        let descriptor = FetchDescriptor<TrainingAsset>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
