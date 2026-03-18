import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXVLM
import FastVLM

extension CVPixelBuffer: @unchecked @retroactive Sendable {}

struct FastVLMInference: Sendable {
    let answer: SunscreenDetectionAnswer
    let rawOutput: String
    let timeToFirstTokenMs: Int?
    let latencyMs: Int
}

enum FastVLMServiceError: LocalizedError {
    case modelMissing
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "FastVLM model files are missing. Run `just download-model` from the repo root, then rebuild."
        case .generationFailed(let message):
            return message
        }
    }
}

private final class FirstTokenTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedMs: Int?
    private var hasRecorded = false

    func record(from startedAt: Date) {
        lock.withLock {
            guard !hasRecorded else { return }
            hasRecorded = true
            recordedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        }
    }

    func value() -> Int? {
        lock.withLock { recordedMs }
    }
}

actor FastVLMService {
    static let shared = FastVLMService()

    private enum LoadState {
        case idle
        case loading(Task<ModelContainer, Error>)
        case loaded(ModelContainer)
    }

    private let prompt = "Is there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO. If unsure, answer NO."
    private let generateParameters = GenerateParameters(temperature: 0.0)
    private let maxTokens = 8
    private var loadState: LoadState = .idle

    private init() {
        FastVLM.register(modelFactory: VLMModelFactory.shared)
    }

    func prewarmIfPossible() async {
        _ = try? await loadModelIfNeeded()
    }

    func loadModelIfNeeded() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            let task = Task {
                #if !targetEnvironment(simulator)
                // MLX GPU cache configuration is valid on-device, but it can abort on iOS Simulator.
                MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
                #endif

                guard let modelDirectory = Self.modelDirectory() else {
                    throw FastVLMServiceError.modelMissing
                }

                let configuration = ModelConfiguration(directory: modelDirectory)
                return try await VLMModelFactory.shared.loadContainer(configuration: configuration) { _ in }
            }

            loadState = .loading(task)

            do {
                let container = try await task.value
                loadState = .loaded(container)
                return container
            } catch {
                loadState = .idle
                throw error
            }

        case .loading(let task):
            return try await task.value

        case .loaded(let container):
            return container
        }
    }

    func detectSunscreen(in pixelBuffer: CVPixelBuffer) async throws -> FastVLMInference {
        let modelContainer = try await loadModelIfNeeded()
        let startedAt = Date()
        let firstTokenTracker = FirstTokenTracker()

        do {
            let rawOutput = try await modelContainer.perform { context in
                let userInput = UserInput(
                    prompt: .text(self.prompt),
                    images: [.ciImage(CIImage(cvPixelBuffer: pixelBuffer))]
                )
                let input = try await context.processor.prepare(input: userInput)
                var sawFirstToken = false

                let generation = try MLXLMCommon.generate(
                    input: input,
                    parameters: self.generateParameters,
                    context: context
                ) { tokens in
                    if !sawFirstToken {
                        sawFirstToken = true
                        firstTokenTracker.record(from: startedAt)
                    }

                    return tokens.count >= self.maxTokens ? .stop : .more
                }

                return generation.output
            }

            let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            let sanitized = SunscreenResponseParser.sanitized(rawOutput)
            return FastVLMInference(
                answer: SunscreenResponseParser.parse(rawOutput),
                rawOutput: sanitized,
                timeToFirstTokenMs: firstTokenTracker.value(),
                latencyMs: latencyMs
            )
        } catch {
            throw FastVLMServiceError.generationFailed(error.localizedDescription)
        }
    }

    static func resolveModelDirectory(searchRoots: [URL]) -> URL? {
        FastVLM.resolveModelDirectory(searchRoots: searchRoots)
    }

    private static func modelDirectory() -> URL? {
        FastVLM.resolveModelDirectory()
    }
}
