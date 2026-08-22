import SwiftUI
import UIKit
import XCTest
@testable import Sunclub

final class DarkModeThemeTests: XCTestCase {
    func testCorePaletteHasAccessibleDarkModeContrast() {
        assertContrast(AppPalette.ink, against: AppPalette.cardFill, style: .dark, minimum: 4.5)
        assertContrast(AppPalette.softInk, against: AppPalette.cardFill, style: .dark, minimum: 3.0)
        assertContrast(AppPalette.ink, against: AppPalette.darkCanvas, style: .dark, minimum: 4.5)
        assertContrast(AppPalette.ink, against: AppPalette.streakBackground, style: .dark, minimum: 4.5)
        assertContrast(AppPalette.sun, against: AppPalette.darkCanvas, style: .dark, minimum: 3.0)
    }

    func testCorePalettePreservesLightModeContrast() {
        assertContrast(AppPalette.ink, against: AppPalette.cardFill, style: .light, minimum: 4.5)
        assertContrast(AppPalette.softInk, against: AppPalette.cardFill, style: .light, minimum: 3.0)
        assertContrast(AppPalette.ink, against: AppPalette.streakBackground, style: .light, minimum: 4.5)
    }

    func testUVPillTextHasSufficientContrastAgainstWarmGlow() {
        assertContrast(AppPalette.ink, against: AppPalette.warmGlow, style: .light, minimum: 3.0)
        assertContrast(AppPalette.ink, against: AppPalette.warmGlow, style: .dark, minimum: 3.0)
    }

    func testElevatedCardFillContrastInDarkMode() {
        assertContrast(AppPalette.ink, against: AppPalette.elevatedCardFill, style: .dark, minimum: 4.5)
        assertContrast(AppPalette.softInk, against: AppPalette.elevatedCardFill, style: .dark, minimum: 3.0)
    }

    func testControlFillContrastInDarkMode() {
        assertContrast(AppPalette.ink, against: AppPalette.controlFill, style: .dark, minimum: 4.5)
    }

    func testDesignSystemBaseColorsAdaptForDarkMode() {
        assertContrast(AppColor.Text.primary, against: AppColor.surfaceElevated, style: .dark, minimum: 4.5)
        assertContrast(AppColor.Text.secondary, against: AppColor.surfaceElevated, style: .dark, minimum: 3.0)
        assertContrast(AppColor.Text.primary, against: AppColor.background, style: .dark, minimum: 4.5)
        assertContrast(AppColor.Text.primary, against: AppColor.control, style: .dark, minimum: 4.5)
    }

    func testPrimaryActionColorsStayReadableAcrossAppearances() {
        assertContrast(AppColor.primaryActionForeground, against: AppColor.primaryAction, style: .light, minimum: 4.5)
        assertContrast(AppColor.primaryActionForeground, against: AppColor.primaryAction, style: .dark, minimum: 4.5)
    }

    func testAccentForegroundMaintainsContrastAcrossAppearances() {
        let accentFills = [
            AppPalette.sun,
            AppPalette.coral,
            AppPalette.aloe,
            AppPalette.pool,
            AppPalette.success
        ]

        for style in [UIUserInterfaceStyle.light, .dark] {
            for fill in accentFills {
                assertContrast(AppPalette.onAccent, against: fill, style: style, minimum: 4.5)
            }
        }
    }

    func testNativeChromeTintMaintainsContrastAcrossAppearancesAndContrastModes() {
        let cases: [(UIUserInterfaceStyle, UIAccessibilityContrast, Color)] = [
            (.light, .normal, .white),
            (.light, .high, .white),
            (.dark, .normal, AppPalette.darkCanvas),
            (.dark, .high, AppPalette.darkCanvas)
        ]

        for (style, accessibilityContrast, background) in cases {
            assertContrast(
                AppPalette.nativeChromeTint,
                against: background,
                style: style,
                accessibilityContrast: accessibilityContrast,
                minimum: 4.5
            )
        }
    }

    private func assertContrast(
        _ foreground: Color,
        against background: Color,
        style: UIUserInterfaceStyle,
        accessibilityContrast: UIAccessibilityContrast = .normal,
        minimum: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let foregroundColor = resolvedColor(
            foreground,
            style: style,
            accessibilityContrast: accessibilityContrast
        )
        let backgroundColor = resolvedColor(
            background,
            style: style,
            accessibilityContrast: accessibilityContrast
        )
        let ratio = contrastRatio(foregroundColor, backgroundColor)

        XCTAssertGreaterThanOrEqual(
            ratio,
            minimum,
            "Expected contrast >= \(minimum), got \(String(format: "%.2f", ratio)).",
            file: file,
            line: line
        )
    }

    private func resolvedColor(
        _ color: Color,
        style: UIUserInterfaceStyle,
        accessibilityContrast: UIAccessibilityContrast
    ) -> UIColor {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = style
            traits.accessibilityContrast = accessibilityContrast
        }
        return UIColor(color).resolvedColor(with: traits)
    }

    private func contrastRatio(_ first: UIColor, _ second: UIColor) -> Double {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> Double {
        let components = rgbaComponents(color)
        return 0.2126 * linearized(components.red)
            + 0.7152 * linearized(components.green)
            + 0.0722 * linearized(components.blue)
    }

    private func linearized(_ component: Double) -> Double {
        component <= 0.03928
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }

    private func rgbaComponents(_ color: UIColor) -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let converted = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .unspecified))
        XCTAssertTrue(converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}
