import Foundation
import XCTest

final class DesignSystemAdoptionTests: XCTestCase {
    func testDesignSystemDefinesRequiredTokensAndComponents() throws {
        let content = try source("app/Sunclub/Sources/Shared/AppDesignSystem.swift")
        let requiredSymbols = [
            "enum AppColor",
            "enum AppRadius",
            "enum AppSpacing",
            "enum AppShadow",
            "struct AppText",
            "struct AppCard",
            "struct PrimaryButton",
            "struct SecondaryPillButton",
            "struct StatusBadge",
            "struct DayCapsule",
            "struct StatCard",
            "struct FeatureIcon",
            "struct InfoRow",
            "static let card: CGFloat = 18",
            "static let button: CGFloat = 14",
            "static let pill: CGFloat = .infinity"
        ]

        for symbol in requiredSymbols {
            XCTAssertTrue(content.contains(symbol), "AppDesignSystem.swift must define \(symbol).")
        }
    }

    func testLegacyHomePathIsRemoved() throws {
        let root = try repoRoot
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: root.appendingPathComponent("app/Sunclub/Sources/Views/HomeView.swift").path),
            "Legacy HomeView.swift should stay removed; TimelineHomeView is the only home surface."
        )

        for path in [
            "app/Sunclub/Sources/Shared/RootView.swift",
            "app/Sunclub/Sources/Shared/RuntimeEnvironment.swift",
            "app/Sunclub/UITests/SunclubUITests.swift"
        ] {
            let content = try source(path)
            XCTAssertFalse(content.contains("UITEST_USE_LEGACY_HOME"), "\(path) must not restore the legacy home launch flag.")
            XCTAssertFalse(content.contains("shouldUseLegacyHome"), "\(path) must not branch to the legacy home.")
        }
    }

    func testSharedScreenWrappersOwnTopStatusBarScrollFade() throws {
        let content = try source("app/Sunclub/Sources/Shared/AppTheme.swift")
        let requiredSymbols = [
            "static let topStatusBarFadeHeight",
            "static let topStatusBarFadeActivationDistance",
            "topStatusBarFadeProgress(for verticalScrollOffset",
            "private struct SunTopStatusBarFade",
            "private extension ScrollGeometry",
            "sunclubVerticalScrollOffset",
            ".onScrollGeometryChange("
        ]

        for symbol in requiredSymbols {
            XCTAssertTrue(
                content.contains(symbol),
                "AppTheme.swift must keep shared status-bar fade support: \(symbol)."
            )
        }

        XCTAssertEqual(
            content.components(separatedBy: "SunTopStatusBarFade(progress:").count - 1,
            2,
            "SunLightScreen and SunDarkScreen should both install the shared top status-bar fade."
        )
        XCTAssertEqual(
            content.components(separatedBy: ".onScrollGeometryChange(").count - 1,
            2,
            "SunLightScreen and SunDarkScreen should both drive the fade from scroll geometry."
        )
    }

    func testTabBarBottomScrimSpansTheScreen() throws {
        let content = try source("app/Sunclub/Sources/Shared/AppTheme.swift")
        guard let start = content.range(of: "struct SunAppTabBar: View {"),
              let end = content.range(of: "    private func tabButton", range: start.upperBound..<content.endIndex) else {
            return XCTFail("AppTheme.swift should keep SunAppTabBar as a distinct view.")
        }

        let tabBar = content[start.lowerBound..<end.lowerBound]
        XCTAssertTrue(
            tabBar.contains(
                """
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        .background {
                """
            ),
            "The tab bar bottom scrim must expand before its background so page backdrops do not bleed at the screen edges."
        )
    }

    func testWeeklySummaryMetricPillsAvoidDarkModeCardFill() throws {
        let content = try source("app/Sunclub/Sources/Views/WeeklyReportView.swift")
        guard let start = content.range(of: "private struct WeeklyMetricPill: View {"),
              let end = content.range(of: "#Preview", range: start.upperBound..<content.endIndex) else {
            return XCTFail("WeeklyReportView.swift should keep WeeklyMetricPill as a distinct view.")
        }

        let metricPill = content[start.lowerBound..<end.lowerBound]
        XCTAssertTrue(
            metricPill.contains("@Environment(\\.colorScheme)"),
            "Weekly metric pills should inspect the color scheme before drawing card backgrounds."
        )
        XCTAssertTrue(
            metricPill.contains("if colorScheme == .light"),
            "Weekly metric pills should avoid the light gray card fill on the dark Insights surface."
        )
    }

    func testScreenCodeRoutesVisualStylingThroughDesignSystem() throws {
        let root = try repoRoot
        let checkedRoots = [
            root.appendingPathComponent("app/Sunclub/Sources/Views"),
            root.appendingPathComponent("app/Sunclub/WatchApp/Sources")
        ]
        let checkedFiles = try checkedRoots.flatMap { try swiftFiles(in: $0) } + [
            root.appendingPathComponent("app/Sunclub/Sources/Shared/SunManualLogFields.swift"),
            root.appendingPathComponent("app/Sunclub/Sources/Shared/SunDayStrip.swift")
        ]

        let forbiddenPatterns: [(pattern: String, message: String)] = [
            (#"\.font\(\.system"#, "Use AppText, AppTextStyle, or AppFont instead of direct system fonts."),
            (#"RoundedRectangle\(cornerRadius:\s*[0-9]"#, "Use AppRadius tokens instead of numeric corner radii."),
            (#"Color\(red:"#, "Use AppColor/AppPalette tokens instead of direct RGB colors."),
            (#"Color\.(red|orange|green|black|gray|white|blue|yellow)"#, "Use semantic color tokens instead of direct SwiftUI colors."),
            (#"\.shadow\("#, "Use AppShadow.soft via .appShadow or a shared component.")
        ]

        for fileURL in checkedFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            for rule in forbiddenPatterns where content.range(of: rule.pattern, options: .regularExpression) != nil {
                XCTFail("\(relativePath(for: fileURL)): \(rule.message)")
            }
        }
    }

    func testCoreSurfacesUseSharedComponents() throws {
        let expectations: [String: [String]] = [
            "app/Sunclub/Sources/Views/TimelineHomeView.swift": [
                "AppCard",
                "AppText",
                "StatusBadge",
                "StatCard"
            ],
            "app/Sunclub/Sources/Shared/SunDayStrip.swift": [
                "DayCapsule"
            ],
            "app/Sunclub/Sources/Views/Components/TimelineFooterBar.swift": [
                "SunBottomNavigationBar",
                "SunBottomNavigationItem"
            ],
            "app/Sunclub/Sources/Views/ManualLogView.swift": [
                "AppCard",
                "PrimaryButton"
            ],
            "app/Sunclub/Sources/Views/WeeklyReportView.swift": [
                "SecondaryPillButton",
                "AppShadow.soft"
            ],
            "app/Sunclub/Sources/Views/HistoryView.swift": [
                "SunInfoRow",
                "PrimaryButton",
                "SecondaryPillButton"
            ],
            "app/Sunclub/WatchApp/Sources/SunclubWatchHomeView.swift": [
                "AppCard",
                "AppText",
                "AppPrimaryButtonStyle"
            ]
        ]

        for (path, symbols) in expectations {
            let content = try source(path)
            for symbol in symbols {
                XCTAssertTrue(content.contains(symbol), "\(path) should use \(symbol).")
            }
        }
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: try repoRoot.appendingPathComponent(path), encoding: .utf8)
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
