import SwiftUI

struct SupportView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SunLightHeader(title: "Support", showsBack: true, onBack: {
                    router.goBack()
                })
                SupportContent()
                Spacer(minLength: 0)
            }
        }
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
    }
}

struct SupportContent: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            supportAction(
                title: "Email Support",
                detail: "Get help or send feedback.",
                icon: .mail,
                url: SunclubWebLinks.supportEmail,
                accessibilityIdentifier: "support.email"
            )
            supportAction(
                title: "Help Center",
                detail: "Find answers to common questions.",
                icon: .circleHelp,
                url: SunclubWebLinks.support,
                accessibilityIdentifier: "support.helpCenter"
            )
            supportAction(
                title: "Documentation",
                detail: "Logging, reminders, widgets, and Shortcuts.",
                icon: .book,
                url: SunclubWebLinks.docs,
                accessibilityIdentifier: "support.docs"
            )

            AppText("Version \(appVersion)", style: .caption, color: AppColor.Text.secondary)
                .padding(.top, AppSpacing.xxs)
                .accessibilityIdentifier("support.about")
        }
    }

    private func supportAction(
        title: String,
        detail: String,
        icon: SunIcon,
        url: URL,
        accessibilityIdentifier: String
    ) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: AppSpacing.xs) {
                icon.image.resizable().scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(AppColor.Text.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    AppText(title, style: .bodyMedium)
                    AppText(detail, style: .caption, color: AppColor.Text.secondary)
                }
                Spacer(minLength: AppSpacing.xxs)
                SunIcon.chevronRight.image.resizable().scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(AppColor.Text.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .padding(AppSpacing.md)
            .sunGlassCard(cornerRadius: AppRadius.card, interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? "1.0"
    }
}

#Preview {
    SunclubPreviewHost {
        SupportView()
    }
}
