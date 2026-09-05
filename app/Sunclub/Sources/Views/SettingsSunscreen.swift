import SwiftUI

struct SettingsSunscreenView: View {
    @Environment(AppState.self) private var appState
    @State private var name = ""
    @State private var spf = 50
    @State private var waterResistance: SunclubSunscreenWaterResistance = .none
    @State private var feedback: String?
    @State private var saveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            AppText(
                "New logs use SPF from your log history first, then your saved sunscreen as a fallback.",
                style: .caption,
                color: AppColor.Text.secondary
            )

            AppCard(showsShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    TextField("Product name", text: $name)
                        .font(AppTextStyle.body.font)
                        .textInputAutocapitalization(.words)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Product name")
                        .accessibilityIdentifier("settings.sunscreen.name")

                    Stepper("SPF \(spf)", value: $spf, in: 1...100)
                        .font(AppTextStyle.body.font)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.sunscreen.spf")

                    Picker("Water-resistance label", selection: $waterResistance) {
                        Text("Not water-resistant").tag(SunclubSunscreenWaterResistance.none)
                        Text("40 minutes").tag(SunclubSunscreenWaterResistance.fortyMinutes)
                        Text("80 minutes").tag(SunclubSunscreenWaterResistance.eightyMinutes)
                    }
                    .pickerStyle(.menu)
                    .font(AppTextStyle.body.font)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("settings.sunscreen.waterResistance")
                }
            }

            AppText(
                "Follow the directions on your sunscreen label.",
                style: .caption,
                color: AppColor.Text.secondary
            )

            if let feedback {
                AppText(feedback, style: .caption, color: saveFailed ? AppPalette.warning : AppColor.Text.secondary)
                    .accessibilityIdentifier("settings.sunscreen.feedback")
            }

            Button("Save sunscreen") {
                saveProfile()
            }
            .sunGlassPrimaryButton()
            .accessibilityIdentifier("settings.sunscreen.save")

            if appState.settings.sunscreenProfile != nil {
                Button("Remove saved sunscreen", role: .destructive) {
                    guard appState.updateSunscreenProfile(nil) else {
                        saveFailed = true
                        feedback = appState.logActionErrorMessage
                            ?? "Sunscreen was not removed. Try again."
                        return
                    }
                    loadProfile()
                    saveFailed = false
                    feedback = "Saved sunscreen removed. Your logs are unchanged."
                }
                .sunGlassSecondaryButton()
                .accessibilityIdentifier("settings.sunscreen.remove")
            }
        }
        .onAppear(perform: loadProfile)
    }

    private func loadProfile() {
        let profile = appState.settings.sunscreenProfile
        name = profile?.name ?? ""
        spf = profile?.spf ?? 50
        waterResistance = profile?.waterResistance ?? .none
    }

    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            saveFailed = true
            feedback = "Enter the name printed on your sunscreen."
            return
        }
        let profile = SunclubSunscreenProfile(name: trimmedName, spf: spf, waterResistance: waterResistance)
        guard appState.updateSunscreenProfile(profile) else {
            saveFailed = true
            feedback = appState.logActionErrorMessage ?? "Sunscreen was not saved. Try again."
            return
        }
        name = profile.name
        saveFailed = false
        feedback = "Sunscreen saved."
    }
}
