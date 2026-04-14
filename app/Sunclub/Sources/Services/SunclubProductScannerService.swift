import Foundation
import Vision
import UIKit

struct SunclubProductScanResult: Equatable, Sendable {
    let spfLevel: Int?
    let expirationText: String?
    let recognizedText: [String]

    var summary: String {
        if let spfLevel {
            return "Detected SPF \(spfLevel)"
        }

        return "No SPF detected"
    }
}

enum SunclubProductScannerService {
    private static let maximumRecognizedLines = 12
    private static let maximumRecognizedLineLength = 96
    private static let spfPatterns = [
        TextPattern(#"\bSPF\s*[:#-]?\s*([0-9]{1,3})\s*(?:\+)?(?!\d)"#),
        TextPattern(#"\bSUNSCREEN\s+SPF\s*[:#-]?\s*([0-9]{1,3})\s*(?:\+)?(?!\d)"#),
        TextPattern(#"\bSUNSCREEN\s*([0-9]{1,3})\s*(?:\+)?(?!\d)"#),
        TextPattern(#"\bSUN\s+PROTECTION\s+FACTOR\s*[:#-]?\s*([0-9]{1,3})\s*(?:\+)?(?!\d)"#),
        TextPattern(#"\b([0-9]{1,3})\s*(?:\+)?\s*SPF\b"#)
    ]
    private static let expirationPatterns = [
        TextPattern(#"\b(?:EXP|EXPIRES|EXPIRATION|USE BY|BEST BY)\s*[:#-]?\s*((?:0?[1-9]|1[0-2])[\/\-](?:20)?[0-9]{2})\b"#),
        TextPattern(#"\b(?:EXP|EXPIRES|EXPIRATION|USE BY|BEST BY)\s*[:#-]?\s*((?:20)?[0-9]{2}[\/\-](?:0?[1-9]|1[0-2]))\b"#),
        TextPattern(#"\b(?:EXP|EXPIRES|EXPIRATION|USE BY|BEST BY)\s*[:#-]?\s*([A-Z]{3,9}\s+[0-9]{2,4})\b"#),
        TextPattern(#"\b((?:0?[1-9]|1[0-2])[\/\-]20[0-9]{2})\b"#),
        TextPattern(#"\b(20[0-9]{2}[\/\-](?:0?[1-9]|1[0-2]))\b"#)
    ]

    static func scan(image: UIImage) async throws -> SunclubProductScanResult {
        guard let cgImage = image.cgImage else {
            throw SunclubProductScannerError.imageUnavailable
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .flatMap { line in
                line
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
            }

        return analyze(recognizedText: lines)
    }

    static func analyze(recognizedText lines: [String]) -> SunclubProductScanResult {
        let normalizedLines = normalizedRecognizedLines(lines)

        return SunclubProductScanResult(
            spfLevel: detectedSPF(in: normalizedLines),
            expirationText: detectedExpiration(in: normalizedLines),
            recognizedText: displayLines(from: normalizedLines)
        )
    }

    private static func detectedSPF(in lines: [String]) -> Int? {
        for line in lines {
            for pattern in spfPatterns {
                if let value = pattern.firstMatch(in: line),
                   let spf = Int(value) {
                    return max(1, min(spf, 100))
                }
            }
        }

        return nil
    }

    private static func detectedExpiration(in lines: [String]) -> String? {
        for line in lines {
            for pattern in expirationPatterns {
                if let value = pattern.firstMatch(in: line) {
                    return value
                }
            }
        }

        return nil
    }

    private static func normalizedRecognizedLines(_ lines: [String]) -> [String] {
        var normalizedLines: [String] = []
        var seenLines = Set<String>()

        for line in lines {
            let normalized = line
                .split { $0.isWhitespace }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                continue
            }

            let key = normalized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seenLines.insert(key).inserted else {
                continue
            }

            normalizedLines.append(normalized)
        }

        return normalizedLines
    }

    private static func displayLines(from lines: [String]) -> [String] {
        Array(lines.prefix(maximumRecognizedLines).map { line in
            guard line.count > maximumRecognizedLineLength else {
                return line
            }

            return String(line.prefix(maximumRecognizedLineLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        })
    }

    private struct TextPattern: @unchecked Sendable {
        let regex: NSRegularExpression
        let captureGroup: Int

        init(_ pattern: String, captureGroup: Int = 1) {
            do {
                regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            } catch {
                preconditionFailure("Invalid scanner regex: \(pattern)")
            }

            self.captureGroup = captureGroup
        }

        func firstMatch(in line: String) -> String? {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, options: [], range: range),
                  captureGroup < match.numberOfRanges else {
                return nil
            }

            let matchRange = match.range(at: captureGroup)
            guard matchRange.location != NSNotFound,
                  let valueRange = Range(matchRange, in: line) else {
                return nil
            }

            return String(line[valueRange])
        }
    }
}

enum SunclubProductScannerError: LocalizedError {
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            return "Sunclub could not read that image."
        }
    }
}
