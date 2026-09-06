import Foundation

/// Durable writes shared by foreground, Shortcut, URL and widget entry points.
/// Authorization and platform effects remain at those entry points.
@MainActor
final class SunclubMutationService {
    struct RecordRequest {
        let day: Date
        let verifiedAt: Date
        let method: VerificationMethod
        var duration: Double?
        let spfLevel: Int?
        let notes: String?
        let replaceOptionalFields: Bool
        let preserveExistingDuration: Bool
        let kind: SunclubChangeKind
        let summary: String
    }

    struct RecordResult {
        let batch: SunclubChangeBatch?
        let day: Date
        let verifiedAt: Date
        let kind: SunclubChangeKind
    }

    let history: SunclubHistoryService
    private let calendar: Calendar

    init(history: SunclubHistoryService, calendar: Calendar = .current) {
        self.history = history
        self.calendar = calendar
    }

    func upsert(_ request: RecordRequest) throws -> RecordResult {
        let day = calendar.startOfDay(for: request.day)
        let batch = try history.applyDayChange(
            for: day, kind: request.kind, summary: request.summary,
            changedFields: [.verifiedAt, .methodRawValue, .verificationDuration, .spfLevel, .notes]
        ) { existing in
            let spf = SunManualLogInput.normalizedSPF(request.spfLevel)
            let notes = SunManualLogInput.normalizedNotes(request.notes)
            guard var snapshot = existing else {
                return DailyRecordProjectionSnapshot(
                    startOfDay: day, verifiedAt: request.verifiedAt,
                    methodRawValue: request.method.rawValue, verificationDuration: request.duration,
                    spfLevel: spf, notes: notes, reapplyCount: 0, lastReappliedAt: nil
                )
            }
            snapshot.verifiedAt = request.verifiedAt
            snapshot.methodRawValue = request.method.rawValue
            snapshot.verificationDuration = request.preserveExistingDuration
                ? (request.duration ?? snapshot.verificationDuration) : request.duration
            if request.replaceOptionalFields {
                snapshot.spfLevel = spf
                snapshot.notes = notes
            } else {
                if let spf { snapshot.spfLevel = spf }
                if let notes { snapshot.notes = notes }
            }
            return snapshot
        }
        return RecordResult(batch: batch, day: day, verifiedAt: request.verifiedAt, kind: request.kind)
    }

    func recordDeparture(at timestamp: Date) throws -> SunclubChangeBatch? {
        try history.recordDeparture(at: timestamp)
    }

    func resolveDeparture(id: UUID, action: DepartureCheckInAction, now: Date) throws -> SunclubChangeBatch? {
        try history.resolveDeparture(id: id, action: action, now: now)
    }

    func reapply(on day: Date, at timestamp: Date, summary: String) throws -> SunclubChangeBatch? {
        try history.applyDayChange(
            for: day, kind: .reapply, summary: summary,
            changedFields: [.reapplyCount, .lastReappliedAt]
        ) { existing in
            guard var snapshot = existing else { return nil }
            snapshot.reapplyCount += 1
            snapshot.lastReappliedAt = timestamp
            return snapshot
        }
    }

    func updateReminder(_ settings: SmartReminderSettings, summary: String) throws -> SunclubChangeBatch? {
        let normalized = settings.normalized(
            fallbackHour: settings.weekdayTime.hour, fallbackMinute: settings.weekdayTime.minute
        )
        let current = try history.settings()
        guard current.smartReminderSettings != normalized
                || current.reminderHour != normalized.weekdayTime.hour
                || current.reminderMinute != normalized.weekdayTime.minute else { return nil }
        let encoded = try JSONEncoder().encode(normalized)
        return try history.applySettingsChange(
            kind: .reminderSettings, summary: summary,
            changedFields: [.reminderHour, .reminderMinute, .smartReminderSettingsData]
        ) { snapshot in
            snapshot.reminderHour = normalized.weekdayTime.hour
            snapshot.reminderMinute = normalized.weekdayTime.minute
            snapshot.smartReminderSettingsData = encoded
        }
    }

    func updateReapply(enabled: Bool, intervalMinutes: Int, summary: String) throws -> SunclubChangeBatch? {
        try history.applySettingsChange(
            kind: .reapplySettings, summary: summary,
            changedFields: [.reapplyReminderEnabled, .reapplyIntervalMinutes]
        ) { snapshot in
            snapshot.reapplyReminderEnabled = enabled
            snapshot.reapplyIntervalMinutes = max(30, min(480, intervalMinutes))
        }
    }

    /// The sole effect gate: failed writes throw before reaching it and no-ops have no batch.
    func followThrough(_ batch: SunclubChangeBatch?, effects: (SunclubChangeBatch) throws -> Void) rethrows {
        guard let batch else { return }
        try effects(batch)
    }
}
