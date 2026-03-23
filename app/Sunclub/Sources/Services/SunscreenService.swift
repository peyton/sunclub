import CoreImage
import Foundation
import FastVLM

extension CVPixelBuffer: @unchecked @retroactive Sendable {}

struct SunscreenInference: Sendable {
    let answer: SunscreenDetectionAnswer
    let rawOutput: String
    let timeToFirstTokenMs: Int?
    let latencyMs: Int
}


actor SunscreenService {
    static let shared = SunscreenService()

    let inferenceService: FastVLMService
    private init() {
      inferenceService = FastVLMService()
    }

    
  func detectSunscreen(in pixelBuffer: CVPixelBuffer, modelDirectory: URL) async throws -> SunscreenInference {
    
    let raw = try await inferenceService.detect(
      in: pixelBuffer,
      modelDirectory: modelDirectory
    )
    let sanitized = SunscreenResponseParser.sanitized(raw.rawOutput)
    return SunscreenInference(
      answer: SunscreenResponseParser.parse(raw.rawOutput),
      rawOutput: sanitized,
      timeToFirstTokenMs: raw.timeToFirstTokenMs,
      latencyMs: raw.latencyMs)
    
  }
}
