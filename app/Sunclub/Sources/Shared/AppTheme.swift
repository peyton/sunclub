import SwiftUI
import UIKit

enum AppPalette {
    private static func adaptive(
        light: UIColor,
        dark: UIColor,
        increasedContrastLight: UIColor? = nil,
        increasedContrastDark: UIColor? = nil
    ) -> Color {
        Color(uiColor: UIColor { traits in
            switch (traits.userInterfaceStyle, traits.accessibilityContrast) {
            case (.dark, .high):
                increasedContrastDark ?? dark
            case (.dark, _):
                dark
            case (_, .high):
                increasedContrastLight ?? light
            default:
                light
            }
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

    static let cream = AppColor.background
    static let pearl = AppColor.surface
    static let warmGlow = AppColor.sunSoft
    static let sun = AppColor.sun
    static let nativeChromeTint = adaptive(
        light: UIColor(AppColor.primaryAction),
        dark: UIColor(AppColor.apricot).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
        increasedContrastLight: .black,
        increasedContrastDark: .white
    )
    static let coral = AppColor.warning
    static let aloe = adaptive(
        light: uiColor(red: 0.320, green: 0.620, blue: 0.410),
        dark: uiColor(red: 0.485, green: 0.830, blue: 0.620)
    )
    static let pool = AppColor.accent
    static let uvExtreme = adaptive(
        light: uiColor(red: 0.780, green: 0.255, blue: 0.560),
        dark: uiColor(red: 0.960, green: 0.430, blue: 0.720)
    )
    static let nightAmber = Color(red: 0.315, green: 0.164, blue: 0.068)
    static let darkCanvas = AppColor.Watch.background
    static let darkSurface = AppColor.Watch.surface
    static let ink = AppColor.Text.primary
    static let softInk = AppColor.Text.secondary
    static let success = AppColor.success
    static let warning = adaptive(
        light: uiColor(red: 0.760, green: 0.240, blue: 0.180),
        dark: uiColor(red: 1.000, green: 0.380, blue: 0.300)
    )
    static let muted = AppColor.muted
    static let streakAccent = adaptive(
        light: uiColor(red: 0.970, green: 0.670, blue: 0.000),
        dark: uiColor(red: 1.000, green: 0.590, blue: 0.110)
    )
    static let streakBackground = adaptive(
        light: uiColor(red: 1.000, green: 0.947, blue: 0.760),
        dark: uiColor(red: 0.244, green: 0.171, blue: 0.092)
    )
    static let cardFill = AppColor.surfaceElevated
    static let elevatedCardFill = AppColor.surfaceElevated
    static let controlFill = AppColor.control
    static let editorFill = AppColor.surface
    static let cardStroke = AppColor.stroke
    static let hairlineStroke = adaptive(
        light: UIColor(AppColor.Text.primary).withAlphaComponent(0.07),
        dark: UIColor(AppColor.Watch.textPrimary).withAlphaComponent(0.14)
    )
    static let onAccent = AppColor.onAccent
    static let white = Color.white

    static func readableUVTint(for level: UVLevel) -> Color {
        let light: UIColor
        switch level {
        case .low: light = uiColor(red: 0.196, green: 0.447, blue: 0.259)
        case .moderate, .high: light = uiColor(red: 0.510, green: 0.310, blue: 0.000)
        case .veryHigh: light = uiColor(red: 0.760, green: 0.240, blue: 0.180)
        case .extreme: light = uiColor(red: 0.630, green: 0.130, blue: 0.400)
        case .unknown: return AppColor.Text.secondary
        }
        return adaptive(
            light: light,
            dark: UIColor(level.designTint),
            increasedContrastLight: .black,
            increasedContrastDark: .white
        )
    }
}

extension UVLevel {
    var designTextTint: Color { AppPalette.readableUVTint(for: self) }

    var designTint: Color {
        switch self {
        case .low:
            return AppPalette.aloe
        case .moderate:
            return AppPalette.sun.opacity(0.78)
        case .high:
            return AppPalette.sun
        case .veryHigh:
            return AppPalette.coral
        case .extreme:
            return AppPalette.uvExtreme
        case .unknown:
            return AppPalette.muted
        }
    }
}

enum AppTypography {
    static let screenTitle = AppTextStyle.largeTitle.font
    static let sectionLabel = AppTextStyle.captionMedium.font
    static let cardTitle = AppTextStyle.sectionHeader.font
    static let body = AppTextStyle.body.font
    static let bodyMedium = AppTextStyle.bodyMedium.font
    static let caption = AppTextStyle.caption.font
    static let captionMedium = AppTextStyle.captionMedium.font
    static let metric = AppTextStyle.metric.font
    static let streakNumber = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    static let pillLabel = AppTextStyle.pillLabel.font
}

enum SunLayout {
    static let tabBarScrollUnderlapPadding: CGFloat = 112
    static let topStatusBarFadeHeight: CGFloat = 92
    static let topStatusBarFadeActivationDistance: CGFloat = 36

    static func topStatusBarFadeProgress(for verticalScrollOffset: CGFloat) -> Double {
        let rawProgress = verticalScrollOffset / topStatusBarFadeActivationDistance
        let clampedProgress = min(1, max(0, Double(rawProgress)))
        return (clampedProgress * 100).rounded() / 100
    }

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
    case illustrationSkinReport = "IllustrationSkinReport"
    case coverageFaceDiagram = "CoverageFaceDiagram"
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
        AppColor.background.ignoresSafeArea()
    }
}

struct SunDarkBackdrop: View {
    var body: some View {
        AppPalette.darkCanvas.ignoresSafeArea()
    }
}

struct SunLightScreen<Content: View, Footer: View>: View {
    @State private var topStatusBarFadeProgress = 0.0

    let content: Content
    let footer: Footer
    let contentAlignment: Alignment
    let contentMaxWidth: CGFloat?
    let contentFrameAlignment: Alignment
    let footerMaxWidth: CGFloat?
    let footerFrameAlignment: Alignment
    let showsFooter: Bool
    let scrollAccessibilityIdentifier: String?

    init(
        contentAlignment: Alignment = .topLeading,
        contentMaxWidth: CGFloat? = nil,
        contentFrameAlignment: Alignment = .leading,
        footerMaxWidth: CGFloat? = nil,
        footerFrameAlignment: Alignment = .center,
        showsFooter: Bool = true,
        scrollAccessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.contentAlignment = contentAlignment
        self.contentMaxWidth = contentMaxWidth
        self.contentFrameAlignment = contentFrameAlignment
        self.footerMaxWidth = footerMaxWidth
        self.footerFrameAlignment = footerFrameAlignment
        self.showsFooter = showsFooter
        self.scrollAccessibilityIdentifier = scrollAccessibilityIdentifier
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                #if os(iOS) && !os(watchOS)
                if #available(iOS 26.0, *) {
                    if showsFooter {
                        scrollingContent(proxy: proxy)
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                nativeFooter
                            }
                    } else {
                        scrollingContent(proxy: proxy)
                    }
                } else {
                    legacyLayout(proxy: proxy)
                }
                #else
                legacyLayout(proxy: proxy)
                #endif

                SunTopStatusBarFade(progress: topStatusBarFadeProgress, background: AppColor.background)
            }

        }
        .background {
            SunBackdrop()
        }
    }

    @ViewBuilder
    private func scrollingContent(proxy: GeometryProxy) -> some View {
        let scrollView = ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .frame(maxWidth: contentMaxWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: contentFrameAlignment)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, showsFooter ? 24 : SunLayout.tabBarScrollUnderlapPadding)
            .frame(minHeight: proxy.size.height - 120, alignment: contentAlignment)
        }
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(
            for: Double.self,
            of: { geometry in
                SunLayout.topStatusBarFadeProgress(for: geometry.sunclubVerticalScrollOffset)
            },
            action: { _, newProgress in
                topStatusBarFadeProgress = newProgress
            }
        )

        if let scrollAccessibilityIdentifier {
            scrollView.accessibilityIdentifier(scrollAccessibilityIdentifier)
        } else {
            scrollView
        }
    }

    private func legacyLayout(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            scrollingContent(proxy: proxy)

            if showsFooter {
                legacyFooter
            }
        }
    }

    private var nativeFooter: some View {
        SunGlassEffectContainer(spacing: 10) {
            footer
                .frame(maxWidth: footerMaxWidth ?? .infinity)
                .frame(maxWidth: .infinity, alignment: footerFrameAlignment)
        }
        .padding(.horizontal, 20)
        .padding(.top, 5)
        .padding(.bottom, 20)
    }

    private var legacyFooter: some View {
        footer
            .frame(maxWidth: footerMaxWidth ?? .infinity)
            .frame(maxWidth: .infinity, alignment: footerFrameAlignment)
            .padding(.horizontal, 20)
            .padding(.top, 5)
            .padding(.bottom, 20)
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

extension SunLightScreen where Footer == EmptyView {
    init(
        contentAlignment: Alignment = .topLeading,
        contentMaxWidth: CGFloat? = nil,
        contentFrameAlignment: Alignment = .leading,
        scrollAccessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            contentAlignment: contentAlignment,
            contentMaxWidth: contentMaxWidth,
            contentFrameAlignment: contentFrameAlignment,
            showsFooter: false,
            scrollAccessibilityIdentifier: scrollAccessibilityIdentifier,
            content: content
        ) { EmptyView() }
    }
}

