import Foundation

enum SunclubLogTodayWidgetFamily: String, CaseIterable, Sendable {
    case systemSmall
    case systemMedium
    case systemLarge
    case systemExtraLarge
    case accessoryInline
    case accessoryCircular
    case accessoryRectangular
}

enum SunclubLogTodayWidgetState: String, Sendable {
    case needsSetup
    case open
    case logged
    case reapplyDue
}

enum SunclubLogTodayWidgetTapAction: Equatable, Sendable {
    case logTodayInPlace
    case logReapplyInPlace
    case open(SunclubWidgetRoute)
}

struct SunclubLogTodayWidgetMetric: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
    let systemImageName: String

    init(title: String, value: String, systemImageName: String) {
        id = "\(title)-\(systemImageName)"
        self.title = title
        self.value = value
        self.systemImageName = systemImageName
    }
}

struct SunclubLogTodayWidgetPresentation: Equatable, Sendable {
    let family: SunclubLogTodayWidgetFamily
    let state: SunclubLogTodayWidgetState
    let eyebrow: String
    let title: String
    let subtitle: String
    let detail: String
    let actionText: String
    let iconName: String
    let inlineText: String
    let circularText: String
    let metrics: [SunclubLogTodayWidgetMetric]

    var accessibilityLabel: String {
        "\(eyebrow), \(title), \(subtitle), \(detail)"
    }

    var tapAction: SunclubLogTodayWidgetTapAction {
        switch state {
        case .needsSetup:
            return .open(.summary)
        case .open:
            return .logTodayInPlace
        case .logged:
            return .open(.updateToday)
        case .reapplyDue:
            return .logReapplyInPlace
        }
    }

    static func make(
        snapshot: SunclubWidgetSnapshot,
        now: Date = Date(),
        family: SunclubLogTodayWidgetFamily,
        calendar: Calendar = Calendar.current
    ) -> SunclubLogTodayWidgetPresentation {
        let state = state(for: snapshot, now: now, calendar: calendar)
        let uvText = uvSummary(for: snapshot)
        let reapplyText = reapplyLabel(for: snapshot, now: now, calendar: calendar)
        let detail = detailText(
            snapshot: snapshot,
            state: state,
            uvText: uvText,
            reapplyText: reapplyText,
            family: family,
            calendar: calendar
        )
        let subtitle = subtitle(for: state, snapshot: snapshot, calendar: calendar)

        return SunclubLogTodayWidgetPresentation(
            family: family,
            state: state,
            eyebrow: eyebrow(for: state),
            title: title(for: state),
            subtitle: subtitle,
            detail: detail,
            actionText: actionText(for: state),
            iconName: iconName(for: state),
            inlineText: inlineText(for: state, subtitle: subtitle, uvText: uvText, reapplyText: reapplyText),
            circularText: circularText(for: state, snapshot: snapshot),
            metrics: metrics(for: snapshot, now: now, calendar: calendar)
        )
    }

