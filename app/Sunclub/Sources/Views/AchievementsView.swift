import SwiftUI

struct AchievementsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var shareSheetItem: ShareSheetItem?
    @State private var feedbackTrigger = 0

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Achievements", showsBack: true, onBack: {
                    router.goBack()
                })

                if let achievementCelebration = appState.achievementCelebration {
                    celebrationCard(for: achievementCelebration)
                }

                SunAssetHero(
                    asset: .illustrationAchievementsShelf,
                    height: 156,
                    glowColor: AppPalette.coral
                )

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

            ForEach(appState.achievements) { achievement in
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

            ForEach(appState.seasonalChallenges) { challenge in
                ChallengeCard(challenge: challenge) {
                    shareChallenge(challenge)
                }
            }
        }
    }

    private func celebrationCard(for achievement: SunclubAchievement) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("New Badge", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)

                Spacer(minLength: 0)

                Button("Dismiss") {
                    feedbackTrigger += 1
                    appState.markAchievementCelebrationSeen()
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppPalette.softInk)
            }

            Text(achievement.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text(achievement.detail)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppPalette.warmGlow.opacity(0.45))
        )
        .overlay(alignment: .topTrailing) {
            SunclubVisualBadge(asset: achievement.id.visualAsset, size: 66)
                .offset(x: -14, y: 14)
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
            .fill(Color.white.opacity(0.72))
    }
}

#Preview {
    SunclubPreviewHost {
        AchievementsView()
    }
}

private struct AchievementCard: View {
    let achievement: SunclubAchievement
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                SunclubVisualBadge(
                    asset: achievement.id.visualAsset,
                    size: 52,
                    isLocked: !achievement.isUnlocked
                )

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(achievement.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppPalette.ink)

                        Spacer(minLength: 0)

                        if achievement.isUnlocked {
                            Text("Unlocked")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(AppPalette.success)
                                )
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
                .fill(achievement.isUnlocked ? AppPalette.warmGlow.opacity(0.38) : Color.white.opacity(0.78))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(achievement.isUnlocked ? AppPalette.sun.opacity(0.34) : AppPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .symbolEffect(.bounce, value: achievement.isUnlocked)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("achievement.card.\(achievement.id.rawValue)")
    }
}

private struct ChallengeCard: View {
    let challenge: SunclubSeasonalChallenge
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(challenge.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(challenge.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 0)

                SunclubVisualBadge(
                    asset: challenge.id.visualAsset,
                    size: 50,
                    isLocked: !challenge.isComplete
                )
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
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.76))
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
            .frame(height: 14)
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(AppPalette.ink.opacity(0.22), lineWidth: 1)
            }
            .accessibilityHidden(true)

            HStack(spacing: 10) {
                Text(summaryLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(AppPalette.ink)
                    )
                    .accessibilityIdentifier("\(accessibilityID).summary")

                Spacer(minLength: 0)

                Text(statusLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isComplete ? AppPalette.success : AppPalette.streakAccent)
                    .accessibilityIdentifier("\(accessibilityID).status")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID)
    }

    private func filledWidth(in totalWidth: CGFloat) -> CGFloat {
        guard normalizedProgress > 0 else { return 0 }
        return max(10, totalWidth * normalizedProgress)
    }
}
