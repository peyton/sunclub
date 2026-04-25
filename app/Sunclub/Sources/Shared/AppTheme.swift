import SwiftUI
import UIKit

enum AppPalette {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func uiColor(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1
    ) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    static let cream = Color(red: 0.982, green: 0.965, blue: 0.939)
    static let pearl = Color(red: 1.000, green: 0.988, blue: 0.960)
    static let warmGlow = adaptive(
        light: uiColor(red: 1.000, green: 0.930, blue: 0.760),
        dark: uiColor(red: 0.430, green: 0.286, blue: 0.126)
    )
    static let sun = adaptive(
        light: uiColor(red: 0.980, green: 0.643, blue: 0.012),
        dark: uiColor(red: 1.000, green: 0.705, blue: 0.145)
    )
    static let coral = adaptive(
        light: uiColor(red: 0.960, green: 0.365, blue: 0.255),
        dark: uiColor(red: 1.000, green: 0.450, blue: 0.340)
    )
    static let aloe = adaptive(
        light: uiColor(red: 0.365, green: 0.720, blue: 0.510),
        dark: uiColor(red: 0.485, green: 0.830, blue: 0.620)
    )
    static let pool = adaptive(
        light: uiColor(red: 0.260, green: 0.655, blue: 0.850),
        dark: uiColor(red: 0.385, green: 0.745, blue: 0.940)
    )
    static let uvExtreme = adaptive(
        light: uiColor(red: 0.780, green: 0.255, blue: 0.560),
        dark: uiColor(red: 0.960, green: 0.430, blue: 0.720)
    )
    static let nightAmber = Color(red: 0.315, green: 0.164, blue: 0.068)
    static let darkCanvas = Color(red: 0.114, green: 0.098, blue: 0.086)
    static let darkSurface = Color(red: 0.171, green: 0.150, blue: 0.129)
    static let ink = adaptive(
        light: uiColor(red: 0.129, green: 0.114, blue: 0.102),
        dark: uiColor(red: 0.964, green: 0.925, blue: 0.855)
    )
    static let softInk = adaptive(
        light: uiColor(red: 0.514, green: 0.459, blue: 0.427),
        dark: uiColor(red: 0.745, green: 0.690, blue: 0.620)
    )
    static let success = adaptive(
        light: uiColor(red: 0.151, green: 0.772, blue: 0.353),
        dark: uiColor(red: 0.360, green: 0.875, blue: 0.540)
    )
    static let warning = adaptive(
        light: uiColor(red: 0.775, green: 0.176, blue: 0.137),
        dark: uiColor(red: 1.000, green: 0.380, blue: 0.300)
    )
    static let muted = adaptive(
        light: uiColor(red: 0.832, green: 0.832, blue: 0.842),
        dark: uiColor(red: 0.430, green: 0.395, blue: 0.360)
    )
    static let streakAccent = adaptive(
        light: uiColor(red: 0.870, green: 0.482, blue: 0.000),
        dark: uiColor(red: 1.000, green: 0.590, blue: 0.110)
    )
    static let streakBackground = adaptive(
        light: uiColor(red: 1.000, green: 0.947, blue: 0.760),
        dark: uiColor(red: 0.244, green: 0.171, blue: 0.092)
    )
    static let cardFill = adaptive(
        light: uiColor(red: 1, green: 1, blue: 1),
        dark: uiColor(red: 0.205, green: 0.178, blue: 0.150)
    )
    static let elevatedCardFill = adaptive(
        light: uiColor(red: 1, green: 1, blue: 1),
        dark: uiColor(red: 0.252, green: 0.220, blue: 0.184)
    )
    static let controlFill = adaptive(
        light: uiColor(red: 1, green: 1, blue: 1),
        dark: uiColor(red: 0.294, green: 0.252, blue: 0.207)
    )
    static let editorFill = adaptive(
        light: uiColor(red: 1, green: 1, blue: 1),
        dark: uiColor(red: 0.139, green: 0.122, blue: 0.104)
    )
    static let cardStroke = adaptive(
        light: uiColor(red: 0.886, green: 0.804, blue: 0.678, alpha: 0.58),
        dark: uiColor(red: 1, green: 0.900, blue: 0.760, alpha: 0.16)
    )
    static let hairlineStroke = adaptive(
        light: uiColor(red: 0, green: 0, blue: 0, alpha: 0.06),
        dark: uiColor(red: 1, green: 0.900, blue: 0.760, alpha: 0.14)
    )
    static let onAccent = Color(red: 0.129, green: 0.114, blue: 0.102)
    static let white = Color.white
}