struct SunDarkScreen<Content: View, Footer: View>: View {
    @State private var topStatusBarFadeProgress = 0.0

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
            ZStack(alignment: .top) {
                #if os(iOS) && !os(watchOS)
                if #available(iOS 26.0, *) {
                    scrollingContent(proxy: proxy)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            SunGlassEffectContainer(spacing: 10) {
                                footer
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 6)
                            .padding(.bottom, 24)
                        }
                } else {
                    legacyLayout(proxy: proxy)
                }
                #else
                legacyLayout(proxy: proxy)
                #endif

                SunTopStatusBarFade(progress: topStatusBarFadeProgress, background: AppColor.background)
            }
        }
        .background {
            SunDarkBackdrop()
        }
    }

    private func scrollingContent(proxy: GeometryProxy) -> some View {
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
        .onScrollGeometryChange(
            for: Double.self,
            of: { geometry in
                SunLayout.topStatusBarFadeProgress(for: geometry.sunclubVerticalScrollOffset)
            },
            action: { _, newProgress in
                topStatusBarFadeProgress = newProgress
            }
        )
    }

    private func legacyLayout(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            scrollingContent(proxy: proxy)

            footer
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 24)
        }
    }
}

extension SunDarkScreen where Footer == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content) { EmptyView() }
    }
}

