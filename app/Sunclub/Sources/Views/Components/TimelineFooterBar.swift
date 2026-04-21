import SwiftUI

struct TimelineFooterBar: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let primaryTitle: String
    let primaryIdentifier: String
    let onPrimaryTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(primaryTitle, action: onPrimaryTap)
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier(primaryIdentifier)

            pillTabs
        }
    }

    @ViewBuilder
    private var pillTabs: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
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
            HStack(spacing: 8) {
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
            .padding(4)
            .background(
                Capsule()
                    .fill(AppPalette.cardFill.opacity(0.72))
            )
            .overlay {
                Capsule()
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(AppPalette.warmGlow.opacity(0.45))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityHint("Opens \(title).")
    }
}
