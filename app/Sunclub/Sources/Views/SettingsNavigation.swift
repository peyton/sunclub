import SwiftUI
import UIKit

extension SettingsView {
    var settingsHome: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            settingsHomeGroup(title: "Daily Use") {
                settingsHomeRow(
                    title: "Sunscreen & Reminders",
                    detail: "Daily reminder times and sunscreen preferences.",
                    icon: .sun,
                    accessibilityIdentifier: "settings.section.reminders"
                ) {
                    router.push(.settingsSunscreenReminders)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Reapply Reminder",
                    detail: sectionDetail(for: .progress),
                    icon: .clock,
                    accessibilityIdentifier: "settings.section.progress"
                ) {
                    router.push(.settingsReapplyReminder)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Notifications",
                    detail: reminderHeadline,
                    icon: .bell,
                    accessibilityIdentifier: "settings.reference.notifications"
                ) {
                    router.push(.settingsNotifications)
                }
            }

            settingsHomeGroup(title: "Data & Integrations") {
                settingsHomeRow(
                    title: "UV & Weather",
                    detail: sectionDetail(for: .advanced),
                    icon: .sun,
                    accessibilityIdentifier: "settings.section.advanced"
                ) {
                    router.push(.settingsHealthWeather)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "iCloud & Data",
                    detail: sectionDetail(for: .data),
                    icon: .cloud,
                    accessibilityIdentifier: "settings.section.data"
                ) {
                    router.push(.settingsData)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Shortcuts",
                    detail: sectionDetail(for: .automation),
                    icon: .sparkles,
                    accessibilityIdentifier: "settings.section.automation"
                ) {
                    router.push(.settingsShortcuts)
                }
            }

            settingsHomeGroup(title: "Privacy & Support") {
                settingsHomeRow(
                    title: "Privacy",
                    detail: "How your data is handled.",
                    icon: .shield,
                    accessibilityIdentifier: "settings.privacy.quick"
                ) {
                    router.push(.privacy)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Support",
                    detail: "Get help or send feedback.",
                    icon: .lifeBuoy,
                    accessibilityIdentifier: "settings.support.quick"
                ) {
                    router.push(.support)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Help & Legal",
                    detail: "Support links and privacy policy.",
                    icon: .circleHelp,
                    accessibilityIdentifier: "settings.section.help"
                ) {
                    router.push(.settingsHelp)
                }

                settingsRowDivider

                settingsHomeRow(
                    title: "Documentation",
                    detail: "Setup, widgets, and Shortcuts.",
                    icon: .book,
                    accessibilityIdentifier: "settings.docs.quick"
                ) {
                    openURL(SunclubWebLinks.docs)
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
        detail: String,
        icon: SunIcon,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsReferenceRowContent(
                title: title,
                detail: detail,
                icon: icon
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @ViewBuilder
    func settingsDetailContent(for detail: SettingsDetail) -> some View {
        switch detail {
        case .sunscreenReminders:
            VStack(alignment: .leading, spacing: 22) {
                smarterReminderSection
                reapplySection
                reminderCoachingSection
            }
        case .reapplyReminder:
            reapplySection
        case .notifications:
            VStack(alignment: .leading, spacing: 22) {
                notificationOverviewCard
                notificationHealthSection
                smarterReminderSection
            }
        case .healthWeather:
            VStack(alignment: .leading, spacing: 22) {
                leaveHomeReminderSection
                uvAndHealthSection
            }
        case .data:
            VStack(alignment: .leading, spacing: 22) {
                iCloudSection
                backupSection
            }
        case .shortcuts:
            VStack(alignment: .leading, spacing: 22) {
                AutomationSettingsPanel(
                    style: .settings,
                    feedbackMessage: $automationFeedback,
                    openURL: openURL
                )
            }
        case .help:
            helpAndLegalSection
        }
    }

    var helpAndLegalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Support")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 12) {
                webLinkButton(
                    title: "Documentation",
                    detail: "Setup, shortcuts, widgets, and data notes.",
                    icon: .book,
                    url: SunclubWebLinks.docs,
                    accessibilityIdentifier: "settings.docs"
                )

                webLinkButton(
                    title: "Help Center",
                    detail: "Open Sunclub support in your browser.",
                    icon: .circleHelp,
                    url: SunclubWebLinks.support,
                    accessibilityIdentifier: "settings.support"
                )

                webLinkButton(
                    title: "Privacy Policy",
                    detail: "Read how Sunclub handles app data and optional Apple features.",
                    icon: .shield,
                    url: SunclubWebLinks.privacy,
                    accessibilityIdentifier: "settings.privacyPolicy"
                )

                webLinkButton(
                    title: "Email Support",
                    detail: "Send an email to support@mail.sunclub.peyton.app.",
                    icon: .mail,
                    url: SunclubWebLinks.supportEmail,
                    accessibilityIdentifier: "settings.emailSupport"
                )
            }

            Text("Sunclub is a habit tracker, not medical advice.")
                .font(AppFont.rounded(size: 13))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func sectionDetail(for section: SettingsSection) -> String {
        switch section {
        case .reminders:
            return reminderHeadline
        case .progress:
            return reapplyEnabled
                ? "Reapply reminder every \(formattedAccessibleInterval(reapplyInterval))."
                : "Reapply reminders are off."
        case .data:
            return appState.cloudSyncStatusPresentation.title
        case .automation:
            let writes = appState.automationPreferences.shortcutWritesEnabled ? "writes on" : "writes off"
            let links = appState.automationPreferences.urlOpenActionsEnabled ? "links on" : "links off"
            return "Shortcuts \(writes), URL \(links)."
        case .advanced:
            let liveUV = liveUVEnabled ? "Live UV on" : "Live UV off"
            let health = healthKitEnabled ? "Health sync on" : "Health sync off"
            return "\(liveUV). \(health)."
        case .help:
            return "Support, privacy, and contact links."
        }
    }

    func webLinkButton(
        title: String,
        detail: String,
        icon: SunIcon,
        url: URL,
        accessibilityIdentifier: String
    ) -> some View {
        Button {
            openURL(url)
        } label: {
            settingsReferenceRowContent(
                title: title,
                detail: detail,
                icon: icon
            )
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                interactive: true,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func settingsReferenceRowContent(
        title: String,
        detail: String,
        icon: SunIcon
    ) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            icon.image.resizable().scaledToFit()
                .foregroundStyle(AppColor.Text.secondary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                AppText(title, style: .bodyMedium)
                AppText(detail, style: .caption, color: AppColor.Text.secondary)
            }

            Spacer(minLength: AppSpacing.xxs)

            SunIcon.chevronRight.image
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(AppColor.Text.secondary)
                .accessibilityHidden(true)
        }
        .padding(AppSpacing.sm)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    var profileDetail: String {
        let name = appState.preferredDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Name, sharing identity, and friend nudges."
        }
        return "\(name), sharing identity, and friend nudges."
    }
}
