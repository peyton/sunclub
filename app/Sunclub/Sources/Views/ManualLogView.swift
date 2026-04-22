import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let context: AppLogContext?

    @State private var targetDate: Date
    @State private var selectedDayPart: DayPart
    @State private var selectedSPF: Int?
    @State private var notes: String = ""
    @State private var hasLoadedInitialState = false
    @State private var feedbackTrigger = 0
    @State private var navigationFeedbackTrigger = 0

    init(context: AppLogContext? = nil) {
        self.context = context
        _targetDate = State(initialValue: context?.date ?? Date())
        _selectedDayPart = State(initialValue: context?.dayPart ?? .morning)
    }

    private var existingRecord: DailyRecord? {
        appState.record(for: targetDate)
    }

    private var isFutureTarget: Bool {
        !appState.canLog(on: targetDate)
    }

    private var validationMessage: String? {
        if isFutureTarget {
            return "Cannot log future date. Pick today or an earlier day."
        }
        return appState.logActionErrorMessage
    }

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 26) {
                SunLightHeader(title: "Log Sunscreen", showsBack: true, onBack: {
                    router.goBack()
                })

                VStack(alignment: .leading, spacing: 10) {
                    Text(existingRecord == nil ? "Ready to save \(selectedDayPart.title.lowercased())" : "Update this \(selectedDayPart.title.lowercased()) log")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(targetDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)

                    Text(
                        existingRecord == nil
                            ? "SPF and notes can be added now or later."
                            : "SPF and notes can be changed before saving."
                    )
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }

                if let validationMessage {
                    SunStatusCard(
                        title: "Can't save this log yet",
                        detail: validationMessage,
                        tint: Color.red.opacity(0.8),
                        symbol: "exclamationmark.triangle.fill"
                    )
                    .accessibilityIdentifier("manualLog.validation")
                }

                dayPartPicker

                SunAssetHero(
                    asset: .illustrationLogBottle,
                    height: heroHeight,
                    glowColor: AppPalette.aloe
                )
                .accessibilityLabel("Sunscreen bottle")

                if let existingRecord {
                    SunStatusCard(
                        title: "Logged at \(existingRecord.verifiedAt.formatted(date: .omitted, time: .shortened))",
                        detail: "Sunclub keeps one entry for this day. Save here to update it.",
                        tint: AppPalette.success,
                        symbol: "checkmark.circle.fill"
                    )
                }

                SunManualLogFields(
                    selectedSPF: $selectedSPF,
                    notes: $notes,
                    accessibilityPrefix: "manualLog",
                    suggestions: appState.manualLogSuggestionState(for: targetDate),
                    detailsInitiallyExpanded: existingRecord != nil || appState.manualLogPrefill != nil
                )

                if !isFutureTarget {
                    scanSPFButton
                }

                Spacer(minLength: 0)
            }
        } footer: {
            Button(primaryActionTitle, action: saveLog)
                .buttonStyle(SunPrimaryButtonStyle())
                .disabled(isFutureTarget)
                .accessibilityIdentifier("manualLog.logToday")
        }
        .onAppear {
            applyResolvedContext()
            syncInitialStateIfNeeded()
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var dayPartPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Day Part")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Picker("Day Part", selection: $selectedDayPart) {
                ForEach(DayPart.allCases) { dayPart in
                    Text(dayPart.title).tag(dayPart)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isFutureTarget)
            .accessibilityIdentifier("manualLog.dayPartPicker")
        }
    }

    private func applyResolvedContext() {
        let resolved = context ?? appState.currentLogContext(for: appState.selectedDay, source: .manualLog)
        targetDate = appState.startOfLocalDay(resolved.date)
        selectedDayPart = resolved.dayPart
        appState.clearLogActionError()
    }

    private func saveLog() {
        guard !isFutureTarget else {
            appState.prepareManualLogRouteContext(
                targetDate: targetDate,
                targetDayPart: selectedDayPart,
                source: .manualLog
            )
            return
        }

        let saveContext = AppLogContext(
            date: targetDate,
            dayPart: selectedDayPart,
            source: context?.source ?? .manualLog
        )
        let didSave = appState.recordVerificationSuccess(
            method: .manual,
            verificationDuration: nil,
            spfLevel: selectedSPF,
            notes: notes,
            context: saveContext
        )
        guard didSave else {
            return
        }
        feedbackTrigger += 1
        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        router.open(.verifySuccess)
    }

    private var primaryActionTitle: String {
        let verb = existingRecord == nil ? "Log" : "Update"
        return "\(verb) \(selectedDayPart.title)"
    }

    private var heroHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 80 : 112
    }

    private var scanSPFButton: some View {
        Button {
            navigationFeedbackTrigger += 1
            appState.prepareManualLogRouteContext(
                targetDate: targetDate,
                targetDayPart: selectedDayPart,
                source: .manualLog
            )
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
