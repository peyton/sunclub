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
                notificationHealthCard
                recoveryCard
                syncRecoveryCard
                reapplyCard

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
                Button(primaryActionTitle) {
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
            appState.refreshNotificationHealth()
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
                .accessibilityIdentifier("home.streakValue")

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

    @ViewBuilder
    private var notificationHealthCard: some View {
        if let presentation = appState.notificationHealthPresentation {
            VStack(alignment: .leading, spacing: 12) {
                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: Color.red.opacity(0.75),
                    symbol: "bell.badge.fill"
                )

                Button(presentation.actionTitle) {
                    switch presentation.state {
                    case .denied:
                        router.open(.settings)
                    case .stale:
                        appState.repairReminderSchedule()
                    case .healthy:
                        break
                    }
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("home.notificationHealthAction")
            }
        }
    }

    @ViewBuilder
    private var recoveryCard: some View {
        if !appState.homeRecoveryActions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Catch Up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                VStack(spacing: 12) {
                    ForEach(appState.homeRecoveryActions) { action in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(action.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppPalette.ink)

                            Text(action.detail)
                                .font(.system(size: 14))
                                .foregroundStyle(AppPalette.softInk)

                            Button(action.buttonTitle) {
                                performRecoveryAction(action)
                            }
                            .buttonStyle(SunSecondaryButtonStyle())
                            .accessibilityIdentifier("home.recovery.\(action.kind.rawValue)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.72))
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var reapplyCard: some View {
        if let presentation = appState.reapplyCheckInPresentation {
            Button {
                router.open(.reapplyCheckIn)
            } label: {
                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: AppPalette.sun,
                    symbol: "arrow.clockwise.circle.fill"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.reapplyCard")
        }
    }

    @ViewBuilder
    private var syncRecoveryCard: some View {
        if appState.pendingImportedBatchCount > 0 || !appState.conflicts.isEmpty {
            Button {
                router.open(.recovery)
            } label: {
                SunStatusCard(
                    title: syncRecoveryTitle,
                    detail: syncRecoveryDetail,
                    tint: !appState.conflicts.isEmpty ? Color.red.opacity(0.75) : AppPalette.sun,
                    symbol: !appState.conflicts.isEmpty
                        ? "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
                        : "icloud.and.arrow.up"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.syncRecoveryCard")
        }
    }

    private var syncRecoveryTitle: String {
        if !appState.conflicts.isEmpty {
            return "Review merged changes"
        }

        return "Imported changes are local-only"
    }

    private var syncRecoveryDetail: String {
        var parts: [String] = []

        if appState.pendingImportedBatchCount > 0 {
            parts.append("\(appState.pendingImportedBatchCount) imported change(s) are waiting for an explicit publish to iCloud.")
        }

        if !appState.conflicts.isEmpty {
            parts.append("\(appState.conflicts.count) auto-merged change(s) should be reviewed.")
        }

        return parts.joined(separator: " ")
    }

    private var primaryActionTitle: String {
        appState.record(for: Date()) == nil ? "Log Today" : "Update Today"
    }

    private func performRecoveryAction(_ action: HomeRecoveryAction) {
        switch action.kind {
        case .logToday:
            router.open(.manualLog)
        case .backfillYesterday:
            router.open(.backfillYesterday)
        }
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