    private static func state(
        for snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> SunclubLogTodayWidgetState {
        guard snapshot.isOnboardingComplete else {
            return .needsSetup
        }
        guard snapshot.hasLoggedToday(now: now, calendar: calendar) else {
            return .open
        }
        if let reapplyDeadline = snapshot.reapplyDeadline(now: now, calendar: calendar),
           reapplyDeadline <= now {
            return .reapplyDue
        }

        return .logged
    }

    private static func eyebrow(for state: SunclubLogTodayWidgetState) -> String {
        switch state {
        case .needsSetup, .open, .logged, .reapplyDue:
            return "Today"
        }
    }

    private static func title(for state: SunclubLogTodayWidgetState) -> String {
        switch state {
        case .needsSetup:
            return "Set up"
        case .open:
            return "Log sunscreen"
        case .logged:
            return "Logged"
        case .reapplyDue:
            return "Reapply due"
        }
    }

    private static func subtitle(
        for state: SunclubLogTodayWidgetState,
        snapshot: SunclubWidgetSnapshot,
        calendar: Calendar
    ) -> String {
        switch state {
        case .needsSetup:
            return "Start tracking"
        case .open:
            return "Not logged yet"
        case .logged, .reapplyDue:
            if let todaySPFLevel = snapshot.todaySPFLevel {
                return "SPF \(todaySPFLevel)"
            }
            return loggedTimeLabel(for: snapshot, calendar: calendar)
        }
    }

    private static func detailText(
        snapshot: SunclubWidgetSnapshot,
        state: SunclubLogTodayWidgetState,
        uvText: String,
        reapplyText: String?,
        family: SunclubLogTodayWidgetFamily,
        calendar: Calendar
    ) -> String {
        switch state {
        case .needsSetup:
            return "Open the app to finish setup."
        case .open:
            if let mostUsedSPF = snapshot.mostUsedSPF {
                return family == .systemSmall ? uvText : "Usual SPF \(mostUsedSPF)"
            }
            return uvText == "Log today" ? "Log sunscreen" : uvText
        case .logged:
            return reapplyText ?? loggedTimeLabel(for: snapshot, calendar: calendar)
        case .reapplyDue:
            return "Reapply due"
        }
    }

    private static func actionText(for state: SunclubLogTodayWidgetState) -> String {
        switch state {
        case .needsSetup:
            return "Open"
        case .open:
            return "Log"
        case .logged:
            return "Edit"
        case .reapplyDue:
            return "Reapply"
        }
    }

    private static func iconName(for state: SunclubLogTodayWidgetState) -> String {
        switch state {
        case .needsSetup:
            return "sun.max.fill"
        case .open, .reapplyDue:
            return "sun.max.fill"
        case .logged:
            return "checkmark.seal.fill"
        }
    }

    private static func inlineText(
        for state: SunclubLogTodayWidgetState,
        subtitle: String,
        uvText: String,
        reapplyText: String?
    ) -> String {
        switch state {
        case .needsSetup:
            return "Set up Sunclub"
        case .open:
            return uvText == "Log today" ? "Log sunscreen" : "Log, \(uvText)"
        case .logged:
            return reapplyText ?? subtitle
        case .reapplyDue:
            return "Reapply due"
        }
    }

    private static func circularText(
        for state: SunclubLogTodayWidgetState,
        snapshot: SunclubWidgetSnapshot
    ) -> String {
        switch state {
        case .needsSetup:
            return "Open"
        case .open:
            return snapshot.currentUVIndex.map { "UV\($0)" } ?? "Log"
        case .logged, .reapplyDue:
            return state == .reapplyDue ? "Due" : "OK"
        }
    }

    private static func metrics(
        for snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> [SunclubLogTodayWidgetMetric] {
        var metrics = [
            SunclubLogTodayWidgetMetric(
                title: "Week",
                value: "\(snapshot.currentWeekAppliedValue(now: now, calendar: calendar))/7",
                systemImageName: "calendar"
            ),
            SunclubLogTodayWidgetMetric(
                title: "Month",
                value: monthPercent(snapshot: snapshot, now: now, calendar: calendar),
                systemImageName: "calendar.badge.checkmark"
            )
        ]

        if let todaySPFLevel = snapshot.todaySPFLevel {
            metrics.append(
                SunclubLogTodayWidgetMetric(
                    title: "SPF",
                    value: "\(todaySPFLevel)",
                    systemImageName: "sun.max.fill"
                )
            )
        } else if let peakUVIndex = snapshot.peakUVIndex ?? snapshot.currentUVIndex {
            metrics.append(
                SunclubLogTodayWidgetMetric(
                    title: "UV",
                    value: "\(peakUVIndex) \(UVLevel.from(index: peakUVIndex).displayName)",
                    systemImageName: "sun.max.fill"
                )
            )
        }

        return metrics
    }

    private static func uvSummary(for snapshot: SunclubWidgetSnapshot) -> String {
        if let currentUVIndex = snapshot.currentUVIndex {
            return "UV \(currentUVIndex) \(UVLevel.from(index: currentUVIndex).displayName)"
        }
        if let peakUVIndex = snapshot.peakUVIndex {
            return "UV \(peakUVIndex) \(UVLevel.from(index: peakUVIndex).displayName)"
        }
        return "Log today"
    }

    private static func monthPercent(
        snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> String {
        let applied = snapshot.monthlyAppliedValue(now: now, calendar: calendar)
        let total = snapshot.monthlyDayValue(now: now, calendar: calendar)
        guard total > 0 else {
            return "0%"
        }

        return "\(Int((Double(applied) / Double(total)) * 100))%"
    }

    private static func reapplyLabel(
        for snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> String? {
        guard let reapplyDeadline = snapshot.reapplyDeadline(now: now, calendar: calendar) else {
            return nil
        }

        if reapplyDeadline <= now {
            return "Reapply due"
        }

        return "Reapply in \(durationLabel(until: reapplyDeadline, now: now))"
    }

    private static func loggedTimeLabel(
        for snapshot: SunclubWidgetSnapshot,
        calendar: Calendar
    ) -> String {
        guard let lastVerifiedAt = snapshot.lastVerifiedAt else {
            return "Logged"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "Logged \(formatter.string(from: lastVerifiedAt))"
    }

    private static func durationLabel(until deadline: Date, now: Date) -> String {
        let minutesUntilDeadline = max(1, Int(ceil(deadline.timeIntervalSince(now) / 60)))
        let hours = minutesUntilDeadline / 60
        let minutes = minutesUntilDeadline % 60

        switch (hours, minutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(minutes)m"
        }
    }
}
