import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var now = Date()

    var todayStatus: DayStatus {
        appState.dayStatus(for: Date(), now: now)
    }

    var body: some View {
        ZStack {
            SunBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    heroCard
                    statusCard
                    actionSection
                    utilitySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            now = Date()
        }
    }

    private var streakCount: Int {
        appState.currentStreak
    }

    private var streakLabel: String {
        let streak = appState.currentStreak
        return streak > 0 ? "\(streak) day streak" : "Fresh start today"
    }

    private var statusText: String {
        switch todayStatus {
        case .applied:
            return "Shield is up for today"
        case .todayPending:
            return "Today's SPF receipt is still missing"
        case .missed:
            return "Yesterday's sun won on paperwork"
        case .future:
            return "Future day"
        }
    }

    private var statusDetail: String {
        switch todayStatus {
        case .applied:
            return "You have a verified application on the books."
        case .todayPending:
            return "Pick one proof method and lock the day in."
        case .missed:
            return "Let's not let the calendar collect another red mark."
        case .future:
            return "Nothing to do here yet."
        }
    }

    private var statusTint: Color {
        switch todayStatus {
        case .applied:
            return AppPalette.success
        case .todayPending:
            return AppPalette.warning
        case .missed:
            return AppPalette.danger
        case .future:
            return AppPalette.sea
        }
    }

    private var heroCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SunPill(title: "Camera-only habit tracking", systemImage: "sparkles", tint: AppPalette.sun)

                Text("SunscreenTrack")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundStyle(AppPalette.ink)

                Text("Three ways to prove today's SPF happened, zero ways for the cloud to snoop.")
                    .font(.callout)
                    .foregroundStyle(AppPalette.softInk)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.sun, AppPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: AppPalette.coral.opacity(0.22), radius: 18, x: 0, y: 10)
        }
        .sunCard()
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's status")
                        .font(.caption)
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(AppPalette.softInk)

                    Text(statusText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.ink)

                    Text(statusDetail)
                        .font(.callout)
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer()

                Image(systemName: statusSymbol)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(statusTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(spacing: 12) {
                MetricTile(value: "\(streakCount)", title: "current streak", tint: statusTint)
                MetricTile(
                    value: appState.settings.expectedBarcode == nil ? "Unset" : "Locked",
                    title: "bottle",
                    tint: AppPalette.sea
                )
                MetricTile(
                    value: "\(appState.trainingAssets.count)",
                    title: "training shots",
                    tint: AppPalette.sun
                )
            }
        }
        .sunCard()
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose your proof")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppPalette.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                HomeActionCard(
                    title: "Scan Barcode",
                    subtitle: "Fastest route when your bottle is nearby.",
                    icon: "barcode.viewfinder",
                    colors: [AppPalette.sun, AppPalette.coral]
                ) {
                    router.open(.barcodeScan)
                }

                HomeActionCard(
                    title: "Take Selfie",
                    subtitle: "Front camera proof with your bottle in frame.",
                    icon: "person.crop.square",
                    colors: [AppPalette.sea, AppPalette.mint]
                ) {
                    router.open(.selfie)
                }
            }

            HomeActionCard(
                title: "Live Video Verify",
                subtitle: "Hold steady for a couple of seconds and let the model confirm the bottle.",
                icon: "video.badge.checkmark",
                colors: [AppPalette.coral, AppPalette.sun]
            ) {
                router.open(.videoVerify)
            }
        }
    }

    private var utilitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SunPill(title: streakLabel, systemImage: "flame.fill", tint: AppPalette.coral)
                SunPill(title: "Local data only", systemImage: "lock.shield.fill", tint: AppPalette.sea)
            }

            HStack(spacing: 14) {
                utilityCard(
                    title: "Calendar",
                    subtitle: "See the month at a glance.",
                    icon: "calendar"
                ) {
                    router.open(.calendar)
                }

                utilityCard(
                    title: "Weekly report",
                    subtitle: "Stats and a ridiculous pep talk.",
                    icon: "chart.bar.xaxis"
                ) {
                    router.open(.weeklyReport)
                }
            }
        }
    }

    private func utilityCard(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppPalette.coral)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.softInk)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .sunCard()
        }
        .buttonStyle(.plain)
    }

    private var statusSymbol: String {
        switch todayStatus {
        case .applied:
            return "checkmark.seal.fill"
        case .todayPending:
            return "clock.fill"
        case .missed:
            return "exclamationmark.triangle.fill"
        case .future:
            return "sparkles"
        }
    }
}

private struct HomeActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.84))
                }

                Spacer(minLength: 0)

                HStack {
                    Text("Open")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 188, alignment: .topLeading)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: colors.last?.opacity(0.22) ?? .clear, radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}
