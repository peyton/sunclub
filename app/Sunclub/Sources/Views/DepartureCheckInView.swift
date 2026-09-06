import SwiftUI

/// Confirm an actual application time; a departure alone never becomes a sunscreen log.
struct DepartureCheckInView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var selectedTime = Date()
    @State private var choosesTime = false
    @State private var receipt: SunclubHistoryMutationReceipt?
    @State private var error: String?

    var body: some View {
        SunLightScreen(scrollAccessibilityIdentifier: "checkIn.scroll") {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SunLightHeader(title: "Sunscreen check-in", usesNativeNavigation: false)
                if let receipt {
                    AppText("Sunscreen logged", style: .title)
                    if let batchID = receipt.batchID, appState.canUndoChangeIfCurrent(batchID: batchID) {
                        Button("Undo") {
                            if case .success = appState.undoChangeIfCurrent(batchID: batchID) { self.receipt = nil }
                            else { error = "Couldn't undo this change. Please try again." }
                        }
                        .buttonStyle(SunSecondaryButtonStyle())
                    }
                    Button("Done") { router.goHome() }.buttonStyle(SunPrimaryButtonStyle())
                } else if let checkIn = appState.departureCheckIns.first(where: {
                    $0.resolution == .unconfirmed && $0.isOnDay(appState.referenceDate)
                }) {
                    AppText("Did you apply sunscreen?", style: .title)
                    AppText("You left home at \(checkIn.departedAt.formatted(date: .omitted, time: .shortened)). If you already applied, choose when.",
                            style: .body, color: AppColor.Text.secondary)
                    ForEach([0, 15, 30], id: \.self) { minutes in
                        Button(minutes == 0 ? "Just now" : "\(minutes) min ago") {
                            confirm(checkIn, at: appState.referenceDate.addingTimeInterval(Double(-minutes * 60)))
                        }
                        .buttonStyle(SunSecondaryButtonStyle())
                        .accessibilityIdentifier("checkIn.confirm.\(minutes)")
                    }
                    Button("Choose time") {
                        selectedTime = checkIn.departedAt
                        choosesTime = true
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    if choosesTime {
                        DatePicker("Application time", selection: $selectedTime,
                                   in: Calendar.current.startOfDay(for: appState.referenceDate)...appState.referenceDate,
                                   displayedComponents: .hourAndMinute)
                        Button("Save application") { confirm(checkIn, at: selectedTime) }
                            .buttonStyle(SunPrimaryButtonStyle())
                    }
                    Button("Remind me in 15 minutes") {
                        resolve(checkIn, action: .snooze(until: appState.referenceDate.addingTimeInterval(900)))
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                    .accessibilityIdentifier("checkIn.snooze")
                    Button("Dismiss") { resolve(checkIn, action: .dismiss) }
                        .buttonStyle(SunSecondaryButtonStyle())
                        .accessibilityIdentifier("checkIn.dismiss")
                } else {
                    AppText("No check-in waiting", style: .title)
                    Button("Back to Today") { router.goHome() }.buttonStyle(SunSecondaryButtonStyle())
                }
                if let error {
                    AppText(error, style: .body, color: AppPalette.warning)
                        .accessibilityIdentifier("checkIn.error")
                }
            }
        }
    }

    private func confirm(_ checkIn: DepartureCheckInSnapshot, at date: Date) {
        let defaults = appState.oneTapLogInput(for: date)
        resolve(checkIn, action: .confirm(appliedAt: date, spfLevel: defaults.spfLevel, notes: defaults.oneTapNotes))
    }

    private func resolve(_ checkIn: DepartureCheckInSnapshot, action: DepartureCheckInAction) {
        switch appState.resolveDepartureCheckIn(id: checkIn.id, action: action) {
        case let .success(receipt):
            error = nil
            if case .confirm = action {
                if receipt.didChange || appState.record(for: checkIn.departedAt) != nil { self.receipt = receipt }
                else { error = "This check-in has already been updated. Return to Today to review it." }
            }
            else { router.goHome() }
        case let .failure(failure): error = failure.localizedDescription
        }
    }
}
