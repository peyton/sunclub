import SwiftUI

struct AchievementsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var shareSheetItem: ShareSheetItem?

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Achievements", showsBack: true, onBack: {
                    router.goBack()
                })

                if let achievementCelebration = appState.achievementCelebration {
                    celebrationCard(for: achievementCelebration)
                }

                achievementsSection
                challengesSection

                Spacer(minLength: 0)
            }
        }
        .sheet(item: $shareSheetItem) { item in
            ActivityShareSheet(items: item.items)
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlock Your Sun Shield")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            ForEach(appState.achievements) { achievement in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: achievement.symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(achievement.isUnlocked ? AppPalette.sun : AppPalette.muted)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(achievement.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppPalette.ink)

                            Text(achievement.detail)
                                .font(.system(size: 14))
                                .foregroundStyle(AppPalette.softInk)
                        }

                        Spacer(minLength: 0)
                    }

                    ProgressView(value: achievement.progress)
                        .tint(achievement.isUnlocked ? AppPalette.sun : AppPalette.muted)

                    HStack {
                        Text("\(achievement.currentValue)/\(achievement.targetValue)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)

                        Spacer(minLength: 0)

                        if achievement.isUnlocked {
                            Button("Share") {
                                shareAchievement(achievement)
                            }
                            .buttonStyle(SunSecondaryButtonStyle())
                        }
                    }
                }
                .padding(18)
                .background(cardBackground)
            }
        }
    }

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seasonal Challenges")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            ForEach(appState.seasonalChallenges) { challenge in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(challenge.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppPalette.ink)

                            Text(challenge.detail)
                                .font(.system(size: 14))
                                .foregroundStyle(AppPalette.softInk)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: challenge.symbolName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(challenge.isComplete ? AppPalette.sun : AppPalette.softInk)
                    }

                    ProgressView(value: challenge.progress)
                        .tint(challenge.isComplete ? AppPalette.sun : AppPalette.ink.opacity(0.35))

                    HStack {
                        Text("\(challenge.currentValue)/\(challenge.targetValue) days")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)

                        Spacer(minLength: 0)

                        if challenge.isComplete {
                            Button("Share") {
                                shareChallenge(challenge)
                            }
                            .buttonStyle(SunSecondaryButtonStyle())
                        }
                    }
                }
                .padding(18)
                .background(cardBackground)
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
    }

    private func shareAchievement(_ achievement: SunclubAchievement) {
        guard let artifact = try? appState.achievementArtifact(for: achievement) else {
            return
        }
        shareSheetItem = ShareSheetItem(items: [artifact.fileURL])
    }

    private func shareChallenge(_ challenge: SunclubSeasonalChallenge) {
        guard let artifact = try? appState.challengeArtifact(for: challenge) else {
            return
        }
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
