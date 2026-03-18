import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var showTimePicker = false
    @State private var reminderTime = Date()
    @State private var showSubscriptionFallback = false

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 30) {
                SunLightHeader(title: "Settings", showsBack: true) {
                    router.goHome()
                }

                reminderSection

                VStack(alignment: .leading, spacing: 18) {
                    SunSettingsRow(title: "Notification Time") {
                        reminderTime = appState.reminderDate
                        showTimePicker = true
                    }
                    .accessibilityIdentifier("settings.notificationTime")

                    SunSettingsRow(title: "Manage Subscription") {
                        openManageSubscriptions()
                    }
                    .accessibilityIdentifier("settings.manageSubscription")
                }

                Spacer(minLength: 420)
            }
        }
        .sheet(isPresented: $showTimePicker) {
            timePickerSheet
        }
        .alert("Manage Subscription Unavailable", isPresented: $showSubscriptionFallback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Subscription management is not available in this environment.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Reminder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(reminderSummary)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppPalette.ink)
                .accessibilityIdentifier("settings.reminderSummary")

            Text("Daily reminders open the sunscreen camera flow directly.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
    }

    private var reminderSummary: String {
        appState.reminderDate.formatted(date: .omitted, time: .shortened)
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

    private func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else {
            showSubscriptionFallback = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                showSubscriptionFallback = true
            }
        }
    }
}

#Preview {
    SunclubPreviewHost {
        SettingsView()
    }
}
