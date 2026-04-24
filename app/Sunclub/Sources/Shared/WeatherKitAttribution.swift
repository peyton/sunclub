import SwiftUI

struct WeatherKitAttributionFooter: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private let weatherKitLegalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    let attribution: SunclubWeatherAttribution?
    let sourceLabel: String
    let showAttributionLink: Bool

    var body: some View {
        HStack(spacing: 4) {
            sourceView

            if showAttributionLink {
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.softInk)

                Button("Data Sources") {
                    openURL(attribution?.legalPageURL ?? weatherKitLegalURL)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.pool)
                .underline()
                .buttonStyle(.plain)
                .accessibilityLabel("Open Apple Weather legal attribution and data sources")
                .accessibilityIdentifier("timeline.weatherKitAttribution")
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityHidden(true)

            Text(sourceLabel)
                .font(.system(size: 11, weight: .medium))
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
