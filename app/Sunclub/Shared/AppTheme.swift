import SwiftUI

enum AppPalette {
    static let cream = Color(red: 0.992, green: 0.972, blue: 0.925)
    static let shell = Color(red: 0.968, green: 0.893, blue: 0.766)
    static let sand = Color(red: 0.930, green: 0.790, blue: 0.604)
    static let sun = Color(red: 0.961, green: 0.645, blue: 0.180)
    static let coral = Color(red: 0.862, green: 0.333, blue: 0.208)
    static let sea = Color(red: 0.121, green: 0.471, blue: 0.498)
    static let mint = Color(red: 0.239, green: 0.612, blue: 0.498)
    static let ink = Color(red: 0.102, green: 0.133, blue: 0.176)
    static let softInk = Color(red: 0.303, green: 0.347, blue: 0.382)
    static let success = Color(red: 0.192, green: 0.580, blue: 0.408)
    static let warning = Color(red: 0.878, green: 0.553, blue: 0.180)
    static let danger = Color(red: 0.757, green: 0.271, blue: 0.227)
}

struct SunBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppPalette.cream,
                    AppPalette.shell,
                    Color(red: 0.914, green: 0.949, blue: 0.933)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppPalette.sun.opacity(0.20))
                .frame(width: 300, height: 300)
                .blur(radius: 24)
                .offset(x: -150, y: -300)

            Circle()
                .fill(AppPalette.sea.opacity(0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 46)
                .offset(x: 180, y: -120)

            Circle()
                .fill(AppPalette.coral.opacity(0.13))
                .frame(width: 360, height: 360)
                .blur(radius: 58)
                .offset(x: 150, y: 380)

            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 520, height: 132)
                .rotationEffect(.degrees(-18))
                .offset(x: 160, y: 250)
                .blur(radius: 3)

            Capsule()
                .fill(AppPalette.ink.opacity(0.05))
                .frame(width: 420, height: 78)
                .rotationEffect(.degrees(24))
                .offset(x: -180, y: 210)

            VStack(spacing: 24) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.09 : 0.04))
                        .frame(width: 520, height: 10)
                        .rotationEffect(.degrees(-14))
                        .offset(x: index.isMultiple(of: 2) ? 110 : 150, y: CGFloat(index * 40) - 180)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct SunScreen<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 64, 0), 760)

            ZStack {
                SunBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        content()
                    }
                    .frame(width: contentWidth, alignment: .top)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                    .frame(width: proxy.size.width, alignment: .center)
                }
                .clipped()
            }
        }
    }
}

private struct SunCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.80))
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.24),
                                        AppPalette.shell.opacity(0.08),
                                        AppPalette.sun.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: AppPalette.ink.opacity(0.10), radius: 22, x: 0, y: 14)
    }
}

extension View {
    func sunCard(padding: CGFloat = 20) -> some View {
        modifier(SunCardModifier(padding: padding))
    }
}

struct SunPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SunPrimaryButton(configuration: configuration)
    }

    private struct SunPrimaryButton: View {
        let configuration: SunPrimaryButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    LinearGradient(
                        colors: [AppPalette.coral, AppPalette.sun],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: AppPalette.coral.opacity(0.28), radius: 18, x: 0, y: 12)
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .opacity(isEnabled ? (configuration.isPressed ? 0.96 : 1) : 0.50)
                .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
        }
    }
}

struct SunSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SunSecondaryButton(configuration: configuration)
    }

    private struct SunSecondaryButton: View {
        let configuration: SunSecondaryButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.82), AppPalette.shell.opacity(0.34)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: AppPalette.ink.opacity(0.06), radius: 12, x: 0, y: 8)
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .opacity(isEnabled ? 1 : 0.52)
                .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
        }
    }
}

struct SunPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title.uppercased(), systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .tracking(0.9)
            .foregroundStyle(AppPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            }
    }
}

struct MetricTile: View {
    let value: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.16), Color.white.opacity(0.54)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

struct SunSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(AppPalette.softInk)

            Text(title)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)

            Text(detail)
                .font(.callout)
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SunInfoRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.softInk)
            }
        }
    }
}

struct SunStatusCard: View {
    let title: String
    let detail: String
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sunCard(padding: 16)
    }
}

struct SunCameraOverlayLabel: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.0)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.94), in: Capsule())
    }
}
