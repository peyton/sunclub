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

    func testLiquidGlassPrimitivesPreserveAvailabilityFallbacks() throws {
        let designSystem = try source("app/Sunclub/Sources/Shared/AppDesignSystem.swift")
        let theme = try source("app/Sunclub/Sources/Shared/AppTheme.swift")

        let designSystemSymbols = [
            "struct SunGlassEffectContainer",
            "func sunGlassSurface(",
            "case regular",
            "case interactive",
            "if #available(iOS 26.0, *)",
            ".regular.interactive()",
            "GlassEffectContainer",
            ".glassProminent",
            ".glass"
        ]

        for symbol in designSystemSymbols {
            XCTAssertTrue(
                designSystem.contains(symbol),
                "AppDesignSystem.swift must provide the availability-aware glass primitive: \(symbol)."
            )
        }

        let themeSymbols = [
            "func sunGlassPrimaryButton()",
            "func sunGlassSecondaryButton()",
            "func sunGlassIconButton()",
            "func sunGlassCard("
        ]

        for symbol in themeSymbols {
            XCTAssertTrue(
                theme.contains(symbol),
                "AppTheme.swift must route shared controls through the glass compatibility layer: \(symbol)."
            )
        }
    }

    func testTappableGlassCardsOptIntoInteractiveSurface() throws {
        let tappableCardRoutes: [String: String] = [
            "app/Sunclub/Sources/Views/AutomationView.swift":
                ".sunGlassCard(cornerRadius: AppRadius.card, interactive: true)",
            "app/Sunclub/Sources/Views/TimelineHomeView.swift":
                ".sunGlassCard(cornerRadius: AppRadius.card, interactive: true)"
        ]

        for (path, interactiveCard) in tappableCardRoutes {
            let content = try source(path)
            XCTAssertTrue(
                content.contains(interactiveCard),
                "Tappable card in \(path) must opt into interactive Liquid Glass."
            )
        }
    }

    func testMainAppButtonsRouteThroughLiquidGlassCompatibilityHelpers() throws {
        let root = try repoRoot
        let checkedFiles = try swiftFiles(in: root.appendingPathComponent("app/Sunclub/Sources/Views")) + [
            root.appendingPathComponent("app/Sunclub/Sources/Shared/RootView.swift")
        ]
        let competingStyle = #"\.buttonStyle\([^\n]+\)\s*\.sunGlass(?:Primary|Secondary|Icon)Button"#

        for fileURL in checkedFiles {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertEqual(
                matchCount(competingStyle, in: content),
                0,
                "\(relativePath(for: fileURL)) must use one availability-aware button-style selector, not chain a legacy style before it."
            )
        }

        let sharedComponents = try source("app/Sunclub/Sources/Shared/AppDesignSystem.swift")
        for helper in ["Primary", "Secondary", "Icon"] {
            XCTAssertTrue(
                sharedComponents.contains("func sunGlass\(helper)Button<LegacyStyle: ButtonStyle>"),
                "sunGlass\(helper)Button must select both native and fallback styles itself."
            )
        }
        XCTAssertGreaterThanOrEqual(
            sharedComponents.components(separatedBy: "buttonStyle(legacyStyle)").count - 1,
            2,
            "The shared availability-aware selector must install its exact pre-iOS-26 fallback style."
        )

        XCTAssertFalse(sharedComponents.contains(".buttonStyle(AppPrimaryButtonStyle())"))
        XCTAssertFalse(sharedComponents.contains(".buttonStyle(AppSecondaryPillButtonStyle())"))
        XCTAssertTrue(
            sharedComponents.contains(
                ".sunGlassPrimaryButton(legacyStyle: AppPrimaryButtonStyle(), usesGlass: usesGlass)"
            )
        )
        XCTAssertTrue(
            sharedComponents.contains(
                ".sunGlassSecondaryButton(legacyStyle: AppSecondaryPillButtonStyle(), usesGlass: usesGlass)"
            )
        )
    }

    func testKnownGlassGroupsKeepSingleMaterialBoundary() throws {
        let achievements = try source("app/Sunclub/Sources/Views/AchievementsView.swift")
        XCTAssertFalse(
            achievements.contains(".sunGlassSecondaryButton()"),
            "Share actions inside achievement glass cards must remain flat within the card."
        )

        let history = try source("app/Sunclub/Sources/Views/HistoryView.swift")
        for marker in [
            "tint: label.contains(\"open\") ? AppPalette.sun : AppPalette.success,\n            usesGlass: false",
            "accessibilityIdentifier: \"history.month.applied\",\n            usesGlass: false",
            "accessibilityIdentifier: \"history.month.active\",\n            usesGlass: false",
            "accessibilityIdentifier: \"history.month.rate\",\n            usesGlass: false"
        ] {
            XCTAssertTrue(
                history.contains(marker),
                "History must flatten known metric components inside its glass parent."
            )
        }

        let timeline = try source("app/Sunclub/Sources/Views/TimelineHomeView.swift")
        for marker in [
            "tint: AppPalette.streakAccent,\n            usesGlass: false",
            "tint: AppPalette.sun,\n            usesGlass: false"
        ] {
            XCTAssertTrue(
                timeline.contains(marker),
                "The two status StatCards inside AppCard must remain flat on iOS 26."
            )
        }

        let verification = try source("app/Sunclub/Sources/Views/VerificationSuccessView.swift")
        XCTAssertEqual(
            verification.components(separatedBy: "usesGlass: false").count - 1,
            2,
            "Success metrics inside SunclubCard must remain flat on iOS 26."
        )

        let designSystem = try source("app/Sunclub/Sources/Shared/AppDesignSystem.swift")
        let theme = try source("app/Sunclub/Sources/Shared/AppTheme.swift")
        XCTAssertTrue(designSystem.contains("var sunGlassBoundaryActive: Bool"))
        XCTAssertTrue(designSystem.contains("if usesGlass, !isInsideGlassBoundary"))
        XCTAssertTrue(theme.contains("if isInsideGlassBoundary"))

        let expectedStandaloneHelperCounts: [String: (primary: Int, secondary: Int, icon: Int)] = [
            "app/Sunclub/Sources/Views/RecoveryView.swift": (0, 0, 0),
            "app/Sunclub/Sources/Views/AutomationView.swift": (0, 0, 0),
            "app/Sunclub/Sources/Views/SettingsView.swift": (1, 0, 0),
            "app/Sunclub/Sources/Views/FriendsView.swift": (2, 1, 0),
            "app/Sunclub/Sources/Views/ProductScannerView.swift": (1, 4, 0)
        ]

        for (path, expected) in expectedStandaloneHelperCounts {
            let content = try source(path)
            XCTAssertEqual(
                content.components(separatedBy: ".sunGlassPrimaryButton()").count - 1,
                expected.primary,
                "\(path) must reserve primary glass for standalone controls."
            )
            XCTAssertEqual(
                content.components(separatedBy: ".sunGlassSecondaryButton()").count - 1,
                expected.secondary,
                "\(path) must reserve secondary glass for standalone controls."
            )
            XCTAssertEqual(
                content.components(separatedBy: ".sunGlassIconButton()").count - 1,
                expected.icon,
                "\(path) must keep icon controls flat when their containing card already supplies glass."
            )
        }
    }

    func testMainAppCardCallSitesUseLiquidGlassCompatibilitySurface() throws {
        let migratedPaths = [
            "app/Sunclub/Sources/Shared/SunDayStrip.swift",
            "app/Sunclub/Sources/Views/AutomationView.swift",
            "app/Sunclub/Sources/Views/FriendsView.swift",
            "app/Sunclub/Sources/Views/HistoryView.swift",
            "app/Sunclub/Sources/Views/ManualLogView.swift",
            "app/Sunclub/Sources/Views/PrivacyView.swift",
            "app/Sunclub/Sources/Views/RecoveryView.swift",
            "app/Sunclub/Sources/Views/SettingsView.swift",
            "app/Sunclub/Sources/Views/SkinHealthReportView.swift",
            "app/Sunclub/Sources/Views/SupportView.swift",
            "app/Sunclub/Sources/Views/Components/TimelineLogSection.swift"
        ]

        for path in migratedPaths {
            let content = try source(path)
            for legacyCall in [
                ".background(cardBackground)",
                ".background(referenceRowBackground)",
                ".background(rowGroupBackground)"
            ] {
                XCTAssertFalse(
                    content.contains(legacyCall),
                    "\(path) must replace \(legacyCall) with the availability-aware glass card helper."
                )
            }
            XCTAssertTrue(content.contains(".sunGlassCard("), "\(path) must adopt sunGlassCard.")
        }

        let interactiveCardPaths = [
            "app/Sunclub/Sources/Shared/SunDayStrip.swift",
            "app/Sunclub/Sources/Views/AutomationView.swift",
            "app/Sunclub/Sources/Views/FriendsView.swift",
            "app/Sunclub/Sources/Views/PrivacyView.swift",
            "app/Sunclub/Sources/Views/SettingsView.swift",
            "app/Sunclub/Sources/Views/SupportView.swift",
            "app/Sunclub/Sources/Views/TimelineHomeView.swift"
        ]
        for path in interactiveCardPaths {
            XCTAssertTrue(
                try source(path).contains("interactive: true"),
                "Tappable cards in \(path) must request interactive glass."
            )
        }
    }

    func testFixedFootersAndRelatedControlsUseNativeGlassContainers() throws {
        let theme = try source("app/Sunclub/Sources/Shared/AppTheme.swift")
        XCTAssertEqual(
            theme.components(separatedBy: ".safeAreaInset(edge: .bottom").count - 1,
            2,
            "Light and dark fixed footers must allow scrolling content beneath their native safe-area overlays."
        )
        XCTAssertGreaterThanOrEqual(
            theme.components(separatedBy: "SunGlassEffectContainer(").count - 1,
            2,
            "Both shared fixed footer variants must group their glass controls."
        )
        XCTAssertTrue(
            theme.contains("private var legacyFooter"),
            "The pre-iOS-26 light footer must retain its opaque gradient fallback."
        )

        let history = try source("app/Sunclub/Sources/Views/HistoryView.swift")
        XCTAssertTrue(history.contains("SunGlassEffectContainer(spacing: 12)"))
        XCTAssertTrue(
            history.contains(".sunGlassIconButton(legacyStyle: HistoryMonthNavigationButtonStyle(isEnabled: isEnabled))")
        )

        let scanner = try source("app/Sunclub/Sources/Views/ProductScannerView.swift")
        XCTAssertTrue(scanner.contains("SunGlassEffectContainer(spacing: 12)"))
        XCTAssertTrue(theme.contains(".sunGlassSurface(cornerRadius: AppRadius.pill)"))
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
                ".sunGlassCard("
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

    private func matchCount(_ pattern: String, in content: String) -> Int {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return 0
        }
        return expression.numberOfMatches(
            in: content,
            range: NSRange(content.startIndex..., in: content)
        )
    }
}
