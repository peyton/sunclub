import SwiftUI

struct TimelineFooterBar: View {
    @Environment(AppRouter.self) private var router

    let primaryTitle: String
    let primaryIdentifier: String
    let onPrimaryTap: () -> Void

    var body: some View {
        SunBottomNavigationBar(
            leadingItems: [
                SunBottomNavigationItem(
                    id: "today",
                    title: "Today",
                    systemImage: "sun.max.fill",
                    accessibilityIdentifier: "timeline.footer.today",
                    action: { router.open(.home) }
                ),
                SunBottomNavigationItem(
                    id: "history",
                    title: "History",
                    systemImage: "calendar",
                    accessibilityIdentifier: "home.historyCard",
                    action: { router.open(.history) }
                )
            ],
            trailingItems: [
                SunBottomNavigationItem(
                    id: "insights",
                    title: "Insights",
                    systemImage: "chart.bar.fill",
                    accessibilityIdentifier: "home.streakCard",
                    action: { router.open(.weeklySummary) }
                ),
                SunBottomNavigationItem(
                    id: "settings",
                    title: "Settings",
                    systemImage: "gearshape.fill",
                    accessibilityIdentifier: "timeline.footer.settings",
                    action: { router.open(.settings) }
                )
            ],
            primaryTitle: primaryTitle,
            primaryIdentifier: primaryIdentifier,
            onPrimaryTap: onPrimaryTap
        )
        .padding(.top, 64)
    }
}
