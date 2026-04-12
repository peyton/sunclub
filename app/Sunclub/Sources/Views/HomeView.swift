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
                uvBriefingCard
                achievementCelebrationCard
                growthLinksGrid

                Button {
                    router.open(.weeklySummary)
                } label: {
                    streakCard
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.streakCard")

                secondaryActionsSection

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
            appState.refreshUVForecastIfNeeded()
            appState.refreshNotificationHealth()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                SunBrandLockup(layout: .inline, markSize: 32)

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

            HStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Image(systemName: greetingSymbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityLabel(greetingSymbolAccessibilityLabel)
            }

            Text(SunclubCopy.Brand.homeSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
        }
    }

    private var todayCard: some View {
        let presentation = appState.todayCardPresentation

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                Spacer(minLength: 0)

                if appState.record(for: Date()) != nil {
                    Label("Logged", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.success)
                }
            }

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

    @ViewBuilder
    private var uvBriefingCard: some View {
        if let uvForecast = appState.uvForecast {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Skin's Weather Report")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    Spacer(minLength: 0)

                    if let peakHour = uvForecast.peakHour {
                        Text("Peak \(peakHour.index)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppPalette.sun)
                    }
                }

                Text(uvForecast.headline)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                if !uvForecast.hours.isEmpty {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(uvForecast.hours.prefix(8))) { hour in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(barColor(for: hour.level))
                                    .frame(width: 18, height: max(CGFloat(hour.index) * 8, 10))

                                Text(hour.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppPalette.softInk)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(uvForecast.recommendation)
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
        }
    }

    @ViewBuilder
    private var achievementCelebrationCard: some View {
        if let achievement = appState.achievementCelebration {
            HStack(spacing: 14) {
                Image(systemName: achievement.symbolName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.sun)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlocked: \(achievement.title)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(achievement.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Button("View") {
                    router.open(.achievements)
                }
                .buttonStyle(SunSecondaryButtonStyle())
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppPalette.warmGlow.opacity(0.5))
            )
        }
    }

    private var growthLinksGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Sunclub")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                homeFeatureButton(
                    title: "Achievements",
                    detail: appState.unseenAchievementCount > 0 ? "\(appState.unseenAchievementCount) new" : "Badges and challenges",
                    symbol: "rosette",
                    route: .achievements
                )

                homeFeatureButton(
                    title: "Friends",
                    detail: appState.friends.isEmpty ? "Invite someone" : "\(appState.friends.count) synced",
                    symbol: "person.2.fill",
                    route: .friends
                )

                homeFeatureButton(
                    title: "Skin Report",
                    detail: "PDF and streak share",
                    symbol: "doc.richtext.fill",
                    route: .skinHealthReport
                )

                homeFeatureButton(
                    title: "Scanner",
                    detail: "Read SPF from a bottle",
                    symbol: "camera.viewfinder",
                    route: .productScanner
                )
            }
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(appState.currentStreak)")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(AppPalette.streakAccent)
                .accessibilityIdentifier("home.streakValue")

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Day streak")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("home.dayStreakLabel")

                if appState.longestStreak > 0 {
                    Text("Best: \(appState.longestStreak)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .accessibilityIdentifier("home.longestStreak")
                }
            }

            Text("Open your last 7 days.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppPalette.streakBackground)
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

    private func homeFeatureButton(
        title: String,
        detail: String,
        symbol: String,
        route: AppRoute
    ) -> some View {
        Button {
            router.open(route)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.softInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
        }
        .buttonStyle(.plain)
    }

    private func barColor(for level: UVLevel) -> Color {
        switch level {
        case .low:
            return AppPalette.success
        case .moderate:
            return AppPalette.sun
        case .high:
            return Color.orange
        case .veryHigh:
            return Color.red.opacity(0.75)
        case .extreme:
            return Color.pink.opacity(0.8)
        case .unknown:
            return AppPalette.muted
        }
    }

    @ViewBuilder
    private var secondaryActionsSection: some View {
        if hasSecondaryActions {
            VStack(alignment: .leading, spacing: 12) {
                Text("Up next")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                notificationHealthCard
                recoveryCard
                syncRecoveryCard
                reapplyCard
            }
        }
    }

    @ViewBuilder
    private var notificationHealthCard: some View {
        if let presentation = appState.notificationHealthPresentation {
            HomeBannerCard(
                title: presentation.title,
                detail: presentation.detail,
                symbol: "bell.badge.fill",
                tint: Color.red.opacity(0.75),
                actionTitle: presentation.actionTitle,
                accessibilityIdentifier: "home.notificationHealthAction"
            ) {
                switch presentation.state {
                case .denied:
                    router.open(.settings)
                case .stale:
                    appState.repairReminderSchedule()
                case .healthy:
                    break
                }
            }
        }
    }

    @ViewBuilder
    private var recoveryCard: some View {
        if !appState.homeRecoveryActions.isEmpty {
            VStack(spacing: 10) {
                ForEach(appState.homeRecoveryActions) { action in
                    HomeBannerCard(
                        title: action.title,
                        detail: action.detail,
                        symbol: action.kind == .logToday ? "sun.max.fill" : "calendar.badge.exclamationmark",
                        tint: AppPalette.sun,
                        actionTitle: action.buttonTitle,
                        accessibilityIdentifier: "home.recovery.\(action.kind.rawValue)"
                    ) {
                        performRecoveryAction(action)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var reapplyCard: some View {
        if let presentation = appState.reapplyCheckInPresentation {
            HomeBannerCard(
                title: presentation.title,
                detail: presentation.detail,
                symbol: "arrow.clockwise.circle.fill",
                tint: AppPalette.sun,
                actionTitle: presentation.actionTitle,
                accessibilityIdentifier: "home.reapplyCard"
            ) {
                router.open(.reapplyCheckIn)
            }
        }
    }

    @ViewBuilder
    private var syncRecoveryCard: some View {
        if appState.pendingImportedBatchCount > 0 || !appState.conflicts.isEmpty {
            HomeBannerCard(
                title: syncRecoveryTitle,
                detail: syncRecoveryDetail,
                symbol: !appState.conflicts.isEmpty
                    ? "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90"
                    : "icloud.and.arrow.up",
                tint: !appState.conflicts.isEmpty ? Color.red.opacity(0.75) : AppPalette.sun,
                actionTitle: "Review",
                accessibilityIdentifier: "home.syncRecoveryCard"
            ) {
                router.open(.recovery)
            }
        }
    }

    private var syncRecoveryTitle: String {
        if !appState.conflicts.isEmpty {
            return "Review changes"
        }

        return "Saved only on this phone"
    }

    private var syncRecoveryDetail: String {
        var parts: [String] = []

        if appState.pendingImportedBatchCount > 0 {
            parts.append(SunclubCopy.Sync.readyToSendToICloud(appState.pendingImportedBatchCount))
        }

        if !appState.conflicts.isEmpty {
            parts.append(SunclubCopy.Sync.mergedChangesNeedReview(appState.conflicts.count))
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
        HomeGreetingFormatter.greeting(
            for: now,
            preferredDisplayName: appState.preferredDisplayName
        )
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

    private var hasSecondaryActions: Bool {
        appState.notificationHealthPresentation != nil
            || !appState.homeRecoveryActions.isEmpty
            || appState.pendingImportedBatchCount > 0
            || !appState.conflicts.isEmpty
            || appState.reapplyCheckInPresentation != nil
    }
    private var greetingSymbolAccessibilityLabel: String {
        greetingSymbol == "sun.max" ? "Daytime" : "Nighttime"
    }
}

enum HomeGreetingFormatter {
    static func greeting(
        for date: Date,
        preferredDisplayName: String,
        calendar: Calendar = .current
    ) -> String {
        let baseGreeting = baseGreeting(for: date, calendar: calendar)
        let displayName = preferredDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !displayName.isEmpty else {
            return baseGreeting
        }

        return "\(baseGreeting), \(displayName)"
    }

    private static func baseGreeting(for date: Date, calendar: Calendar) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
}

private struct HomeBannerCard: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let actionTitle: String
    let accessibilityIdentifier: String
    let action: () -> Void

    init(
        title: String,
        detail: String,
        symbol: String,
        tint: Color,
        actionTitle: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tint = tint
        self.actionTitle = actionTitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(tint, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(actionTitle, action: action)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppPalette.warmGlow.opacity(0.5))
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityIdentifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

#Preview {
    SunclubPreviewHost {
        HomeView()
    }
}
