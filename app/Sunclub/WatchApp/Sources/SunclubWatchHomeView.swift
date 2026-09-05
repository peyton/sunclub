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
        guard let lastVerifiedAt = snapshot.lastReappliedAt ?? snapshot.lastVerifiedAt else {
            return "Logged"
        }

        return "Applied \(lastVerifiedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var loggedDetailText: String {
        snapshot.todaySPFLevel.map { "SPF \($0)" } ?? "Logged today"
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var primaryAction: HomeDailyPlanAction {
        guard snapshot.isOnboardingComplete else { return .openSettings }
        return snapshot.hasLoggedToday() ? .logReapply : .logToday
    }

    private var primaryActionTitle: String {
        switch primaryAction {
        case .logToday:
            return "Log sunscreen"
        case .logReapply:
            return "Log reapplication"
        case .viewProgress:
            return "Refresh progress"
        default:
            return "Open iPhone"
        }
    }

    private var primaryActionSymbol: String {
        switch primaryAction {
        case .logReapply:
            return "timer"
        case .viewProgress:
            return "arrow.clockwise"
        case .logToday:
            return "sun.max.fill"
        default:
            return "iphone"
        }
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
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        statusCard
                        reapplyCard
                        uvCard
                    }
                }

                logButton
            }
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
                performPrimaryAction()
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
            performPrimaryAction()
        } label: {
            if isLogging {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label(
                    primaryActionTitle,
                    systemImage: primaryActionSymbol
                )
                    .font(AppTextStyle.bodyMedium.font)
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .controlSize(.large)
        .disabled(isLogging)
        .accessibilityLabel(primaryActionTitle)
        .accessibilityHint("Uses the current Sunclub next action on your paired iPhone.")
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
                let now = Date()
                if let currentUVIndex = snapshot.currentUVIndex(at: now) {
                    let level = UVLevel.from(index: currentUVIndex)
                    Text("UV \(currentUVIndex) · \(level.displayName)")
                        .font(AppTextStyle.caption.font)
                        .foregroundStyle(watchTextSecondary)
                    if let peakUVIndex = snapshot.peakUVIndex(at: now),
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
                    if isDue {
                        AppText("Reapply due", style: .bodyMedium, color: watchTextPrimary)
                    } else {
                        Text(timerInterval: Date()...max(Date(), deadline), countsDown: true)
                            .font(AppFont.rounded(size: 24, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(watchTextPrimary)
                    }
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

    private func performPrimaryAction() {
        guard !isLogging else {
            return
        }

        switch primaryAction {
        case .viewProgress, .openSettings, .backfillYesterday, .addDetails, .reviewRecovery, .repairReminders:
            syncCoordinator.refreshSnapshot()
            return
        case .logToday, .logReapply:
            break
        }

        isLogging = true
        Task {
            switch primaryAction {
            case .logReapply:
                _ = await syncCoordinator.logReapply()
            default:
                _ = await syncCoordinator.logToday()
            }
            isLogging = false
        }
    }

}
