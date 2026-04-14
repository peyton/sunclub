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
        VStack(alignment: .leading, spacing: 8) {
            header
            logButton

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
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
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.hasLoggedToday() ? "Protected today" : "Still open")
                .font(.headline)
            Text(currentStreak == 1 ? "1 day streak" : "\(currentStreak) day streak")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
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
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.orange)
        .disabled(isLogging)
        .accessibilityLabel(snapshot.hasLoggedToday() ? "Refresh wrist log" : "Log sunscreen")
        .accessibilityHint("Sends today's sunscreen log to your paired iPhone.")
        .accessibilityIdentifier("watch.logSunscreen")
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Today", systemImage: snapshot.hasLoggedToday() ? "checkmark.circle.fill" : "sun.max")
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.hasLoggedToday() ? .green : .orange)

            Text(snapshot.hasLoggedToday() ? "Logged from wrist or phone." : "Button above logs from your wrist.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let syncStatus = syncCoordinator.syncStatus, !syncStatus.isEmpty {
                Text(syncStatus)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var uvCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("UV", systemImage: "sun.max")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let currentUVIndex = snapshot.currentUVIndex {
                Text("Current UV \(currentUVIndex)")
                    .font(.body.weight(.semibold))
                if let peakUVIndex = snapshot.peakUVIndex,
                   let peakUVHour = snapshot.peakUVHour {
                    Text("Peak \(peakUVIndex) at \(peakUVHour.formatted(date: .omitted, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Waiting for iPhone forecast")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var reapplyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Reapply", systemImage: "timer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let deadline = snapshot.reapplyDeadline() {
                Text(deadline > Date() ? "Haptic reminder at \(deadline.formatted(date: .omitted, time: .shortened))" : "Reapply now")
                    .font(.footnote.weight(.medium))
            } else {
                Text("No wrist reminder scheduled")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
