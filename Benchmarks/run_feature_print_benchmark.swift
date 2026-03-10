#!/usr/bin/env swift

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct Manifest: Decodable {
    struct Item: Decodable {
        let code: String
        let name: String
        let filename: String
        let url: String
    }

    let target: Item
    let negatives: [Item]
}

struct MatchConfig {
    let label: String
    let directHitThreshold: Float
    let supportThreshold: Float
    let requiredSupportCount: Int
    let consensusTopK: Int
    let consensusThreshold: Float

    static let legacy = MatchConfig(
        label: "Legacy min-distance<=18.5",
        directHitThreshold: 18.5,
        supportThreshold: 18.5,
        requiredSupportCount: 1,
        consensusTopK: 1,
        consensusThreshold: 18.5
    )

    static let selfie = MatchConfig(
        label: "App selfie matcher",
        directHitThreshold: 0.56,
        supportThreshold: 0.60,
        requiredSupportCount: 2,
        consensusTopK: 4,
        consensusThreshold: 0.59
    )

    static let video = MatchConfig(
        label: "App video matcher (single-frame)",
        directHitThreshold: 0.58,
        supportThreshold: 0.62,
        requiredSupportCount: 2,
        consensusTopK: 4,
        consensusThreshold: 0.60
    )
}

struct MatchDecision {
    let accepted: Bool
    let bestDistance: Float
    let consensusDistance: Float
    let supportCount: Int
}

struct Evaluation {
    let name: String
    let category: String
    let label: Bool
    let bestDistance: Float
    let consensusDistance: Float
    let supportCount: Int
    let accepted: Bool
}

struct Metrics {
    let accuracy: Double
    let precision: Double
    let recall: Double
    let f1: Double
    let truePositives: Int
    let trueNegatives: Int
    let falsePositives: Int
    let falseNegatives: Int
}

struct VariantProfile {
    let rotationDegrees: ClosedRange<Double>
    let scale: ClosedRange<Double>
    let xShift: ClosedRange<Double>
    let yShift: ClosedRange<Double>
    let brightness: ClosedRange<Double>
    let contrast: ClosedRange<Double>
    let saturation: ClosedRange<Double>
    let blurRadius: ClosedRange<Double>

    static let training = VariantProfile(
        rotationDegrees: -6...6,
        scale: 0.76...0.9,
        xShift: -28...28,
        yShift: -34...34,
        brightness: -0.02...0.05,
        contrast: 0.94...1.08,
        saturation: 0.88...1.06,
        blurRadius: 0...0.4
    )

    static let positive = VariantProfile(
        rotationDegrees: -12...12,
        scale: 0.62...0.94,
        xShift: -56...56,
        yShift: -62...62,
        brightness: -0.05...0.09,
        contrast: 0.88...1.12,
        saturation: 0.82...1.14,
        blurRadius: 0...0.9
    )

    static let negative = VariantProfile(
        rotationDegrees: -14...14,
        scale: 0.62...0.96,
        xShift: -58...58,
        yShift: -64...64,
        brightness: -0.06...0.1,
        contrast: 0.86...1.15,
        saturation: 0.8...1.18,
        blurRadius: 0...1.0
    )
}

struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(nextUInt64() % 10_000_000) / 9_999_999
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
    }

    mutating func colorComponent(in range: ClosedRange<Double>) -> CGFloat {
        CGFloat(value(in: range))
    }
}

enum BenchmarkError: Error {
    case missingDataset(URL)
    case imageLoadFailed(URL)
    case imageWriteFailed(URL)
    case featurePrintFailed(String)
}

