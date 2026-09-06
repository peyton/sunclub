import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum AppColor {
    private static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit) && !os(watchOS)
        return Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
        #else
        return light
        #endif
    }

    enum Text {
        static let primary = AppColor.adaptive(
            light: Color(red: 0.192157, green: 0.145098, blue: 0.121569),
            dark: Color(red: 1.000000, green: 0.972549, blue: 0.941176)
        )
        static let secondary = AppColor.adaptive(
            light: Color(red: 0.458824, green: 0.388235, blue: 0.345098),
            dark: Color(red: 0.796078, green: 0.705882, blue: 0.643137)
        )
    }

    enum Watch {
        static let background = Color(red: 0.145098, green: 0.109804, blue: 0.094118)
        static let surface = Color(red: 0.188235, green: 0.141176, blue: 0.117647)
        static let textPrimary = Color(red: 1.000000, green: 0.972549, blue: 0.941176)
        static let textSecondary = Color(red: 0.796078, green: 0.705882, blue: 0.643137)
        static let extreme = Color(red: 1.000, green: 0.430, blue: 0.720)
    }

    static let background = adaptive(
        light: Color(red: 1.000000, green: 0.972549, blue: 0.941176),
        dark: Color(red: 0.145098, green: 0.109804, blue: 0.094118)
    )
    static let backgroundWarm = adaptive(
        light: Color(red: 1.000000, green: 0.909804, blue: 0.811765),
        dark: Color(red: 0.286275, green: 0.196078, blue: 0.129412)
    )
    static let surface = adaptive(
        light: Color(red: 1.000000, green: 0.988235, blue: 0.972549),
        dark: Color(red: 0.188235, green: 0.141176, blue: 0.117647)
    )
    static let surfaceElevated = adaptive(
        light: Color(red: 1.000000, green: 1.000000, blue: 1.000000),
        dark: Color(red: 0.227451, green: 0.172549, blue: 0.141176)
    )
    static let control = adaptive(
        light: Color(red: 1.000000, green: 0.909804, blue: 0.811765),
        dark: Color(red: 0.286275, green: 0.196078, blue: 0.129412)
    )
    static let accent = adaptive(
        light: Color(red: 0.654902, green: 0.286275, blue: 0.047059),
        dark: Color(red: 1.000000, green: 0.737255, blue: 0.482353)
    )
    static let accentSoft = adaptive(
        light: Color(red: 1.000000, green: 0.909804, blue: 0.811765),
        dark: Color(red: 0.286275, green: 0.196078, blue: 0.129412)
    )
    static let apricot = adaptive(
        light: Color(red: 0.929412, green: 0.580392, blue: 0.121569),
        dark: Color(red: 1.000000, green: 0.737255, blue: 0.482353)
    )
    static let sun = adaptive(
        light: Color(red: 0.970, green: 0.670, blue: 0.000),
        dark: Color(red: 1.000, green: 0.705, blue: 0.145)
    )
    static let sunSoft = adaptive(
        light: Color(red: 1.000, green: 0.905, blue: 0.620),
        dark: Color(red: 0.430, green: 0.286, blue: 0.126)
    )
    static let success = adaptive(
        light: Color(red: 0.275, green: 0.760, blue: 0.340),
        dark: Color(red: 0.360, green: 0.875, blue: 0.540)
    )
    static let warning = adaptive(
        light: Color(red: 0.870, green: 0.290, blue: 0.220),
        dark: Color(red: 1.000, green: 0.450, blue: 0.340)
    )
    static let muted = adaptive(
        light: Color(red: 0.796078, green: 0.725490, blue: 0.678431),
        dark: Color(red: 0.552941, green: 0.470588, blue: 0.415686)
    )
    static let stroke = adaptive(
        light: Color(red: 0.192157, green: 0.145098, blue: 0.121569).opacity(0.095),
        dark: Color(red: 1.000000, green: 0.972549, blue: 0.941176).opacity(0.160)
    )
    // Native prominent glass uses white labels in both appearances.
    static let primaryAction = Color(red: 0.654902, green: 0.286275, blue: 0.047059)
    static let primaryActionForeground = Color.white
    // Foreground for bright sun, success, and severity fills, not deep action orange.
    static let onAccent = Color(red: 0.086275, green: 0.054902, blue: 0.035294)
    static let onColor = Color.white
}

