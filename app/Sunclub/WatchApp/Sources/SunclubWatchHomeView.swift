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

    private var applicationStatus: SunclubApplicationStatus {
        snapshot.applicationStatus()
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var primaryActionTitle: String {
        applicationStatus.isSetupComplete ? applicationStatus.actionTitle : "Open iPhone"
    }

    private var primaryActionSymbol: String {
        applicationStatus.isSetupComplete ? applicationStatus.symbol : "iphone"
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
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        statusCard
                        uvCard
                    }
                }

                logButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
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
        .buttonStyle(.borderedProminent)
        .tint(AppColor.primaryAction)
        .controlSize(.regular)
        .frame(minHeight: 44)
        .disabled(isLogging)
        .accessibilityLabel(primaryActionTitle)
        .accessibilityHint("Uses the current Sunclub next action on your paired iPhone.")
        .accessibilityIdentifier("watch.logSunscreen")
    }

    private var statusCard: some View {
        let now = Date()
        let status = snapshot.applicationStatus(now: now)
        return AppCard(padding: AppSpacing.xxs, fill: watchCardFill, showsShadow: false) {
            VStack(alignment: .leading, spacing: 4) {
                Text(status.title)
                    .font(.caption)
                    .foregroundStyle(watchTextSecondary)

                Group {
                    if !status.isSetupComplete {
                        Text("Finish setup on iPhone")
                            .font(.headline)
                    } else if status.isReapplyDue {
                        Text("Now")
                            .font(.title2.weight(.semibold))
                    } else if let deadline = status.reapplyDeadline {
                        Text(timerInterval: now...max(now, deadline), countsDown: true)
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                    } else if let applied = status.lastAppliedAt {
                        Text(applied, style: .time)
                            .font(.title2.weight(.semibold))
                    }
                }
                .foregroundStyle(watchTextPrimary)

                if status.reapplyDeadline != nil, let applied = status.lastAppliedAt {
                    Text("Applied \(applied, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(watchTextSecondary)
                }

                if let visibleSyncStatus {
                    Text(visibleSyncStatus)
                        .font(.caption)
                        .foregroundStyle(watchTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var uvCard: some View {
        AppCard(padding: AppSpacing.xs, fill: watchCardFill, showsShadow: false) {
            VStack(alignment: .leading, spacing: 7) {
                if applicationStatus.hasLoggedToday, let spf = snapshot.todaySPFLevel {
                    Text("SPF \(spf)")
                        .font(.caption)
                        .foregroundStyle(watchTextSecondary)
                }
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

    private func performPrimaryAction() {
        guard !isLogging else { return }
        let status = applicationStatus
        guard status.isSetupComplete else {
            syncCoordinator.refreshSnapshot()
            return
        }

        isLogging = true
        Task {
            if status.hasLoggedToday {
                _ = await syncCoordinator.logReapply()
            } else {
                _ = await syncCoordinator.logToday()
            }
            isLogging = false
        }
    }
}