private struct SunTopStatusBarFade: View {
    let progress: Double
    let background: Color

    var body: some View {
        LinearGradient(
            colors: [
                background.opacity(progress),
                background.opacity(progress * 0.96),
                background.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: SunLayout.topStatusBarFadeHeight)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension ScrollGeometry {
    var sunclubVerticalScrollOffset: CGFloat {
        max(0, contentOffset.y + contentInsets.top)
    }
}

struct SunPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTextStyle.bodyMedium.font)
            .foregroundStyle(isEnabled ? AppColor.primaryActionForeground : AppPalette.softInk)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(isEnabled ? AppColor.primaryAction : AppPalette.muted.opacity(0.28))
                    .appShadow(isEnabled ? AppShadow.floating : nil)
            )
            .opacity(configuration.isPressed ? 0.90 : (isEnabled ? 1 : 0.68))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.976 : 1))
            .animation(AppMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct SunSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTextStyle.pillLabel.font)
            .foregroundStyle(AppPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(AppPalette.controlFill.opacity(isEnabled ? 0.86 : 0.48))
                    .appShadow(isEnabled ? AppShadow.soft : nil)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.982 : 1))
            .animation(AppMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

struct SunTextButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTextStyle.captionMedium.font)
            .foregroundStyle(AppPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(configuration.isPressed ? AppPalette.warmGlow.opacity(0.54) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(AppMotion.easeOut(duration: 0.14, reduceMotion: reduceMotion), value: configuration.isPressed)
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
        AppCard(
            padding: padding,
            cornerRadius: cornerRadius,
            fill: AppPalette.cardFill.opacity(fillOpacity)
        ) {
            content
        }
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
    @Environment(\.sunGlassBoundaryActive) private var isInsideGlassBoundary

    let value: String
    let label: String
    var symbolName: String?
    var tint: Color = AppPalette.sun
    var accessibilityIdentifier: String?
    var usesGlass = true

    @ViewBuilder
    var body: some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            if usesGlass, !isInsideGlassBoundary {
                pillContent.sunGlassCard(
                    cornerRadius: AppRadius.insetCard,
                    fillOpacity: 0.72,
                    legacyFill: AppPalette.controlFill,
                    legacyStroke: AppPalette.hairlineStroke,
                    legacyShadow: nil
                )
            } else {
                pillContent
            }
        } else {
            legacyPill
        }
        #else
        legacyPill
        #endif
    }

    private var pillContent: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier ?? "sunclub.metricPill")
    }

    private var legacyPill: some View {
        pillContent
        .sunGlassCard(
            cornerRadius: AppRadius.insetCard,
            fillOpacity: 0.72,
            legacyFill: AppPalette.controlFill,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
    }
}

