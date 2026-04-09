import SwiftUI

struct ReapplyCheckInView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Reapply Check-In", showsBack: true, onBack: {
                    router.goBack()
                })

                if let presentation = appState.reapplyCheckInPresentation {
                    reapplyContent(presentation: presentation)
                } else {
                    fallbackContent
                }

                Spacer(minLength: 0)
            }
        } footer: {
            footerAction
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private func reapplyContent(presentation: ReapplyCheckInPresentation) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(presentation.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text(presentation.detail)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)

            SunStatusCard(
                title: "Lightweight follow-through",
                detail: "This only tracks whether you actually reapplied today. It does not create a second daily streak entry.",
                tint: AppPalette.sun,
                symbol: "arrow.clockwise.circle.fill"
            )
        }
    }

    private var fallbackContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No daily log yet")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)

            Text("Reapply check-ins only make sense after you have logged sunscreen for today. Log today first, then come back here later if you reapply.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
    }

    @ViewBuilder
    private var footerAction: some View {
        if let presentation = appState.reapplyCheckInPresentation {
            Button(presentation.actionTitle) {
                appState.recordReapplication()
                router.goHome()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("reapply.log")
        } else {
            Button("Log Today") {
                router.open(.manualLog)
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("reapply.logTodayFallback")
        }
    }
}

#Preview {
    SunclubPreviewHost {
        ReapplyCheckInView()
    }
}
