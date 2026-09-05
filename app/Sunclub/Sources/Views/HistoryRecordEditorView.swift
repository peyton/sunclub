import SwiftUI

struct HistoryRecordEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let existingRecord: DailyRecord?
    let route: AppRoute?
    let targetContext: AppLogContext?
    let prefill: ManualLogPrefill?
    let accessibilityPrefix: String

    @State private var selectedSPF: Int?
    @State private var selectedAreas: Set<String>
    @State private var notes: String
    @State private var selectedTimestamp: Date
    @State private var hasLoadedInitialState = false
    @State private var hasSaved = false

    init(
        day: Date,
        existingRecord: DailyRecord?,
        route: AppRoute? = nil,
        targetContext: AppLogContext? = nil,
        prefill: ManualLogPrefill? = nil,
        accessibilityPrefix: String = "historyEditor"
    ) {
        self.day = targetContext?.date ?? day
        self.existingRecord = existingRecord
        self.route = route
        self.targetContext = targetContext
        self.prefill = prefill
        self.accessibilityPrefix = accessibilityPrefix
        _selectedSPF = State(initialValue: existingRecord?.spfLevel)
        _selectedAreas = State(initialValue: SunManualLogInput.coveredAreas(in: existingRecord?.notes))
        _notes = State(initialValue: SunManualLogInput.notesRemovingCoveredAreas(existingRecord?.notes))
        _selectedTimestamp = State(initialValue: existingRecord?.verifiedAt ?? targetContext?.date ?? day)
    }

    var body: some View {
        if route == nil {
            NavigationStack {
                editor
            }
        } else {
            editor
        }
    }

    private var editor: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if #unavailable(iOS 26.0) {
                    cancelButton
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    AppText(existingRecord == nil ? "Log sunscreen" : "Edit log", style: .largeTitle)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("\(accessibilityPrefix).title")
                    AppText(
                        day.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                        style: .caption,
                        color: AppColor.Text.secondary
                    )
                    .accessibilityIdentifier("\(accessibilityPrefix).timestamp")
                }

                DatePicker(
                    (existingRecord?.reapplyCount ?? 0) > 0 ? "First application" : "Application time",
                    selection: $selectedTimestamp,
                    in: allowedTimestampRange,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
                .font(AppTextStyle.body.font)
                .tint(AppColor.accent)
                .frame(minHeight: 44)
                .accessibilityIdentifier("\(accessibilityPrefix).timePicker")

                SunManualLogFields(
                    selectedSPF: $selectedSPF,
                    notes: $notes,
                    selectedAreas: $selectedAreas,
                    accessibilityPrefix: accessibilityPrefix,
                    suggestions: appState.manualLogSuggestionState(for: day),
                    showsOptionalDisclosure: false
                )

                if let errorMessage = inputValidationMessage ?? appState.logActionErrorMessage {
                    AppText(errorMessage, style: .caption, color: AppPalette.warning)
                        .accessibilityLabel("Couldn’t save. \(errorMessage)")
                        .accessibilityIdentifier(
                            accessibilityPrefix == "manualLog" ? "manualLog.validation" : "historyEditor.error"
                        )
                }
            }
        } footer: {
            Button("Save", action: saveLog)
                .sunGlassPrimaryButton()
                .disabled(inputValidationMessage != nil || hasSaved)
                .accessibilityIdentifier(
                    accessibilityPrefix == "manualLog" ? "manualLog.logToday" : "historyEditor.save"
                )
        }
        .onAppear {
            appState.clearLogActionError()
            syncInitialStateIfNeeded()
        }
        .onDisappear {
            appState.clearLogActionError()
        }
        .sunNavigationBarCompatibility()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
            }
        }
        .interactivePopGestureEnabled()
    }

    private var cancelButton: some View {
        Button("Cancel", action: closeEditor)
            .frame(minHeight: 44)
            .accessibilityIdentifier("screen.back")
    }

    private var inputValidationMessage: String? {
        if !appState.canLog(on: day) {
            return "Choose today or an earlier date in History."
        }
        if !allowedTimestampRange.contains(selectedTimestamp) {
            return "Choose a time on this day that is not in the future."
        }
        let serializedCount = SunManualLogInput.notesWithCoveredAreas(notes, areas: selectedAreas).count
        let overage = serializedCount - SunManualLogInput.noteCharacterLimit
        if overage > 0 {
            return "Shorten notes by \(overage) \(overage == 1 ? "character" : "characters") or remove coverage."
        }
        return nil
    }

    private func saveLog() {
        guard !hasSaved, inputValidationMessage == nil,
              let serializedNotes = SunManualLogInput.validatedNotesWithCoveredAreas(notes, areas: selectedAreas) else {
            return
        }
        let result = appState.saveManualRecord(
            for: day,
            dayPart: targetContext?.dayPart,
            verifiedAt: selectedTimestamp,
            spfLevel: selectedSPF,
            notes: serializedNotes
        )
        guard case let .success(receipt) = result else { return }
        hasSaved = true
        if receipt.didChange,
           Calendar.current.isDate(day, inSameDayAs: appState.referenceDate),
           appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        closeEditor()
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else { return }
        hasLoadedInitialState = true
        guard existingRecord == nil else { return }

        if let prefill {
            selectedSPF = prefill.spfLevel
            selectedAreas = SunManualLogInput.coveredAreas(in: prefill.notes)
            notes = SunManualLogInput.notesRemovingCoveredAreas(prefill.notes)
        } else {
            let defaults = appState.oneTapLogInput(for: day)
            selectedSPF = defaults.spfLevel
            selectedAreas = defaults.coveredAreas
        }
        selectedTimestamp = defaultTimestamp
    }

    private var allowedTimestampRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let endOfDay = nextDay.addingTimeInterval(-1)
        let upperBound = max(start, min(endOfDay, appState.referenceDate))
        return start...upperBound
    }

    private var defaultTimestamp: Date {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: day)
        if calendar.isDate(targetDay, inSameDayAs: appState.referenceDate) {
            return appState.referenceDate
        }
        return calendar.date(
            bySettingHour: (targetContext?.dayPart ?? .morning).defaultHour,
            minute: 0,
            second: 0,
            of: targetDay
        ) ?? targetDay
    }

    private func closeEditor() {
        if accessibilityPrefix == "manualLog" {
            appState.clearManualLogPrefill()
        }
        if route != nil {
            router.goBack()
        } else {
            dismiss()
        }
    }
}

struct HistoryEditorTestHarnessView: View {
    @Environment(AppState.self) private var appState

    let day: Date
    @State private var isPresentingEditor = true

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 12) {
                Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(AppTextStyle.title.font)
                    .foregroundStyle(AppPalette.ink)
                    .accessibilityIdentifier("historyHarness.day")

                Text(spfSummary)
                    .font(AppTextStyle.bodyMedium.font)
                    .foregroundStyle(AppPalette.softInk)
                    .accessibilityIdentifier("historyHarness.spf")
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            HistoryRecordEditorView(
                day: day,
                existingRecord: appState.record(for: day)
            )
        }
    }

    private var spfSummary: String {
        guard let spf = currentRecord?.spfLevel else {
            return "No SPF logged"
        }

        return "SPF \(spf)"
    }

    private var currentRecord: DailyRecord? {
        let dayStart = Calendar.current.startOfDay(for: day)
        return appState.records.first { Calendar.current.isDate($0.startOfDay, inSameDayAs: dayStart) }
    }
}
