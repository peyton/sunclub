import SwiftUI

/// A gauge tap opens detail; dragging across it must remain a scroll, not activate the button.
struct TodayQuietGlassTapButtonStyle: PrimitiveButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onTapGesture {
                if isEnabled { configuration.trigger() }
            }
    }
}

struct TodayDaylightUVSummary: View {
    let presentation: TodayQuietGlassUVPresentation

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            SunIcon.sun.image
                .resizable().scaledToFit()
                .foregroundStyle(AppColor.accent)
                .frame(width: AppSpacing.lg, height: AppSpacing.lg)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if let index = presentation.index {
                    AppText("\(presentation.title) \(index)", style: .bodyMedium)
                        .accessibilityIdentifier("home.uvIndexValue")
                    AppText(presentation.level.displayName, style: .caption,
                            color: presentation.level.designTextTint)
                        .accessibilityIdentifier("home.uvIndexLevel")
                } else {
                    AppText("UV unavailable", style: .bodyMedium)
                        .accessibilityIdentifier("home.uvUnavailable")
                }
            }
            Spacer(minLength: AppSpacing.xxs)
            AppText("Forecast", style: .captionMedium, color: AppColor.accent)
            SunIcon.chevronRight.image
                .resizable().scaledToFit()
                .foregroundStyle(AppColor.Text.secondary)
                .frame(width: AppSpacing.xs, height: AppSpacing.xs)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, AppSpacing.xxs)
    }
}

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
                    .frame(minHeight: AppSpacing.xl * 6)
                    .background {
                        GeometryReader { geometry in
                            let diameter = min(geometry.size.width, geometry.size.height)
                            ring
                                .frame(width: diameter, height: diameter)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: AppSpacing.xl * 8)
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

            if let index = presentation.index {
                AppText(presentation.title, style: .caption, color: AppColor.Text.secondary, alignment: .center)
                Text(index.formatted())
                    .font(AppFont.heroMetric(size: metricSize))
                    .monospacedDigit()
                    .foregroundStyle(presentation.level.designTextTint)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.uvIndexValue")

                AppText(presentation.level.displayName, style: .sectionHeader, color: presentation.level.designTextTint, alignment: .center)
                    .accessibilityIdentifier("home.uvIndexLevel")
            } else {
                AppText("UV unavailable", style: .sectionHeader, alignment: .center)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let presentation: TodayQuietGlassLogPresentation
    var editSPF: () -> Void = {}
    var editTime: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            if presentation.spfLabel != nil {
                Button(action: editTime) {
                    HStack(spacing: AppSpacing.xxs) {
                        AppText(presentation.title, style: .sectionHeader, alignment: .leading)
                            .contentTransition(reduceMotion ? .identity : .numericText())
                        SunIcon.chevronRight.image.resizable().scaledToFit()
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Edits application times.")
                .accessibilityIdentifier(presentation.statusIdentifier)
            } else {
                AppText("No sunscreen logged", style: .sectionHeader, alignment: .leading)
                    .accessibilityIdentifier(presentation.statusIdentifier)
            }

            if let spf = presentation.spfLabel {
                Button(action: editSPF) {
                    HStack(spacing: AppSpacing.xxs) {
                        AppText(spf, style: .bodyMedium)
                        SunIcon.chevronRight.image.resizable().scaledToFit()
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spf)
                .accessibilityHint("Edits SPF for this log.")
                .accessibilityIdentifier("home.editSPF")
            }
            if !presentation.detail.isEmpty {
                AppText(presentation.detail, style: .caption, color: AppColor.Text.secondary, alignment: .leading)
                    .accessibilityIdentifier("timeline.statusDetail")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                AppText(text, style: .body, alignment: .leading)
                if let detail {
                    AppText(detail, style: .caption, color: AppColor.Text.secondary, alignment: .leading)
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
        .frame(maxWidth: .infinity, minHeight: AppSpacing.xl + AppSpacing.sm, alignment: .leading)
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
