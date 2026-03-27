import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var showTimePicker = false
    @State private var reminderTime = Date()
    @State private var reapplyEnabled = false
    @State private var reapplyInterval = 120

    private let reapplyOptions = [30, 60, 90, 120, 180, 240]

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 30) {
              SunLightHeader(title: "Settings", showsBack: true, onBack: {
                    router.goHome()
                })

                reminderSection

                VStack(alignment: .leading, spacing: 18) {
                    SunSettingsRow(title: "Notification Time") {
                        reminderTime = appState.reminderDate
                        showTimePicker = true
                    }
                    .accessibilityIdentifier("settings.notificationTime")
                }

                reapplySection

                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
        .onAppear {
            reapplyEnabled = appState.settings.reapplyReminderEnabled
            reapplyInterval = appState.settings.reapplyIntervalMinutes
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reminders")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(reminderSummary)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("settings.reminderSummary")

            Text(reminderDescription)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
    }

    private var reapplySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reapplication Reminder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

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
    }

    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remaining = minutes % 60
            return remaining > 0 ? "\(hours)h\(remaining)m" : "\(hours)h"
        }
    }

    private var reminderSummary: String {
        appState.reminderDate.formatted(date: .omitted, time: .shortened)
    }

    private var reminderDescription: String {
        if appState.isBottleScanEnabled {
            return "Daily reminders open the sunscreen camera flow directly."
        }

        return "Daily reminders open today's sunscreen check-in directly."
    }

    private var timePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Reminder Time",
                    selection: $reminderTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button("Save Time") {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                    appState.updateDailyReminder(hour: components.hour ?? 8, minute: components.minute ?? 0)
                    showTimePicker = false
                }
                .buttonStyle(SunPrimaryButtonStyle())
            }
            .padding(24)
            .navigationTitle("Notification Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showTimePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SunclubPreviewHost {
        SettingsView()
    }
}
