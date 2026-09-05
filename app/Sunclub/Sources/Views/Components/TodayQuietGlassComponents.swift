import SwiftUI

struct TodayQuietGlassGauge: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var metricSize: CGFloat = 72

    let presentation: TodayQuietGlassUVPresentation

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                gaugeCopy
                    .padding(.vertical, AppSpacing.lg)
            } else {
                gaugeCopy
                    .padding(AppSpacing.xl)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AppSpacing.xl * 8)
                    .background {
                        GeometryReader { geometry in
                            let diameter = min(geometry.size.width, geometry.size.height)
                            ring
                                .frame(width: diameter, height: diameter)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: AppSpacing.xl * 10)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var gaugeCopy: some View {
        VStack(spacing: AppSpacing.xxs) {
            SunIcon.sun.image
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColor.sun)
                .frame(width: AppSpacing.xl, height: AppSpacing.xl)
                .accessibilityHidden(true)

            AppText(presentation.title, style: .caption, color: AppColor.Text.secondary, alignment: .center)

            if let index = presentation.index {
                Text(index.formatted())
                    .font(AppFont.heroMetric(size: metricSize))
                    .monospacedDigit()
                    .foregroundStyle(presentation.level.designTextTint)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.uvIndexValue")

                AppText(presentation.level.displayName, style: .title, color: presentation.level.designTextTint, alignment: .center)
                    .accessibilityIdentifier("home.uvIndexLevel")
            } else {
                AppText("No current reading", style: .sectionHeader, alignment: .center)
                    .accessibilityIdentifier("home.uvUnavailable")
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .strokeBorder(AppColor.sunSoft.opacity(0.55), lineWidth: AppSpacing.xs)

            if presentation.index != nil {
                Circle()
                    .inset(by: AppSpacing.xs / 2)
                    .trim(from: 0, to: presentation.gaugeFraction)
                    .stroke(presentation.level.designTint, style: StrokeStyle(lineWidth: AppSpacing.xs, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .accessibilityHidden(true)
    }
}

struct TodayQuietGlassLogSummary: View {
    let presentation: TodayQuietGlassLogPresentation

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            AppText(presentation.title, style: .title, alignment: .center)
                .accessibilityIdentifier(presentation.statusIdentifier)

            AppText(presentation.detail, style: .body, color: AppColor.Text.secondary, alignment: .center)
                .accessibilityIdentifier("timeline.statusDetail")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxs)
        .contentShape(Rectangle())
    }
}

struct TodayQuietGlassReminder: View {
    let text: String
    var detail: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            SunIcon.clock.image
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColor.sun)
                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                .accessibilityHidden(true)

            VStack(spacing: AppSpacing.xxs) {
                AppText(text, style: .body, alignment: .center)
                if let detail {
                    AppText(detail, style: .caption, color: AppColor.Text.secondary, alignment: .center)
                }
            }

            if showsChevron {
                SunIcon.chevronRight.image
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppColor.Text.secondary)
                    .frame(width: AppSpacing.xs, height: AppSpacing.xs)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: AppSpacing.xl + AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .contentShape(Rectangle())
    }
}

struct TodayQuietGlassLogButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                SunIcon.plus.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppTextStyle.bodyMedium.font)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: AppSpacing.xl + AppSpacing.lg)
            .padding(.horizontal, AppSpacing.sm)
        }
        .sunGlassPrimaryButton(legacyStyle: AppPrimaryButtonStyle())
        .tint(AppColor.primaryAction)
        .accessibilityIdentifier("home.logManually")
    }
}
