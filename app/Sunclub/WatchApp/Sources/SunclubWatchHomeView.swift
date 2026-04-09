import SwiftUI

struct SunclubWatchHomeView: View {
    @State private var syncCoordinator = SunclubWatchSyncCoordinator.shared
    @State private var isLogging = false

    private var snapshot: SunclubWidgetSnapshot {
        syncCoordinator.snapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                statusCard
                uvCard
                reapplyCard

                Button {
                    logFromWrist()
                } label: {
                    if isLogging {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(snapshot.hasLoggedToday() ? "Refresh Wrist Log" : "Log Sunscreen", systemImage: "sun.max.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isLogging)
            }
            .padding()
        }
        .navigationTitle("Sunclub")
        .onAppear {
            syncCoordinator.refreshSnapshot()
        }
        .onOpenURL { url in
            guard url.host == "watch", url.path == "/log" else {
                return
            }
            logFromWrist()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.hasLoggedToday() ? "Protected today" : "Still open today")
                .font(.headline)
            Text("\(snapshot.currentStreak)-day streak")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Today", systemImage: snapshot.hasLoggedToday() ? "checkmark.circle.fill" : "sun.max")
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.hasLoggedToday() ? .green : .orange)

            Text(snapshot.hasLoggedToday() ? "Logged from your wrist or phone." : "Tap once to log sunscreen from your wrist.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let syncStatus = syncCoordinator.syncStatus, !syncStatus.isEmpty {
                Text(syncStatus)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
