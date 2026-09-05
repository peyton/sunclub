import SwiftUI
import UIKit

extension SettingsView {
    var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HealthKit")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $healthKitEnabled) {
                    Text("Sync sunscreen logs to Apple Health")
                        .font(AppFont.rounded(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .accessibilityIdentifier("settings.healthKitToggle")
                .onChange(of: healthKitEnabled) { _, newValue in
                    appState.updateHealthKitEnabled(newValue)
                }

                let detail = appState.healthKitAvailable
                    ? "Sunclub writes UV exposure samples when you log. Imported Health UV samples in the last year: \(appState.growthSettings.healthKit.importedSampleCount)."
                    : "Health data is unavailable on this device."

                SunStatusCard(
                    title: healthKitEnabled ? "Health sync is on" : "Health sync is off",
                    detail: detail,
                    tint: AppPalette.sun,
                    symbol: "heart.text.square.fill"
                )
            }
            .padding(18)
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    var uvBriefingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily UV Briefing")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                ReminderToggleCard(
                    title: "Morning UV briefing",
                    detail: dailyUVBriefingEnabled
                        ? "Send a morning note with peak UV and protection advice."
                        : "Only the standard sunscreen reminders stay on.",
                    isOn: $dailyUVBriefingEnabled,
                    accessibilityIdentifier: "settings.uvBriefingToggle"
                )
                .onChange(of: dailyUVBriefingEnabled) { _, newValue in
                    appState.updateUVBriefingPreferences(dailyBriefingEnabled: newValue)
                }

                ReminderToggleCard(
                    title: "Extreme UV alert",
                    detail: extremeUVAlertsEnabled
                        ? "Sunclub sends an extra heads-up on extreme UV days."
                        : "No extra UV alert is sent even on extreme days.",
                    isOn: $extremeUVAlertsEnabled,
                    accessibilityIdentifier: "settings.extremeUVToggle"
                )
                .onChange(of: extremeUVAlertsEnabled) { _, newValue in
                    appState.updateUVBriefingPreferences(extremeAlertEnabled: newValue)
                }
            }
            .padding(18)
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    var liveUVSection: some View {
        let presentation = appState.liveUVStatusPresentation

        return VStack(alignment: .leading, spacing: 14) {
            Text("Live UV")
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $liveUVEnabled) {
                    Text("Use Apple Weather for Live UV")
                        .font(AppTextStyle.bodyMedium.font)
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .onChange(of: liveUVEnabled) { _, newValue in
                    let didSave = appState.updateLiveUVPreference(
                        enabled: newValue,
                        allowPermissionPrompt: newValue
                    )
                    if !didSave {
                        liveUVEnabled = appState.settings.usesLiveUV
                    }
                }
                .accessibilityIdentifier("settings.liveUVToggle")

                Text("Choose Current Location or save a city for Apple Weather. Sunclub reuses forecasts for up to eight hours, then shows cached or locally estimated UV when a refresh is unavailable.")
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button(appState.settings.selectedUVPlace == nil ? "Choose a City" : "Change UV City") {
                    isChoosingUVCity = true
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.liveUV.chooseCity")

                if let selectedPlace = appState.settings.selectedUVPlace {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("Saved city: \(selectedPlace.displayName)")
                            .font(AppTextStyle.captionMedium.font)
                            .foregroundStyle(AppPalette.ink)

                        Spacer(minLength: 8)

                        Button("Remove") {
                            if appState.updateSelectedUVPlace(nil) {
                                appState.refreshUVForecastIfNeeded()
                            }
                        }
                        .font(AppTextStyle.captionMedium.font)
                        .foregroundStyle(AppColor.warning)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.liveUV.removeCity")
                    }
                }

                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: liveUVStatusTint(for: presentation),
                    symbol: "sun.max.circle.fill"
                )
                .accessibilityIdentifier("settings.liveUV.status")

                Text("Apple Weather and cached Apple Weather include attribution and a Data Sources link. Local estimates are labeled separately.")
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle = presentation.actionTitle,
                   let actionKind = presentation.actionKind {
                    Button(actionTitle) {
                        handleLiveUVAction(actionKind)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("settings.liveUV.action")
                }
            }
            .padding(18)
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    var uvAndHealthSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("UV & Weather")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            liveUVSection
            uvBriefingSection
            healthKitSection
        }
    }

    func liveUVStatusTint(for presentation: LiveUVStatusPresentation) -> Color {
        switch presentation.actionKind {
        case .some(.openSettings), .some(.requestPermission):
            return AppColor.warning.opacity(0.72)
        case .some(.refresh):
            return liveUVEnabled ? AppPalette.sun : AppPalette.softInk
        case .none:
            return liveUVEnabled ? AppPalette.sun : AppPalette.softInk
        }
    }

    func handleLiveUVAction(_ action: LiveUVActionKind) {
        switch action {
        case .openSettings:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        case .requestPermission, .refresh:
            appState.performLiveUVAction(action)
        }
    }
}