enum AppTypography {
    static let screenTitle = Font.system(size: 28, weight: .semibold)
    static let sectionLabel = Font.system(size: 14, weight: .semibold)
    static let cardTitle = Font.system(size: 18, weight: .semibold)
    static let body = Font.system(size: 16)
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    static let caption = Font.system(size: 13)
    static let captionMedium = Font.system(size: 13, weight: .medium)
    static let metric = Font.system(size: 14, weight: .medium)
    static let streakNumber = Font.system(size: 64, weight: .heavy)
    static let pillLabel = Font.system(size: 13, weight: .semibold)
}

enum AppRadius {
    static let card: CGFloat = 20
    static let insetCard: CGFloat = 16
    static let control: CGFloat = 14
}

enum SunLayout {
    enum ContentWidth {
        static let wizard: CGFloat = 640
        static let form: CGFloat = 720
        static let readable: CGFloat = 860
        static let wideReadable: CGFloat = 1040
    }
}

enum SunMotion {
    static func easeInOut(duration: Double, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration)
    }

    static func easeOut(duration: Double, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }

    static func repeatingEaseInOut(
        duration: Double,
        reduceMotion: Bool,
        autoreverses: Bool = true
    ) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration).repeatForever(autoreverses: autoreverses)
    }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                SunDarkBackdrop()
            } else {
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
            }
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
    let contentAlignment: Alignment
    let contentMaxWidth: CGFloat?
    let contentFrameAlignment: Alignment
    let footerMaxWidth: CGFloat?
    let footerFrameAlignment: Alignment

    init(
        contentAlignment: Alignment = .topLeading,
        contentMaxWidth: CGFloat? = nil,
        contentFrameAlignment: Alignment = .leading,
        footerMaxWidth: CGFloat? = nil,
        footerFrameAlignment: Alignment = .center,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.contentAlignment = contentAlignment
        self.contentMaxWidth = contentMaxWidth
        self.contentFrameAlignment = contentFrameAlignment
        self.footerMaxWidth = footerMaxWidth
        self.footerFrameAlignment = footerFrameAlignment
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
                        .frame(maxWidth: contentMaxWidth ?? .infinity, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: contentFrameAlignment)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 18)
                        .frame(minHeight: proxy.size.height - 120, alignment: contentAlignment)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    footer
                        .frame(maxWidth: footerMaxWidth ?? .infinity)
                        .frame(maxWidth: .infinity, alignment: footerFrameAlignment)
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                        .background {
                            LinearGradient(
                                colors: [
                                    AppPalette.cardFill.opacity(0),
                                    AppPalette.cardFill.opacity(0.92),
                                    AppPalette.cardFill.opacity(0.98)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        }
                }
            }

        }
        .background {
            SunBackdrop()
        }
    }
}

