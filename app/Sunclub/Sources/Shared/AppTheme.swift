import SwiftUI

enum AppPalette {
    static let cream = Color(red: 0.982, green: 0.965, blue: 0.939)
    static let warmGlow = Color(red: 1.000, green: 0.930, blue: 0.760)
    static let sun = Color(red: 0.980, green: 0.643, blue: 0.012)
    static let darkCanvas = Color(red: 0.114, green: 0.098, blue: 0.086)
    static let darkSurface = Color(red: 0.171, green: 0.150, blue: 0.129)
    static let ink = Color(red: 0.129, green: 0.114, blue: 0.102)
    static let softInk = Color(red: 0.514, green: 0.459, blue: 0.427)
    static let success = Color(red: 0.151, green: 0.772, blue: 0.353)
    static let muted = Color(red: 0.832, green: 0.832, blue: 0.842)
    static let white = Color.white
}

struct SunBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.cream, Color.white, AppPalette.cream],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppPalette.warmGlow.opacity(0.65))
                .frame(width: 360, height: 360)
                .blur(radius: 55)
                .offset(x: -110, y: -280)

            Circle()
                .fill(AppPalette.sun.opacity(0.12))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 120, y: 420)
        }
        .ignoresSafeArea()
    }
}

struct SunDarkBackdrop: View {
    var body: some View {
        ZStack {
            AppPalette.darkCanvas

            Circle()
                .fill(Color.white.opacity(0.035))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: -120, y: -260)

            Circle()
                .fill(AppPalette.sun.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 130, y: 340)
        }
        .ignoresSafeArea()
    }
}

struct SunLightScreen<Content: View, Footer: View>: View {
    let content: Content
    let footer: Footer

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            content
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 18)
                        .frame(minHeight: proxy.size.height - 120, alignment: .top)
                    }

                    footer
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                }
            }

        }
        .background {
            SunBackdrop()
        }
    }
}

extension SunLightScreen where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content) { EmptyView() }
    }
}

struct SunDarkScreen<Content: View, Footer: View>: View {
    let content: Content
    let footer: Footer

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 26) {
                            content
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 18)
                        .frame(minHeight: proxy.size.height - 120, alignment: .top)
                    }

                    footer
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                }
            }
        }
        .background {
            SunDarkBackdrop()
        }
    }
}

extension SunDarkScreen where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content) { EmptyView() }
    }
}

struct SunScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        SunLightScreen {
            content
        }
    }
}

struct SunPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppPalette.sun)
            )
            .opacity(configuration.isPressed ? 0.90 : 1)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct SunSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct SunStepHeader: View {
    let step: Int
    let total: Int
    var tint: Color = Color.white.opacity(0.62)

    var body: some View {
        Text("Step \(step) of \(total)")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityIdentifier("step.header")
    }
}

struct SunLightHeader: View {
    let title: String
    let showsBack: Bool
    let trailingSystemImage: String?
    let onBack: (() -> Void)?
    let onTrailingTap: (() -> Void)?

    init(
        title: String,
        showsBack: Bool = false,
        onBack: (() -> Void)? = nil,
        trailingSystemImage: String? = nil,
        onTrailingTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.showsBack = showsBack
        self.onBack = onBack
        self.trailingSystemImage = trailingSystemImage
        self.onTrailingTap = onTrailingTap
    }

    var body: some View {
        HStack {
            if showsBack {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("screen.back")
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            Spacer(minLength: 0)

            if let trailingSystemImage {
                Button(action: { onTrailingTap?() }) {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }
}

struct SunLogoMark: View {
    let size: CGFloat

    var body: some View {
        let cornerRadius = size * 0.22
        let coreSize = size * 0.38

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.984, green: 0.969, blue: 0.937),
                            Color(red: 1.000, green: 0.929, blue: 0.741)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(AppPalette.sun.opacity(0.12), lineWidth: max(1, size * 0.008))
                .frame(width: size * 0.51, height: size * 0.51)

            Circle()
                .stroke(AppPalette.sun.opacity(0.06), lineWidth: max(1, size * 0.004))
                .frame(width: size * 0.63, height: size * 0.63)

            Circle()
                .fill(AppPalette.sun)
                .frame(width: coreSize, height: coreSize)

            Circle()
                .fill(Color(red: 1.000, green: 0.867, blue: 0.502).opacity(0.3))
                .frame(width: size * 0.23, height: size * 0.23)
                .offset(x: -size * 0.03, y: -size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

struct SunSettingsRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct SunStatusCard: View {
    let title: String
    let detail: String
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.82))
        )
    }
}

struct SunCameraOverlayLabel: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.92), in: Capsule())
    }
}
