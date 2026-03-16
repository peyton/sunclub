#!/usr/bin/env swift

import AppKit
import Foundation
import Vision

struct ManifestRecord: Decodable {
    let sample_id: String
    let image_path: String?
    let local_path: String?
}

struct ScoreRecord: Encodable {
    let sample_id: String
    let distances: [Float]
    let latency_ms: Double
}

func argument(named name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else {
        return nil
    }
    return CommandLine.arguments[index + 1]
}

func readJSONL<T: Decodable>(path: String) throws -> [T] {
    let url = URL(fileURLWithPath: path)
    let text = try String(contentsOf: url, encoding: .utf8)
    let decoder = JSONDecoder()
    return try text.split(separator: "\n").map { line in
        try decoder.decode(T.self, from: Data(line.utf8))
    }
}

func loadCGImage(path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path)
    guard let image = NSImage(contentsOf: url) else {
        throw NSError(domain: "FeaturePrintCLI", code: 1)
    }
    var rect = CGRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        throw NSError(domain: "FeaturePrintCLI", code: 2)
    }
    return cgImage
}

func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation {
    let request = VNGenerateImageFeaturePrintRequest()
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try handler.perform([request])
    guard let observation = request.results?.first as? VNFeaturePrintObservation else {
        throw NSError(domain: "FeaturePrintCLI", code: 3)
    }
    return observation
}

guard let enrollmentManifest = argument(named: "--enrollment-manifest"),
      let testManifest = argument(named: "--test-manifest"),
      let outputPath = argument(named: "--output")
else {
    fputs("Missing required arguments\n", stderr)
    exit(1)
}

let enrollmentRecords = try readJSONL(path: enrollmentManifest) as [ManifestRecord]
let testRecords = try readJSONL(path: testManifest) as [ManifestRecord]
let enrollmentPrints = try enrollmentRecords.map {
    guard let path = $0.image_path ?? $0.local_path else {
        throw NSError(domain: "FeaturePrintCLI", code: 4)
    }
    return try featurePrint(for: loadCGImage(path: path))
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

let outputURL = URL(fileURLWithPath: outputPath)
FileManager.default.createFile(atPath: outputURL.path, contents: nil)
let handle = try FileHandle(forWritingTo: outputURL)

for record in testRecords {
    guard let imagePath = record.image_path ?? record.local_path else {
        throw NSError(domain: "FeaturePrintCLI", code: 5)
    }
    let start = DispatchTime.now()
    let observation = try featurePrint(for: loadCGImage(path: imagePath))
    var distances: [Float] = []
    for enrollment in enrollmentPrints {
        var distance: Float = 0
        try observation.computeDistance(&distance, to: enrollment)
        distances.append(distance)
    }
    let end = DispatchTime.now()
    let latency = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    let scoreRecord = ScoreRecord(sample_id: record.sample_id, distances: distances.sorted(), latency_ms: latency)
    let data = try encoder.encode(scoreRecord)
    handle.write(data)
    handle.write(Data([0x0A]))
}

try handle.close()
