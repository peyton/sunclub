import SwiftUI

enum AppPalette {
    static let cream = Color(red: 0.982, green: 0.965, blue: 0.939)
    static let pearl = Color(red: 1.000, green: 0.988, blue: 0.960)
    static let warmGlow = Color(red: 1.000, green: 0.930, blue: 0.760)
    static let sun = Color(red: 0.980, green: 0.643, blue: 0.012)
    static let coral = Color(red: 0.960, green: 0.365, blue: 0.255)
    static let aloe = Color(red: 0.365, green: 0.720, blue: 0.510)
    static let pool = Color(red: 0.260, green: 0.655, blue: 0.850)
    static let uvExtreme = Color(red: 0.780, green: 0.255, blue: 0.560)
    static let nightAmber = Color(red: 0.315, green: 0.164, blue: 0.068)
    static let darkCanvas = Color(red: 0.114, green: 0.098, blue: 0.086)
    static let darkSurface = Color(red: 0.171, green: 0.150, blue: 0.129)
    static let ink = Color(red: 0.129, green: 0.114, blue: 0.102)
    static let softInk = Color(red: 0.514, green: 0.459, blue: 0.427)
    static let success = Color(red: 0.151, green: 0.772, blue: 0.353)
    static let muted = Color(red: 0.832, green: 0.832, blue: 0.842)
    static let streakAccent = Color(red: 0.870, green: 0.482, blue: 0.000)
    static let streakBackground = Color(red: 1.000, green: 0.947, blue: 0.760)
    static let white = Color.white
}

enum SunclubVisualAsset: String, CaseIterable {
    case backgroundSunGrainLight = "BackgroundSunGrainLight"
    case backgroundSunGrainDark = "BackgroundSunGrainDark"
    case backgroundUVBands = "BackgroundUVBands"
    case heroWelcomeMorningKit = "HeroWelcomeMorningKit"
    case heroNotificationNudge = "HeroNotificationNudge"
    case illustrationLogBottle = "IllustrationLogBottle"
    case illustrationScannerLabel = "IllustrationScannerLabel"
    case illustrationHistoryCalendar = "IllustrationHistoryCalendar"
    case illustrationAchievementsShelf = "IllustrationAchievementsShelf"
    case illustrationFriendsPair = "IllustrationFriendsPair"
    case illustrationSkinReport = "IllustrationSkinReport"
    case motifSunRing = "MotifSunRing"
    case motifShieldGlow = "MotifShieldGlow"
    case motifScanSheen = "MotifScanSheen"
    case badgeFirstLog = "BadgeFirstLog"
    case badgeThreeDay = "BadgeThreeDay"
    case badgeSevenDay = "BadgeSevenDay"
    case badgeThirtyDay = "BadgeThirtyDay"
    case badgeHighUV = "BadgeHighUV"
    case badgeTraveler = "BadgeTraveler"
    case badgeRecovery = "BadgeRecovery"
    case badgePerfectWeek = "BadgePerfectWeek"
    case widgetTextureWarm = "WidgetTextureWarm"
    case widgetTextureCool = "WidgetTextureCool"
    case widgetTextureNight = "WidgetTextureNight"
    case shareCardBackdropWarm = "ShareCardBackdropWarm"
    case shareCardBackdropCool = "ShareCardBackdropCool"
    case shareCardBackdropAchievement = "ShareCardBackdropAchievement"

    var image: Image {
        Image(rawValue)
    }
}

extension SunclubAchievementID {
    var visualAsset: SunclubVisualAsset {
        switch self {
        case .streak7:
            return .badgeSevenDay
        case .streak30, .streak100, .streak365:
            return .badgeThirtyDay
        case .firstReapply, .reapplyRelay:
            return .badgeThreeDay
        case .firstBackfill:
            return .badgeRecovery
        case .summerSurvivor, .morningGlow, .weekendCanopy:
            return .badgePerfectWeek
        case .winterWarrior:
            return .badgeTraveler
        case .spfSampler, .bottleDetective:
            return .badgeFirstLog
        case .noteTaker, .homeBase, .liveSignal:
            return .badgeTraveler
        case .highUVHero:
            return .badgeHighUV
        case .socialSpark:
            return .badgeThreeDay
        }
    }
}

extension SunclubChallengeID {
    var visualAsset: SunclubVisualAsset {
        switch self {
        case .summerShield:
            return .badgePerfectWeek
        case .uvAwarenessWeek:
            return .badgeHighUV
        case .winterSkin:
            return .badgeRecovery
        }
    }
}

struct SunclubAssetImage: View {
    let asset: SunclubVisualAsset
    var contentMode: ContentMode = .fit
    var maxHeight: CGFloat?
    var opacity: Double = 1

    var body: some View {
        asset.image
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: maxHeight)
            .opacity(opacity)
            .accessibilityHidden(true)
    }
}

struct SunBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.cream, AppPalette.pearl, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            SunclubVisualAsset.backgroundSunGrainLight.image
                .resizable()
                .scaledToFill()
                .opacity(0.52)
                .blendMode(.multiply)

            SunclubVisualAsset.backgroundUVBands.image
                .resizable()
                .scaledToFill()
                .opacity(0.18)
                .blur(radius: 18)
                .offset(y: 300)
                .blendMode(.softLight)
        }
        .ignoresSafeArea()
    }
}

