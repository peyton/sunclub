import Foundation
import FastVLM
import Observation

enum FastVLMModelAvailability: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case ready
    case failed(String)
}

@MainActor
protocol FastVLMModelAssetProviding: AnyObject {
    var availability: FastVLMModelAvailability { get }
    var requiresDownloadConsent: Bool { get }

    func recordDownloadConsent()
    func refresh() async
    func prepareForVerification() async -> URL?
    func resolvedModelDirectory() -> URL?
}

@MainActor
protocol OnDemandResourceRequesting: AnyObject {
    var progress: Progress { get }
    func beginAccessingResources() async throws
}

@MainActor
final class BundleOnDemandResourceRequest: NSObject, OnDemandResourceRequesting {
    private let request: NSBundleResourceRequest

    init(tags: [String]) {
        request = NSBundleResourceRequest(tags: Set(tags))
        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
    }

    var progress: Progress {
        request.progress
    }

    func beginAccessingResources() async throws {
        try await request.beginAccessingResources()
    }
}

@MainActor
@Observable
final class FastVLMModelDownloadService: FastVLMModelAssetProviding {
    private enum Constants {
        static let consentKey = "sunclub.fastvlm.model-download-consent"
        static let resourceTag = "fastvlm-model"
        static let localBuildGuidance = "FastVLM is not staged for this local build. Run `just download-model`, rebuild, and try again."
    }

    static let shared = FastVLMModelDownloadService()

    private let requestFactory: ([String]) -> OnDemandResourceRequesting
    private let defaults: UserDefaults
    private let searchRootsProvider: () -> [URL]
    private var activeRequest: OnDemandResourceRequesting?

    private(set) var availability: FastVLMModelAvailability = .notDownloaded

    init(
        requestFactory: @escaping ([String]) -> OnDemandResourceRequesting = { BundleOnDemandResourceRequest(tags: $0) },
        defaults: UserDefaults = .standard,
        searchRootsProvider: @escaping () -> [URL] = {
            [Bundle.main.resourceURL].compactMap { $0 }
        }
    ) {
        self.requestFactory = requestFactory
        self.defaults = defaults
        self.searchRootsProvider = searchRootsProvider
        refreshAvailability()
    }

    var requiresDownloadConsent: Bool {
        guard case .ready = availability else {
            return !defaults.bool(forKey: Constants.consentKey)
        }

        return false
    }

    func recordDownloadConsent() {
        defaults.set(true, forKey: Constants.consentKey)
    }

    func refresh() async {
        refreshAvailability()
    }

    func prepareForVerification() async -> URL? {
        if let directory = resolvedModelDirectory() {
            availability = .ready
            return directory
        }

        availability = .notDownloaded

        guard !requiresDownloadConsent else {
            return nil
        }

        return await downloadModel()
    }

    func resolvedModelDirectory() -> URL? {
        FastVLM.resolveModelDirectory(searchRoots: searchRootsProvider())
    }

    private func downloadModel() async -> URL? {
        if let directory = resolvedModelDirectory() {
            availability = .ready
            return directory
        }

        let request = activeRequest ?? requestFactory([Constants.resourceTag])
        activeRequest = request
        availability = .downloading(progress: 0)

        let progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let clamped = max(0, min(request.progress.fractionCompleted, 1))
                self?.availability = .downloading(progress: clamped)
                try? await Task.sleep(for: .milliseconds(120))
            }
        }

        do {
            try await request.beginAccessingResources()
            progressTask.cancel()

            guard let directory = resolvedModelDirectory() else {
                availability = .failed("FastVLM downloaded, but the model files could not be found.")
                activeRequest = nil
                return nil
            }

            availability = .ready
            return directory
        } catch {
            progressTask.cancel()
            availability = .failed(localizedErrorMessage(for: error))
            activeRequest = nil
            return nil
        }
    }

    private func refreshAvailability() {
        if resolvedModelDirectory() != nil {
            availability = .ready
        } else {
            availability = .notDownloaded
        }
    }

    private func localizedErrorMessage(for error: Error) -> String {
        #if DEBUG
        Constants.localBuildGuidance
        #else
        error.localizedDescription
        #endif
    }
}
