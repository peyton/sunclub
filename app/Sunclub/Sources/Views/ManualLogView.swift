import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var referenceDate = Date()
    @State private var selectedSPF: Int?
    @State private var notes: String = ""
    @State private var hasLoadedInitialState = false
    @State private var feedbackTrigger = 0
    @State private var navigationFeedbackTrigger = 0

    private var existingRecord: DailyRecord? {
        appState.record(for: referenceDate)
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Log Sunscreen", showsBack: true, onBack: {
                    router.goBack()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text(existingRecord == nil ? "Ready to save today" : "Update this log")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(
                        existingRecord == nil
                            ? "SPF and notes can be added now or later."
                            : "SPF and notes can be changed before saving."
                    )
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }

                SunAssetHero(
                    asset: .illustrationLogBottle,
                    height: heroHeight,
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

                SunManualLogFields(
                    selectedSPF: $selectedSPF,
                    notes: $notes,
                    accessibilityPrefix: "manualLog",
                    suggestions: appState.manualLogSuggestionState(for: referenceDate),
                    detailsInitiallyExpanded: existingRecord != nil || appState.manualLogPrefill != nil
                )

                scanSPFButton

                Spacer(minLength: 0)
            }
        } footer: {
            Button(primaryActionTitle, action: logToday)
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("manualLog.logToday")
        }
        .onAppear {
            referenceDate = appState.referenceDate
            syncInitialStateIfNeeded()
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
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

    private var heroHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 80 : 112
    }

    private var scanSPFButton: some View {
        Button {
            navigationFeedbackTrigger += 1
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
                    Text("Scan Bottle SPF")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Read a label and confirm before using it.")
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
