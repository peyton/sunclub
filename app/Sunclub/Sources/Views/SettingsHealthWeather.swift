import SwiftUI
import UIKit

extension SettingsView {
    var healthKitEnabled: Bool {
        appState.growthSettings.healthKit.isEnabled
    }

    var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: Binding(
                    get: { appState.growthSettings.healthKit.isEnabled },
                    set: { appState.updateHealthKitEnabled($0) }
                )) {
                    Text("Sync sunscreen logs to Apple Health")
                        .font(AppFont.rounded(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .accessibilityIdentifier("settings.healthKitToggle")

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
                Toggle("Morning UV briefing", isOn: $dailyUVBriefingEnabled)
                    .font(AppTextStyle.bodyMedium.font)
                    .tint(AppPalette.sun)
                    .accessibilityIdentifier("settings.uvBriefingToggle")
                    .onChange(of: dailyUVBriefingEnabled) { _, newValue in
                        appState.updateUVBriefingPreferences(dailyBriefingEnabled: newValue)
                    }

                Toggle("Extreme UV alert", isOn: $extremeUVAlertsEnabled)
                    .font(AppTextStyle.bodyMedium.font)
                    .tint(AppPalette.sun)
                    .accessibilityIdentifier("settings.extremeUVToggle")
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
                    Text("Use current location")
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
                        .foregroundStyle(AppPalette.warning)
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
