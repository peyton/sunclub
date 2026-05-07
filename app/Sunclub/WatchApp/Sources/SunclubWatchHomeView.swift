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

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    uvCard
                    statusCard
                    reapplyCard
                }
            }

            logButton
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
        HStack(alignment: .firstTextBaseline) {
            AppText("sunclub", style: .captionMedium, color: AppColor.sun)
            Spacer(minLength: 0)
            AppText(Date().formatted(date: .omitted, time: .shortened), style: .caption, color: AppColor.surfaceElevated)
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
        AppCard(padding: AppSpacing.xs, fill: AppColor.Text.primary, showsShadow: false) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Today", systemImage: snapshot.hasLoggedToday() ? "checkmark.circle.fill" : "sun.max")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(snapshot.hasLoggedToday() ? AppColor.success : AppColor.accent)

                AppText(
                    snapshot.hasLoggedToday() ? "Logged from wrist or phone." : "Use the button below to log.",
                    style: .caption,
                    color: AppColor.surfaceElevated
                )

                if let syncStatus = syncCoordinator.syncStatus, !syncStatus.isEmpty {
                    AppText(syncStatus, style: .captionMedium, color: AppColor.sunSoft)
                }
            }
        }
    }

    private var uvCard: some View {
        AppCard(padding: AppSpacing.xs, fill: AppColor.Text.primary, showsShadow: false) {
            VStack(alignment: .leading, spacing: 7) {
                if let currentUVIndex = snapshot.currentUVIndex {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        AppText("\(currentUVIndex)", style: .largeTitle, color: AppColor.sun)
                        VStack(alignment: .leading, spacing: 2) {
                            AppText("UV Index", style: .captionMedium, color: AppColor.surfaceElevated)
                            AppText(UVLevel.from(index: currentUVIndex).displayName, style: .caption, color: AppColor.sunSoft)
                        }
                    }
                    if let peakUVIndex = snapshot.peakUVIndex,
                       let peakUVHour = snapshot.peakUVHour {
                        AppText(
                            "Peak \(peakUVIndex) at \(peakUVHour.formatted(date: .omitted, time: .shortened))",
                            style: .caption,
                            color: AppColor.surfaceElevated
                        )
                    }
                } else {
                    AppText("Waiting for iPhone forecast", style: .caption, color: AppColor.surfaceElevated)
                }
            }
        }
    }

    private var reapplyCard: some View {
        AppCard(padding: AppSpacing.xs, fill: AppColor.Text.primary, showsShadow: false) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Reapply", systemImage: "timer")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppColor.sunSoft)

                if let deadline = snapshot.reapplyDeadline() {
                    AppText(
                        deadline > Date() ? "Haptic reminder at \(deadline.formatted(date: .omitted, time: .shortened))" : "Reapply now",
                        style: .captionMedium,
                        color: AppColor.surfaceElevated
                    )
                } else {
                    AppText("No wrist reminder scheduled", style: .caption, color: AppColor.surfaceElevated)
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
