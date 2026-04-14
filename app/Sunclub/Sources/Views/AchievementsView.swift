import SwiftUI

struct AchievementsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var shareSheetItem: ShareSheetItem?
    @State private var feedbackTrigger = 0

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "Achievements", showsBack: true, onBack: {
                    router.goBack()
                })

                if let achievementCelebration = appState.achievementCelebration {
                    celebrationCard(for: achievementCelebration)
                }

                badgeOverviewCard

                achievementsSection
                challengesSection

                Spacer(minLength: 0)
            }
        }
        .sheet(item: $shareSheetItem) { item in
            ActivityShareSheet(items: item.items)
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Progress Badges")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                Spacer(minLength: 0)

                Text("\(appState.achievements.filter(\.isUnlocked).count)/\(appState.achievements.count) unlocked")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppPalette.warmGlow.opacity(0.75))
                    )
            }

            ForEach(sortedAchievements) { achievement in
                AchievementCard(achievement: achievement) {
                    shareAchievement(achievement)
                }
            }
        }
    }

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenges")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            ForEach(sortedChallenges) { challenge in
                ChallengeCard(challenge: challenge) {
                    shareChallenge(challenge)
                }
            }
        }
    }

    private var badgeOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                BadgeShelfPreview()

                VStack(alignment: .leading, spacing: 6) {
                    Text(nextAchievement == nil ? "Badge shelf complete" : "Next badge")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(nextBadgeDetail)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .sunGlassCard(cornerRadius: 22, fillOpacity: 0.70)
    }

    private func celebrationCard(for achievement: SunclubAchievement) -> some View {
        AchievementCelebrationCard(achievement: achievement) {
            feedbackTrigger += 1
            appState.markAchievementCelebrationSeen()
        }
    }

    private func shareAchievement(_ achievement: SunclubAchievement) {
        guard let artifact = try? appState.achievementArtifact(for: achievement) else {
            return
        }
        feedbackTrigger += 1
        var items: [Any] = [artifact.fileURL]
        if let shareText = artifact.shareText {
            items.append(shareText)
        }
        appState.recordShareActionStarted()
        shareSheetItem = ShareSheetItem(items: items)
    }

    private func shareChallenge(_ challenge: SunclubSeasonalChallenge) {
        guard let artifact = try? appState.challengeArtifact(for: challenge) else {
            return
        }
        feedbackTrigger += 1
        appState.recordShareActionStarted()
        shareSheetItem = ShareSheetItem(items: [artifact.fileURL])
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppPalette.cardFill.opacity(0.72))
    }

    private var sortedAchievements: [SunclubAchievement] {
        appState.achievements.sorted { lhs, rhs in
            if lhs.isUnlocked != rhs.isUnlocked {
                return !lhs.isUnlocked
            }

            if !lhs.isUnlocked, !rhs.isUnlocked {
                let lhsRemaining = remainingCount(for: lhs)
                let rhsRemaining = remainingCount(for: rhs)
                if lhsRemaining != rhsRemaining {
                    return lhsRemaining < rhsRemaining
                }
            }

            if lhs.progress != rhs.progress {
                return lhs.progress > rhs.progress
            }

            if lhs.targetValue != rhs.targetValue {
                return lhs.targetValue < rhs.targetValue
            }

            return lhs.title < rhs.title
        }
    }

    private var sortedChallenges: [SunclubSeasonalChallenge] {
        appState.seasonalChallenges.sorted { lhs, rhs in
            if lhs.isComplete != rhs.isComplete {
                return !lhs.isComplete
            }

            if !lhs.isComplete, !rhs.isComplete {
                let lhsRemaining = remainingCount(for: lhs)
                let rhsRemaining = remainingCount(for: rhs)
                if lhsRemaining != rhsRemaining {
                    return lhsRemaining < rhsRemaining
                }
            }

            if lhs.progress != rhs.progress {
                return lhs.progress > rhs.progress
            }

            if lhs.targetValue != rhs.targetValue {
                return lhs.targetValue < rhs.targetValue
            }

            return lhs.title < rhs.title
        }
    }

    private var nextAchievement: SunclubAchievement? {
        sortedAchievements.first { !$0.isUnlocked }
    }

    private var nextBadgeDetail: String {
        guard let nextAchievement else {
            return "Every badge is unlocked. Completed medals stay below for sharing."
        }

        let remaining = max(nextAchievement.targetValue - nextAchievement.currentValue, 0)
        return "\(nextAchievement.title): \(remaining) left."
    }

    private func remainingCount(for achievement: SunclubAchievement) -> Int {
        max(achievement.targetValue - achievement.currentValue, 0)
    }

    private func remainingCount(for challenge: SunclubSeasonalChallenge) -> Int {
        max(challenge.targetValue - challenge.currentValue, 0)
    }
}

#Preview {
    SunclubPreviewHost {
        AchievementsView()
    }
}

private struct AchievementCelebrationCard: View {
    let achievement: SunclubAchievement
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SunclubBadgeMedallion(
                asset: achievement.id.visualAsset,
                size: 82,
                tint: achievement.id.badgeTint
            )

            VStack(alignment: .leading, spacing: 8) {
                header
                title
                detail
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background { celebrationBackground }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.cardStroke, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Label("New Badge", systemImage: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppPalette.streakAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppPalette.warmGlow.opacity(0.68), in: Capsule())

            Spacer(minLength: 0)

            Button("Dismiss", action: onDismiss)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)
                .buttonStyle(.plain)
        }
    }

    private var title: some View {
        Text(achievement.title)
            .font(.system(size: 23, weight: .bold))
            .foregroundStyle(AppPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var detail: some View {
        Text(achievement.detail)
            .font(.system(size: 14))
            .foregroundStyle(AppPalette.softInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var celebrationBackground: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppPalette.warmGlow.opacity(0.48))

            SunclubVisualAsset.motifSunRing.image
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .opacity(0.16)
                .offset(x: 34, y: 38)
                .accessibilityHidden(true)
        }
    }
}

