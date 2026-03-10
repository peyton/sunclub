import SwiftUI

enum AppPalette {
    static let cream = Color(red: 0.995, green: 0.972, blue: 0.900)
    static let shell = Color(red: 0.973, green: 0.910, blue: 0.808)
    static let sun = Color(red: 0.964, green: 0.651, blue: 0.200)
    static let coral = Color(red: 0.878, green: 0.404, blue: 0.271)
    static let sea = Color(red: 0.157, green: 0.514, blue: 0.529)
    static let mint = Color(red: 0.322, green: 0.639, blue: 0.494)
    static let ink = Color(red: 0.137, green: 0.192, blue: 0.220)
    static let softInk = Color(red: 0.324, green: 0.373, blue: 0.396)
    static let success = Color(red: 0.239, green: 0.596, blue: 0.431)
    static let warning = Color(red: 0.882, green: 0.553, blue: 0.180)
    static let danger = Color(red: 0.761, green: 0.286, blue: 0.247)
}

struct SunBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppPalette.cream,
                    AppPalette.shell,
                    Color(red: 0.937, green: 0.964, blue: 0.941)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(AppPalette.sun.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: -140, y: -270)

            Circle()
                .fill(AppPalette.sea.opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 170, y: -120)

            Circle()
                .fill(AppPalette.coral.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: 120, y: 360)

            RoundedRectangle(cornerRadius: 64, style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 280, height: 200)
                .rotationEffect(.degrees(18))
                .offset(x: 150, y: 260)
                .blur(radius: 4)
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
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    content()
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
    }
}

private struct SunCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.74))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.34),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.58), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
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
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    LinearGradient(
                        colors: [AppPalette.sun, AppPalette.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                }
                .shadow(color: AppPalette.coral.opacity(0.24), radius: 16, x: 0, y: 10)
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .opacity(isEnabled ? (configuration.isPressed ? 0.96 : 1) : 0.48)
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
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(AppPalette.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Color.white.opacity(configuration.isPressed ? 0.86 : 0.7), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
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
        Label(title, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.14), in: Capsule())
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
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(1.1)
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(16)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
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
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(1.4)
                .foregroundStyle(AppPalette.softInk)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .serif))
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
                .frame(width: 38, height: 38)
                .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
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
                    .font(.headline)
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
        Text(title)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.92), in: Capsule())
    }
}