final class BenchmarkContext {
    let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func loadManifest(at url: URL) throws -> Manifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Manifest.self, from: data)
    }

    func loadImage(at url: URL) throws -> CGImage {
        guard let image = NSImage(contentsOf: url) else {
            throw BenchmarkError.imageLoadFailed(url)
        }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw BenchmarkError.imageLoadFailed(url)
        }
        return cgImage
    }

    func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw BenchmarkError.imageWriteFailed(url)
        }

        let properties = [
            kCGImageDestinationLossyCompressionQuality: 0.93
        ] as CFDictionary

        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw BenchmarkError.imageWriteFailed(url)
        }
    }

    func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw BenchmarkError.featurePrintFailed("No feature print produced")
        }
        return observation
    }

    func generateVariant(
        baseImage: CGImage,
        seed: UInt64,
        profile: VariantProfile,
        canvasSize: CGFloat = 512
    ) throws -> CGImage {
        var rng = SeededGenerator(seed: seed)
        let canvasRect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)

        let baseCI = CIImage(cgImage: baseImage)
        let cropRect = baseCI.extent.insetBy(
            dx: baseCI.extent.width * 0.08,
            dy: baseCI.extent.height * 0.05
        )
        let cropped = baseCI.cropped(to: cropRect)

        let bgColorA = CIColor(
            red: rng.colorComponent(in: 0.93...0.99),
            green: rng.colorComponent(in: 0.91...0.98),
            blue: rng.colorComponent(in: 0.87...0.95)
        )
        let bgColorB = CIColor(
            red: rng.colorComponent(in: 0.80...0.93),
            green: rng.colorComponent(in: 0.87...0.97),
            blue: rng.colorComponent(in: 0.92...0.99)
        )

        let solid = CIImage(color: bgColorA).cropped(to: canvasRect)
        let radial = CIFilter.radialGradient()
        radial.center = CGPoint(
            x: rng.value(in: 150...360),
            y: rng.value(in: 150...360)
        )
        radial.radius0 = 12
        radial.radius1 = Float(rng.value(in: 180...340))
        radial.color0 = bgColorB
        radial.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let background = radial.outputImage!.cropped(to: canvasRect).composited(over: solid)

        let fit = min(canvasSize * 0.62 / cropped.extent.width, canvasSize * 0.72 / cropped.extent.height)
        let scale = CGFloat(rng.value(in: profile.scale)) * fit
        let scaled = cropped.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent

        let centered = scaled.transformed(
            by: CGAffineTransform(translationX: -scaledExtent.midX, y: -scaledExtent.midY)
        )
        let rotated = centered.transformed(
            by: CGAffineTransform(rotationAngle: CGFloat(rng.value(in: profile.rotationDegrees)) * .pi / 180)
        )
        let translated = rotated.transformed(
            by: CGAffineTransform(
                translationX: canvasSize / 2 + CGFloat(rng.value(in: profile.xShift)),
                y: canvasSize / 2 + CGFloat(rng.value(in: profile.yShift))
            )
        )

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = translated
        colorControls.brightness = Float(rng.value(in: profile.brightness))
        colorControls.contrast = Float(rng.value(in: profile.contrast))
        colorControls.saturation = Float(rng.value(in: profile.saturation))
        var styled = colorControls.outputImage!

        let blurRadius = rng.value(in: profile.blurRadius)
        if blurRadius > 0.01 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = styled
            blur.radius = Float(blurRadius)
            styled = blur.outputImage!.cropped(to: styled.extent)
        }

        let shadowBase = styled
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputBrightnessKey: -0.92,
                    kCIInputContrastKey: 0.4
                ]
            )
            .transformed(by: CGAffineTransform(translationX: 0, y: -4))
        let shadowBlur = CIFilter.gaussianBlur()
        shadowBlur.inputImage = shadowBase
        shadowBlur.radius = 10
        let shadowed = shadowBlur.outputImage!.cropped(to: canvasRect)

        let composite = styled.composited(over: shadowed.composited(over: background)).cropped(to: canvasRect)
        guard let cgImage = ciContext.createCGImage(composite, from: canvasRect) else {
            throw BenchmarkError.imageWriteFailed(URL(fileURLWithPath: "/dev/null"))
        }
        return cgImage
    }
}

func distances(from sample: VNFeaturePrintObservation, to training: [VNFeaturePrintObservation]) throws -> [Float] {
    try training.map { reference in
        var distance: Float = 0
        try sample.computeDistance(&distance, to: reference)
        return distance
    }
}

func evaluate(distances: [Float], config: MatchConfig) -> MatchDecision {
    let sorted = distances.sorted()
    let bestDistance = sorted[0]
    let topKCount = max(1, min(config.consensusTopK, sorted.count))
    let consensusDistance = sorted.prefix(topKCount).reduce(0, +) / Float(topKCount)
    let supportCount = distances.filter { $0 <= config.supportThreshold }.count
    let requiredSupportCount = min(max(1, config.requiredSupportCount), distances.count)

    let accepted = bestDistance <= config.directHitThreshold ||
        (supportCount >= requiredSupportCount && consensusDistance <= config.consensusThreshold)

    return MatchDecision(
        accepted: accepted,
        bestDistance: bestDistance,
        consensusDistance: consensusDistance,
        supportCount: supportCount
    )
}

