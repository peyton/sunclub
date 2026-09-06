import SwiftUI

extension SettingsView {
    var settingsHome: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            settingsHomeGroup(title: "Daily Use") {
                settingsHomeRow(
                    title: "Sunscreen",
                    detail: appState.settings.sunscreenProfile.map { "\($0.name) · SPF \($0.spf)" },
                    icon: .sunscreen,
                    accessibilityIdentifier: "settings.section.sunscreen"
                ) {
                    router.push(.settingsSunscreen)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Reminders",
                    detail: reminderHeadline,
                    icon: .bell,
                    accessibilityIdentifier: "settings.section.reminders"
                ) {
                    router.push(.settingsSunscreenReminders)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "UV & Weather",
                    icon: .sun,
                    accessibilityIdentifier: "settings.section.advanced"
                ) {
                    router.push(.settingsHealthWeather)
                }
            }

            settingsHomeGroup(title: "Connections") {
                settingsHomeRow(
                    title: "Apple Health",
                    detail: healthKitEnabled ? "Sync on" : "Sync off",
                    icon: .heartPulse,
                    accessibilityIdentifier: "settings.section.health"
                ) {
                    router.push(.settingsHealth)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "iCloud & Backup",
                    detail: appState.cloudSyncStatusPresentation.title,
                    icon: .cloud,
                    accessibilityIdentifier: "settings.section.data"
                ) {
                    router.push(.settingsData)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Shortcuts",
                    icon: .sparkles,
                    accessibilityIdentifier: "settings.section.automation"
                ) {
                    router.push(.settingsShortcuts)
                }
            }

            settingsHomeGroup(title: "Privacy & Support") {
                settingsHomeRow(
                    title: "Privacy",
                    icon: .shield,
                    accessibilityIdentifier: "settings.privacy.quick"
                ) {
                    router.push(.privacy)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Support",
                    icon: .lifeBuoy,
                    accessibilityIdentifier: "settings.support.quick"
                ) {
                    router.push(.support)
                }
            }
        }
    }

    func settingsHomeGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            AppText(title, style: .bodyMedium)
                .accessibilityAddTraits(.isHeader)

            AppCard(padding: 0, showsShadow: false) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    private var settingsRowDivider: some View {
        Divider()
            .overlay(AppColor.stroke)
            .padding(.horizontal, AppSpacing.sm)
            .accessibilityHidden(true)
    }

    func settingsHomeRow(
        title: String,
        detail: String? = nil,
        icon: SunIcon,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.xs) {
                icon.image.resizable().scaledToFit()
                    .foregroundStyle(AppColor.Text.secondary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    AppText(title, style: .bodyMedium)
                    if let detail, !detail.isEmpty {
                        AppText(detail, style: .caption, color: AppColor.Text.secondary)
                    }
                }

                Spacer(minLength: AppSpacing.xxs)

                SunIcon.chevronRight.image
                    .resizable().scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(AppColor.Text.secondary)
                    .accessibilityHidden(true)
            }
            .padding(AppSpacing.sm)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    func settingsDetailContent(for detail: SettingsDetail) -> some View {
        switch detail {
        case .sunscreen:
            SettingsSunscreenView()
        case .sunscreenReminders, .reapplyReminder, .notifications:
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                smarterReminderSection
                reapplySection
                leaveHomeReminderSection
                reminderCoachingSection

                DisclosureGroup {
                    notificationHealthSection
                        .padding(.top, AppSpacing.sm)
                } label: {
                    Text("Troubleshoot")
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.reminders.troubleshoot")
                }
                .font(AppTextStyle.bodyMedium.font)
            }
        case .healthWeather:
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                liveUVSection
                uvBriefingSection
            }
        case .health:
            healthKitSection
        case .data:
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                iCloudSection
                backupSection
            }
        case .shortcuts:
            AutomationSettingsPanel(
                style: .settings,
                feedbackMessage: $automationFeedback,
                openURL: openURL
            )
        case .help:
            SupportContent()
        }
    }
}
