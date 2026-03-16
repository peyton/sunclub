import Foundation
import AVFoundation
import Vision
import UIKit

enum VisionFeaturePrintError: Error {
    case noImageData
    case noFeaturePrint
}

final class VisionFeaturePrintService {
    nonisolated(unsafe) static let shared = VisionFeaturePrintService()

    nonisolated func featurePrint(from sampleBuffer: CMSampleBuffer) async throws -> VNFeaturePrintObservation {
        try featurePrintSync(from: sampleBuffer)
    }

    nonisolated func featurePrint(from data: Data) async throws -> VNFeaturePrintObservation {
        try featurePrintSync(from: data)
    }

    nonisolated func featurePrint(from pixelBuffer: CVImageBuffer) async throws -> VNFeaturePrintObservation {
        try featurePrintSync(from: pixelBuffer)
    }

    nonisolated func featurePrint(from cgImage: CGImage) async throws -> VNFeaturePrintObservation {
        try featurePrintSync(from: cgImage)
    }

    nonisolated func featurePrintSync(from sampleBuffer: CMSampleBuffer) throws -> VNFeaturePrintObservation {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw VisionFeaturePrintError.noImageData
        }
        return try featurePrintSync(from: pixelBuffer)
    }

    nonisolated func featurePrintSync(from data: Data) throws -> VNFeaturePrintObservation {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw VisionFeaturePrintError.noImageData
        }
        return try featurePrintSync(from: cgImage)
    }

    nonisolated func featurePrintSync(from pixelBuffer: CVImageBuffer) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.compactMap({ $0 as? VNFeaturePrintObservation }).first else {
            throw VisionFeaturePrintError.noFeaturePrint
        }
        return observation
    }

    nonisolated func featurePrintSync(from cgImage: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.compactMap({ $0 as? VNFeaturePrintObservation }).first else {
            throw VisionFeaturePrintError.noFeaturePrint
        }
        return observation
    }

    nonisolated func distance(between lhs: VNFeaturePrintObservation, and rhs: VNFeaturePrintObservation) throws -> Float {
        var distance: Float = 0
        try lhs.computeDistance(&distance, to: rhs)
        return distance
    }

    nonisolated func serialize(_ observation: VNFeaturePrintObservation) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    nonisolated func deserialize(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    nonisolated func distances(for sample: VNFeaturePrintObservation, to storedPayloads: [Data]) -> [Float] {
        var distances: [Float] = []

        for payload in storedPayloads {
            guard let stored = deserialize(payload) else { continue }
            do {
                distances.append(try distance(between: sample, and: stored))
            } catch {
                continue
            }
        }

        return distances
    }

    nonisolated func bestDistance(for sample: VNFeaturePrintObservation, to storedPayloads: [Data]) async -> Float? {
        distances(for: sample, to: storedPayloads).min()
    }

    nonisolated func detectBarcodes(in data: Data) async -> [String] {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return [] }
        return await detectBarcodes(in: cgImage)
    }

    nonisolated func detectBarcodes(in cgImage: CGImage) async -> [String] {
        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        return request.results?
            .compactMap { $0 as? VNBarcodeObservation }
            .compactMap { $0.payloadStringValue } ?? []
    }
}
