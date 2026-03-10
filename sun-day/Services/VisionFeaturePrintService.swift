import Foundation
import AVFoundation
import Vision
import UIKit

enum VisionFeaturePrintError: Error {
    case noImageData
    case noFeaturePrint
}

final class VisionFeaturePrintService {
    static let shared = VisionFeaturePrintService()

    func featurePrint(from sampleBuffer: CMSampleBuffer) async throws -> VNFeaturePrintObservation {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw VisionFeaturePrintError.noImageData
        }
        return try await featurePrint(from: pixelBuffer)
    }

    func featurePrint(from data: Data) async throws -> VNFeaturePrintObservation {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw VisionFeaturePrintError.noImageData
        }
        return try await featurePrint(from: cgImage)
    }

    func featurePrint(from pixelBuffer: CVImageBuffer) async throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.compactMap({ $0 as? VNFeaturePrintObservation }).first else {
            throw VisionFeaturePrintError.noFeaturePrint
        }
        return observation
    }

    func featurePrint(from cgImage: CGImage) async throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.compactMap({ $0 as? VNFeaturePrintObservation }).first else {
            throw VisionFeaturePrintError.noFeaturePrint
        }
        return observation
    }

    func distance(between lhs: VNFeaturePrintObservation, and rhs: VNFeaturePrintObservation) throws -> Float {
        var distance: Float = 0
        try lhs.computeDistance(&distance, to: rhs)
        return distance
    }

    func serialize(_ observation: VNFeaturePrintObservation) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    func deserialize(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }

    func distances(for sample: VNFeaturePrintObservation, to storedPayloads: [Data]) -> [Float] {
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

    func bestDistance(for sample: VNFeaturePrintObservation, to storedPayloads: [Data]) async -> Float? {
        distances(for: sample, to: storedPayloads).min()
    }

    func detectBarcodes(in data: Data) async -> [String] {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return [] }
        return await detectBarcodes(in: cgImage)
    }

    func detectBarcodes(in cgImage: CGImage) async -> [String] {
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
