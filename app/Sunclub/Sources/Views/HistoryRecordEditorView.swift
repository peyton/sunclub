import SwiftUI

struct HistoryRecordEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let day: Date
    let existingRecord: DailyRecord?
    let route: AppRoute?
    let targetContext: AppLogContext?

    @State private var selectedSPF: Int?
    @State private var selectedAreas: Set<String>
    @State private var notes: String
    @State private var selectedTimestamp: Date
    @State private var hasLoadedInitialState = false

    init(
        day: Date,
        existingRecord: DailyRecord?,
        route: AppRoute? = nil,
        targetContext: AppLogContext? = nil
    ) {
        self.day = day
        self.existingRecord = existingRecord
        self.route = route
        self.targetContext = targetContext
        _selectedSPF = State(initialValue: existingRecord?.spfLevel)
        let existingAreas = SunManualLogInput.coveredAreas(in: existingRecord?.notes)
        _selectedAreas = State(initialValue: existingAreas.isEmpty ? SunManualLogInput.defaultCoveredAreas : existingAreas)
        _notes = State(initialValue: SunManualLogInput.notesRemovingCoveredAreas(existingRecord?.notes))
        _selectedTimestamp = State(initialValue: existingRecord?.verifiedAt ?? day)
    }

    var body: some View {
        SunLightScreen(
            contentMaxWidth: SunLayout.ContentWidth.form,
            contentFrameAlignment: .center,
            footerMaxWidth: SunLayout.ContentWidth.form
        ) {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: editorTitle, showsBack: true, onBack: {
                    closeEditor()
                })

                SunScreenTitleBlock(
                    eyebrow: day.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                    title: existingRecord == nil ? "No sunscreen logged" : "Completed",
                    detail: editorMessage,
                    symbolName: existingRecord == nil ? "calendar.badge.plus" : "checkmark.circle.fill",
                    tint: existingRecord == nil ? AppPalette.sun : AppPalette.success
                )
                .accessibilityIdentifier("historyEditor.title")

                SunclubCard(cornerRadius: AppRadius.card, padding: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        AppText("Application time", style: .bodyMedium)
                        DatePicker(
                            "Application time",
                            selection: $selectedTimestamp,
                            in: allowedTimestampRange,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("historyEditor.timePicker")

                        AppText(
                            "Saved for \(selectedTimestamp.formatted(.dateTime.weekday(.wide).month(.wide).day().hour().minute())).",
                            style: .caption,
                            color: AppColor.Text.secondary
                        )
                    }
                }

                SunclubCard(cornerRadius: 20, padding: 16) {
                    SunManualLogFields(
                        selectedSPF: $selectedSPF,
                        notes: $notes,
                        selectedAreas: $selectedAreas,
                        accessibilityPrefix: "historyEditor",
                        suggestions: appState.manualLogSuggestionState(for: day),
                        showsOptionalDisclosure: false
                    )
                }

                if let errorMessage = appState.logActionErrorMessage {
                    SunInfoRow(
                        title: "Couldn’t save",
                        detail: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: AppColor.warning
                    )
                    .padding(AppSpacing.sm)
                    .sunGlassCard(cornerRadius: AppRadius.card)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Save error. \(errorMessage)")
                    .accessibilityIdentifier("historyEditor.error")
                }
            }
        } footer: {
            Button(primaryActionTitle) {
                let result = appState.saveManualRecord(
                    for: targetContext?.date ?? day,
                    dayPart: targetContext?.dayPart,
                    verifiedAt: selectedTimestamp,
                    spfLevel: selectedSPF,
                    notes: SunManualLogInput.notesWithCoveredAreas(notes, areas: selectedAreas)
                )
                if case .success = result {
                    closeEditor()
                }
            }
            .sunGlassPrimaryButton()
            .accessibilityIdentifier("historyEditor.save")
        }
        .onAppear {
            appState.clearLogActionError()
            syncInitialStateIfNeeded()
        }
        .onDisappear {
            appState.clearLogActionError()
        }
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
    }

    private var editorTitle: String {
        existingRecord == nil ? "Backfill Day" : "Edit Entry"
    }

    private var editorMessage: String {
        if existingRecord == nil {
            return "Add a log for this day so your history stays complete."
        }

        return "Update the time, SPF, covered areas, or note for this day."
    }

    private var primaryActionTitle: String {
        if appState.logActionErrorMessage != nil {
            return "Try Again"
        }
        return existingRecord == nil ? "Save Backfill" : "Save Changes"
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else {
            return
        }

        hasLoadedInitialState = true

        guard existingRecord == nil else {
            return
        }

        let suggestions = appState.manualLogSuggestionState(for: day)
        selectedSPF = suggestions.defaultSPF
        selectedTimestamp = defaultTimestamp
    }

    private var allowedTimestampRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: targetContext?.date ?? day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let endOfDay = nextDay.addingTimeInterval(-1)
        let upperBound = max(start, min(endOfDay, appState.referenceDate))
        return start...upperBound
    }

    private var defaultTimestamp: Date {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: targetContext?.date ?? day)
        if calendar.isDate(targetDay, inSameDayAs: appState.referenceDate) {
            return appState.referenceDate
        }

        let hour = switch targetContext?.dayPart ?? .morning {
        case .morning: 9
        case .afternoon: 13
        case .evening: 18
        case .night: 21
        }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: targetDay) ?? targetDay
    }

    private func closeEditor() {
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
