import Foundation
import Vision

struct FeaturePrintMatchConfiguration {
    let directHitThreshold: Float
    let supportThreshold: Float
    let requiredSupportCount: Int
    let consensusTopK: Int
    let consensusThreshold: Float

    static let selfie = FeaturePrintMatchConfiguration(
        directHitThreshold: 0.56,
        supportThreshold: 0.60,
        requiredSupportCount: 2,
        consensusTopK: 4,
        consensusThreshold: 0.59
    )

    static let video = FeaturePrintMatchConfiguration(
        directHitThreshold: 0.58,
        supportThreshold: 0.62,
        requiredSupportCount: 2,
        consensusTopK: 4,
        consensusThreshold: 0.60
    )
}

struct FeaturePrintMatchResult {
    let isMatch: Bool
    let bestDistance: Float?
    let consensusDistance: Float?
    let supportCount: Int
    let comparedCount: Int
}

final class FeaturePrintMatcher {
    static let shared = FeaturePrintMatcher()

    func evaluate(
        sample: VNFeaturePrintObservation,
        storedPayloads: [Data],
        configuration: FeaturePrintMatchConfiguration
    ) -> FeaturePrintMatchResult {
        let distances = VisionFeaturePrintService.shared.distances(for: sample, to: storedPayloads)
        guard !distances.isEmpty else {
            return FeaturePrintMatchResult(
                isMatch: false,
                bestDistance: nil,
                consensusDistance: nil,
                supportCount: 0,
                comparedCount: 0
            )
        }

        let sorted = distances.sorted()
        let bestDistance = sorted[0]
        let topKCount = max(1, min(configuration.consensusTopK, sorted.count))
        let consensusDistance = sorted.prefix(topKCount).reduce(0, +) / Float(topKCount)
        let supportCount = distances.filter { $0 <= configuration.supportThreshold }.count
        let requiredSupportCount = min(max(1, configuration.requiredSupportCount), distances.count)

        let directHit = bestDistance <= configuration.directHitThreshold
        let consensusHit = supportCount >= requiredSupportCount && consensusDistance <= configuration.consensusThreshold

        return FeaturePrintMatchResult(
            isMatch: directHit || consensusHit,
            bestDistance: bestDistance,
            consensusDistance: consensusDistance,
            supportCount: supportCount,
            comparedCount: distances.count
        )
    }
}
