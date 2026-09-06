import SwiftUI

struct WeatherKitAttributionFooter: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private let weatherKitLegalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    let attribution: SunclubWeatherAttribution?
    let sourceLabel: String
    let showAttributionLink: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.xs) { attributionContent }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) { attributionContent }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var attributionContent: some View {
        sourceView
        if showAttributionLink {
            Button {
                openURL(attribution?.legalPageURL ?? weatherKitLegalURL)
            } label: {
                Text("Data Sources")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppColor.accent)
                    .underline()
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Apple Weather legal attribution and data sources")
            .accessibilityIdentifier("timeline.weatherKitAttribution")
        }
    }

    @ViewBuilder
    private var sourceView: some View {
        if showAttributionLink, let markURL {
            AsyncImage(url: markURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 96, maxHeight: 14, alignment: .leading)
                        .accessibilityLabel(sourceLabel)
                default:
                    fallbackSourceView
                }
            }
            .frame(minHeight: 14)
        } else {
            fallbackSourceView
        }
    }

    private var fallbackSourceView: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.circle.fill")
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
                .accessibilityHidden(true)

            Text(sourceLabel == UVReadingSource.cachedWeatherKit.statusLabel ? "Apple Weather" : sourceLabel)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
        }
    }

    private var markURL: URL? {
        switch colorScheme {
        case .dark:
            return attribution?.darkMarkURL ?? attribution?.lightMarkURL
        default:
            return attribution?.lightMarkURL ?? attribution?.darkMarkURL
        }
    }
}
