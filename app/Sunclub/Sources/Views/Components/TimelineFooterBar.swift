import SwiftUI

struct TimelineFooterBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let primaryTitle: String
    let primaryIdentifier: String
    let onPrimaryTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                AppText("Log", style: .sectionHeader)

                Spacer(minLength: 0)

                Button("History") {
                    router.open(.history)
                }
                .font(AppTextStyle.bodyMedium.font)
                .foregroundStyle(AppPalette.success)
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.historyCard")
                .accessibilityHint("Opens your full calendar history.")
            }

            PrimaryButton(primaryTitle, systemImage: "sun.max", identifier: primaryIdentifier, action: onPrimaryTap)

            pillTabs
        }
    }

    @ViewBuilder
    private var pillTabs: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: AppSpacing.xs) {
                pillButton(
                    title: "Weekly",
                    systemImage: "chart.bar.fill",
                    identifier: "home.streakCard",
                    action: { router.open(.weeklySummary) }
                )
                pillButton(
                    title: "Accountability",
                    systemImage: "person.2.fill",
                    identifier: "timeline.footer.accountability",
                    action: { router.open(.friends) }
                )
            }
        } else {
            HStack(spacing: AppSpacing.md) {
                pillButton(
                    title: "Weekly",
                    systemImage: "chart.bar.fill",
                    identifier: "home.streakCard",
                    action: { router.open(.weeklySummary) }
                )
                pillButton(
                    title: "Accountability",
                    systemImage: "person.2.fill",
                    identifier: "timeline.footer.accountability",
                    action: { router.open(.friends) }
                )
            }
        }
    }

    private func pillButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(AppFont.rounded(size: 22, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(title)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(AppSecondaryPillButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityHint("Opens \(title).")
    }
}