enum AppRadius {
    static let card: CGFloat = 18
    static let button: CGFloat = 14
    static let pill: CGFloat = .infinity
    static let tiny: CGFloat = 8
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let insetCard: CGFloat = 14
    static let control: CGFloat = 14
}

// swiftlint:disable identifier_name
enum AppSpacing {
    static let xxs: CGFloat = 8
    static let xs: CGFloat = 12
    static let sm: CGFloat = 16
    static let md: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}
// swiftlint:enable identifier_name

struct AppShadowStyle {
    let color: Color
    let radius: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
}

enum AppShadow {
    static let soft = AppShadowStyle(
        color: AppColor.Text.primary.opacity(0.055),
        radius: 16,
        xOffset: 0,
        yOffset: 8
    )
    static let floating = AppShadowStyle(
        color: AppColor.Text.primary.opacity(0.100),
        radius: 24,
        xOffset: 0,
        yOffset: 14
    )
}

enum AppMotion {
    static func easeOut(duration: Double, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }
}

enum SunGlassSurfaceStyle {
    case regular
    case interactive
}

private struct SunGlassBoundaryActiveKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sunGlassBoundaryActive: Bool {
        get { self[SunGlassBoundaryActiveKey.self] }
        set { self[SunGlassBoundaryActiveKey.self] = newValue }
    }
}

struct SunGlassEffectContainer<Content: View>: View {
    var spacing: CGFloat?
    let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private struct SunGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let style: SunGlassSurfaceStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            switch style {
            case .regular:
                content
                    .environment(\.sunGlassBoundaryActive, true)
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            case .interactive:
                content
                    .environment(\.sunGlassBoundaryActive, true)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

private enum SunGlassButtonRole {
    case primary
    case secondary
    case icon
}

private struct SunGlassButtonStyleModifier<LegacyStyle: ButtonStyle>: ViewModifier {
    @Environment(\.sunGlassBoundaryActive) private var isInsideGlassBoundary

    let role: SunGlassButtonRole
    let legacyStyle: LegacyStyle
    let usesGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *), usesGlass, !isInsideGlassBoundary {
            switch role {
            case .primary:
                content.buttonStyle(.glassProminent)
                    .tint(AppColor.primaryAction)
            case .secondary, .icon:
                content.buttonStyle(.glass)
            }
        } else {
            content.buttonStyle(legacyStyle)
        }
        #else
        content.buttonStyle(legacyStyle)
        #endif
    }
}

extension View {
    func sunGlassPrimaryButton<LegacyStyle: ButtonStyle>(
        legacyStyle: LegacyStyle,
        usesGlass: Bool = true
    ) -> some View {
        modifier(
            SunGlassButtonStyleModifier(
                role: .primary,
                legacyStyle: legacyStyle,
                usesGlass: usesGlass
            )
        )
    }

    func sunGlassSecondaryButton<LegacyStyle: ButtonStyle>(
        legacyStyle: LegacyStyle,
        usesGlass: Bool = true
    ) -> some View {
        modifier(
            SunGlassButtonStyleModifier(
                role: .secondary,
                legacyStyle: legacyStyle,
                usesGlass: usesGlass
            )
        )
    }

    func sunGlassIconButton<LegacyStyle: ButtonStyle>(
        legacyStyle: LegacyStyle,
        usesGlass: Bool = true
    ) -> some View {
        modifier(
            SunGlassButtonStyleModifier(
                role: .icon,
                legacyStyle: legacyStyle,
                usesGlass: usesGlass
            )
        )
    }
}

enum AppFont {
    /// Supply a @ScaledMetric value to honor the view's Dynamic Type environment.
    static func heroMetric(size: CGFloat = 72) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .rounded, weight: weight)
    }

    static func monospace(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .monospaced, weight: weight)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 34...:
            return .largeTitle
        case 28..<34:
            return .title
        case 24..<28:
            return .title2
        case 20..<24:
            return .title3
        case 17..<20:
            return .body
        case 15..<17:
            return .callout
        case 13..<15:
            return .subheadline
        case 11..<13:
            return .footnote
        default:
            return .caption2
        }
    }
}

enum AppTextStyle {
    case largeTitle
    case title
    case sectionHeader
    case body
    case bodyMedium
    case caption
    case captionMedium
    case metric
    case pillLabel

