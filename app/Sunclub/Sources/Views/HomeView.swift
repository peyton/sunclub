import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var now = Date()

    var body: some View {
        SunLightScreen {
            VStack(spacing: 26) {
                header

                todayCard

                Button {
                    router.open(.weeklySummary)
                } label: {
                    streakCard
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.streakCard")

                Button {
                    router.open(.history)
                } label: {
                    historyCard
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.historyCard")

                Spacer(minLength: 0)
            }
        } footer: {
            VStack(spacing: 12) {
                Button("Log Manually") {
                    router.open(.manualLog)
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("home.logManually")
            }
        }
        .onAppear {
            now = Date()
            appState.clearVerificationSuccessPresentation()
            appState.refreshUVReadingIfNeeded()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Image(systemName: greetingSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
            }

            Spacer(minLength: 0)

            Button {
                router.open(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.72))
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.settingsButton")
        }
    }

    private var todayCard: some View {
        let presentation = appState.todayCardPresentation

        return VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(presentation.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("home.todayStatus")

            if let uvHeadline = presentation.uvHeadline,
               let uvSymbolName = presentation.uvSymbolName {
                HStack(spacing: 8) {
                    Image(systemName: uvSymbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.sun)

                    Text(uvHeadline)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("home.uvHeadline")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppPalette.warmGlow.opacity(0.45))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(uvHeadline)
                .accessibilityIdentifier("home.uvStatus")
            }

            Text(presentation.detail)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
                .accessibilityIdentifier("home.todayDetail")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(appState.currentStreak)")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(Color(red: 0.870, green: 0.482, blue: 0.000))

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Day Streak")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppPalette.ink)

                if appState.longestStreak > 0 {
                    Text("Best: \(appState.longestStreak)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                }
            }

            Text("Tap to see your last 7 days.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 1.000, green: 0.947, blue: 0.760))
        )
    }

    private var historyCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppPalette.sun)

            VStack(alignment: .leading, spacing: 2) {
                Text("History")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text("View your full calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private var greetingSymbol: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<17:
            return "sun.max"
        default:
            return "moon.stars"
        }
    }
}

#Preview {
    SunclubPreviewHost {
        HomeView()
    }
}
