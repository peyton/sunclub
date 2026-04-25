import SwiftUI

struct SunclubWatchHomeView: View {
    @State private var syncCoordinator = SunclubWatchSyncCoordinator.shared
    @State private var isLogging = false

    private var snapshot: SunclubWidgetSnapshot {
        syncCoordinator.snapshot
    }

    private var currentStreak: Int {
        snapshot.streakValue()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            header
            logButton

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    statusCard
                    uvCard
                    reapplyCard
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .navigationTitle("Sunclub")
        .onAppear {
            syncCoordinator.refreshSnapshot()
        }
        .onOpenURL { url in
            guard url.host == "watch" else {
                return
            }

            switch url.path {
            case "/log":
                logFromWrist()
            case "/open":
                syncCoordinator.refreshSnapshot()
            default:
                return
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            AppText(
                snapshot.hasLoggedToday() ? "Applied" : "Open",
                style: .sectionHeader,
                color: AppColor.surfaceElevated
            )
            AppText(
                currentStreak == 1 ? "1 day streak" : "\(currentStreak) day streak",
                style: .captionMedium,
                color: AppColor.accent
            )
        }
    }

    private var logButton: some View {
        Button {
            logFromWrist()
        } label: {
            if isLogging {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label(snapshot.hasLoggedToday() ? "Refresh Log" : "Log Sunscreen", systemImage: "sun.max.fill")
                    .font(AppTextStyle.bodyMedium.font)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .controlSize(.large)
        .disabled(isLogging)
        .accessibilityLabel(snapshot.hasLoggedToday() ? "Refresh wrist log" : "Log sunscreen")
        .accessibilityHint("Sends today's sunscreen log to your paired iPhone.")
        .accessibilityIdentifier("watch.logSunscreen")
    }

    private var statusCard: some View {
        AppCard(padding: AppSpacing.xs, showsShadow: false) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Today", systemImage: snapshot.hasLoggedToday() ? "checkmark.circle.fill" : "sun.max")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(snapshot.hasLoggedToday() ? AppColor.success : AppColor.accent)

                AppText(
                    snapshot.hasLoggedToday() ? "Logged from wrist or phone." : "Button above logs from your wrist.",
                    style: .caption,
                    color: AppColor.Text.secondary
                )

                if let syncStatus = syncCoordinator.syncStatus, !syncStatus.isEmpty {
                    AppText(syncStatus, style: .captionMedium, color: AppColor.Text.secondary)
                }
            }
        }
    }

    private var uvCard: some View {
        AppCard(padding: AppSpacing.xs, showsShadow: false) {
            VStack(alignment: .leading, spacing: 6) {
                Label("UV", systemImage: "sun.max")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppColor.Text.secondary)

                if let currentUVIndex = snapshot.currentUVIndex {
                    AppText("Current UV \(currentUVIndex)", style: .bodyMedium)
                    if let peakUVIndex = snapshot.peakUVIndex,
                       let peakUVHour = snapshot.peakUVHour {
                        AppText(
                            "Peak \(peakUVIndex) at \(peakUVHour.formatted(date: .omitted, time: .shortened))",
                            style: .caption,
                            color: AppColor.Text.secondary
                        )
                    }
                } else {
                    AppText("Waiting for iPhone forecast", style: .caption, color: AppColor.Text.secondary)
                }
            }
        }
    }

    private var reapplyCard: some View {
        AppCard(padding: AppSpacing.xs, showsShadow: false) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Reapply", systemImage: "timer")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppColor.Text.secondary)

                if let deadline = snapshot.reapplyDeadline() {
                    AppText(
                        deadline > Date() ? "Haptic reminder at \(deadline.formatted(date: .omitted, time: .shortened))" : "Reapply now",
                        style: .captionMedium
                    )
                } else {
                    AppText("No wrist reminder scheduled", style: .caption, color: AppColor.Text.secondary)
                }
            }
        }
    }

    private func logFromWrist() {
        guard !isLogging else {
            return
        }

        isLogging = true
        Task {
            _ = await syncCoordinator.logToday()
            isLogging = false
        }
    }
}
