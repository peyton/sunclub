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
            light: Color(red: 0.025, green: 0.108, blue: 0.205),
            dark: Color(red: 0.964, green: 0.925, blue: 0.855)
        )
        static let secondary = AppColor.adaptive(
            light: Color(red: 0.310, green: 0.360, blue: 0.440),
            dark: Color(red: 0.745, green: 0.690, blue: 0.620)
        )
    }

    enum Watch {
        static let background = Color(red: 0.055, green: 0.052, blue: 0.048)
        static let surface = Color(red: 0.125, green: 0.115, blue: 0.100)
        static let textPrimary = Color(red: 0.965, green: 0.925, blue: 0.855)
        static let textSecondary = Color(red: 0.745, green: 0.690, blue: 0.620)
        static let extreme = Color(red: 1.000, green: 0.430, blue: 0.720)
    }

    static let background = adaptive(
        light: Color(red: 0.988, green: 0.965, blue: 0.925),
        dark: Color(red: 0.114, green: 0.098, blue: 0.086)
    )
    static let backgroundWarm = adaptive(
        light: Color(red: 1.000, green: 0.933, blue: 0.720),
        dark: Color(red: 0.315, green: 0.164, blue: 0.068)
    )
    static let surface = adaptive(
        light: Color(red: 1.000, green: 0.995, blue: 0.982),
        dark: Color(red: 0.171, green: 0.150, blue: 0.129)
    )
    static let surfaceElevated = adaptive(
        light: Color(red: 1.000, green: 1.000, blue: 1.000),
        dark: Color(red: 0.252, green: 0.220, blue: 0.184)
    )
    static let control = adaptive(
        light: Color(red: 0.965, green: 0.976, blue: 1.000),
        dark: Color(red: 0.294, green: 0.252, blue: 0.207)
    )
    static let accent = adaptive(
        light: Color(red: 0.080, green: 0.455, blue: 0.980),
        dark: Color(red: 0.385, green: 0.745, blue: 0.940)
    )
    static let accentSoft = adaptive(
        light: Color(red: 0.845, green: 0.910, blue: 1.000),
        dark: Color(red: 0.120, green: 0.200, blue: 0.300)
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
        light: Color(red: 0.825, green: 0.850, blue: 0.875),
        dark: Color(red: 0.430, green: 0.395, blue: 0.360)
    )
    static let stroke = adaptive(
        light: Color(red: 0.025, green: 0.108, blue: 0.205).opacity(0.095),
        dark: Color(red: 1.000, green: 0.900, blue: 0.760).opacity(0.160)
    )
    static let primaryAction = adaptive(
        light: Color(red: 0.025, green: 0.108, blue: 0.205),
        dark: Color(red: 1.000, green: 0.705, blue: 0.145)
    )
    static let primaryActionForeground = adaptive(
        light: .white,
        dark: Color(red: 0.012, green: 0.036, blue: 0.075)
    )
    static let onAccent = Color(red: 0.012, green: 0.036, blue: 0.075)
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
        color: AppColor.Text.primary.opacity(0.070),
        radius: 16,
        xOffset: 0,
        yOffset: 8
    )
    static let floating = AppShadowStyle(
        color: AppColor.Text.primary.opacity(0.120),
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

enum AppFont {
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func monospace(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
            return .system(size: 32, weight: .semibold, design: .rounded)
        case .title:
            return .system(size: 26, weight: .semibold, design: .rounded)
        case .sectionHeader:
            return .system(size: 21, weight: .semibold, design: .rounded)
        case .body:
            return .system(size: 17, weight: .regular, design: .rounded)
        case .bodyMedium:
            return .system(size: 17, weight: .medium, design: .rounded)
        case .caption:
            return .system(size: 14, weight: .regular, design: .rounded)
        case .captionMedium:
            return .system(size: 14, weight: .medium, design: .rounded)
        case .metric:
            return .system(size: 18, weight: .semibold, design: .rounded)
        case .pillLabel:
            return .system(size: 14, weight: .semibold, design: .rounded)
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

    var body: some View {
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
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.identifier = identifier
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

                AppText(title, style: .bodyMedium, color: AppColor.primaryActionForeground)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(AppPrimaryButtonStyle())

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
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.identifier = identifier
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
        .buttonStyle(AppSecondaryPillButtonStyle())

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

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isFuture ? AppColor.surface.opacity(0.35) : fill)

                if isFuture {
                    DiagonalHatch(color: AppColor.muted.opacity(0.28))
                        .clipShape(Circle())
                        .padding(2)
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
    let value: String
    let label: String
    var systemImage: String
    var tint: Color = AppColor.accent

    var body: some View {
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
        .background {
            RoundedRectangle(cornerRadius: AppRadius.insetCard, style: .continuous)
                .fill(AppColor.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.insetCard, style: .continuous)
                .stroke(AppColor.stroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
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
    func appShadow(_ style: AppShadowStyle?) -> some View {
        shadow(
            color: style?.color ?? .clear,
            radius: style?.radius ?? 0,
            x: style?.xOffset ?? 0,
            y: style?.yOffset ?? 0
        )
    }
}
