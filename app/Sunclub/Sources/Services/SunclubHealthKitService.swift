import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
protocol SunclubHealthKitServing: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorizationIfNeeded() async -> Bool
    func exportLog(
        recordDate: Date,
        uvIndex: Int?,
        externalID: UUID?,
        spfLevel: Int?
    ) async
    func recentUVSampleCount(since startDate: Date) async -> Int
}

@MainActor
final class SunclubHealthKitService: SunclubHealthKitServing {
    static let shared = SunclubHealthKitService()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        #if canImport(HealthKit)
        guard isAvailable,
              let uvType = HKObjectType.quantityType(forIdentifier: .uvExposure) else {
            return false
        }

        do {
            try await store.requestAuthorization(toShare: [uvType], read: [uvType])
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    func exportLog(
        recordDate: Date,
        uvIndex: Int?,
        externalID: UUID?,
        spfLevel: Int?
    ) async {
        #if canImport(HealthKit)
        guard await requestAuthorizationIfNeeded(),
              let uvType = HKObjectType.quantityType(forIdentifier: .uvExposure) else {
            return
        }

        let sampleValue = Double(max(uvIndex ?? 1, 1))
        let metadata = metadata(externalID: externalID, spfLevel: spfLevel)
        let sample = HKQuantitySample(
            type: uvType,
            quantity: HKQuantity(unit: .count(), doubleValue: sampleValue),
            start: recordDate,
            end: recordDate,
            metadata: metadata
        )

        do {
            try await store.save(sample)
        } catch {
            return
        }
        #endif
    }

    func recentUVSampleCount(since startDate: Date) async -> Int {
        #if canImport(HealthKit)
        guard isAvailable,
              let uvType = HKObjectType.quantityType(forIdentifier: .uvExposure) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: uvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            store.execute(query)
        }
        #else
        return 0
        #endif
    }

    #if canImport(HealthKit)
    private func metadata(externalID: UUID?, spfLevel: Int?) -> [String: Any] {
        var metadata: [String: Any] = [
            "com.sunclub.sample_kind": "sunscreen-log"
        ]
        if let externalID {
            metadata[HKMetadataKeyExternalUUID] = externalID.uuidString
        }
        if let spfLevel {
            metadata["com.sunclub.spf"] = spfLevel
        }
        return metadata
    }
    #endif
}