extension SunLightScreen where Footer == EmptyView {
    init(
        contentAlignment: Alignment = .topLeading,
        contentMaxWidth: CGFloat? = nil,
        contentFrameAlignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            contentAlignment: contentAlignment,
            contentMaxWidth: contentMaxWidth,
            contentFrameAlignment: contentFrameAlignment,
            content: content
        ) { EmptyView() }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isEnabled ? AppPalette.onAccent : AppPalette.softInk)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? AppPalette.sun : AppPalette.muted.opacity(0.28))
                    .shadow(
                        color: AppPalette.sun.opacity(isEnabled ? (configuration.isPressed ? 0.08 : 0.18) : 0),
                        radius: configuration.isPressed ? 3 : 10,
                        x: 0,
                        y: configuration.isPressed ? 2 : 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.90 : (isEnabled ? 1 : 0.68))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.976 : 1))
            .animation(SunMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct SunSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppPalette.controlFill.opacity(isEnabled ? 0.86 : 0.48))
                    .shadow(
                        color: AppPalette.ink.opacity(configuration.isPressed ? 0.015 : 0.045),
                        radius: configuration.isPressed ? 2 : 8,
                        x: 0,
                        y: configuration.isPressed ? 1 : 4
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.982 : 1))
            .animation(SunMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct SunTextButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? AppPalette.warmGlow.opacity(0.54) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(SunMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct SunclubCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let fillOpacity: Double
    let content: Content

    init(
        cornerRadius: CGFloat = AppRadius.card,
        padding: CGFloat = 16,
        fillOpacity: Double = 0.86,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.fillOpacity = fillOpacity
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .sunGlassCard(cornerRadius: cornerRadius, fillOpacity: fillOpacity)
    }
}

struct SunScreenTitleBlock: View {
    let eyebrow: String?
    let title: String
    let detail: String?
    var symbolName: String?
    var tint: Color = AppPalette.sun
    var titleFont: Font = AppTypography.screenTitle

    init(
        eyebrow: String? = nil,
        title: String,
        detail: String? = nil,
        symbolName: String? = nil,
        tint: Color = AppPalette.sun,
        titleFont: Font = AppTypography.screenTitle
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.tint = tint
        self.titleFont = titleFont
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Text(eyebrow)
                    .font(AppTypography.sectionLabel)
                    .foregroundStyle(AppPalette.softInk)
                    .textCase(.uppercase)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
            }

            if let detail {
                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SunMetricPill: View {
    let value: String
    let label: String
    var symbolName: String?
    var tint: Color = AppPalette.sun
    var accessibilityIdentifier: String?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(label)
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.insetCard, style: .continuous)
                .fill(AppPalette.controlFill.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.insetCard, style: .continuous)
                .stroke(AppPalette.hairlineStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier ?? "sunclub.metricPill")
    }
}

struct SunWeekProgressDay: Identifiable, Equatable {
    let date: Date
    let isLogged: Bool
    let isToday: Bool
    let isFuture: Bool

    var id: Date { date }
}

struct SunWeekProgressRow: View {
    let days: [SunWeekProgressDay]
    var calendar: Calendar = .current
    var loggedTint: Color = AppPalette.success

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    Text(weekdayLetter(for: day.date))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(day.isToday ? AppPalette.ink : AppPalette.softInk)

                    ZStack {
                        Circle()
                            .fill(circleFill(for: day))
                            .overlay {
                                Circle()
                                    .stroke(circleStroke(for: day), lineWidth: day.isToday ? 1.5 : 1)
                            }

                        if day.isLogged {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppPalette.onAccent)
                        } else if day.isToday {
                            Circle()
                                .stroke(
                                    AppPalette.sun.opacity(0.75),
                                    style: StrokeStyle(lineWidth: 1.4, dash: [3, 3])
                                )
                                .padding(6)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(width: 34, height: 34)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(for: day))
            }
        }
        .accessibilityIdentifier("sunclub.weekProgressRow")
    }

    private func circleFill(for day: SunWeekProgressDay) -> Color {
        if day.isLogged {
            return loggedTint
        }
        if day.isToday {
            return AppPalette.warmGlow.opacity(0.44)
        }
        if day.isFuture {
            return AppPalette.muted.opacity(0.10)
        }
        return AppPalette.cardFill.opacity(0.72)
    }

    private func circleStroke(for day: SunWeekProgressDay) -> Color {
        if day.isLogged {
            return loggedTint.opacity(0.42)
        }
        if day.isToday {
            return AppPalette.sun.opacity(0.56)
        }
        return AppPalette.hairlineStroke
    }

    private func weekdayLetter(for date: Date) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let weekday = calendar.component(.weekday, from: date)
        let index = (weekday - 1 + symbols.count) % symbols.count
        return symbols[index]
    }

    private func accessibilityLabel(for day: SunWeekProgressDay) -> String {
        let dateText = day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if day.isLogged {
            return "\(dateText), logged"
        }
        if day.isToday {
            return "\(dateText), not yet logged"
        }
        if day.isFuture {
            return "\(dateText), upcoming"
        }
        return "\(dateText), not logged"
    }
}

struct SunEmptyStateView: View {
    let title: String
    let detail: String
    var asset: SunclubVisualAsset?
    var symbolName: String?
    var tint: Color = AppPalette.sun

