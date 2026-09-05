import Foundation

/// Foreground timestamp and receipt wording policy; the shared mutation service owns the write.
@MainActor
struct SunclubLogRequestResolver {
    let calendar: Calendar
    let now: Date

    func application(
        method: VerificationMethod, part: DayPart, day: Date, source: LogSource,
        timestamp: Date?, duration: Double?, spfLevel: Int?, notes: String?
    ) throws -> SunclubMutationService.RecordRequest {
        let target = try validatedDay(day)
        let resolvedTimestamp: Date
        if let timestamp {
            guard calendar.isDate(timestamp, inSameDayAs: target), timestamp <= now else {
                throw SunclubHistoryMutationError.futureTime
            }
            resolvedTimestamp = timestamp
        } else if calendar.isDate(target, inSameDayAs: now), part == DayPart.resolve(for: now, calendar: calendar) {
            resolvedTimestamp = now
        } else {
            resolvedTimestamp = verifiedAt(for: target, in: part)
        }
        let sourceLabel: String
        switch source {
        case .automation, .deepLink, .widget, .watch: sourceLabel = " via \(source.rawValue)"
        default: sourceLabel = ""
        }
        return .init(
            day: target, verifiedAt: resolvedTimestamp, method: method, duration: duration,
            spfLevel: spfLevel, notes: notes, replaceOptionalFields: false, preserveExistingDuration: false,
            kind: .manualLog, summary: "Logged \(part.shortTitle.lowercased()) sunscreen\(sourceLabel)."
        )
    }

    func manualRecord(
        day: Date, dayPart: DayPart?, timestamp: Date?, existingTimestamp: Date?, spfLevel: Int?, notes: String?
    ) throws -> SunclubMutationService.RecordRequest {
        let target = try validatedDay(day)
        let resolvedTimestamp = timestamp ?? existingTimestamp
            ?? dayPart.map { verifiedAt(for: target, in: $0) } ?? defaultVerifiedAt(for: target)
        guard resolvedTimestamp <= now else { throw SunclubHistoryMutationError.futureTime }
        let kind: SunclubChangeKind = existingTimestamp == nil ? .historyBackfill : .historyEdit
        let summary = kind == .historyBackfill
            ? "Backfilled \(target.formatted(.dateTime.month().day()))."
            : "Edited \(target.formatted(.dateTime.month().day()))."
        return .init(
            day: target, verifiedAt: resolvedTimestamp, method: .manual,
            spfLevel: spfLevel, notes: notes, replaceOptionalFields: true, preserveExistingDuration: true,
            kind: kind, summary: summary
        )
    }

    private func validatedDay(_ day: Date) throws -> Date {
        let target = calendar.startOfDay(for: day)
        guard target <= calendar.startOfDay(for: now) else { throw SunclubHistoryMutationError.futureDate }
        return target
    }

    private func defaultVerifiedAt(for day: Date) -> Date {
        let current = calendar.dateComponents([.hour, .minute, .second], from: now)
        let target = calendar.dateComponents([.year, .month, .day], from: day)
        return calendar.date(from: DateComponents(year: target.year, month: target.month, day: target.day,
                                                  hour: current.hour, minute: current.minute, second: current.second)) ?? day
    }

    private func verifiedAt(for day: Date, in part: DayPart) -> Date {
        calendar.date(bySettingHour: part.defaultHour, minute: 0, second: 0, of: day) ?? day
    }
}
