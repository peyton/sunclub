import SwiftUI

struct WeatherKitAttributionFooter: View {
    @Environment(\.openURL) private var openURL

    let attribution: SunclubWeatherAttribution?
    let sourceLabel: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityHidden(true)

            Text(sourceLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppPalette.softInk)

            if let attribution {
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.softInk)

                Button("Weather") {
                    openURL(attribution.legalPageURL)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.pool)
                .underline()
                .buttonStyle(.plain)
                .accessibilityLabel("Open Apple Weather attribution page")
                .accessibilityIdentifier("timeline.weatherKitAttribution")
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
}
