import SwiftUI

struct HistoryRecordEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    @State private var originalSnapshot: DailyRecordProjectionSnapshot?
    @State private var originalRecordID: UUID?
    @State private var selectedReapplicationTime: Date?
    @State private var initialDraft: EditorDraft?
    @State private var confirmsDiscard = false

    private struct EditorDraft: Equatable {
        let time: Date
        let reapplication: Date?
        let spf: Int?
        let areas: Set<String>
        let notes: String
    }

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
        _originalSnapshot = State(initialValue: existingRecord?.projectionSnapshot)
        _originalRecordID = State(initialValue: existingRecord?.id)
        _selectedReapplicationTime = State(initialValue: existingRecord?.lastReappliedAt)
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
                        day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()),
                        style: .caption,
                        color: AppColor.Text.secondary
                    )
                    .accessibilityIdentifier("\(accessibilityPrefix).timestamp")
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    AppText("Timing", style: .captionMedium, color: AppColor.Text.secondary)
                        .accessibilityAddTraits(.isHeader)
                    timePicker(
                        (originalSnapshot?.reapplyCount ?? 0) > 0 ? "First application" : "Application time",
                        selection: $selectedTimestamp,
                        identifier: "\(accessibilityPrefix).timePicker"
                    )

                    if selectedReapplicationTime != nil {
                        timePicker(
                            "Latest reapplication",
                            selection: Binding(
                                get: { selectedReapplicationTime ?? selectedTimestamp },
                                set: { selectedReapplicationTime = $0 }
                            ),
                            identifier: "\(accessibilityPrefix).reapplicationTimePicker"
                        )
                    }

                }

                Divider().overlay(AppColor.stroke).accessibilityHidden(true)

                SunManualLogFields(
                    selectedSPF: $selectedSPF,
                    notes: $notes,
                    selectedAreas: $selectedAreas,
                    accessibilityPrefix: accessibilityPrefix,
                    suggestions: originalSnapshot == nil ? appState.manualLogSuggestionState(for: day) : .empty,
                    showsOptionalDisclosure: true,
                    detailsInitiallyExpanded: false
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
            Button(action: saveLog) {
                Text("Save")
                    .font(AppTextStyle.bodyMedium.font)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
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
        .interactiveDismissDisabled(hasUnsavedChanges)
        .alert("Discard changes?", isPresented: $confirmsDiscard) {
            Button("Discard changes", role: .destructive, action: closeEditor)
            Button("Keep editing", role: .cancel) { }
        }
    }

    @ViewBuilder
    private func timePicker(_ title: String, selection: Binding<Date>, identifier: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                AppText(title, style: .body)
                    .accessibilityHidden(true)
                timePickerControl(title, selection: selection, identifier: identifier)
                    .labelsHidden()
            }
        } else {
            timePickerControl(title, selection: selection, identifier: identifier)
        }
    }

    private func timePickerControl(_ title: String, selection: Binding<Date>, identifier: String) -> some View {
        DatePicker(title, selection: selection, in: allowedTimestampRange, displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
            .font(AppTextStyle.body.font)
            .tint(AppColor.accent)
            .frame(minHeight: 44)
            .accessibilityLabel(title)
            .accessibilityIdentifier(identifier)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            if hasUnsavedChanges { confirmsDiscard = true } else { closeEditor() }
        }
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
        if let selectedReapplicationTime,
           (!allowedTimestampRange.contains(selectedReapplicationTime) || selectedReapplicationTime < selectedTimestamp) {
            return "Reapplication must be after the first application and not in the future."
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
        let result = appState.saveEditedRecord(
            for: day, recordID: originalRecordID, expected: originalSnapshot,
            verifiedAt: selectedTimestamp, lastReappliedAt: selectedReapplicationTime,
            spfLevel: selectedSPF, notes: serializedNotes
        )
        guard result.succeeded else { return }
        hasSaved = true
        closeEditor()
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else { return }
        hasLoadedInitialState = true
        defer { initialDraft = draft }
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

    private var draft: EditorDraft {
        EditorDraft(time: selectedTimestamp, reapplication: selectedReapplicationTime,
                    spf: selectedSPF, areas: selectedAreas, notes: notes)
    }

    private var hasUnsavedChanges: Bool {
        !hasSaved && initialDraft.map { $0 != draft } == true
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
