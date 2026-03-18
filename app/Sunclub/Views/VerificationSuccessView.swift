import SwiftUI

struct VerificationSuccessView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    private var presentation: VerificationSuccessPresentation {
        appState.verificationSuccessPresentation
            ?? VerificationSuccessPresentation(streak: appState.currentStreak)
    }

    var body: some View {
        SunLightScreen {
            VStack(spacing: 28) {
                Spacer(minLength: 120)

                Circle()
                    .fill(AppPalette.success)
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Text("Logged")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("success.title")

                    Text(presentation.detail)
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 300)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            Button("Done") {
                appState.clearVerificationSuccessPresentation()
                router.goHome()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("success.done")
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SunclubPreviewHost(scenario: .verificationSuccess) {
        VerificationSuccessView()
    }
}
