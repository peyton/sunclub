import SwiftUI

struct PrivacyView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center
        ) {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "Privacy", showsBack: true, onBack: {
                    router.goBack()
                })

                AppCard(padding: 20, cornerRadius: AppRadius.card, fill: AppPalette.elevatedCardFill) {
                    VStack(alignment: .leading, spacing: 20) {
                        SunProductIcon(systemName: "lock.fill", tint: AppPalette.aloe, size: 44)

                        Text("Privacy, by design.")
                            .font(AppFont.rounded(size: 28, weight: .bold))
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        privacyRows

                        Button {
                            openURL(SunclubWebLinks.privacy)
                        } label: {
                            HStack(spacing: 6) {
                                Text("Learn more about our privacy practices")
                                Image(systemName: "arrow.right")
                                    .font(AppFont.rounded(size: 12, weight: .semibold))
                            }
                            .font(AppTextStyle.captionMedium.font)
                            .foregroundStyle(AppPalette.pool)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("privacy.learnMore")
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var privacyRows: some View {
        VStack(alignment: .leading, spacing: 16) {
            SunInfoRow(
                title: "Your data stays yours.",
                detail: "We don't sell your data or show ads.",
                systemImage: "shield.checkered",
                tint: AppPalette.aloe
            )

            SunInfoRow(
                title: "iCloud sync is end-to-end on your devices.",
                detail: "Your sunscreen history follows you privately.",
                systemImage: "icloud",
                tint: AppPalette.aloe
            )

            SunInfoRow(
                title: "You're in control.",
                detail: "Export or delete your data anytime from Settings.",
                systemImage: "square.and.arrow.up",
                tint: AppPalette.aloe
            )
        }
        .accessibilityIdentifier("privacy.rows")
    }
}

#Preview {
    SunclubPreviewHost {
        PrivacyView()
    }
}
