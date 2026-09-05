import SwiftUI
import UIKit

extension SettingsView {
    var settingsHome: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsHubIntro

            settingsHomeGroup(title: "Daily Use") {
                settingsHomeRow(
                    title: "Sunscreen & Reminders",
                    detail: "SPF defaults, daily reminder times, and reapply timing.",
                    symbolName: "sun.max.fill",
                    tint: AppPalette.sun,
                    accessibilityIdentifier: "settings.section.reminders"
                ) {
                    router.push(.settingsSunscreenReminders)
                }

                settingsHomeRow(
                    title: "Reapply Reminder",
                    detail: sectionDetail(for: .progress),
                    symbolName: "clock.badge.checkmark.fill",
                    tint: AppPalette.sun,
                    accessibilityIdentifier: "settings.section.progress"
                ) {
                    router.push(.settingsReapplyReminder)
                }

                settingsHomeRow(
                    title: "Notifications",
                    detail: reminderHeadline,
                    symbolName: "bell.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.reference.notifications"
                ) {
                    router.push(.settingsNotifications)
                }
            }

            settingsHomeGroup(title: "Data & Integrations") {
                settingsHomeRow(
                    title: "UV & Weather",
                    detail: sectionDetail(for: .advanced),
                    symbolName: "cloud.sun.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.section.advanced"
                ) {
                    router.push(.settingsHealthWeather)
                }

                settingsHomeRow(
                    title: "iCloud & Data",
                    detail: sectionDetail(for: .data),
                    symbolName: "icloud.fill",
                    tint: AppPalette.aloe,
                    accessibilityIdentifier: "settings.section.data"
                ) {
                    router.push(.settingsData)
                }

                settingsHomeRow(
                    title: "Shortcuts",
                    detail: sectionDetail(for: .automation),
                    symbolName: "wand.and.stars",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.section.automation"
                ) {
                    router.push(.settingsShortcuts)
                }
            }

            settingsHomeGroup(title: "Privacy & Support") {
                settingsHomeRow(
                    title: "Privacy",
                    detail: "Data, iCloud, export, and deletion practices.",
                    symbolName: "lock.shield.fill",
                    tint: AppPalette.aloe,
                    accessibilityIdentifier: "settings.privacy.quick"
                ) {
                    router.push(.privacy)
                }

                settingsHomeRow(
                    title: "Support",
                    detail: "Help center, email support, and feedback.",
                    symbolName: "lifepreserver.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.support.quick"
                ) {
                    router.push(.support)
                }

                settingsHomeRow(
                    title: "Help & Legal",
                    detail: "Documentation, privacy policy, email support, and support links.",
                    symbolName: "questionmark.circle.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.section.help"
                ) {
                    router.push(.settingsHelp)
                }

                settingsHomeRow(
                    title: "Documentation",
                    detail: "Setup, widgets, Shortcuts, and privacy details.",
                    symbolName: "book.pages.fill",
                    tint: AppPalette.pool,
                    accessibilityIdentifier: "settings.docs.quick"
                ) {
                    openURL(SunclubWebLinks.docs)
                }
            }
        }
    }

    var settingsHubIntro: some View {
        AppCard(padding: 18, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep your sun routine tuned.")
                    .font(AppFont.rounded(size: 24, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Manage reminders, privacy, sync, Shortcuts, and display preferences from one place.")
                    .font(AppFont.rounded(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func settingsHomeGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(spacing: 0) {
                content()
            }
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    func settingsHomeRow(
        title: String,
        detail: String,
        symbolName: String,
        tint: Color,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsReferenceRowContent(
                title: title,
                detail: detail,
                symbolName: symbolName,
                tint: tint,
                trailingText: nil,
                showsChevron: true
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
                    symbolName: "book.pages.fill",
                    url: SunclubWebLinks.docs,
                    accessibilityIdentifier: "settings.docs"
                )

                webLinkButton(
                    title: "Help Center",
                    detail: "Open Sunclub support in your browser.",
                    symbolName: "questionmark.circle.fill",
                    url: SunclubWebLinks.support,
                    accessibilityIdentifier: "settings.support"
                )

                webLinkButton(
                    title: "Privacy Policy",
                    detail: "Read how Sunclub handles app data and optional Apple features.",
                    symbolName: "lock.shield.fill",
                    url: SunclubWebLinks.privacy,
                    accessibilityIdentifier: "settings.privacyPolicy"
                )

                webLinkButton(
                    title: "Email Support",
                    detail: "Send an email to support@mail.sunclub.peyton.app.",
                    symbolName: "envelope.fill",
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
        symbolName: String,
        url: URL,
        accessibilityIdentifier: String
    ) -> some View {
        Button {
            openURL(url)
        } label: {
            SunInfoRow(
                title: title,
                detail: detail,
                systemImage: symbolName,
                tint: AppPalette.pool,
                showsChevron: true
            )
            .padding(18)
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

    func settingsReferenceRowContent(
        title: String,
        detail: String,
        symbolName: String,
        tint: Color,
        trailingText: String?,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            SunProductIcon(systemName: symbolName, tint: tint, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.ink)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
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
