import Foundation
import XCTest
@testable import Sunclub

@MainActor
private final class MockOnDemandResourceRequest: OnDemandResourceRequesting {
    let progress = Progress(totalUnitCount: 100)
    var onBegin: (() throws -> Void)?

    func beginAccessingResources() async throws {
        progress.completedUnitCount = 100
        try onBegin?()
    }
}

@MainActor
final class FastVLMModelDownloadServiceTests: XCTestCase {
    func testPrepareForVerificationWaitsForConsent() async throws {
        let (defaults, suiteName) = try makeDefaults()
        let root = try makeTemporaryDirectory()
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        let request = MockOnDemandResourceRequest()
        let service = FastVLMModelDownloadService(
            requestFactory: { _ in request },
            defaults: defaults,
            searchRootsProvider: { [root] }
        )

        let modelDirectory = await service.prepareForVerification()

        XCTAssertNil(modelDirectory)
        XCTAssertTrue(service.requiresDownloadConsent)
        XCTAssertEqual(service.availability, .notDownloaded)
    }

    func testPrepareForVerificationDownloadsModelAfterConsent() async throws {
        let (defaults, suiteName) = try makeDefaults()
        let root = try makeTemporaryDirectory()
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        let request = MockOnDemandResourceRequest()
        request.onBegin = {
            try Self.writeConfigFile(at: root.appendingPathComponent("model/config.json"))
        }

        let service = FastVLMModelDownloadService(
            requestFactory: { _ in request },
            defaults: defaults,
            searchRootsProvider: { [root] }
        )

        service.recordDownloadConsent()
        let modelDirectory = await service.prepareForVerification()

        XCTAssertEqual(modelDirectory, root.appendingPathComponent("model"))
        XCTAssertEqual(service.resolvedModelDirectory(), root.appendingPathComponent("model"))
        XCTAssertEqual(service.availability, .ready)
    }

    func testPrepareForVerificationSurfacesDownloadFailure() async throws {
        let (defaults, suiteName) = try makeDefaults()
        let root = try makeTemporaryDirectory()
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        let request = MockOnDemandResourceRequest()
        request.onBegin = {
            throw NSError(domain: "SunclubTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "download failed"])
        }

        let service = FastVLMModelDownloadService(
            requestFactory: { _ in request },
            defaults: defaults,
            searchRootsProvider: { [root] }
        )

        service.recordDownloadConsent()
        let modelDirectory = await service.prepareForVerification()

        XCTAssertNil(modelDirectory)
        guard case let .failed(message) = service.availability else {
            return XCTFail("Expected failed availability state")
        }
        XCTAssertTrue(message.contains("just download-model"))
    }

    func testRefreshMarksExistingModelAsReady() throws {
        let (defaults, suiteName) = try makeDefaults()
        let root = try makeTemporaryDirectory()
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: root)
        }

        try Self.writeConfigFile(at: root.appendingPathComponent("config.json"))

        let service = FastVLMModelDownloadService(
            requestFactory: { _ in MockOnDemandResourceRequest() },
            defaults: defaults,
            searchRootsProvider: { [root] }
        )

        XCTAssertEqual(service.availability, .ready)
        XCTAssertEqual(service.resolvedModelDirectory(), root)
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "sunclub.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw NSError(domain: "SunclubTests", code: 1)
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func writeConfigFile(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: url)
    }
}
