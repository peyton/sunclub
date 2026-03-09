import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var now = Date()

    var todayStatus: DayStatus {
        appState.dayStatus(for: Date(), now: now)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text("SunscreenTrack")
                        .font(.largeTitle)
                        .bold()
                    Text("Daily sunscreen tracker for this device")
                        .foregroundStyle(.secondary)
                }

                statusCard

                VStack(spacing: 10) {
                    Text("Today's action")
                        .font(.headline)

                    VStack(spacing: 10) {
                        actionButton(title: "Scan Barcode", icon: "barcode.viewfinder", route: .barcodeScan)
                        actionButton(title: "Take Selfie", icon: "person.fill.viewfinder", route: .selfie)
                        actionButton(title: "Live Video Verify", icon: "video", route: .videoVerify)
                    }

                    HStack {
                        Button("Calendar") { router.open(.calendar) }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)

                        Button("Weekly Report") { router.open(.weeklyReport) }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }

                if let streakText = streakLabel {
                    Text(streakText)
                        .font(.headline)
                }

                Spacer(minLength: 30)
            }
            .padding()
        }
        .onAppear {
            now = Date()
        }
    }

    private var streakLabel: String? {
        let streak = appState.currentStreak
        return streak > 0 ? "Current streak: \(streak) day(s)" : nil
    }

    private var statusCard: some View {
        let statusText: String
        let color: Color

        switch todayStatus {
        case .applied:
            statusText = "Applied today"
            color = .green
        case .todayPending:
            statusText = "Not yet applied today"
            color = .orange
        case .missed:
            statusText = "Missed today"
            color = .red
        case .future:
            statusText = ""
            color = .clear
        }

        return RoundedRectangle(cornerRadius: 16)
            .fill(color.opacity(0.15))
            .overlay(
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(color)
                    .padding(.vertical, 20)
            )
            .frame(maxWidth: .infinity)
    }

    private func actionButton(title: String, icon: String, route: AppRoute) -> some View {
        Button {
            router.open(route)
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .bold()
                Spacer()
                Image(systemName: "chevron.right")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(0.15))
            .cornerRadius(12)
        }
    }
}