func metrics(for evaluations: [Evaluation]) -> Metrics {
    let tp = evaluations.filter { $0.label && $0.accepted }.count
    let tn = evaluations.filter { !$0.label && !$0.accepted }.count
    let fp = evaluations.filter { !$0.label && $0.accepted }.count
    let fn = evaluations.filter { $0.label && !$0.accepted }.count
    let total = max(1, evaluations.count)

    let precisionDenominator = max(1, tp + fp)
    let recallDenominator = max(1, tp + fn)
    let precision = Double(tp) / Double(precisionDenominator)
    let recall = Double(tp) / Double(recallDenominator)
    let f1Denominator = max(0.0001, precision + recall)

    return Metrics(
        accuracy: Double(tp + tn) / Double(total),
        precision: precision,
        recall: recall,
        f1: (2 * precision * recall) / f1Denominator,
        truePositives: tp,
        trueNegatives: tn,
        falsePositives: fp,
        falseNegatives: fn
    )
}

func percentile(_ values: [Float], q: Double) -> Float {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * q)))
    return sorted[index]
}

func format(_ value: Double) -> String {
    String(format: "%.3f", value)
}

func format(_ value: Float) -> String {
    String(format: "%.2f", value)
}

func printReport(
    label: String,
    metrics: Metrics,
    positiveDistances: [Float],
    negativeDistances: [Float],
    falsePositives: [Evaluation],
    falseNegatives: [Evaluation]
) {
    print("")
    print(label)
    print("  accuracy \(format(metrics.accuracy))  precision \(format(metrics.precision))  recall \(format(metrics.recall))  f1 \(format(metrics.f1))")
    print("  tp \(metrics.truePositives)  tn \(metrics.trueNegatives)  fp \(metrics.falsePositives)  fn \(metrics.falseNegatives)")
    print("  positives best-distance p50 \(format(percentile(positiveDistances, q: 0.50)))  p95 \(format(percentile(positiveDistances, q: 0.95)))")
    print("  negatives best-distance p05 \(format(percentile(negativeDistances, q: 0.05)))  p50 \(format(percentile(negativeDistances, q: 0.50)))")

    if !falsePositives.isEmpty {
        print("  hardest false positives:")
        for example in falsePositives.prefix(4) {
            print("    \(example.name) [\(example.category)] best \(format(example.bestDistance)) consensus \(format(example.consensusDistance)) support \(example.supportCount)")
        }
    }

    if !falseNegatives.isEmpty {
        print("  hardest false negatives:")
        for example in falseNegatives.prefix(4) {
            print("    \(example.name) best \(format(example.bestDistance)) consensus \(format(example.consensusDistance)) support \(example.supportCount)")
        }
    }
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let manifestURL = root.appendingPathComponent("dataset_manifest.json")
let rawDir = root.appendingPathComponent("Datasets/raw", isDirectory: true)
let generatedDir = root.appendingPathComponent("Datasets/generated", isDirectory: true)
let strictMode = CommandLine.arguments.contains("--strict")

let context = BenchmarkContext()
let manifest = try context.loadManifest(at: manifestURL)
let fileManager = FileManager.default

let allItems = [manifest.target] + manifest.negatives
for item in allItems {
    let sourcePath = rawDir.appendingPathComponent(item.filename)
    guard fileManager.fileExists(atPath: sourcePath.path) else {
        throw BenchmarkError.missingDataset(sourcePath)
    }
}

if fileManager.fileExists(atPath: generatedDir.path) {
    try fileManager.removeItem(at: generatedDir)
}

let trainDir = generatedDir.appendingPathComponent("train", isDirectory: true)
let positiveDir = generatedDir.appendingPathComponent("positive", isDirectory: true)
let negativeDir = generatedDir.appendingPathComponent("negative", isDirectory: true)

try fileManager.createDirectory(at: trainDir, withIntermediateDirectories: true)
try fileManager.createDirectory(at: positiveDir, withIntermediateDirectories: true)
try fileManager.createDirectory(at: negativeDir, withIntermediateDirectories: true)

let targetBaseImage = try context.loadImage(at: rawDir.appendingPathComponent(manifest.target.filename))
let negativeBaseImages = try manifest.negatives.map { item in
    (item, try context.loadImage(at: rawDir.appendingPathComponent(item.filename)))
}

let trainingCount = 16
let positiveCount = 24
let negativeVariantsPerItem = 6

var trainingPrints: [VNFeaturePrintObservation] = []
for index in 0..<trainingCount {
    let image = try context.generateVariant(
        baseImage: targetBaseImage,
        seed: 1_000 + UInt64(index),
        profile: .training
    )
    let url = trainDir.appendingPathComponent(String(format: "train_%02d.jpg", index + 1))
    try context.writeJPEG(image, to: url)
    trainingPrints.append(try context.featurePrint(for: image))
}

var positivePrints: [(String, VNFeaturePrintObservation)] = []
for index in 0..<positiveCount {
    let image = try context.generateVariant(
        baseImage: targetBaseImage,
        seed: 10_000 + UInt64(index),
        profile: .positive
    )
    let name = String(format: "positive_%02d", index + 1)
    let url = positiveDir.appendingPathComponent("\(name).jpg")
    try context.writeJPEG(image, to: url)
    positivePrints.append((name, try context.featurePrint(for: image)))
}

var negativePrints: [(String, String, VNFeaturePrintObservation)] = []
for (itemIndex, pair) in negativeBaseImages.enumerated() {
    let (item, image) = pair
    for variant in 0..<negativeVariantsPerItem {
        let rendered = try context.generateVariant(
            baseImage: image,
            seed: 100_000 + UInt64(itemIndex * 100) + UInt64(variant),
            profile: .negative
        )
        let name = "\(item.filename.replacingOccurrences(of: ".jpg", with: ""))_\(variant + 1)"
        let url = negativeDir.appendingPathComponent("\(name).jpg")
        try context.writeJPEG(rendered, to: url)
        negativePrints.append((name, item.name, try context.featurePrint(for: rendered)))
    }
}

let configs: [MatchConfig] = [.legacy, .selfie, .video]

print("Sunscreen feature-print benchmark")
print("  target: \(manifest.target.name) (\(manifest.target.code))")
print("  training variants: \(trainingCount)")
print("  positive test variants: \(positiveCount)")
print("  negative test variants: \(negativePrints.count)")
print("  generated dataset: \(generatedDir.path)")
print("  strict mode: \(strictMode ? "on" : "off")")

var strictFailures: [String] = []

for config in configs {
    var evaluations: [Evaluation] = []

    for (name, sample) in positivePrints {
        let sampleDistances = try distances(from: sample, to: trainingPrints)
        let decision = evaluate(distances: sampleDistances, config: config)
        evaluations.append(
            Evaluation(
                name: name,
                category: "target",
                label: true,
                bestDistance: decision.bestDistance,
                consensusDistance: decision.consensusDistance,
                supportCount: decision.supportCount,
                accepted: decision.accepted
            )
        )
    }

    for (name, category, sample) in negativePrints {
        let sampleDistances = try distances(from: sample, to: trainingPrints)
        let decision = evaluate(distances: sampleDistances, config: config)
        evaluations.append(
            Evaluation(
                name: name,
                category: category,
                label: false,
                bestDistance: decision.bestDistance,
                consensusDistance: decision.consensusDistance,
                supportCount: decision.supportCount,
                accepted: decision.accepted
            )
        )
    }

    let summary = metrics(for: evaluations)
    let positiveDistances = evaluations.filter(\.label).map(\.bestDistance)
    let negativeDistances = evaluations.filter { !$0.label }.map(\.bestDistance)
    let falsePositives = evaluations
        .filter { !$0.label && $0.accepted }
        .sorted { $0.bestDistance < $1.bestDistance }
    let falseNegatives = evaluations
        .filter { $0.label && !$0.accepted }
        .sorted { $0.bestDistance < $1.bestDistance }

    printReport(
        label: config.label,
        metrics: summary,
        positiveDistances: positiveDistances,
        negativeDistances: negativeDistances,
        falsePositives: falsePositives,
        falseNegatives: falseNegatives
    )

    if strictMode && config.label != MatchConfig.legacy.label {
        if summary.precision < 0.90 || summary.recall < 0.85 || summary.f1 < 0.87 {
            strictFailures.append(config.label)
        }
    }
}

if strictFailures.isEmpty {
    print("")
    print("Benchmark completed without strict failures.")
} else {
    fputs("Strict benchmark failure for: \(strictFailures.joined(separator: ", "))\n", stderr)
    exit(1)
}
