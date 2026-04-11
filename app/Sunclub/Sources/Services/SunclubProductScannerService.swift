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
    static func scan(image: UIImage) async throws -> SunclubProductScanResult {
        guard let cgImage = image.cgImage else {
            throw SunclubProductScannerError.imageUnavailable
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let strings = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .flatMap { line in
                line
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
            }

        return SunclubProductScanResult(
            spfLevel: detectedSPF(in: strings),
            expirationText: detectedExpiration(in: strings),
            recognizedText: strings
        )
    }

    private static func detectedSPF(in lines: [String]) -> Int? {
        let patterns = [
            #"\bSPF\s*([0-9]{1,3})\b"#,
            #"\bSUNSCREEN\s*([0-9]{1,3})\b"#,
            #"\b([0-9]{1,3})\s*SPF\b"#
        ]

        for line in lines {
            for pattern in patterns {
                if let value = firstMatch(for: pattern, in: line),
                   let spf = Int(value) {
                    return max(1, min(spf, 100))
                }
            }
        }

        return nil
    }

    private static func detectedExpiration(in lines: [String]) -> String? {
        let patterns = [
            #"\b(0?[1-9]|1[0-2])[\/\-](20[0-9]{2})\b"#,
            #"\b(20[0-9]{2})[\/\-](0?[1-9]|1[0-2])\b"#,
            #"\bEXP[:\s]+([A-Z]{3}\s+[0-9]{4})\b"#
        ]

        for line in lines {
            for pattern in patterns {
                if let value = firstMatch(for: pattern, in: line) {
                    return value
                }
            }
        }

        return nil
    }

    private static func firstMatch(for pattern: String, in line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }

        if match.numberOfRanges > 1,
           let valueRange = Range(match.range(at: 1), in: line) {
            return String(line[valueRange])
        }

        guard let fullRange = Range(match.range(at: 0), in: line) else {
            return nil
        }
        return String(line[fullRange])
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