struct SunLabelPill: View {
    let title: String
    var systemImage: String?
    var tint: Color = AppPalette.ink
    var fill: Color = AppPalette.warmGlow.opacity(0.70)
    var minWidth: CGFloat = 112

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(AppFont.rounded(size: 11, weight: .bold))
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(AppFont.rounded(size: 12, weight: .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minWidth: minWidth)
        .background(fill, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
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

struct SunLightHeader: View {
    private let sideButtonSize: CGFloat = 44

    let title: String
    let showsBack: Bool
    let usesNativeNavigation: Bool
    let trailingSystemImage: String?
    let trailingAccessibilityLabel: String?
    let trailingAccessibilityHint: String?
    let trailingAccessibilityIdentifier: String?
    let onBack: (() -> Void)?
    let onTrailingTap: (() -> Void)?

    init(
        title: String,
        showsBack: Bool = false,
        usesNativeNavigation: Bool = true,
        onBack: (() -> Void)? = nil,
        trailingSystemImage: String? = nil,
        trailingAccessibilityLabel: String? = nil,
        trailingAccessibilityHint: String? = nil,
        trailingAccessibilityIdentifier: String? = nil,
        onTrailingTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.showsBack = showsBack
        self.usesNativeNavigation = usesNativeNavigation
        self.onBack = onBack
        self.trailingSystemImage = trailingSystemImage
        self.trailingAccessibilityLabel = trailingAccessibilityLabel
        self.trailingAccessibilityHint = trailingAccessibilityHint
        self.trailingAccessibilityIdentifier = trailingAccessibilityIdentifier
        self.onTrailingTap = onTrailingTap
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *), usesNativeNavigation {
            nativeHeader
        } else {
            legacyHeader
        }
    }

    @available(iOS 26.0, *)
    private var nativeHeader: some View {
        Text(title)
            .font(AppTypography.screenTitle)
            .foregroundStyle(AppPalette.ink)
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                if let trailingSystemImage {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { onTrailingTap?() }) {
                            Image(systemName: trailingSystemImage)
                        }
                        .accessibilityLabel(trailingAccessibilityLabel ?? title)
                        .accessibilityHint(trailingAccessibilityHint ?? "")
                        .accessibilityIdentifier(trailingAccessibilityIdentifier ?? "")
                    }
                }
            }
    }

    private var legacyHeader: some View {
        HStack(alignment: .top, spacing: 10) {
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
            }

            Text(title)
                .font(AppTypography.screenTitle)
                .foregroundStyle(AppPalette.ink)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, showsBack ? 3 : 0)

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
                .accessibilityLabel(trailingAccessibilityLabel ?? title)
                .accessibilityHint(trailingAccessibilityHint ?? "")
                .accessibilityIdentifier(trailingAccessibilityIdentifier ?? "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }
}

private struct SunNavigationBarCompatibilityModifier: ViewModifier {
    let title: String?
    let displayMode: NavigationBarItem.TitleDisplayMode

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let title {
                content
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(displayMode)
                    .toolbar(.visible, for: .navigationBar)
            } else {
                content
                    .toolbar(.visible, for: .navigationBar)
            }
        } else {
            content
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct SunGlassCardModifier: ViewModifier {
    @Environment(\.sunGlassBoundaryActive) private var isInsideGlassBoundary

    let cornerRadius: CGFloat
    let fillOpacity: Double
    let interactive: Bool
    let legacyFill: Color
    let legacyStroke: Color
    let legacyShadow: AppShadowStyle?

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            if isInsideGlassBoundary {
                content
            } else {
                content.sunGlassSurface(
                    cornerRadius: cornerRadius,
                    style: interactive ? .interactive : .regular
                )
            }
        } else {
            legacyCard(content)
        }
        #else
        legacyCard(content)
        #endif
    }

    private func legacyCard(_ content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(legacyFill.opacity(fillOpacity))
                    .appShadow(legacyShadow)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(legacyStroke, lineWidth: 1)
            }
    }
}

