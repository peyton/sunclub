//
//  FastVLMService.swift
//  FastVLM
//
//  Created by Peyton Randolph on 3/22/26.
//

import CoreImage
import Foundation
import MLX
import MLXLMCommon
import MLXVLM

public struct FastVLMInference: Sendable {
    public let answer: String
    public let rawOutput: String
    public let timeToFirstTokenMs: Int?
    public let latencyMs: Int
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


public actor FastVLMService {
    private enum LoadState {
        case idle
        case loading(URL, Task<ModelContainer, Error>)
        case loaded(URL, ModelContainer)
    }

    private let prompt = "Is there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO. If unsure, answer NO."
    private let generateParameters = GenerateParameters(temperature: 0.0)
    private let maxTokens = 8
    private var loadState: LoadState = .idle

    public init() {
        FastVLM.register(modelFactory: VLMModelFactory.shared)
    }

    public func prewarmIfPossible(modelDirectory: URL?) async {
        guard let modelDirectory else { return }
        _ = try? await loadModelIfNeeded(modelDirectory: modelDirectory)
    }

    public func loadModelIfNeeded(modelDirectory: URL) async throws -> ModelContainer {
        let normalizedModelDirectory = modelDirectory.resolvingSymlinksInPath().standardizedFileURL

        switch loadState {
        case .idle:
            return try await loadContainer(from: normalizedModelDirectory)

        case .loading(let directory, let task):
            if directory == normalizedModelDirectory {
                return try await task.value
            }

            loadState = .idle
            return try await loadContainer(from: normalizedModelDirectory)

        case .loaded(let directory, let container):
            if directory == normalizedModelDirectory {
                return container
            }

            loadState = .idle
            return try await loadContainer(from: normalizedModelDirectory)
        }
    }

    public func detect(in pixelBuffer: CVPixelBuffer, modelDirectory: URL) async throws -> FastVLMInference {
        let startedAt = Date()
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let modelContainer = try await loadModelIfNeeded(modelDirectory: modelDirectory)
        let firstTokenTracker = FirstTokenTracker()

        do {
            let rawOutput = try await modelContainer.perform { context in
                let userInput = UserInput(
                    prompt: .text(self.prompt),
                    images: [.ciImage(ciImage)]
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
            return FastVLMInference(
                answer: rawOutput,
                rawOutput: rawOutput,
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

    private func loadContainer(from modelDirectory: URL) async throws -> ModelContainer {
        let task = Task {
            #if !targetEnvironment(simulator)
            // MLX GPU cache configuration is valid on-device, but it can abort on iOS Simulator.
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
            #endif

            let configuration = ModelConfiguration(directory: modelDirectory)
            return try await VLMModelFactory.shared.loadContainer(configuration: configuration) { _ in }
        }

        loadState = .loading(modelDirectory, task)

        do {
            let container = try await task.value
            loadState = .loaded(modelDirectory, container)
            return container
        } catch {
            loadState = .idle
            throw error
        }
    }
}
