import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var selectedSPF: Int?
    @State private var notes: String = ""
    @State private var hasLoadedInitialState = false
    @State private var feedbackTrigger = 0

    private var existingRecord: DailyRecord? {
        appState.record(for: Date())
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Today's Log", showsBack: true, onBack: {
                    router.goBack()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text(existingRecord == nil ? "Log today" : "Update today's log")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(
                        existingRecord == nil
                            ? "Tap Log Today now, or add optional SPF and notes first."
                            : "You're editing today's entry. Update the SPF or note below."
                    )
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }

                SunAssetHero(
                    asset: .illustrationLogBottle,
                    height: 154,
                    glowColor: AppPalette.aloe
                )
                .accessibilityLabel("Sunscreen bottle")

                if let existingRecord {
                    SunStatusCard(
                        title: "Logged at \(existingRecord.verifiedAt.formatted(date: .omitted, time: .shortened))",
                        detail: "Sunclub keeps one entry for today. Save here to update it.",
                        tint: AppPalette.success,
                        symbol: "checkmark.circle.fill"
                    )
                }

                scanSPFButton

                SunManualLogFields(
                    selectedSPF: $selectedSPF,
                    notes: $notes,
                    accessibilityPrefix: "manualLog",
                    suggestions: appState.manualLogSuggestionState(for: Date()),
                    detailsInitiallyExpanded: existingRecord != nil || appState.manualLogPrefill != nil
                )

                Spacer(minLength: 0)
            }
        } footer: {
            Button(primaryActionTitle, action: logToday)
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("manualLog.logToday")
        }
        .onAppear(perform: syncInitialStateIfNeeded)
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private func logToday() {
        feedbackTrigger += 1
        appState.recordVerificationSuccess(
            method: .manual,
            verificationDuration: nil,
            spfLevel: selectedSPF,
            notes: notes
        )
        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        router.open(.verifySuccess)
    }

    private var primaryActionTitle: String {
        existingRecord == nil ? "Log Today" : "Update Today"
    }

    private var scanSPFButton: some View {
        Button {
            feedbackTrigger += 1
            router.push(.productScanner)
        } label: {
            HStack(spacing: 12) {
                SunclubVisualAsset.illustrationScannerLabel.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan SPF")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Optional. Read a bottle label and confirm before using it.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(18)
            .sunGlassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the SPF scanner.")
        .accessibilityIdentifier("manualLog.scanSPF")
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else {
            return
        }

        hasLoadedInitialState = true

        if let existingRecord {
            selectedSPF = existingRecord.spfLevel
            notes = existingRecord.notes ?? ""
            return
        }

        if let manualLogPrefill = appState.manualLogPrefill {
            selectedSPF = manualLogPrefill.spfLevel
            notes = manualLogPrefill.notes
            appState.clearManualLogPrefill()
            return
        }
    }
}

#Preview {
    SunclubPreviewHost {
        ManualLogView()
    }
}
