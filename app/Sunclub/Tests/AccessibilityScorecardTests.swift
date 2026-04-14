import Foundation
import XCTest

final class AccessibilityScorecardTests: XCTestCase {
    func testAgentsRequiresPerfectAccessibilityScorecardForAppChanges() throws {
        let content = try String(contentsOf: repoRoot.appendingPathComponent("AGENTS.md"), encoding: .utf8)
        let requiredPhrases = [
            "Accessibility Scorecard Rules",
            "VoiceOver",
            "Voice Control",
            "Larger Text",
            "Dark Interface",
            "Differentiate Without Color Alone",
            "Sufficient Contrast",
            "Reduced Motion",
            "Captions",
            "Audio Descriptions",
            "SunMotion",
            "UITEST_FORCE_*"
        ]

        for phrase in requiredPhrases {
            XCTAssertTrue(content.contains(phrase), "AGENTS.md must mention \(phrase).")
        }
    }

    func testAppSourceAvoidsKnownAccessibilityScorecardRegressions() throws {
        let sourceRoot = try repoRoot.appendingPathComponent("app/Sunclub/Sources")
        let sourceFiles = try swiftFiles(in: sourceRoot)
        let forbiddenSnippets = [
            ".minimumScaleFactor(",
            ".lineLimit(",
            "withAnimation(.",
            ".animation(.ease",
            ".animation(.spring",
            ".animation(.linear",
            ".animation(.bouncy",
            ".animation(.smooth",
            ".animation(.snappy",
            ".foregroundStyle(.white)",
            ".foregroundStyle(AppPalette.white)"
        ]

        for fileURL in sourceFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for snippet in forbiddenSnippets where content.contains(snippet) {
                XCTFail("\(relativePath(for: fileURL)) contains \(snippet). Preserve Dynamic Type, contrast, and Reduce Motion scorecard rules.")
            }
        }
    }

    func testAccessibilityUITestLaunchOverridesAreWired() throws {
        let root = try repoRoot
        let runtimeEnvironment = try String(
            contentsOf: root.appendingPathComponent("app/Sunclub/Sources/Shared/RuntimeEnvironment.swift"),
            encoding: .utf8
        )
        let appEntry = try String(
            contentsOf: root.appendingPathComponent("app/Sunclub/Sources/SunclubApp.swift"),
            encoding: .utf8
        )

        for argument in [
            "UITEST_FORCE_DARK_MODE",
            "UITEST_FORCE_ACCESSIBILITY_TEXT",
            "UITEST_FORCE_REDUCE_MOTION",
            "UITEST_FORCE_DIFFERENTIATE_WITHOUT_COLOR",
            "UITEST_FORCE_INCREASE_CONTRAST"
        ] {
            XCTAssertTrue(runtimeEnvironment.contains(argument), "RuntimeEnvironment must define \(argument).")
        }

        for modifier in [
            "preferredColorScheme",
            "sunclubDynamicTypeSizeOverride",
            "sunclubAccessibilityReduceMotionOverride",
            "sunclubAccessibilityDifferentiateWithoutColorOverride",
            "sunclubColorSchemeContrastOverride",
            "shouldUseIncreasedAccessibilityContrast"
        ] {
            XCTAssertTrue(
                appEntry.contains(modifier) || runtimeEnvironment.contains(modifier),
                "SunclubApp or RuntimeEnvironment must apply \(modifier)."
            )
        }
    }

    private var repoRoot: URL {
        get throws {
            var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            while directory.path != "/" {
                if FileManager.default.fileExists(atPath: directory.appendingPathComponent("AGENTS.md").path) {
                    return directory
                }
                directory.deleteLastPathComponent()
            }

            throw XCTSkip("Could not locate repository root from \(#filePath).")
        }
    }

    private func swiftFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return try enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else {
                return nil
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            return values.isRegularFile == true ? url : nil
        }
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = (try? repoRoot.path) ?? ""
        guard !rootPath.isEmpty, url.path.hasPrefix(rootPath) else {
            return url.path
        }

        return String(url.path.dropFirst(rootPath.count + 1))
    }
}
