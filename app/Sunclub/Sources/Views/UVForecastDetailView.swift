import SwiftUI

struct UVForecastDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    private var selectedDay: Date {
        appState.selectedDay
    }

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: 18) {
                forecastHeader

                if let currentUV {
                    UVForecastHeroCard(
                        index: currentUV.index,
                        level: currentUV.level,
                        sourceLabel: currentUV.sourceLabel,
                        recommendation: currentUV.recommendation
                    )

                    SunStatusCard(
                        title: "Verified UV",
                        detail: verificationDetail,
                        tint: AppPalette.pool,
                        symbol: "checkmark.seal.fill"
                    )
                    .accessibilityIdentifier("uvForecast.verified")
                } else {
                    SunStatusCard(
                        title: "UV data unavailable",
                        detail: appState.liveUVStatusPresentation.detail,
                        tint: AppPalette.sun,
                        symbol: "arrow.clockwise"
                    )
                    .accessibilityIdentifier("uvForecast.unavailable")
                }

                if !forecastHours.isEmpty {
                    hourlyForecastCard
                }

                protectionTipsCard

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
        .accessibilityIdentifier("uvForecast.detail")
    }

    private var forecastHeader: some View {
        HStack {
            Button {
                router.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(AppTextStyle.sectionHeader.font)
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("screen.back")

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Text(locationTitle)
                    Image(systemName: "location.fill")
                        .font(AppTextStyle.captionMedium.font)
                        .accessibilityHidden(true)
                }
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.ink)

                Text(selectedDay.formatted(.dateTime.month(.wide).day().year()))
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            Button {
                openURL(SunclubWebLinks.docs)
            } label: {
                Image(systemName: "info.circle")
                    .font(AppTextStyle.sectionHeader.font)
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("UV index documentation")
            .accessibilityIdentifier("uvForecast.docs")
        }
    }

    private var currentUV: UVForecastPresentationReading? {
        guard appState.uvStatus.availability == .available,
              appState.uvStatus.freshness == .fresh else {
            return nil
        }

        if let reading = appState.uvReading,
           reading.source == .weatherKit,
           reading.isFresh(at: appState.referenceDate),
           Calendar.current.isDate(reading.timestamp, inSameDayAs: selectedDay) {
            return UVForecastPresentationReading(
                index: reading.index,
                level: reading.level,
                sourceLabel: reading.source.statusLabel,
                recommendation: reading.level.shortAdvice
            )
        }

        if appState.uvForecast?.isAvailable == true,
           let peakHour = forecastHours.max(by: { $0.index < $1.index }) {
            return UVForecastPresentationReading(
                index: peakHour.index,
                level: peakHour.level,
                sourceLabel: appState.uvForecast?.sourceLabel ?? peakHour.sourceLabel,
                recommendation: appState.uvForecast?.recommendation ?? peakHour.level.shortAdvice
            )
        }

        return nil
    }

    private var locationTitle: String {
        appState.uvStatus.source?.displayName ?? "UV location not set"
    }

    private var verificationDetail: String {
        let source = appState.uvStatus.source?.displayName ?? "your UV location"
        let updated = appState.uvStatus.updatedAt?.formatted(date: .omitted, time: .shortened) ?? "recently"
        if let window = appState.uvProtectionWindow {
            return "Apple Weather · \(source) · Updated \(updated). Protection recommended \(window.start.formatted(date: .omitted, time: .shortened))–\(window.end.formatted(date: .omitted, time: .shortened))."
        }
        return "Apple Weather · \(source) · Updated \(updated)."
    }

    private var hourlyForecastCard: some View {
        AppCard(padding: 16, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Hourly Forecast")
                    .font(AppTextStyle.sectionHeader.font)
                    .foregroundStyle(AppPalette.ink)

                VStack(spacing: 0) {
                    ForEach(forecastHours) { hour in
                        hourlyForecastRow(hour)

                        if hour.id != forecastHours.last?.id {
                            Divider()
                                .overlay(AppPalette.hairlineStroke)
                        }
                    }
                }
                .accessibilityIdentifier("uvForecast.hourly")
            }
        }
    }

    private func hourlyForecastRow(_ hour: SunclubUVHourForecast) -> some View {
        HStack(spacing: 14) {
            Text(hour.date.formatted(.dateTime.hour()))
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.ink)
                .frame(width: 48, alignment: .leading)

            Image(systemName: hour.level.symbolName)
                .font(AppTextStyle.bodyMedium.font)
                .foregroundStyle(AppPalette.sun)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text("\(hour.index)")
                .font(AppTextStyle.metric.font)
                .foregroundStyle(AppPalette.ink)
                .frame(width: 28, alignment: .leading)

            Spacer(minLength: 0)

            Text(hour.level.displayName)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hour.date.formatted(.dateTime.hour())), UV \(hour.index), \(hour.level.displayName)")
    }

    private var protectionTipsCard: some View {
        AppCard(padding: 16, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Sun Protection Tips")
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text("Seek shade during peak sun hours, wear a hat, and use UV-protective clothing.")
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("uvForecast.tips")
    }

    private var forecastHours: [SunclubUVHourForecast] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedDay)
        let liveHours = appState.uvForecast?.hours.filter {
            calendar.isDate($0.date, inSameDayAs: day)
        } ?? []

        if !liveHours.isEmpty {
            let lateMorningHours = liveHours.filter {
                let hour = calendar.component(.hour, from: $0.date)
                return hour >= 10 && hour <= 15
            }
            return Array((lateMorningHours.isEmpty ? liveHours : lateMorningHours).prefix(6))
        }

        return []
    }
}

private struct UVForecastPresentationReading {
    let index: Int
    let level: UVLevel
    let sourceLabel: String
    let recommendation: String
}

private struct UVForecastHeroCard: View {
    let index: Int
    let level: UVLevel
    let sourceLabel: String
    let recommendation: String

    var body: some View {
        AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Text("\(index)")
                        .font(AppTypography.streakNumber)
                        .foregroundStyle(AppPalette.sun)
                        .frame(minWidth: 88, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("UV Index")
                            .font(AppTextStyle.captionMedium.font)
                            .foregroundStyle(AppPalette.sun)

                        Text(level.displayName)
                            .font(AppTypography.screenTitle)
                            .foregroundStyle(AppPalette.sun)

                        Text(sourceLabel)
                            .font(AppTextStyle.caption.font)
                            .foregroundStyle(AppPalette.softInk)
                    }
                }

                Text(recommendation)
                    .font(AppTextStyle.body.font)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("UV Index \(index), \(level.displayName). \(recommendation)")
        .accessibilityIdentifier("uvForecast.hero")
    }
}

#Preview {
    SunclubPreviewHost {
        UVForecastDetailView()
    }
}
