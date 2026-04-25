import SwiftUI

enum AppColor {
    enum Text {
        static let primary = Color(red: 0.075, green: 0.071, blue: 0.067)
        static let secondary = Color(red: 0.400, green: 0.372, blue: 0.345)
    }

    static let background = Color(red: 0.992, green: 0.984, blue: 0.965)
    static let backgroundWarm = Color(red: 1.000, green: 0.944, blue: 0.804)
    static let surface = Color(red: 1.000, green: 0.998, blue: 0.992)
    static let surfaceElevated = Color(red: 1.000, green: 1.000, blue: 1.000)
    static let control = Color(red: 1.000, green: 0.968, blue: 0.910)
    static let accent = Color(red: 0.965, green: 0.610, blue: 0.035)
    static let accentSoft = Color(red: 1.000, green: 0.890, blue: 0.620)
    static let success = Color(red: 0.155, green: 0.715, blue: 0.330)
    static let warning = Color(red: 0.760, green: 0.240, blue: 0.180)
    static let muted = Color(red: 0.845, green: 0.835, blue: 0.820)
    static let stroke = Color(red: 0.075, green: 0.071, blue: 0.067).opacity(0.075)
    static let onAccent = Color(red: 0.075, green: 0.071, blue: 0.067)
    static let onColor = Text.primary
}

enum AppRadius {
    static let card: CGFloat = 22
    static let button: CGFloat = 18
    static let pill: CGFloat = .infinity
    static let tiny: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let insetCard: CGFloat = 18
    static let control: CGFloat = 18
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
        radius: 18,
        xOffset: 0,
        yOffset: 10
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
        switch self {
        case .largeTitle:
            return -0.35
        case .title:
            return -0.30
        case .sectionHeader:
            return -0.20
        default:
            return 0
        }
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

                AppText(title, style: .bodyMedium, color: AppColor.onColor)
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
                .fill(tint.opacity(0.10))

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
            .foregroundStyle(isEnabled ? AppColor.onColor : AppColor.Text.secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(isEnabled ? AppColor.accent : AppColor.muted.opacity(0.42))
                    .appShadow(isEnabled ? AppShadow.soft : nil)
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
