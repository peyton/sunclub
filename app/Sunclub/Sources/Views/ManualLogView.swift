import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let context: AppLogContext?

    @State private var targetDate: Date
    @State private var selectedDayPart: DayPart
    @State private var selectedSPF: Int?
    @State private var selectedAreas: Set<String> = SunManualLogInput.defaultCoveredAreas
    @State private var notes: String = ""
    @State private var hasLoadedInitialState = false
    @State private var isShowingWhenEditor = false
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
        if selectedAreas.isEmpty {
            return "Select at least one area."
        }
        return appState.logActionErrorMessage
    }

    private var isSaveDisabled: Bool {
        isFutureTarget || selectedAreas.isEmpty
    }

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(alignment: .leading, spacing: 18) {
                manualLogNavigationHeader

                if let validationMessage {
                    SunStatusCard(
                        title: "Can't save this log yet",
                        detail: validationMessage,
                        tint: AppColor.warning.opacity(0.8),
                        symbol: "exclamationmark.triangle.fill"
                    )
                    .accessibilityIdentifier("manualLog.validation")
                }

                titleBlock

                AppCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 18) {
                        referenceFormRows

                        SunManualLogFields(
                            selectedSPF: $selectedSPF,
                            notes: $notes,
                            selectedAreas: $selectedAreas,
                            accessibilityPrefix: "manualLog",
                            suggestions: appState.manualLogSuggestionState(for: targetDate),
                            showsOptionalDisclosure: false,
                            showsSPFSelector: false,
                            detailsInitiallyExpanded: true
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        } footer: {
            PrimaryButton("Save Log", identifier: "manualLog.logToday", action: saveLog)
                .disabled(isSaveDisabled)
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

    private var manualLogNavigationHeader: some View {
        HStack(alignment: .center) {
            Button("Cancel") {
                router.goBack()
            }
            .font(AppTextStyle.captionMedium.font)
            .foregroundStyle(AppPalette.sun)
            .buttonStyle(.plain)
            .accessibilityIdentifier("screen.back")

            Spacer(minLength: 0)

            Spacer(minLength: 0)

            Button("Save") {
                saveLog()
            }
            .font(AppTextStyle.captionMedium.font)
            .foregroundStyle(isSaveDisabled ? AppPalette.softInk : AppPalette.ink)
            .buttonStyle(.plain)
            .disabled(isSaveDisabled)
            .accessibilityIdentifier("manualLog.saveTop")
        }
        .frame(minHeight: 44)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Log Sunscreen")
                .font(AppFont.rounded(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(whenValue)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.softInk)
                .accessibilityIdentifier("manualLog.timestamp")
        }
    }

    private var referenceFormRows: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(SunMotion.easeInOut(duration: 0.18, reduceMotion: reduceMotion)) {
                    isShowingWhenEditor.toggle()
                }
            } label: {
                referenceFormRowContent(
                    title: "When",
                    value: whenValue,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .disabled(isFutureTarget)
            .accessibilityIdentifier("manualLog.whenRow")

            if isShowingWhenEditor {
                whenEditor
            }

            Divider()
                .overlay(AppPalette.hairlineStroke)

            Menu {
                ForEach(commonSPFLevels, id: \.self) { level in
                    Button("SPF \(level)") {
                        selectedSPF = level
                    }
                }

                if selectedSPF != nil {
                    Button("Clear SPF", role: .destructive) {
                        selectedSPF = nil
                    }
                }
            } label: {
                referenceFormRowContent(
                    title: "SPF",
                    value: selectedSPF.map { "\($0)" } ?? "Choose",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .disabled(isFutureTarget)
            .accessibilityIdentifier("manualLog.spfRow")

            Divider()
                .overlay(AppPalette.hairlineStroke)

            Menu {
                productPresetButton(title: "Sunclub Mineral SPF 50", spf: 50)
                productPresetButton(title: "Sunclub Mineral SPF 30", spf: 30)
                productPresetButton(title: "Sunclub Mineral SPF 70", spf: 70)
            } label: {
                referenceFormRowContent(
                    title: "Product",
                    value: selectedSPF.map { "Sunclub Mineral SPF \($0)" } ?? "Choose product",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .disabled(isFutureTarget)
            .accessibilityIdentifier("manualLog.productRow")
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppPalette.cardFill.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppPalette.hairlineStroke, lineWidth: 1)
        }
        .accessibilityIdentifier("manualLog.referenceRows")
    }

    private var commonSPFLevels: [Int] {
        [15, 30, 50, 70, 100]
    }

    private var whenValue: String {
        if Calendar.current.isDate(targetDate, inSameDayAs: appState.referenceDate) {
            return "Today, \(appState.referenceDate.formatted(date: .omitted, time: .shortened))"
        }
        return "\(targetDate.formatted(.dateTime.month(.abbreviated).day())), \(selectedDayPart.title)"
    }

    private func productPresetButton(title: String, spf: Int) -> some View {
        Button(title) {
            selectedSPF = spf
        }
    }

    private var whenEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker(
                "Date",
                selection: $targetDate,
                in: Date.distantPast...appState.referenceDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(AppTextStyle.captionMedium.font)
            .tint(AppPalette.sun)
            .accessibilityIdentifier("manualLog.datePicker")

            dayPartPicker
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(AppPalette.controlFill.opacity(0.34))
    }

    private func referenceFormRowContent(title: String, value: String, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(AppTextStyle.captionMedium.font)
                .foregroundStyle(AppPalette.ink)

            Spacer(minLength: 8)

            Text(value)
                .font(AppTextStyle.caption.font)
                .foregroundStyle(AppPalette.softInk)
                .multilineTextAlignment(.trailing)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(AppFont.rounded(size: 11, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk.opacity(0.7))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
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
        guard !selectedAreas.isEmpty else {
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
            notes: SunManualLogInput.notesWithCoveredAreas(notes, areas: selectedAreas),
            context: saveContext
        )
        guard didSave else {
            return
        }
        feedbackTrigger += 1
        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        router.open(.home)
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else {
            return
        }

        hasLoadedInitialState = true

        if let existingRecord {
            selectedSPF = existingRecord.spfLevel
            let recordAreas = SunManualLogInput.coveredAreas(in: existingRecord.notes)
            selectedAreas = recordAreas.isEmpty ? SunManualLogInput.defaultCoveredAreas : recordAreas
            notes = SunManualLogInput.notesRemovingCoveredAreas(existingRecord.notes)
            return
        }

        if let manualLogPrefill = appState.manualLogPrefill {
            selectedSPF = manualLogPrefill.spfLevel
            let prefillAreas = SunManualLogInput.coveredAreas(in: manualLogPrefill.notes)
            selectedAreas = prefillAreas.isEmpty ? SunManualLogInput.defaultCoveredAreas : prefillAreas
            notes = SunManualLogInput.notesRemovingCoveredAreas(manualLogPrefill.notes)
            appState.clearManualLogPrefill()
            return
        }

        selectedAreas = SunManualLogInput.defaultCoveredAreas
    }
}

#Preview {
    SunclubPreviewHost {
        ManualLogView()
    }
}
