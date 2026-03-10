import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var now = Date()

    private var todayStatus: DayStatus {
        appState.dayStatus(for: Date(), now: now)
    }

    var body: some View {
        SunScreen {
            heroCard
            todayCard

            VStack(alignment: .leading, spacing: 14) {
                SunSectionHeader(
                    eyebrow: "Daily actions",
                    title: "Choose your proof",
                    detail: "All three routes land in the same daily record. Pick the one that matches your current level of sunscreen bureaucracy."
                )

                actionCard(
                    title: "Scan Barcode",
                    detail: "Fastest when the bottle is already in your hand.",
                    systemImage: "barcode.viewfinder",
                    colors: [AppPalette.sun, AppPalette.coral]
                ) {
                    router.open(.barcodeScan)
                }

                actionCard(
                    title: "Take Selfie",
                    detail: "Front camera proof with your bottle visible in frame.",
                    systemImage: "person.crop.square",
                    colors: [AppPalette.sea, AppPalette.mint]
                ) {
                    router.open(.selfie)
                }

                actionCard(
                    title: "Live Video Verify",
                    detail: "Hold still for a moment and let the bottle model do the rest.",
                    systemImage: "video.badge.checkmark",
                    colors: [AppPalette.coral, AppPalette.sun]
                ) {
                    router.open(.videoVerify)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SunSectionHeader(
                    eyebrow: "History",
                    title: "Check the bigger pattern",
                    detail: "Calendar marks misses, weekly report keeps the tone mildly unhinged."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    quickLinkCard(
                        title: "Calendar",
                        detail: "Review every day in the month grid.",
                        systemImage: "calendar"
                    ) {
                        router.open(.calendar)
                    }

                    quickLinkCard(
                        title: "Weekly report",
                        detail: "Seven-day stats and a local pep talk.",
                        systemImage: "chart.bar.xaxis"
                    ) {
                        router.open(.weeklyReport)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            now = Date()
        }
    }

    private var heroCard: some View {
        ViewThatFits {
            HStack(alignment: .top, spacing: 16) {
                heroCopy

                Spacer(minLength: 0)

                heroBadge
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    heroBadge
                    Spacer(minLength: 0)
                }

                heroCopy
            }
        }
        .sunCard()
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's status")
                        .font(.caption)
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(AppPalette.softInk)

                    Text(statusTitle)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.ink)

                    Text(statusDetail)
                        .font(.callout)
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 0)

                Image(systemName: statusSymbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(statusTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(value: "\(appState.currentStreak)", title: "current streak", tint: statusTint)
                MetricTile(value: appState.settings.expectedBarcode == nil ? "Unset" : "Locked", title: "bottle", tint: AppPalette.sea)
                MetricTile(value: "\(appState.trainingAssets.count)", title: "training views", tint: AppPalette.sun)
            }
        }
        .sunCard()
    }

    private var streakLabel: String {
        let streak = appState.currentStreak
        return streak > 0 ? "\(streak) day streak" : "Fresh day"
    }

    private var statusTitle: String {
        switch todayStatus {
        case .applied:
            return "Shielded for today"
        case .todayPending:
            return "Proof still pending"
        case .missed:
            return "Missed day on record"
        case .future:
            return "Future date"
        }
    }

    private var statusDetail: String {
        switch todayStatus {
        case .applied:
            return "You have a verified sunscreen application logged for today."
        case .todayPending:
            return "Pick a proof method below and lock the day in before the sun starts freelancing."
        case .missed:
            return "The calendar already marked the miss. Today is your rebound arc."
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

    private func actionCard(title: String, detail: String, systemImage: String, colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 56, height: 56)

                    Image(systemName: systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.84))
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .padding(18)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: (colors.last ?? AppPalette.coral).opacity(0.20), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private func quickLinkCard(title: String, detail: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppPalette.coral)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.softInk)
            }
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            .sunCard()
        }
        .buttonStyle(.plain)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SunPill(title: "On-device only", systemImage: "lock.shield.fill", tint: AppPalette.sea)
                SunPill(title: streakLabel, systemImage: "flame.fill", tint: AppPalette.coral)
            }

            Text("SunscreenTrack")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundStyle(AppPalette.ink)

            Text("The daily SPF receipt desk. Scan it, selfie it, or hold it up to the camera and make the habit official.")
                .font(.callout)
                .foregroundStyle(AppPalette.softInk)
        }
    }

    private var heroBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppPalette.sun, AppPalette.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 94, height: 94)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: AppPalette.coral.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}
