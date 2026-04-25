import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

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
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "Log Sunscreen", showsBack: true, onBack: {
                    router.goBack()
                })

                SunScreenTitleBlock(
                    eyebrow: targetDate.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                    title: existingRecord == nil ? "Ready to log" : "Update this log",
                    detail: existingRecord == nil
                        ? "Save the day now. Add SPF or a note if it helps."
                        : "Adjust timing, SPF, or notes before saving.",
                    symbolName: existingRecord == nil ? "sun.max.fill" : "checkmark.circle.fill",
                    tint: existingRecord == nil ? AppPalette.sun : AppPalette.success
                )

                if let validationMessage {
                    SunStatusCard(
                        title: "Can't save this log yet",
                        detail: validationMessage,
                        tint: AppColor.warning.opacity(0.8),
                        symbol: "exclamationmark.triangle.fill"
                    )
                    .accessibilityIdentifier("manualLog.validation")
                }

                if let existingRecord {
                    SunStatusCard(
                        title: "Logged at \(existingRecord.verifiedAt.formatted(date: .omitted, time: .shortened))",
                        detail: "Sunclub keeps one entry for this day. Save here to update it.",
                        tint: AppPalette.success,
                        symbol: "checkmark.circle.fill"
                    )
                }

                AppCard(padding: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: 20) {
                        dayPartPicker

                        SunManualLogFields(
                            selectedSPF: $selectedSPF,
                            notes: $notes,
                            accessibilityPrefix: "manualLog",
                            suggestions: appState.manualLogSuggestionState(for: targetDate),
                            showsOptionalDisclosure: true,
                            detailsInitiallyExpanded: false
                        )
                    }
                }

                if !isFutureTarget {
                    scanSPFButton
                }

                Spacer(minLength: 0)
            }
        } footer: {
            PrimaryButton(primaryActionTitle, systemImage: "sun.max", identifier: "manualLog.logToday", action: saveLog)
                .disabled(isFutureTarget)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Timing")
                .font(AppTypography.sectionLabel)
                .foregroundStyle(AppPalette.softInk)

            Picker("Day Part", selection: $selectedDayPart) {
                ForEach(DayPart.logPickerParts(including: selectedDayPart)) { dayPart in
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
                Image(systemName: "camera.viewfinder")
                    .font(AppFont.rounded(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)
                    .frame(width: 34, height: 34)
                    .background(AppPalette.warmGlow.opacity(0.45), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan bottle SPF")
                        .font(AppFont.rounded(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text("Read a label and confirm before using it.")
                        .font(AppFont.rounded(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .fill(AppPalette.cardFill.opacity(0.72))
                    .appShadow(AppShadow.soft)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppPalette.cardStroke, lineWidth: 1)
            }
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