private struct SunGlassIconButtonStyleModifier: ViewModifier {
    @Environment(\.sunGlassBoundaryActive) private var isInsideGlassBoundary

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *), !isInsideGlassBoundary {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.plain)
        }
        #else
        content.buttonStyle(.plain)
        #endif
    }
}

extension View {
    func sunNavigationBarCompatibility(
        title: String? = nil,
        displayMode: NavigationBarItem.TitleDisplayMode = .inline
    ) -> some View {
        modifier(SunNavigationBarCompatibilityModifier(title: title, displayMode: displayMode))
    }
}

struct SunLogoMark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let coreRadius = size * 0.18
            let rayInner = size * 0.33
            let rayOuter = size * 0.48
            var core = Path()
            core.addEllipse(
                in: CGRect(
                    x: center.x - coreRadius,
                    y: center.y - coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                )
            )
            context.fill(core, with: .color(AppPalette.sun))

            for index in 0..<8 {
                let angle = (Double(index) / 8) * 2 * .pi
                let start = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * rayInner,
                    y: center.y + CGFloat(sin(angle)) * rayInner
                )
                let end = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * rayOuter,
                    y: center.y + CGFloat(sin(angle)) * rayOuter
                )
                var ray = Path()
                ray.move(to: start)
                ray.addLine(to: end)
                context.stroke(
                    ray,
                    with: .color(AppPalette.sun),
                    style: StrokeStyle(lineWidth: max(2, size * 0.08), lineCap: .round)
                )
            }
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
    @Environment(\.sunGlassBoundaryActive) private var isInsideGlassBoundary

    let title: String
    let detail: String
    let tint: Color
    let symbol: String

    @ViewBuilder
    var body: some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            if isInsideGlassBoundary {
                cardContent
            } else {
                cardContent.sunGlassCard(cornerRadius: 18, fillOpacity: 0.88)
            }
        } else {
            legacyCard
        }
        #else
        legacyCard
        #endif
    }

    private var cardContent: some View {
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
        .accessibilityElement(children: .combine)
    }

    private var legacyCard: some View {
        cardContent
        .sunGlassCard(cornerRadius: 18, fillOpacity: 0.88)
    }
}

