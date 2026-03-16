import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var now = Date()

    var body: some View {
        SunLightScreen {
            VStack(spacing: 26) {
                header

                activeProductCard

                Button {
                    router.open(.weeklySummary)
                } label: {
                    streakCard
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.streakCard")

                Spacer(minLength: 340)
            }
        } footer: {
            Button("Verify Now") {
                router.open(.verifyCamera)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .disabled(appState.activeProduct == nil || !appState.hasTrainingData())
            .opacity(appState.activeProduct == nil || !appState.hasTrainingData() ? 0.42 : 1)
            .accessibilityIdentifier("home.verifyNow")
        }
        .onAppear {
            now = Date()
            appState.clearVerificationSuccessPresentation()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Text(greeting)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Image(systemName: greetingSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
            }

            Spacer(minLength: 0)

            Button {
                router.open(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.settingsButton")
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(appState.currentStreak)")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(Color(red: 0.870, green: 0.482, blue: 0.000))

            Text("Day Streak")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppPalette.ink)

            if let product = appState.activeProduct {
                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 1.000, green: 0.947, blue: 0.760))
        )
    }

    private var activeProductCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Product")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(appState.activeProduct?.name ?? "No sunscreen selected")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("home.activeProductName")

            Text(productDetail)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    private var greetingSymbol: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<17:
            return "sun.max"
        default:
            return "moon.stars"
        }
    }

    private var productDetail: String {
        guard let product = appState.activeProduct else {
            return "Add and train a sunscreen bottle in Settings to start verifying."
        }

        if appState.hasTrainingData() {
            return "Ready to verify. \(appState.activeTrainingAssets.count) training photos saved for \(product.name)."
        }

        return "\(product.name) needs training photos before verification."
    }
}