    var font: Font {
        switch self {
        case .largeTitle:
            return .system(.largeTitle, design: .rounded, weight: .semibold)
        case .title:
            return .system(.title2, design: .rounded, weight: .semibold)
        case .sectionHeader:
            return .system(.title3, design: .rounded, weight: .semibold)
        case .body:
            return .system(.body, design: .rounded)
        case .bodyMedium:
            return .system(.body, design: .rounded, weight: .medium)
        case .caption:
            return .system(.subheadline, design: .rounded)
        case .captionMedium:
            return .system(.subheadline, design: .rounded, weight: .medium)
        case .metric:
            return .system(.headline, design: .rounded, weight: .semibold)
        case .pillLabel:
            return .system(.subheadline, design: .rounded, weight: .semibold)
        }
    }

    var tracking: CGFloat {
        0
    }
}

struct AppText: View {
    let content: Text
    var style: AppTextStyle = .body
    var color: Color = AppColor.Text.primary
    var alignment: TextAlignment = .leading

    init(
        _ text: String,
        style: AppTextStyle = .body,
        color: Color = AppColor.Text.primary,
        alignment: TextAlignment = .leading
    ) {
        self.content = Text(text)
        self.style = style
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AppCard<Content: View>: View {
    @Environment(\.sunGlassBoundaryActive) private var isInsideGlassBoundary

    var padding: CGFloat = AppSpacing.md
    var cornerRadius: CGFloat = AppRadius.card
    var fill: Color = AppColor.surfaceElevated
    var showsShadow = true
    let content: Content

    init(
        padding: CGFloat = AppSpacing.md,
        cornerRadius: CGFloat = AppRadius.card,
        fill: Color = AppColor.surfaceElevated,
        showsShadow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.fill = fill
        self.showsShadow = showsShadow
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            if isInsideGlassBoundary {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(padding)
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(padding)
                    .sunGlassSurface(cornerRadius: cornerRadius)
            }
        } else {
            legacyBody
        }
        #else
        legacyBody
        #endif
    }

    private var legacyBody: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .appShadow(showsShadow ? AppShadow.soft : nil)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColor.stroke, lineWidth: 1)
            }
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var identifier: String?
    var usesGlass: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        identifier: String? = nil,
        usesGlass: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.identifier = identifier
        self.usesGlass = usesGlass
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        let button = Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(AppTextStyle.bodyMedium.font)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .sunGlassPrimaryButton(legacyStyle: AppPrimaryButtonStyle(), usesGlass: usesGlass)

        if let identifier {
            button.accessibilityIdentifier(identifier)
        } else {
            button
        }
    }
}

struct SecondaryPillButton: View {
    let title: String
    var systemImage: String?
    var identifier: String?
    var usesGlass: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        identifier: String? = nil,
        usesGlass: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.identifier = identifier
        self.usesGlass = usesGlass
        self.action = action
    }

    @ViewBuilder
    var body: some View {
        let button = Button(action: action) {
            HStack(spacing: AppSpacing.xxs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .accessibilityHidden(true)
                }

                AppText(title, style: .pillLabel)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .sunGlassSecondaryButton(legacyStyle: AppSecondaryPillButtonStyle(), usesGlass: usesGlass)

        if let identifier {
            button.accessibilityIdentifier(identifier)
        } else {
            button
        }
    }
}

