import SwiftUI

struct SupportView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "Support", showsBack: true, onBack: {
                    router.goBack()
                })

                SunScreenTitleBlock(
                    title: "Get help with Sunclub",
                    detail: "Support, documentation, and feedback stay one tap away.",
                    symbolName: "lifepreserver.fill",
                    tint: AppPalette.pool
                )

                VStack(alignment: .leading, spacing: 12) {
                    supportAction(
                        title: "Email Support",
                        detail: "Ask for help with logging, reminders, sync, or billing.",
                        symbolName: "envelope.fill",
                        url: SunclubWebLinks.supportEmail,
                        accessibilityIdentifier: "support.email"
                    )

                    supportAction(
                        title: "Help Center",
                        detail: "Read setup, widget, Shortcuts, and privacy guides.",
                        symbolName: "questionmark.circle.fill",
                        url: SunclubWebLinks.support,
                        accessibilityIdentifier: "support.helpCenter"
                    )

                    supportAction(
                        title: "Feedback",
                        detail: "Report a problem or suggest an improvement.",
                        symbolName: "bubble.left.and.bubble.right.fill",
                        url: SunclubWebLinks.supportEmail,
                        accessibilityIdentifier: "support.feedback"
                    )

                    SunInfoRow(
                        title: "About Sunclub",
                        detail: "Version \(appVersion)",
                        systemImage: "sun.max.fill",
                        tint: AppPalette.sun,
                        showsChevron: false
                    )
                    .padding(16)
                    .background(referenceRowBackground)
                    .accessibilityIdentifier("support.about")
                }

                Spacer(minLength: 0)
            }
        }
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
    }

    private func supportAction(
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
            .padding(16)
            .background(referenceRowBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var referenceRowBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.84))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppPalette.hairlineStroke, lineWidth: 1)
            }
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