struct SunProductIcon: View {
    let systemName: String
    var tint: Color = AppPalette.pool
    var fill: Color? = nil
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(AppFont.rounded(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(fill ?? tint.opacity(0.12))
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct SunInfoRow: View {
    let title: String
    let detail: String
    var systemImage: String
    var tint: Color = AppPalette.pool
    var trailingText: String?
    var showsChevron = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SunProductIcon(systemName: systemImage, tint: tint, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.ink)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SunUVIndexCard: View {
    let index: Int
    let level: UVLevel
    let sourceLabel: String
    let recommendation: String
    var title: String = "UV Index"

    var body: some View {
        let tint = level.designTint

        ZStack(alignment: .topLeading) {
            AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(AppTextStyle.captionMedium.font)
                            .foregroundStyle(AppPalette.softInk)

                        Text(level.displayName)
                            .font(AppTextStyle.title.font)
                            .foregroundStyle(tint)
                            .accessibilityIdentifier("home.uvIndexLevel")

                        Text(sourceLabel)
                            .font(AppTextStyle.captionMedium.font)
                            .foregroundStyle(AppPalette.ink)
                    }
                    .padding(.leading, 124)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(recommendation)
                        .font(AppTextStyle.caption.font)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            uvMeter(tint: tint)
                .frame(width: 116, height: 116)
                .offset(x: -5, y: -22)
                .accessibilityHidden(true)
        }
        .padding(.top, 22)
        .padding(.leading, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("UV Index \(index), \(level.displayName). \(recommendation)")
        .accessibilityIdentifier("home.uvIndexCard")
    }

    private func uvMeter(tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(AppPalette.cardFill)
                .appShadow(AppShadow.soft)

            Circle()
                .stroke(AppPalette.warmGlow.opacity(0.72), lineWidth: 12)

            Circle()
                .trim(from: 0, to: min(CGFloat(index) / 11, 1))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(index)")
                .font(AppFont.rounded(size: 46, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}

struct SunChartBar: Identifiable {
    var id: String { label }
    let label: String
    let value: Int
    let tint: Color
}

struct SunMiniBarChart: View {
    let bars: [SunChartBar]
    var maxValue: Int = 11

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(bars) { bar in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: AppRadius.tiny, style: .continuous)
                        .fill(bar.tint)
                        .frame(height: barHeight(for: bar.value))
                        .frame(maxWidth: .infinity)

                    Text(bar.label)
                        .font(AppFont.rounded(size: 10, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76, alignment: .bottom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hourly UV exposure chart")
    }

    private func barHeight(for value: Int) -> CGFloat {
        let clamped = max(0, min(value, maxValue))
        return max(8, CGFloat(clamped) / CGFloat(maxValue) * 48)
    }
}

struct SunForecastStrip: View {
    let hours: [SunclubUVHourForecast]
    var maxCount = 5

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(displayedHours) { hour in
                VStack(spacing: 4) {
                    Text(hour.date.formatted(.dateTime.hour()))
                        .font(AppFont.rounded(size: 10, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    Image(systemName: hour.level.symbolName)
                        .font(AppFont.rounded(size: 15, weight: .semibold))
                        .foregroundStyle(hour.level.designTint)
                        .frame(height: 18)
                        .accessibilityHidden(true)

                    Text("\(hour.index)")
                        .font(AppFont.rounded(size: 14, weight: .bold))
                        .foregroundStyle(hour.level.designTint)

                    Text(hour.level.displayName)
                        .font(AppFont.rounded(size: 9, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hourly UV forecast")
        .accessibilityIdentifier("home.forecastStrip")
    }

    private var displayedHours: [SunclubUVHourForecast] {
        Array(hours.prefix(maxCount))
    }
}

struct SunCameraOverlayLabel: View {
    let title: String
    let tint: Color

    @ViewBuilder
    var body: some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            label
                .foregroundStyle(AppPalette.ink)
                .sunGlassSurface(cornerRadius: AppRadius.pill)
        } else {
            legacyLabel
        }
        #else
        legacyLabel
        #endif
    }

    private var label: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private var legacyLabel: some View {
        label
            .foregroundStyle(AppPalette.onAccent)
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
    @ViewBuilder
    func sunLegacyButtonBackground(
        cornerRadius: CGFloat,
        fill: Color,
        stroke: Color = .clear
    ) -> some View {
        #if os(iOS) && !os(watchOS)
        if #available(iOS 26.0, *) {
            self
        } else {
            legacySunButtonBackground(cornerRadius: cornerRadius, fill: fill, stroke: stroke)
        }
        #else
        legacySunButtonBackground(cornerRadius: cornerRadius, fill: fill, stroke: stroke)
        #endif
    }

    func sunGlassPrimaryButton() -> some View {
        sunGlassPrimaryButton(legacyStyle: SunPrimaryButtonStyle())
    }

    func sunGlassSecondaryButton() -> some View {
        sunGlassSecondaryButton(legacyStyle: SunSecondaryButtonStyle())
    }

    func sunGlassIconButton() -> some View {
        modifier(SunGlassIconButtonStyleModifier())
    }

    func sunGlassCard(
        cornerRadius: CGFloat = AppRadius.card,
        fillOpacity: Double = 0.86,
        interactive: Bool = false,
        legacyFill: Color = AppPalette.cardFill,
        legacyStroke: Color = AppPalette.cardStroke,
        legacyShadow: AppShadowStyle? = AppShadow.soft
    ) -> some View {
        modifier(
            SunGlassCardModifier(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                interactive: interactive,
                legacyFill: legacyFill,
                legacyStroke: legacyStroke,
                legacyShadow: legacyShadow
            )
        )
    }

    private func legacySunButtonBackground(
        cornerRadius: CGFloat,
        fill: Color,
        stroke: Color
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            }
    }
}
