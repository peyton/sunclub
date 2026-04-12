import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var now = Date()
    @State private var isExploreExpanded = false
    @State private var isUVExpanded = false
    @State private var feedbackTrigger = 0

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
                .accessibilityHint("Opens your last 7 days.")
                .accessibilityIdentifier("home.streakCard")

                accountabilityHomeCard
                accountabilityNudgeCard
                uvBriefingSection
                achievementCelebrationCard
                secondaryActionsSection

                Button {
                    router.open(.history)
                } label: {
                    historyCard
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your full calendar history.")
                .accessibilityIdentifier("home.historyCard")

                exploreSection

                Spacer(minLength: 0)
            }
        } footer: {
            footerActions
        }
        .onAppear {
            now = Date()
            appState.refreshUVReadingIfNeeded()
            appState.refreshUVForecastIfNeeded()
            appState.refreshNotificationHealth()
        }
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
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
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.72))

                if appState.record(for: Date()) != nil {
                    SunclubVisualAsset.motifShieldGlow.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116, height: 116)
                        .opacity(0.20)
                        .offset(x: 28, y: 30)
                }
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var accountabilityHomeCard: some View {
        if let presentation = appState.homeAccountabilityPresentation {
            HomeAccountabilityCard(
                presentation: presentation,
                onPrimaryAction: {
                    performAccountabilityAction(presentation)
                },
                onOpenFriends: {
                    router.open(.friends)
                }
            )
        }
    }

    @ViewBuilder
    private var accountabilityNudgeCard: some View {
        if appState.shouldShowAccountabilityNudge {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppPalette.sun)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add sunscreen accountability")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)

                        Text("Invite a friend after your first few logs. They only see streak status and whether today is done.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    Button("Set Up") {
                        router.open(.accountabilityOnboarding)
                    }
                    .buttonStyle(SunPrimaryButtonStyle())
                    .accessibilityIdentifier("home.accountabilityNudge.setup")

                    Button("Not Now") {
                        appState.dismissAccountabilityNudge()
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("home.accountabilityNudge.dismiss")
                }
            }
            .padding(18)
            .sunGlassCard(cornerRadius: 18)
        }
    }

    @ViewBuilder
    private var uvBriefingSection: some View {
        if let uvForecast = appState.uvForecast {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("UV Today")
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

                if shouldShowExpandedUVForecast(uvForecast), !uvForecast.hours.isEmpty {
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
                    .padding(12)
                    .background {
                        SunclubVisualAsset.backgroundUVBands.image
                            .resizable()
                            .scaledToFill()
                            .opacity(0.24)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                if shouldShowExpandedUVForecast(uvForecast) {
                    Text(uvForecast.recommendation)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.softInk)
                }

                Button(isUVExpanded ? "Show Less" : "Show More") {
                    feedbackTrigger += 1
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isUVExpanded.toggle()
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.ink)
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.uvBriefingToggle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .sunGlassCard(cornerRadius: 22)
        }
    }

    @ViewBuilder
    private var achievementCelebrationCard: some View {
        if let achievement = appState.achievementCelebration {
            HStack(spacing: 14) {
                SunclubBadgeMedallion(
                    asset: achievement.id.visualAsset,
                    size: 58,
                    tint: AppPalette.sun
                )

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
                    feedbackTrigger += 1
                    router.open(.achievements)
                }
                .buttonStyle(SunSecondaryButtonStyle())
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.warmGlow.opacity(0.5))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            }
        }
    }

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                feedbackTrigger += 1
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExploreExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.sun)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Explore")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)

                        Text("Optional tools for badges, accountability, reports, and scanning.")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExploreExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                }
                .padding(18)
                .sunGlassCard(cornerRadius: 18)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows optional Sunclub tools.")
            .accessibilityIdentifier("home.exploreToggle")

            if isExploreExpanded {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    homeFeatureButton(
                        title: "Achievements",
                        detail: appState.unseenAchievementCount > 0 ? "\(appState.unseenAchievementCount) new" : "Progress badges",
                        symbol: "rosette",
                        route: .achievements
                    )

                    homeFeatureButton(
                        title: "Accountability",
                        detail: appState.friends.isEmpty ? "Invite or add nearby" : "\(appState.friends.count) saved",
                        symbol: "person.2.fill",
                        route: .friends
                    )

                    homeFeatureButton(
                        title: "Health Report",
                        detail: "Export a PDF",
                        symbol: "doc.richtext.fill",
                        route: .skinHealthReport
                    )

                    homeFeatureButton(
                        title: "SPF Scanner",
                        detail: "Read a bottle label",
                        symbol: "camera.viewfinder",
                        route: .productScanner
                    )
                }
                .accessibilityIdentifier("home.exploreGrid")
            }
        }
    }

    private var streakCard: some View {
        ZStack(alignment: .topTrailing) {
            SunclubVisualAsset.motifSunRing.image
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 190)
                .opacity(0.24)
                .offset(x: 38, y: -36)

            VStack(alignment: .leading, spacing: 12) {
                Text("\(appState.currentStreak)")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppPalette.streakAccent, AppPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityIdentifier("home.streakValue")

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Day streak")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("home.dayStreakLabel")

                    if appState.longestStreak > 0 {
                        Text("Best: \(appState.longestStreak)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)
                            .accessibilityIdentifier("home.longestStreak")
                    }
                }

                HStack(spacing: 6) {
                    ForEach(Array(recentDayTrack.enumerated()), id: \.offset) { _, isLogged in
                        Capsule()
                            .fill(isLogged ? AppPalette.sun : Color.white.opacity(0.68))
                            .overlay {
                                Capsule()
                                    .stroke(Color.white.opacity(0.60), lineWidth: 1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 9)
                    }
                }
                .accessibilityHidden(true)

                Text("Open your weekly streak, then view full history.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
            }
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
            feedbackTrigger += 1
            router.open(route)
        } label: {
            ZStack(alignment: .topTrailing) {
                featureAsset(for: route).image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .opacity(0.24)
                    .offset(x: 14, y: -10)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(featureTint(for: route))

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(18)
            .sunGlassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(title).")
        .accessibilityIdentifier("home.feature.\(route.rawValue)")
    }

    private func barColor(for level: UVLevel) -> Color {
        switch level {
        case .low:
            return AppPalette.aloe
        case .moderate:
            return AppPalette.sun
        case .high:
            return AppPalette.coral
        case .veryHigh:
            return Color.red.opacity(0.78)
        case .extreme:
            return AppPalette.uvExtreme
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

    @ViewBuilder
    private var footerActions: some View {
        if appState.record(for: Date()) == nil {
            Button("Log Today") {
                feedbackTrigger += 1
                router.open(.manualLog)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("home.logManually")
        } else {
            VStack(spacing: 10) {
                Button(loggedPrimaryActionTitle) {
                    feedbackTrigger += 1
                    if appState.reapplyCheckInPresentation != nil {
                        router.open(.reapplyCheckIn)
                    } else {
                        router.open(.weeklySummary)
                    }
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("home.loggedPrimaryAction")

                Button("Edit Today's Log") {
                    feedbackTrigger += 1
                    router.open(.manualLog)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("home.editToday")
            }
        }
    }

    private var loggedPrimaryActionTitle: String {
        appState.reapplyCheckInPresentation?.actionTitle ?? "View Progress"
    }

    private func performRecoveryAction(_ action: HomeRecoveryAction) {
        switch action.kind {
        case .logToday:
            router.open(.manualLog)
        case .backfillYesterday:
            router.open(.backfillYesterday)
        }
    }

    private func performAccountabilityAction(_ presentation: HomeAccountabilityPresentation) {
        switch presentation.primaryActionKind {
        case .invite, .view:
            router.open(.friends)
        case .poke:
            guard let friendID = presentation.primaryFriendID else {
                router.open(.friends)
                return
            }
            appState.sendDirectPoke(to: friendID)
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
    }

    private func shouldShowExpandedUVForecast(_ forecast: SunclubUVForecast) -> Bool {
        isUVExpanded || isElevatedUVLevel(forecast.peakHour?.level)
    }

    private func isElevatedUVLevel(_ level: UVLevel?) -> Bool {
        switch level {
        case .high, .veryHigh, .extreme:
            return true
        default:
            return false
        }
    }

    private var greetingSymbolAccessibilityLabel: String {
        greetingSymbol == "sun.max" ? "Daytime" : "Nighttime"
    }

    private var recentDayTrack: [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recorded = Set(appState.recordedDays.map { calendar.startOfDay(for: $0) })

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: today) else {
                return nil
            }
            return recorded.contains(day)
        }
    }

    private func featureAsset(for route: AppRoute) -> SunclubVisualAsset {
        switch route {
        case .achievements:
            return .illustrationAchievementsShelf
        case .friends:
            return .illustrationFriendsPair
        case .skinHealthReport:
            return .illustrationSkinReport
        case .productScanner:
            return .illustrationScannerLabel
        default:
            return .motifShieldGlow
        }
    }

    private func featureTint(for route: AppRoute) -> Color {
        switch route {
        case .achievements:
            return AppPalette.coral
        case .friends:
            return AppPalette.pool
        case .skinHealthReport:
            return AppPalette.aloe
        case .productScanner:
            return AppPalette.sun
        default:
            return AppPalette.sun
        }
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
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        }
    }
}

private struct HomeAccountabilityCard: View {
    let presentation: HomeAccountabilityPresentation
    let onPrimaryAction: () -> Void
    let onOpenFriends: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AppPalette.sun, in: Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Accountability")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppPalette.softInk)

                        Text(presentation.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(presentation.openCountText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppPalette.ink)
                            Text(presentation.loggedCountText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppPalette.softInk)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppPalette.softInk)
                            .padding(.top, 2)
                    }
                }

                Text(presentation.detail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                if !presentation.friends.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presentation.friends) { friend in
                                HomeAccountabilityFriendChip(friend: friend)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.accountabilityFriendStrip")
                }

                if let latestPokeText = presentation.latestPokeText {
                    Label(latestPokeText, systemImage: "hand.tap.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppPalette.softInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.accountabilityLatestPoke")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpenFriends)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.accountabilityOpen")

            if presentation.primaryActionKind != .view {
                Button(presentation.primaryActionTitle, action: onPrimaryAction)
                    .buttonStyle(SunPrimaryButtonStyle())
                    .accessibilityIdentifier("home.accountabilityPoke")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.accountabilityCard")
    }
}

private struct HomeAccountabilityFriendChip: View {
    let friend: HomeAccountabilityFriendPresentation

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(friend.hasLoggedToday ? AppPalette.success : AppPalette.sun)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(friend.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                    .lineLimit(1)

                Text("\(friend.status) · \(friend.streak)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.82))
        )
    }
}

#Preview {
    SunclubPreviewHost {
        HomeView()
    }
}
