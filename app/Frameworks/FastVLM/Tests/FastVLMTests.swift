import Foundation
import XCTest
import FastVLM

final class FastVLMTests: XCTestCase {
    func testResolveModelDirectoryFindsFrameworkBundleLayout() throws {
        let sandbox = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let frameworkRoot = sandbox.appendingPathComponent("FastVLM.framework", isDirectory: true)
        let appRoot = sandbox.appendingPathComponent("Sunclub.app", isDirectory: true)
        let frameworkConfig = frameworkRoot.appendingPathComponent("FastVLM/model/config.json")
        let appConfig = appRoot.appendingPathComponent("config.json")

        try writeConfigFile(at: frameworkConfig)
        try writeConfigFile(at: appConfig)

        XCTAssertEqual(
            FastVLM.resolveModelDirectory(searchRoots: [frameworkRoot, appRoot]),
            frameworkConfig.deletingLastPathComponent()
        )
    }

    func testResolveModelDirectoryFallsBackToRootConfig() throws {
        let sandbox = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        let bundleRoot = sandbox.appendingPathComponent("FastVLM.framework", isDirectory: true)
        let config = bundleRoot.appendingPathComponent("config.json")
        try writeConfigFile(at: config)

        XCTAssertEqual(
            FastVLM.resolveModelDirectory(searchRoots: [bundleRoot]),
            bundleRoot
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeConfigFile(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(to: url)
    }
}