private struct BadgeShelfPreview: View {
    private let badges: [(SunclubVisualAsset, Color)] = [
        (.badgeSevenDay, AppPalette.pool),
        (.badgeRecovery, AppPalette.aloe),
        (.badgeHighUV, AppPalette.uvExtreme)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.warmGlow.opacity(0.34))
                .frame(width: 104, height: 78)

            HStack(spacing: -14) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    SunclubBadgeMedallion(asset: badge.0, size: 52, tint: badge.1)
                }
            }
        }
        .frame(width: 112, height: 88)
        .accessibilityHidden(true)
    }
}

private struct AchievementCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let achievement: SunclubAchievement
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                SunclubBadgeMedallion(
                    asset: achievement.id.visualAsset,
                    size: 68,
                    isLocked: !achievement.isUnlocked,
                    tint: achievement.id.badgeTint
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(achievement.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        if achievement.isUnlocked {
                            AchievementStatusPill(text: "Unlocked", tint: AppPalette.success)
                                .accessibilityIdentifier("achievement.status.\(achievement.id.rawValue)")
                        }
                    }

                    Text(achievement.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            MilestoneProgressMeter(
                progress: achievement.progress,
                currentValue: achievement.currentValue,
                targetValue: achievement.targetValue,
                isComplete: achievement.isUnlocked,
                unit: nil,
                accessibilityID: "achievement.progress.\(achievement.id.rawValue)"
            )

            if achievement.isUnlocked {
                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppPalette.warmGlow.opacity(0.65))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.sun.opacity(0.35), lineWidth: 1)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(achievement.isUnlocked ? AppPalette.warmGlow.opacity(0.34) : AppPalette.cardFill.opacity(0.78))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(achievement.isUnlocked ? AppPalette.sun.opacity(0.34) : AppPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .symbolEffect(.bounce, value: reduceMotion ? false : achievement.isUnlocked)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("achievement.card.\(achievement.id.rawValue)")
    }
}

private struct ChallengeCard: View {
    let challenge: SunclubSeasonalChallenge
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                SunclubBadgeMedallion(
                    asset: challenge.id.visualAsset,
                    size: 68,
                    isLocked: !challenge.isComplete,
                    tint: challenge.id.badgeTint
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(challenge.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        if challenge.isComplete {
                            AchievementStatusPill(text: "Complete", tint: AppPalette.success)
                        }
                    }

                    Text(challenge.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            MilestoneProgressMeter(
                progress: challenge.progress,
                currentValue: challenge.currentValue,
                targetValue: challenge.targetValue,
                isComplete: challenge.isComplete,
                unit: "days",
                accessibilityID: "challenge.progress.\(challenge.id.rawValue)"
            )

            if challenge.isComplete {
                Button {
                    onShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppPalette.warmGlow.opacity(0.65))
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(challenge.isComplete ? AppPalette.warmGlow.opacity(0.34) : AppPalette.cardFill.opacity(0.76))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(challenge.isComplete ? AppPalette.sun.opacity(0.34) : AppPalette.ink.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AchievementStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct MilestoneProgressMeter: View {
    let progress: Double
    let currentValue: Int
    let targetValue: Int
    let isComplete: Bool
    let unit: String?
    let accessibilityID: String

    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var percent: Int {
        Int((normalizedProgress * 100).rounded())
    }

    private var remainingValue: Int {
        max(targetValue - currentValue, 0)
    }

    private var statusLabel: String {
        if isComplete {
            return "Unlocked"
        }

        let noun = unit.map { " \($0)" } ?? ""
        return "\(remainingValue)\(noun) left"
    }

    private var summaryLabel: String {
        let noun = unit.map { " \($0)" } ?? ""
        return "\(percent)% | \(currentValue)/\(targetValue)\(noun)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(AppPalette.ink.opacity(0.20))

                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isComplete
                                    ? [AppPalette.success, AppPalette.sun]
                                    : [AppPalette.sun, AppPalette.streakAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: filledWidth(in: proxy.size.width))
                }
            }
            .frame(height: 10)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(AppPalette.ink.opacity(0.10), lineWidth: 1)
            }
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(summaryLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("\(accessibilityID).summary")

                Spacer(minLength: 0)

                Text(statusLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isComplete ? AppPalette.success : AppPalette.streakAccent)
                    .accessibilityIdentifier("\(accessibilityID).status")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(summaryLabel), \(statusLabel)")
        .accessibilityIdentifier(accessibilityID)
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        guard normalizedProgress > 0 else { return 0 }
        return max(10, totalWidth * normalizedProgress)
    }
}

private extension SunclubAchievementID {
    var badgeTint: Color {
        switch self {
        case .highUVHero:
            return AppPalette.uvExtreme
        case .streak7, .streak30, .streak100, .streak365:
            return AppPalette.pool
        case .firstBackfill, .winterWarrior:
            return AppPalette.aloe
        case .summerSurvivor, .morningGlow, .weekendCanopy:
            return AppPalette.coral
        default:
            return AppPalette.sun
        }
    }
}

private extension SunclubChallengeID {
    var badgeTint: Color {
        switch self {
        case .summerShield:
            return AppPalette.coral
        case .uvAwarenessWeek:
            return AppPalette.uvExtreme
        case .winterSkin:
            return AppPalette.aloe
        }
    }
}
