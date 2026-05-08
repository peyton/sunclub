import SwiftUI

struct SunclubWatchHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var syncCoordinator = SunclubWatchSyncCoordinator.shared
    @State private var isLogging = false

    private var snapshot: SunclubWidgetSnapshot {
        syncCoordinator.snapshot
    }

    private var visibleSyncStatus: String? {
        guard let syncStatus = syncCoordinator.syncStatus?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !syncStatus.isEmpty else {
            return nil
        }

        switch syncStatus {
        case "Snapshot refreshed.", "Status updated.":
            return nil
        default:
            return syncStatus
        }
    }

    private var loggedStatusText: String {
        guard let lastVerifiedAt = snapshot.lastVerifiedAt else {
            return "Logged"
        }

        return "Logged \(lastVerifiedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var loggedDetailText: String {
        snapshot.todaySPFLevel.map { "SPF \($0)" } ?? "Logged today"
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var watchBackground: Color {
        isDarkMode ? AppColor.Watch.background : AppColor.background
    }

    private var watchCardFill: Color {
        isDarkMode ? AppColor.Watch.surface : AppColor.surfaceElevated
    }

    private var watchTextPrimary: Color {
        isDarkMode ? AppColor.Watch.textPrimary : AppColor.Text.primary
    }

    private var watchTextSecondary: Color {
        isDarkMode ? AppColor.Watch.textSecondary : AppColor.Text.secondary
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            watchBackground.ignoresSafeArea()
        }
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
            AppText("Sunclub", style: .captionMedium, color: AppColor.sun)
            Spacer(minLength: 0)
            AppText(
                Date().formatted(date: .omitted, time: .shortened),
                style: .caption,
                color: watchTextSecondary
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
                Label(
                    snapshot.hasLoggedToday() ? "Update log" : "Log sunscreen",
                    systemImage: "sun.max.fill"
                )
                    .font(AppTextStyle.bodyMedium.font)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .controlSize(.large)
        .disabled(isLogging)
        .accessibilityLabel(
            snapshot.hasLoggedToday() ? "Update today's sunscreen log" : "Log sunscreen"
        )
        .accessibilityHint("Saves today's sunscreen log on your paired iPhone.")
        .accessibilityIdentifier("watch.logSunscreen")
    }

    private var statusCard: some View {
        AppCard(padding: AppSpacing.xs, fill: watchCardFill, showsShadow: false) {
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    snapshot.hasLoggedToday() ? "Logged" : "Log sunscreen",
                    systemImage: snapshot.hasLoggedToday() ? "checkmark.circle.fill" : "sun.max"
                )
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(snapshot.hasLoggedToday() ? AppColor.success : AppColor.sun)

                AppText(
                    snapshot.hasLoggedToday() ? "\(loggedStatusText) · \(loggedDetailText)" : "Not logged",
                    style: .caption,
                    color: watchTextSecondary
                )

                if let visibleSyncStatus {
                    AppText(visibleSyncStatus, style: .captionMedium, color: AppColor.accent)
                }
            }
        }
    }

    private var uvCard: some View {
        AppCard(padding: AppSpacing.xs, fill: watchCardFill, showsShadow: false) {
            VStack(alignment: .leading, spacing: 7) {
                if let currentUVIndex = snapshot.currentUVIndex {
                    let level = UVLevel.from(index: currentUVIndex)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        AppText("\(currentUVIndex)", style: .largeTitle, color: watchTint(for: level))
                        VStack(alignment: .leading, spacing: 2) {
                            AppText("UV", style: .captionMedium, color: watchTextPrimary)
                            AppText(
                                level.displayName,
                                style: .caption,
                                color: watchTextSecondary
                            )
                        }
                    }
                    if let peakUVIndex = snapshot.peakUVIndex,
                       let peakUVHour = snapshot.peakUVHour {
                        AppText(
                            "Peak \(peakUVIndex) at \(peakUVHour.formatted(date: .omitted, time: .shortened))",
                            style: .caption,
                            color: watchTextSecondary
                        )
                    }
                } else {
                    AppText("Open iPhone for forecast", style: .caption, color: watchTextSecondary)
                }
            }
        }
    }

    private var reapplyCard: some View {
        AppCard(padding: AppSpacing.xs, fill: watchCardFill, showsShadow: false) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Reapply", systemImage: "timer")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppColor.sun)

                if let deadline = snapshot.reapplyDeadline() {
                    let isDue = deadline <= Date()
                    AppText(
                        isDue
                            ? "Reapply due"
                            : "Reapply in \(durationLabel(until: deadline, now: Date()))",
                        style: .captionMedium,
                        color: isDue ? AppColor.warning : watchTextSecondary
                    )
                } else {
                    AppText(
                        snapshot.hasLoggedToday() ? "No timer" : "Log to time reapply",
                        style: .caption,
                        color: watchTextSecondary
                    )
                }
            }
        }
    }

    private func watchTint(for level: UVLevel) -> Color {
        switch level {
        case .low:
            return AppColor.success
        case .moderate, .high:
            return AppColor.sun
        case .veryHigh:
            return AppColor.warning
        case .extreme:
            return AppColor.Watch.extreme
        case .unknown:
            return watchTextSecondary
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

    private func durationLabel(until deadline: Date, now: Date) -> String {
        let minutesUntilDeadline = max(1, Int(ceil(deadline.timeIntervalSince(now) / 60)))
        let hours = minutesUntilDeadline / 60
        let minutes = minutesUntilDeadline % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(minutes)m"
        }
    }
}
