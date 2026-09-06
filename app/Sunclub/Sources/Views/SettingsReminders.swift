import SwiftUI
import UIKit

extension SettingsView {
    var smarterReminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Reminders")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(reminderHeadline)
                .font(AppFont.rounded(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("settings.reminderSummary")

            if let preview = appState.nextDailyReminderPreview {
                Text(preview.summary)
                    .font(AppFont.rounded(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.nextReminderPreview")
            }

            if let status = appState.notificationHealthStatusPresentation {
                VStack(alignment: .leading, spacing: 10) {
                    SunStatusCard(
                        title: status.title,
                        detail: status.detail,
                        tint: notificationStatusTint(for: status),
                        symbol: status.symbolName
                    )
                    .accessibilityIdentifier("settings.notificationStatus")

                    if let actionTitle = status.actionTitle,
                       let actionKind = status.actionKind {
                        Button(actionTitle) {
                            handleNotificationStatusAction(actionKind)
                        }
                        .buttonStyle(SunSecondaryButtonStyle())
                        .accessibilityIdentifier("settings.notificationStatus.action")
                    }
                }
            }

            VStack(spacing: 12) {
                reminderCard(for: .weekday)
                reminderCard(for: .weekend)
            }

            AppCard(showsShadow: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Toggle("Follow local time when traveling", isOn: $followsTravelTimeZone)
                        .font(AppTextStyle.bodyMedium.font)
                        .tint(AppPalette.nativeChromeTint)
                        .accessibilityIdentifier("settings.travelToggle")
                        .onChange(of: followsTravelTimeZone) { _, newValue in
                            appState.updateTravelTimeZoneHandling(followsTravelTimeZone: newValue)
                        }
                    if !followsTravelTimeZone {
                        AppText(anchoredTimeZoneLabel, style: .caption, color: AppColor.Text.secondary)
                    }
                }
            }

            AppCard(showsShadow: false) {
                Toggle("Evening log reminder", isOn: $streakRiskEnabled)
                    .font(AppTextStyle.bodyMedium.font)
                    .tint(AppPalette.nativeChromeTint)
                    .accessibilityIdentifier("settings.eveningLogReminderToggle")
                    .onChange(of: streakRiskEnabled) { _, newValue in
                        appState.updateStreakRiskReminder(enabled: newValue)
                    }
            }
        }
    }

    func reminderCard(for kind: ReminderScheduleKind) -> some View {
        Button {
            pickerTime = appState.reminderDate(for: kind)
            selectedReminderPicker = kind
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.title)
                        .font(AppFont.rounded(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Text(formattedReminderTime(for: kind))
                        .font(AppFont.rounded(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Image(systemName: "chevron.right")
                        .font(AppFont.rounded(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                }
            }
            .padding(18)
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                interactive: true,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier(for: kind))
    }

    var leaveHomeReminderCard: some View {
        let presentation = appState.leaveHomeReminderStatusPresentation

        return VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $leaveHomeReminderEnabled) {
                Text("Remind me when I leave home")
                    .font(AppFont.rounded(size: 17, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.nativeChromeTint)
            .onChange(of: leaveHomeReminderEnabled) { _, newValue in
                appState.updateLeaveHomeReminderEnabled(enabled: newValue)
            }
            .accessibilityIdentifier("settings.leaveHomeToggle")

            if leaveHomeReminderEnabled || appState.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil {
                SunStatusCard(
                    title: presentation.title,
                    detail: presentation.detail,
                    tint: leaveHomeReminderTint(for: presentation.tone),
                    symbol: presentation.symbol
                )
                .accessibilityIdentifier("settings.leaveHome.status")
            }

            if let actionTitle = presentation.actionTitle,
               let actionKind = presentation.actionKind,
               leaveHomeReminderEnabled || appState.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil {
                Button(actionTitle) {
                    handleLeaveHomeReminderAction(actionKind)
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.leaveHome.action")
            }

            if appState.settings.smartReminderSettings.leaveHomeReminder.homeLocation != nil {
                Button("Reset Home") {
                    appState.clearSavedHomeLocation()
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.leaveHome.resetHome")
            }
        }
        .padding(18)
        .sunGlassCard(
            cornerRadius: AppRadius.card,
            fillOpacity: 0.82,
            legacyStroke: AppPalette.hairlineStroke,
            legacyShadow: nil
        )
    }

    var leaveHomeReminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Leave-Home Reminder")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            leaveHomeReminderCard
        }
    }

    var reapplySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Live Activities", isOn: Binding(
                get: { appState.settings.smartReminderSettings.liveActivitiesEnabled },
                set: { appState.updateLiveActivities(enabled: $0) }
            ))
            .tint(AppPalette.nativeChromeTint)
            .accessibilityIdentifier("settings.liveActivitiesToggle")
            AppText("Show sunscreen check-ins and reapply timers on your Lock Screen when available.", style: .caption, color: AppColor.Text.secondary)

            Text("Reapply Reminder")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $reapplyEnabled) {
                    Text("Remind to reapply")
                        .font(AppFont.rounded(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.nativeChromeTint)
                .onChange(of: reapplyEnabled) { _, newValue in
                    appState.updateReapplySettings(enabled: newValue, intervalMinutes: reapplyInterval)
                }
                .accessibilityIdentifier("settings.reapplyToggle")

                if reapplyEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interval")
                            .font(AppFont.rounded(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)

                        LazyVGrid(columns: reapplyIntervalColumns, spacing: 8) {
                            ForEach(reapplyOptions, id: \.self) { minutes in
                                reapplyIntervalButton(minutes)
                            }
                        }
                        .accessibilityIdentifier("settings.reapplyInterval")
                    }
                }
            }
            .padding(18)
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    @ViewBuilder
    var reminderCoachingSection: some View {
        let suggestions = appState.reminderCoachingSuggestions

        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suggested Times")
                    .font(AppFont.rounded(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)

                VStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(suggestion.title)
                                .font(AppFont.rounded(size: 17, weight: .semibold))
                                .foregroundStyle(AppPalette.ink)

                            Text(suggestion.detail)
                                .font(AppFont.rounded(size: 14))
                                .foregroundStyle(AppPalette.softInk)

                            Button(suggestion.actionTitle) {
                                appState.applyReminderCoachingSuggestion(suggestion)
                                syncLocalState()
                            }
                            .buttonStyle(SunSecondaryButtonStyle())
                            .accessibilityIdentifier("settings.coaching.\(suggestion.kind.rawValue)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .sunGlassCard(
                            cornerRadius: AppRadius.card,
                            fillOpacity: 0.82,
                            legacyStroke: AppPalette.hairlineStroke,
                            legacyShadow: nil
                        )
                    }
                }
            }
        }
    }

    var notificationHealthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notification Help")
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                if let presentation = appState.notificationHealthPresentation, presentation.state == .denied {
                    SunStatusCard(
                        title: presentation.title,
                        detail: presentation.detail,
                        tint: AppColor.warning.opacity(0.72),
                        symbol: "bell.badge.fill"
                    )

                    Button(presentation.actionTitle) {
                        handleNotificationHealthAction(for: presentation)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("settings.notificationHealth.action")
                }

                Button("Send Test Reminder") {
                    sendTestNotification()
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.notificationHealth.sendTest")

                Button("Copy Diagnostics") {
                    copyNotificationDiagnostics()
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("settings.notificationHealth.copyDiagnostics")

                if !notificationToolFeedback.isEmpty {
                    Text(notificationToolFeedback)
                        .font(AppTextStyle.captionMedium.font)
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.notificationHealth.feedback")
                }
            }
            .padding(18)
            .sunGlassCard(
                cornerRadius: AppRadius.card,
                fillOpacity: 0.82,
                legacyStroke: AppPalette.hairlineStroke,
                legacyShadow: nil
            )
        }
    }

    var reminderHeadline: String {
        let weekday = formattedReminderTime(for: .weekday)
        let weekend = formattedReminderTime(for: .weekend)

        if weekday == weekend {
            return "Every day at \(weekday)"
        }

        return "Weekdays \(weekday), weekends \(weekend)"
    }

    var anchoredTimeZoneLabel: String {
        let timeZone = appState.settings.smartReminderSettings.anchoredTimeZone
        return timeZone.localizedName(for: .generic, locale: .current)
            ?? timeZone.identifier.replacingOccurrences(of: "_", with: " ")
    }

    func formattedReminderTime(for kind: ReminderScheduleKind) -> String {
        appState.reminderDate(for: kind).formatted(date: .omitted, time: .shortened)
    }

    func accessibilityIdentifier(for kind: ReminderScheduleKind) -> String {
        switch kind {
        case .weekday:
            return "settings.weekdayReminderTime"
        case .weekend:
            return "settings.weekendReminderTime"
        }
    }

    func leaveHomeReminderTint(for tone: LeaveHomeReminderTone) -> Color {
        switch tone {
        case .neutral:
            return AppPalette.softInk
        case .success:
            return AppPalette.success
        case .warning:
            return AppColor.warning.opacity(0.72)
        }
    }

    func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h\(remaining)m" : "\(hours)h"
    }

    var reapplyIntervalColumns: [GridItem] {
        let minimumWidth: CGFloat = dynamicTypeSize.isAccessibilitySize ? 124 : 64
        return [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)]
    }

    func reapplyIntervalButton(_ minutes: Int) -> some View {
        let isSelected = reapplyInterval == minutes

        return Button {
            guard !isSelected else {
                return
            }
            reapplyInterval = minutes
            appState.updateReapplySettings(enabled: reapplyEnabled, intervalMinutes: minutes)
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(AppFont.rounded(size: 10, weight: .bold))
                }

                Text(formatInterval(minutes))
                    .font(AppFont.rounded(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? AppPalette.onAccent : AppPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                    .fill(isSelected ? AppPalette.sun : AppPalette.cardFill.opacity(0.72))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reapply interval \(formattedAccessibleInterval(minutes))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("settings.reapplyInterval.\(minutes)")
    }

    func handleNotificationHealthAction(for presentation: NotificationHealthPresentation) {
        switch presentation.state {
        case .denied:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        case .stale:
            appState.refreshNotificationHealth()
        case .healthy:
            break
        }
    }

    func sendTestNotification() {
        notificationToolFeedback = "Scheduling test reminder…"
        Task {
            let result = await NotificationManager.shared.sendTestNotification()
            notificationToolFeedback = result.message
            appState.refreshNotificationHealth()
        }
    }

    func copyNotificationDiagnostics() {
        Task {
            let diagnostics = await NotificationManager.shared.diagnostics(using: appState)
            UIPasteboard.general.string = diagnostics
            notificationToolFeedback = "Notification diagnostics copied."
        }
    }

    func handleNotificationStatusAction(_ action: NotificationHealthStatusAction) {
        switch action {
        case .requestPermission:
            appState.requestNotificationAuthorizationAndSchedule()
        }
    }

    func notificationStatusTint(for status: NotificationHealthStatusPresentation) -> Color {
        if status.actionKind != nil {
            return AppPalette.sun
        }

        return status.needsAttention ? AppColor.warning.opacity(0.72) : AppPalette.success
    }

    func handleLeaveHomeReminderAction(_ action: LeaveHomeReminderActionKind) {
        switch action {
        case .setHomeFromCurrentLocation:
            appState.saveCurrentLocationAsHome()
        case .requestAlwaysAuthorization:
            appState.requestLeaveHomeMonitoringPermission()
        case .openSettings:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        }
    }

    func reminderPickerSheet(for schedule: ReminderScheduleKind) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    schedule.title,
                    selection: $pickerTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button("Save Time") {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: pickerTime)
                    appState.updateReminderTime(
                        for: schedule,
                        hour: components.hour ?? 8,
                        minute: components.minute ?? 0
                    )
                    syncLocalState()
                    selectedReminderPicker = nil
                }
                .sunGlassPrimaryButton()
            }
            .padding(24)
            .navigationTitle(schedule.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedReminderPicker = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
