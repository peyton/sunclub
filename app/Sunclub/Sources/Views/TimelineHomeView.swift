import SwiftUI

/// Today is always the current local day. History owns date selection.
struct TimelineHomeView: View {
    static let errorTextColor = AppPalette.warning

    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @State private var receipt: SunclubHistoryMutationReceipt?
    @State private var isLogging = false
    @State private var feedbackTrigger = 0
    @State private var undoError: String?
    @State private var spfEdit: LoggedSPFEditTarget?

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: appState.referenceDate), by: 60)) { _ in
            todayContent(now: appState.referenceDate)
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .sheet(item: $spfEdit) { target in
            LoggedSPFEditorView(target: target)
        }
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .sunNavigationBarCompatibility()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func todayContent(now: Date) -> some View {
        let record = appState.record(for: now)
        let log = TodayQuietGlassLogPresentation(
            record: record, now: now,
            remindersEnabled: appState.settings.reapplyReminderEnabled,
            reapplyPlan: appState.reapplyReminderPlan
        )
        let uvPresentation = TodayQuietGlassUVPresentation(
            reading: appState.uvReading, forecast: appState.uvForecast,
            status: appState.uvStatus, protectionWindow: appState.uvProtectionWindow,
            selectedDay: now, now: now
        )
        return SunLightScreen(scrollAccessibilityIdentifier: "timeline.scroll") {
            VStack(spacing: AppSpacing.md) {
                todayHeader(now: now)

                Button { router.push(.uvForecast) } label: {
                    TodayQuietGlassGauge(presentation: uvPresentation)
                }
                .buttonStyle(TodayQuietGlassTapButtonStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(uvPresentation.accessibilityLabel)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { router.push(.uvForecast) }
                .accessibilityHint("Opens the UV forecast.")
                .accessibilityIdentifier("home.uvIndexCard")

                if let pending = appState.pendingDepartureCheckIn {
                    departurePrompt(pending)
                }

                TodayQuietGlassLogSummary(presentation: log) {
                    if let record { spfEdit = LoggedSPFEditTarget(record: record) }
                }

                if let reminder = log.reminderText {
                    Button { router.push(.reapplyCheckIn) } label: {
                        TodayQuietGlassReminder(text: reminder, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(reminder)
                    .accessibilityHint("Opens reminder options.")
                    .accessibilityIdentifier("home.reapplyReminder")
                }

                TodayQuietGlassLogButton(title: record == nil ? "Log sunscreen" : "Log reapplication", action: logNow)
                    .disabled(isLogging)

                if record != nil { logActions }

                if let error = undoError ?? appState.logActionErrorMessage ?? appState.lastRefreshError {
                    AppText(error, style: .body, color: Self.errorTextColor)
                        .accessibilityIdentifier("home.logError")
                }

                uvSource(uvPresentation)
                attentionActions
            }
            .frame(maxWidth: .infinity)
        }
        .refreshable {
            appState.refresh()
            refresh()
        }
    }

    private func todayHeader(now: Date) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            SunLightHeader(title: "Today", usesNativeNavigation: false)
            AppText(now.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                    style: .captionMedium, color: AppColor.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today, \(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
        .accessibilityIdentifier("timeline.headline")
    }

    private var logActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.lg) { receiptActions }
            VStack(spacing: AppSpacing.xs) { receiptActions }
        }
    }

    @ViewBuilder
    private var receiptActions: some View {
        if let receipt,
           Calendar.current.isDate(receipt.day, inSameDayAs: appState.referenceDate),
           let batchID = receipt.batchID, appState.canUndoChangeIfCurrent(batchID: batchID) {
            Button {
                switch appState.undoChangeIfCurrent(batchID: batchID) {
                case .success:
                    self.receipt = nil
                    undoError = nil
                case let .failure(error):
                    undoError = error.localizedDescription
                }
            } label: {
                Text("Undo")
                    .font(AppTextStyle.body.font)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("home.undoLog")
        }
        Button {
            let now = appState.referenceDate
            router.push(.manualLog, targetDate: now, targetDayPart: appState.dayPart(for: now))
        } label: {
            Text("Edit log")
                .font(AppTextStyle.body.font)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("home.sunscreenLogCard")
    }

    @ViewBuilder
    private func uvSource(_ presentation: TodayQuietGlassUVPresentation) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            if let source = presentation.sourceLabel {
                // Attribution below owns the provider name; this line owns place and freshness.
                let detail = attributionSource(presentation) == nil
                    ? source : source.replacingOccurrences(of: "Apple Weather · ", with: "")
                AppText(detail, style: .caption, color: AppColor.Text.secondary)
                    .accessibilityIdentifier("home.uvSource")
            } else {
                AppText(presentation.detail, style: .caption, color: AppColor.Text.secondary)
                if appState.settings.selectedUVPlace == nil && !appState.settings.usesLiveUV {
                    Button("Set location") { router.push(.settingsHealthWeather) }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("home.setLocation")
                } else {
                    Button("Refresh UV", action: refresh)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("home.refreshUV")
                }
            }
            if attributionSource(presentation) != nil {
                WeatherKitAttributionFooter(
                    attribution: appState.weatherAttribution, sourceLabel: "Apple Weather", showAttributionLink: true
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.xxs)
    }

    private func attributionSource(_ presentation: TodayQuietGlassUVPresentation) -> String? {
        guard presentation.index != nil else { return nil }
        if let reading = appState.uvReading, reading.index >= 0 {
            return reading.source.shouldDisplayAttribution ? reading.source.statusLabel : nil
        }
        return appState.uvForecast.map(\.sourceLabel)
            .flatMap { UVReadingSource.shouldDisplayAttribution(for: $0) ? $0 : nil }
    }

    @ViewBuilder
    private var attentionActions: some View {
        if appState.pendingImportedBatchCount > 0 || !appState.conflicts.isEmpty {
            Button("Review sync changes") { router.push(.recovery) }
                .frame(minHeight: AppSpacing.xl + AppSpacing.sm)
                .accessibilityIdentifier("timeline.syncRecoveryCard")
        }
        if let health = appState.notificationHealthPresentation, health.state == .denied {
            Button("Review reminders") { router.push(.settingsSunscreenReminders) }
                .frame(minHeight: 44)
                .accessibilityIdentifier("timeline.notificationHealthAction")
        }
    }

    private func departurePrompt(_ pending: DepartureCheckInSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            AppText("Did you apply sunscreen?", style: .title)
            AppText("Left home at \(pending.departedAt.formatted(date: .omitted, time: .shortened)) · Unconfirmed",
                    style: .caption, color: AppColor.Text.secondary)
            Button("Already applied") { router.push(.departureCheckIn) }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("home.checkIn.confirm")
            Button("Remind me in 15 minutes") {
                _ = appState.resolveDepartureCheckIn(id: pending.id, action: .snooze(until: appState.referenceDate.addingTimeInterval(900)))
            }
            .buttonStyle(SunSecondaryButtonStyle())
            .accessibilityIdentifier("home.checkIn.snooze")
            Button("Dismiss") { _ = appState.resolveDepartureCheckIn(id: pending.id, action: .dismiss) }
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.checkIn.dismiss")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.departureCheckIn")
    }

    private func logNow() {
        guard !isLogging else { return }
        isLogging = true
        undoError = nil
        let result = SunTodayLogAction.perform(in: appState)
        if case let .success(saved) = result, saved.didChange {
            receipt = saved
            feedbackTrigger += 1
        }
        // Keep the button disabled through a double-tap, including synchronous local saves.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            isLogging = false
        }
    }

    private func refresh() {
        appState.refreshUVForecastIfNeeded()
        appState.refreshNotificationHealth()
    }
}