    var body: some View {
        VStack(spacing: 16) {
            if let asset {
                asset.image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 128)
                    .accessibilityHidden(true)
            } else if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 64, height: 64)
                    .background(AppPalette.warmGlow.opacity(0.46), in: Circle())
                    .accessibilityHidden(true)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)

                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppPalette.softInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .sunGlassCard(cornerRadius: AppRadius.card)
        .accessibilityElement(children: .combine)
    }
}

struct SunStepHeader: View {
    let step: Int
    let total: Int
    var tint: Color = AppPalette.softInk

    var body: some View {
        Text("Step \(step) of \(total)")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityIdentifier("step.header")
    }
}

struct SunLightHeader: View {
    private let sideButtonSize: CGFloat = 44

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
                            .frame(width: sideButtonSize, height: sideButtonSize)
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("screen.back")
            } else {
                Color.clear.frame(width: sideButtonSize, height: sideButtonSize)
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
                            .frame(width: sideButtonSize, height: sideButtonSize)
                    }
                )
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: sideButtonSize, height: sideButtonSize)
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
        .accessibilityHidden(true)
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
                .foregroundStyle(AppPalette.onAccent)
                .frame(width: 36, height: 36)
                .background(tint, in: Circle())
                .accessibilityHidden(true)

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
        .sunGlassCard(cornerRadius: 18, fillOpacity: 0.88)
        .accessibilityElement(children: .combine)
    }
}

struct SunCameraOverlayLabel: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppPalette.onAccent)
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
                        colors: [AppPalette.cardFill.opacity(0.64), AppPalette.warmGlow.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppPalette.cardStroke, lineWidth: 1)
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
    enum MilestoneLevel: Equatable {
        case standard
        case minor
        case major
        case epic

        var sizeMultiplier: CGFloat {
            switch self {
            case .standard: return 1.0
            case .minor: return 1.08
            case .major: return 1.14
            case .epic: return 1.22
            }
        }

        var glowOpacity: Double {
            switch self {
            case .standard: return 0.20
            case .minor: return 0.28
            case .major: return 0.36
            case .epic: return 0.48
            }
        }
    }

    static func milestoneLevel(for streak: Int) -> MilestoneLevel {
        switch streak {
        case 365...: return .epic
        case 30...: return .major
        case 7...: return .minor
        default: return .standard
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var size: CGFloat = 180
    var milestone: MilestoneLevel = .standard
    @State private var isAnimating = false

    private var effectiveSize: CGFloat {
        size * milestone.sizeMultiplier
    }

    var body: some View {
        ZStack {
            SunclubVisualAsset.motifSunRing.image
                .resizable()
                .scaledToFit()
                .frame(width: effectiveSize, height: effectiveSize)
                .opacity(reduceMotion ? (0.52 + milestone.glowOpacity * 0.5) : (isAnimating ? (0.68 + milestone.glowOpacity) : (0.44 + milestone.glowOpacity * 0.5)))
                .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1.08 : 0.94))

            SunclubVisualAsset.motifShieldGlow.image
                .resizable()
                .scaledToFit()
                .frame(width: effectiveSize * 0.72, height: effectiveSize * 0.72)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                isAnimating = false
                return
            }

            withAnimation(SunMotion.repeatingEaseInOut(duration: 1.8, reduceMotion: reduceMotion)) {
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
                .stroke(AppPalette.cardStroke.opacity(isLocked ? 0.74 : 1), lineWidth: max(1, size * 0.035))

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
                    .background(AppPalette.controlFill.opacity(0.84), in: Circle())
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
                AppPalette.cardFill.opacity(0.84),
                AppPalette.muted.opacity(0.44)
            ]
        }

        return [
            AppPalette.elevatedCardFill.opacity(0.98),
            AppPalette.warmGlow.opacity(0.50),
            tint.opacity(0.22)
        ]
    }
}

extension View {
    func sunGlassCard(cornerRadius: CGFloat = AppRadius.card, fillOpacity: Double = 0.86) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppPalette.cardFill.opacity(fillOpacity))
                    .shadow(color: AppPalette.ink.opacity(0.045), radius: 12, x: 0, y: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
    }
}
