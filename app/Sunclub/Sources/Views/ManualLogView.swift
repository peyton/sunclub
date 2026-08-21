import SwiftUI

struct ManualLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let context: AppLogContext?

    @State private var targetDate: Date
    @State private var targetTime: Date
    @State private var selectedDayPart: DayPart
    @State private var selectedSPF: Int?
    @State private var selectedAreas: Set<String> = SunManualLogInput.defaultCoveredAreas
    @State private var notes: String = ""
    @State private var hasLoadedInitialState = false
    @State private var isShowingWhenEditor = false
    @State private var isShowingProductEditor = false
    @State private var productName = ""
    @State private var productSPF = 50
    @State private var productWaterResistance: SunclubSunscreenWaterResistance = .none
    @State private var productValidationMessage: String?
    @State private var feedbackTrigger = 0
    @State private var navigationFeedbackTrigger = 0

    init(context: AppLogContext? = nil) {
        self.context = context
        let initialDate = context?.date ?? Date()
        let initialTime = context.map {
            Calendar.current.date(
                bySettingHour: $0.dayPart.defaultHour,
                minute: 0,
                second: 0,
                of: $0.date
            ) ?? $0.date
        } ?? Date()
        _targetDate = State(initialValue: initialDate)
        _targetTime = State(initialValue: initialTime)
        _selectedDayPart = State(initialValue: context?.dayPart ?? .morning)
    }

    private var existingRecord: DailyRecord? {
        appState.record(for: targetDate)
    }

    private var isFutureTarget: Bool {
        !appState.canLog(on: targetDate) || resolvedVerifiedAt > appState.referenceDate
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
        .sunNavigationBarCompatibility()
        .interactivePopGestureEnabled()
    }

    @ViewBuilder
    private var manualLogNavigationHeader: some View {
        if #available(iOS 26.0, *) {
            nativeManualLogNavigationHeader
        } else {
            legacyManualLogNavigationHeader
        }
    }

    @available(iOS 26.0, *)
    private var nativeManualLogNavigationHeader: some View {
        Color.clear
            .frame(height: 0)
            .accessibilityHidden(true)
            .navigationTitle("Log Sunscreen")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: closeLog)
                        .accessibilityIdentifier("screen.back")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: saveLog)
                        .disabled(isSaveDisabled)
                        .accessibilityIdentifier("manualLog.saveTop")
                }
            }
    }

    private var legacyManualLogNavigationHeader: some View {
        HStack(alignment: .center) {
            Button("Cancel") {
                closeLog()
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
                .font(AppTypography.screenTitle)
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
            .accessibilityLabel("SPF")
            .accessibilityValue(selectedSPF.map { "SPF \($0) selected" } ?? "Choose")
            .accessibilityIdentifier("manualLog.spfRow")

            Divider()
                .overlay(AppPalette.hairlineStroke)

            Button {
                withAnimation(SunMotion.easeInOut(duration: 0.18, reduceMotion: reduceMotion)) {
                    isShowingProductEditor.toggle()
                }
            } label: {
                referenceFormRowContent(
                    title: "Product",
                    value: savedProductSummary,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .disabled(isFutureTarget)
            .accessibilityLabel("Product")
            .accessibilityValue(savedProductSummary)
            .accessibilityIdentifier("manualLog.productRow")

            if isShowingProductEditor {
                productEditor
            }
        }
        .sunGlassCard(
            cornerRadius: AppRadius.medium,
            fillOpacity: 0.72,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
    }

    private var commonSPFLevels: [Int] {
        [15, 30, 50, 70, 100]
    }

    private var whenValue: String {
        if Calendar.current.isDate(resolvedVerifiedAt, inSameDayAs: appState.referenceDate) {
            return "Today, \(resolvedVerifiedAt.formatted(date: .omitted, time: .shortened))"
        }
        return resolvedVerifiedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private var resolvedVerifiedAt: Date {
        let dayComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: targetTime)
        return Calendar.current.date(
            from: DateComponents(
                year: dayComponents.year,
                month: dayComponents.month,
                day: dayComponents.day,
                hour: timeComponents.hour,
                minute: timeComponents.minute
            )
        ) ?? targetDate
    }

    private var savedProductSummary: String {
        guard let profile = appState.settings.sunscreenProfile else {
            return "Add reusable profile"
        }
        return "\(profile.name), SPF \(profile.spf)"
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

            DatePicker(
                "Time",
                selection: $targetTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .font(AppTextStyle.captionMedium.font)
            .tint(AppPalette.sun)
            .accessibilityIdentifier("manualLog.timePicker")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(AppPalette.controlFill.opacity(0.34))
    }

    private var productEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let productValidationMessage {
                Text(productValidationMessage)
                    .font(AppTextStyle.caption.font)
                    .foregroundStyle(AppColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("manualLog.productValidation")
            }

            TextField("Product name", text: $productName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("manualLog.productName")

            Picker("Product SPF", selection: $productSPF) {
                ForEach(commonSPFLevels, id: \.self) { level in
                    Text("SPF \(level)").tag(level)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("manualLog.productSPF")

            VStack(alignment: .leading, spacing: 8) {
                Text("Water-resistance label")
                    .font(AppTextStyle.captionMedium.font)
                    .foregroundStyle(AppPalette.ink)

                Picker("Water-resistance label", selection: $productWaterResistance) {
                    ForEach(SunclubSunscreenWaterResistance.allCases, id: \.self) { resistance in
                        Text(waterResistanceTitle(resistance)).tag(resistance)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("manualLog.productWaterResistance")
            }

            Text("Use the product label as the source of truth. Reapply after swimming, sweating, or toweling off.")
                .font(AppTextStyle.caption.font)
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    productSaveButton
                    if appState.settings.sunscreenProfile != nil {
                        productRemoveButton
                    }
                }

                VStack(spacing: 10) {
                    productSaveButton
                    if appState.settings.sunscreenProfile != nil {
                        productRemoveButton
                    }
                }
            }
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

    private func applyResolvedContext() {
        let resolved = context ?? appState.currentLogContext(for: appState.selectedDay, source: .manualLog)
        targetDate = appState.startOfLocalDay(resolved.date)
        let existingTimestamp = appState.record(for: resolved.date)?.verifiedAt
        targetTime = existingTimestamp
            ?? (Calendar.current.isDate(resolved.date, inSameDayAs: appState.referenceDate)
                ? appState.referenceDate
                : Calendar.current.date(
                bySettingHour: resolved.dayPart.defaultHour,
                minute: 0,
                second: 0,
                of: resolved.date
            ))
            ?? resolved.date
        selectedDayPart = appState.dayPart(for: targetTime)
        appState.clearLogActionError()
        syncProductProfile()
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

        let exactTimestamp = resolvedVerifiedAt
        selectedDayPart = appState.dayPart(for: exactTimestamp)
        let saveContext = AppLogContext(
            date: targetDate,
            dayPart: selectedDayPart,
            source: context?.source ?? .manualLog
        )
        let result = appState.recordVerificationSuccess(
            method: .manual,
            verificationDuration: nil,
            spfLevel: selectedSPF,
            notes: SunManualLogInput.notesWithCoveredAreas(notes, areas: selectedAreas),
            verifiedAt: exactTimestamp,
            context: saveContext
        )
        guard result.succeeded else {
            return
        }
        feedbackTrigger += 1
        if appState.settings.reapplyReminderEnabled {
            appState.scheduleReapplyReminder()
        }
        appState.clearManualLogPrefill()
        router.open(.home)
    }

    private func closeLog() {
        appState.clearManualLogPrefill()
        router.goBack()
    }

    private func syncInitialStateIfNeeded() {
        guard !hasLoadedInitialState else {
            return
        }

        hasLoadedInitialState = true

        if let existingRecord {
            targetTime = existingRecord.verifiedAt
            selectedDayPart = appState.dayPart(for: existingRecord.verifiedAt)
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
            return
        }

        let defaults = appState.oneTapLogInput(for: targetDate)
        selectedSPF = appState.settings.sunscreenProfile?.spf ?? defaults.spfLevel
        selectedAreas = defaults.coveredAreas.isEmpty
            ? SunManualLogInput.defaultCoveredAreas
            : defaults.coveredAreas
    }

    private func syncProductProfile() {
        guard let profile = appState.settings.sunscreenProfile else {
            productName = ""
            productSPF = selectedSPF ?? 50
            productWaterResistance = .none
            return
        }

        productName = profile.name
        productSPF = profile.spf
        productWaterResistance = profile.waterResistance
    }

    private func saveProductProfile() {
        let name = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            productValidationMessage = "Enter the name printed on your sunscreen."
            return
        }

        let profile = SunclubSunscreenProfile(
            name: name,
            spf: productSPF,
            waterResistance: productWaterResistance
        )
        guard appState.updateSunscreenProfile(profile) else {
            productValidationMessage = appState.logActionErrorMessage ?? "Sunclub could not save this profile. Retry."
            return
        }

        selectedSPF = profile.spf
        productValidationMessage = nil
        isShowingProductEditor = false
    }

    private func removeProductProfile() {
        guard appState.updateSunscreenProfile(nil) else {
            productValidationMessage = appState.logActionErrorMessage ?? "Sunclub could not remove this profile. Retry."
            return
        }

        productValidationMessage = nil
        isShowingProductEditor = false
        syncProductProfile()
    }

    private func waterResistanceTitle(_ resistance: SunclubSunscreenWaterResistance) -> String {
        switch resistance {
        case .none:
            return "None"
        case .fortyMinutes:
            return "40 min"
        case .eightyMinutes:
            return "80 min"
        }
    }

    private var productSaveButton: some View {
        Button("Save Profile") {
            saveProductProfile()
        }
        .buttonStyle(SunPrimaryButtonStyle())
        .accessibilityIdentifier("manualLog.saveProductProfile")
    }

    private var productRemoveButton: some View {
        Button("Remove", role: .destructive) {
            removeProductProfile()
        }
        .buttonStyle(SunSecondaryButtonStyle())
        .accessibilityIdentifier("manualLog.removeProductProfile")
    }
}

#Preview {
    SunclubPreviewHost {
        ManualLogView()
    }
}