struct SunDarkBackdrop: View {
    var body: some View {
        ZStack {
            AppPalette.darkCanvas

            SunclubVisualAsset.backgroundSunGrainDark.image
                .resizable()
                .scaledToFill()
                .opacity(0.88)

            SunclubVisualAsset.motifSunRing.image
                .resizable()
                .scaledToFit()
                .frame(width: 340, height: 340)
                .opacity(0.18)
                .offset(x: 120, y: 280)
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
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.coral, AppPalette.sun],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppPalette.sun.opacity(configuration.isPressed ? 0.12 : 0.30), radius: configuration.isPressed ? 4 : 16, x: 0, y: configuration.isPressed ? 3 : 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.90 : 1)
            .scaleEffect(configuration.isPressed ? 0.976 : 1)
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
                    .shadow(color: AppPalette.ink.opacity(configuration.isPressed ? 0.02 : 0.06), radius: configuration.isPressed ? 2 : 10, x: 0, y: configuration.isPressed ? 1 : 5)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
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
                Button(
                    action: { onBack?() },
                    label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)
                            .frame(width: 32, height: 32)
                    }
                )
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
                Button(
                    action: { onTrailingTap?() },
                    label: {
                        Image(systemName: trailingSystemImage)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppPalette.ink)
                            .frame(width: 32, height: 32)
                    }
                )
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

struct SunBrandLockup: View {
    enum Layout {
        case inline
        case stacked
    }

    let layout: Layout
    let markSize: CGFloat
    let subtitle: String?

    init(
        layout: Layout = .inline,
        markSize: CGFloat = 28,
        subtitle: String? = nil
    ) {
        self.layout = layout
        self.markSize = markSize
        self.subtitle = subtitle
    }

    var body: some View {
        Group {
            switch layout {
            case .inline:
                HStack(spacing: 10) {
                    SunLogoMark(size: markSize)

                    textBlock(alignment: .leading)
                }
            case .stacked:
                VStack(spacing: 12) {
                    SunLogoMark(size: markSize)
                    textBlock(alignment: .center)
                }
            }
        }
    }

    private func textBlock(alignment: TextAlignment) -> some View {
        VStack(spacing: 4) {
            Text("sunclub")
                .font(.system(size: layout == .inline ? 20 : 34, weight: .heavy))
                .foregroundStyle(AppPalette.ink)
                .tracking(0)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .multilineTextAlignment(alignment)
            }
        }
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

struct SunAssetHero: View {
    let asset: SunclubVisualAsset
    var height: CGFloat = 210
    var glowColor: Color = AppPalette.sun

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.64), AppPalette.warmGlow.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.58), lineWidth: 1)
                }
                .shadow(color: glowColor.opacity(0.16), radius: 28, x: 0, y: 18)

            asset.image
                .resizable()
                .scaledToFit()
                .padding(18)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

struct SunSuccessBurst: View {
    var size: CGFloat = 180
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            SunclubVisualAsset.motifSunRing.image
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .opacity(isAnimating ? 0.68 : 0.44)
                .scaleEffect(isAnimating ? 1.08 : 0.94)

            SunclubVisualAsset.motifShieldGlow.image
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.72, height: size * 0.72)
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct SunclubVisualBadge: View {
    let asset: SunclubVisualAsset
    var size: CGFloat = 54
    var isLocked = false

    var body: some View {
        asset.image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(isLocked ? 0.1 : 1)
            .opacity(isLocked ? 0.54 : 1)
            .accessibilityHidden(true)
    }
}

struct SunclubBadgeMedallion: View {
    let asset: SunclubVisualAsset
    var size: CGFloat = 64
    var isLocked = false
    var tint: Color = AppPalette.sun

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: medallionFill,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(isLocked ? 0.46 : 0.72), lineWidth: max(1, size * 0.035))

            asset.image
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.90, height: size * 0.90)
                .saturation(isLocked ? 0.02 : 1)
                .opacity(isLocked ? 0.42 : 1)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(10, size * 0.18), weight: .bold))
                    .foregroundStyle(AppPalette.softInk.opacity(0.82))
                    .frame(width: size * 0.34, height: size * 0.34)
                    .background(Color.white.opacity(0.72), in: Circle())
                    .offset(x: size * 0.27, y: size * 0.27)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(isLocked ? 0.04 : 0.18), radius: isLocked ? 4 : 14, x: 0, y: isLocked ? 2 : 8)
        .accessibilityHidden(true)
    }

    private var medallionFill: [Color] {
        if isLocked {
            return [
                Color.white.opacity(0.84),
                AppPalette.muted.opacity(0.44)
            ]
        }

        return [
            Color.white.opacity(0.98),
            AppPalette.warmGlow.opacity(0.50),
            tint.opacity(0.22)
        ]
    }
}

extension View {
    func sunGlassCard(cornerRadius: CGFloat = 20, fillOpacity: Double = 0.72) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(fillOpacity))
                    .shadow(color: AppPalette.ink.opacity(0.055), radius: 18, x: 0, y: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            }
    }
}
