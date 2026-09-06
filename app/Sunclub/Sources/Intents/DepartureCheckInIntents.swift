import AppIntents
import Foundation

struct SnoozeDepartureCheckInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Remind me in 15 minutes"
    static let openAppWhenRun = false
    static let isDiscoverable = false
    @Parameter(title: "Check-in") var checkInID: String
    init() {}
    init(checkInID: String) { self.checkInID = checkInID }
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: checkInID) else { throw SunclubAutomationError.invalidInput("Invalid check-in.") }
        let result = try SunclubAutomationRuntime.performStandalone(.snoozeDepartureCheckIn(id: id), invocation: .widget)
        await DepartureCheckInIntentEffects.sync(didChange: result.didChange == true)
        return .result()
    }
}

struct DismissDepartureCheckInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Dismiss check-in"
    static let openAppWhenRun = false
    static let isDiscoverable = false
    @Parameter(title: "Check-in") var checkInID: String
    init() {}
    init(checkInID: String) { self.checkInID = checkInID }
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: checkInID) else { throw SunclubAutomationError.invalidInput("Invalid check-in.") }
        let result = try SunclubAutomationRuntime.performStandalone(.dismissDepartureCheckIn(id: id), invocation: .widget)
        await DepartureCheckInIntentEffects.sync(didChange: result.didChange == true)
        return .result()
    }
}

enum DepartureCheckInIntentAction: String, AppEnum {
    case confirm, snooze, dismiss
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Check-in action")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .confirm: "Confirm application", .snooze: "Remind me in 15 minutes", .dismiss: "Dismiss"
    ]
}

struct ResolveDepartureCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Sunscreen Check-in"
    static let description = IntentDescription("Confirm an application time, snooze, or dismiss today's departure check-in.")
    @Parameter(title: "Action") var action: DepartureCheckInIntentAction
    @Parameter(title: "Application time") var appliedAt: Date?
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let operation: SunclubAutomationAction
        switch action {
        case .confirm:
            guard let appliedAt else { throw SunclubAutomationError.invalidInput("Choose when you applied sunscreen.") }
            operation = .confirmDepartureCheckIn(id: nil, appliedAt: appliedAt)
        case .snooze: operation = .snoozeDepartureCheckIn(id: nil)
        case .dismiss: operation = .dismissDepartureCheckIn(id: nil)
        }
        let result = try SunclubAutomationRuntime.performStandalone(operation, invocation: .shortcut)
        await DepartureCheckInIntentEffects.sync(didChange: result.didChange == true)
        return .result(dialog: IntentDialog(stringLiteral: result.message))
    }
}

@MainActor
enum DepartureCheckInIntentEffects {
    static func sync(didChange: Bool) async {
        guard didChange else { return }
        let snapshot = SunclubWidgetSnapshotStore().load()
        let now = Date()
        await SunclubDepartureReminderBridge.sync(snapshot: snapshot, now: now)
        await SunclubLoggingReminderBridge.sync(snapshot: snapshot, now: now)
        await SunclubLiveActivitySnapshotBridge.updateExisting(snapshot: snapshot, now: now)
    }
}