struct StatusBadge: View {
    let title: String
    var systemImage: String = "checkmark.shield.fill"
    var tint: Color = AppColor.success

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))

            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 2)

            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)

                AppText(title, style: .captionMedium)
            }
            .padding(AppSpacing.xs)
        }
        .frame(width: 104, height: 104)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct FeatureIcon: View {
    let systemName: String
    var tint: Color = AppColor.accent
    var fill: Color = AppColor.control
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .stroke(AppColor.stroke, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct InfoRow: View {
    let title: String
    let detail: String
    var systemImage: String
    var tint: Color = AppColor.accent
    var showsChevron = false

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            FeatureIcon(systemName: systemImage, tint: tint, fill: tint.opacity(0.12), size: 36)

            VStack(alignment: .leading, spacing: 2) {
                AppText(title, style: .bodyMedium)
                AppText(detail, style: .caption, color: AppColor.Text.secondary)
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.Text.secondary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct DayCapsule: View {
    var fill: Color
    var stroke: Color = AppColor.stroke
    var isSelected = false
    var isFuture = false
    var isComplete = false
    var showsSecondaryDot = false
    var size: CGFloat = 54
    var dayNumber: String?
    var statusSymbolName: String?
    var foreground: Color = AppColor.Text.primary

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isFuture ? AppColor.surface.opacity(0.35) : fill)

                if isFuture {
                    DiagonalHatch(color: AppColor.muted.opacity(isSelected ? 0.40 : 0.28))
                        .clipShape(Circle())
                        .padding(isSelected ? 1 : 2)
                }

                Circle()
                    .strokeBorder(
                        isSelected ? AppColor.Text.primary : stroke,
                        lineWidth: isSelected ? 2 : 1.5
                    )
                    .padding(isSelected ? 0 : 3)

                if isComplete {
                    Circle()
                        .strokeBorder(AppColor.surfaceElevated.opacity(0.92), lineWidth: 3)
                        .padding(5)
                }

                if dayNumber != nil || statusSymbolName != nil {
                    VStack(spacing: 0) {
                        if let dayNumber {
                            Text(dayNumber)
                                .font(AppTextStyle.captionMedium.font)
                        }
                        if let statusSymbolName {
                            Image(systemName: statusSymbolName)
                                .font(AppTextStyle.captionMedium.font)
                        }
                    }
                    .foregroundStyle(foreground)
                }
            }
            .frame(width: size, height: size)

            Circle()
                .fill(showsSecondaryDot ? AppColor.success : Color.clear)
                .frame(width: 8, height: 8)
        }
        .frame(width: size + 8)
        .accessibilityHidden(true)
    }
}

struct StatCard: View {
    @Environment(\.sunGlassBoundaryActive) private var isInsideGlassBoundary

    let value: String
    let label: String
    var systemImage: String
    var tint: Color = AppColor.accent
    var usesGlass = true

    @ViewBuilder
    var body: some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            if usesGlass, !isInsideGlassBoundary {
                cardContent
                    .sunGlassSurface(cornerRadius: AppRadius.insetCard)
            } else {
                cardContent
            }
        } else {
            legacyCard
        }
        #else
        legacyCard
        #endif
    }

    private var cardContent: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                AppText(value, style: .title)
                AppText(label, style: .caption, color: AppColor.Text.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var legacyCard: some View {
        cardContent
        .background {
            RoundedRectangle(cornerRadius: AppRadius.insetCard, style: .continuous)
                .fill(AppColor.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.insetCard, style: .continuous)
                .stroke(AppColor.stroke, lineWidth: 1)
        }
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(isEnabled ? AppColor.primaryActionForeground : AppColor.Text.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(isEnabled ? AppColor.primaryAction : AppColor.muted.opacity(0.42))
                    .appShadow(isEnabled ? AppShadow.floating : nil)
            }
            .opacity(configuration.isPressed ? 0.90 : (isEnabled ? 1 : 0.68))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.978 : 1))
            .animation(AppMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct AppSecondaryPillButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColor.Text.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                Capsule()
                    .fill(AppColor.control.opacity(isEnabled ? 0.72 : 0.36))
                    .appShadow(isEnabled ? AppShadow.soft : nil)
            }
            .overlay {
                Capsule()
                    .stroke(AppColor.stroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.90 : (isEnabled ? 1 : 0.68))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.982 : 1))
            .animation(AppMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

private struct DiagonalHatch: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var currentX = -size.height
            while currentX < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: currentX, y: size.height))
                path.addLine(to: CGPoint(x: currentX + size.height, y: 0))
                context.stroke(path, with: .color(color), lineWidth: 1)
                currentX += 6
            }
        }
    }
}

extension View {
    func sunGlassSurface(
        cornerRadius: CGFloat = AppRadius.card,
        style: SunGlassSurfaceStyle = .regular
    ) -> some View {
        modifier(SunGlassSurfaceModifier(cornerRadius: cornerRadius, style: style))
    }

    func appShadow(_ style: AppShadowStyle?) -> some View {
        shadow(
            color: style?.color ?? .clear,
            radius: style?.radius ?? 0,
            x: style?.xOffset ?? 0,
            y: style?.yOffset ?? 0
        )
    }
}
