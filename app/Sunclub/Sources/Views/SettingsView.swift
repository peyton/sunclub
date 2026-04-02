import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReminderPicker: ReminderScheduleKind?
    @State private var pickerTime = Date()
    @State private var reapplyEnabled = false
    @State private var reapplyInterval = 120
    @State private var followsTravelTimeZone = true
    @State private var streakRiskEnabled = true

    private let reapplyOptions = [30, 60, 90, 120, 180, 240]

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 30) {
                SunLightHeader(title: "Settings", showsBack: true, onBack: {
                    dismiss()
                })

                smarterReminderSection
                reapplySection

                Spacer(minLength: 0)
            }
        }
        .sheet(item: $selectedReminderPicker) { schedule in
            reminderPickerSheet(for: schedule)
        }
        .onAppear(perform: syncLocalState)
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var smarterReminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Smarter Reminders")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(reminderHeadline)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("settings.reminderSummary")

            Text(reminderDescription)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)

            VStack(spacing: 12) {
                reminderCard(for: .weekday, detail: "Used Monday through Friday")
                reminderCard(for: .weekend, detail: "Used Saturday and Sunday")
            }

            ReminderToggleCard(
                title: "Follow local time when traveling",
                detail: followsTravelTimeZone
                    ? "Sunclub adjusts reminders to the time zone you are currently in."
                    : "Sunclub keeps reminders pinned to \(anchoredTimeZoneLabel).",
                isOn: $followsTravelTimeZone,
                accessibilityIdentifier: "settings.travelToggle"
            )
            .onChange(of: followsTravelTimeZone) { _, newValue in
                appState.updateTravelTimeZoneHandling(followsTravelTimeZone: newValue)
            }

            ReminderToggleCard(
                title: "Streak at risk nudge",
                detail: streakRiskEnabled
                    ? "If you have an active streak, Sunclub sends an evening save-it reminder before the day closes."
                    : "Sunclub only sends the main reminder schedule.",
                isOn: $streakRiskEnabled,
                accessibilityIdentifier: "settings.streakRiskToggle"
            )
            .onChange(of: streakRiskEnabled) { _, newValue in
                appState.updateStreakRiskReminder(enabled: newValue)
            }
        }
    }

    private func reminderCard(for kind: ReminderScheduleKind, detail: String) -> some View {
        Button {
            pickerTime = appState.reminderDate(for: kind)
            selectedReminderPicker = kind
        } label: {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(AppPalette.softInk)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Text(formattedReminderTime(for: kind))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.softInk)
                }
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier(for: kind))
    }

    private var reapplySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reapplication Reminder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $reapplyEnabled) {
                    Text("Remind to reapply")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                }
                .tint(AppPalette.sun)
                .onChange(of: reapplyEnabled) { _, newValue in
                    appState.updateReapplySettings(enabled: newValue, intervalMinutes: reapplyInterval)
                }
                .accessibilityIdentifier("settings.reapplyToggle")

                if reapplyEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interval")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppPalette.softInk)

                        HStack(spacing: 8) {
                            ForEach(reapplyOptions, id: \.self) { minutes in
                                Button {
                                    reapplyInterval = minutes
                                    appState.updateReapplySettings(enabled: reapplyEnabled, intervalMinutes: minutes)
                                } label: {
                                    Text(formatInterval(minutes))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(reapplyInterval == minutes ? .white : AppPalette.ink)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(reapplyInterval == minutes ? AppPalette.sun : Color.white.opacity(0.72))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .accessibilityIdentifier("settings.reapplyInterval")
                    }
                }

                Text("Get a reminder to reapply sunscreen after your daily check-in.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(18)
            .background(cardBackground)
        }
    }

    private var reminderHeadline: String {
        let weekday = formattedReminderTime(for: .weekday)
        let weekend = formattedReminderTime(for: .weekend)

        if weekday == weekend {
            return "Every day at \(weekday)"
        }

        return "Weekdays \(weekday), weekends \(weekend)"
    }

    private var reminderDescription: String {
        let travelLine = followsTravelTimeZone
            ? "Travel mode keeps reminders on local time."
            : "Travel mode is off, so reminders stay on \(anchoredTimeZoneLabel)."
        let streakLine = streakRiskEnabled
            ? " Evening nudges rescue active streaks."
            : " Evening streak nudges are off."
        return travelLine + streakLine
    }

    private var anchoredTimeZoneLabel: String {
        let timeZone = appState.settings.smartReminderSettings.anchoredTimeZone
        return timeZone.localizedName(for: .generic, locale: .current)
            ?? timeZone.identifier.replacingOccurrences(of: "_", with: " ")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            }
    }

    private func formattedReminderTime(for kind: ReminderScheduleKind) -> String {
        appState.reminderDate(for: kind).formatted(date: .omitted, time: .shortened)
    }

    private func accessibilityIdentifier(for kind: ReminderScheduleKind) -> String {
        switch kind {
        case .weekday:
            return "settings.weekdayReminderTime"
        case .weekend:
            return "settings.weekendReminderTime"
        }
    }

    private func syncLocalState() {
        let reminderSettings = appState.settings.smartReminderSettings
        followsTravelTimeZone = reminderSettings.followsTravelTimeZone
        streakRiskEnabled = reminderSettings.streakRiskEnabled
        reapplyEnabled = appState.settings.reapplyReminderEnabled
        reapplyInterval = appState.settings.reapplyIntervalMinutes
    }

    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remaining = minutes % 60
        return remaining > 0 ? "\(hours)h\(remaining)m" : "\(hours)h"
    }

    private func reminderPickerSheet(for schedule: ReminderScheduleKind) -> some View {
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
                .buttonStyle(SunPrimaryButtonStyle())
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

private struct ReminderToggleCard: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
            }
            .tint(AppPalette.sun)
            .accessibilityIdentifier(accessibilityIdentifier)

            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                }
        )
    }
}

#Preview {
    SunclubPreviewHost {
        SettingsView()
    }
}
