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

    static func make(
        snapshot: SunclubWidgetSnapshot,
        now: Date = Date(),
        family: SunclubLogTodayWidgetFamily,
        calendar: Calendar = Calendar.current
    ) -> SunclubLogTodayWidgetPresentation {
        let state = state(for: snapshot, now: now, calendar: calendar)
        let streak = snapshot.streakValue(now: now, calendar: calendar)
        let uvText = uvSummary(for: snapshot)
        let reapplyText = reapplyLabel(for: snapshot, now: now, calendar: calendar)
        let detail = detailText(
            snapshot: snapshot,
            state: state,
            uvText: uvText,
            reapplyText: reapplyText,
            family: family
        )
        let subtitle = subtitle(for: state, snapshot: snapshot, streak: streak)

        return SunclubLogTodayWidgetPresentation(
            family: family,
            state: state,
            eyebrow: eyebrow(for: state),
            title: title(for: state),
            subtitle: subtitle,
            detail: detail,
            actionText: actionText(for: state),
            iconName: iconName(for: state),
            inlineText: inlineText(for: state, subtitle: subtitle, streak: streak, uvText: uvText, reapplyText: reapplyText),
            circularText: circularText(for: state, snapshot: snapshot, streak: streak),
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
            return "Protected"
        case .reapplyDue:
            return "SPF due?"
        }
    }

    private static func subtitle(
        for state: SunclubLogTodayWidgetState,
        snapshot: SunclubWidgetSnapshot,
        streak: Int
    ) -> String {
        switch state {
        case .needsSetup:
            return "Start tracking"
        case .open:
            return "No SPF logged today"
        case .logged, .reapplyDue:
            let loggedText = snapshot.todaySPFLevel.map { "SPF \($0) logged" } ?? "Protected today"
            return "\(loggedText) - \(streak)d streak"
        }
    }

    private static func detailText(
        snapshot: SunclubWidgetSnapshot,
        state: SunclubLogTodayWidgetState,
        uvText: String,
        reapplyText: String?,
        family: SunclubLogTodayWidgetFamily
    ) -> String {
        switch state {
        case .needsSetup:
            return "Open the app to finish setup."
        case .open:
            if let mostUsedSPF = snapshot.mostUsedSPF {
                return family == .systemSmall ? uvText : "Usual SPF \(mostUsedSPF)"
            }
            return uvText == "Today open" ? "Tap to add SPF" : uvText
        case .logged:
            return reapplyText ?? "Protected today"
        case .reapplyDue:
            return "Reapply now"
        }
    }

    private static func actionText(for state: SunclubLogTodayWidgetState) -> String {
        switch state {
        case .needsSetup:
            return "Open"
        case .open:
            return "Log"
        case .logged:
            return "Update"
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
        streak: Int,
        uvText: String,
        reapplyText: String?
    ) -> String {
        switch state {
        case .needsSetup:
            return "Open Today"
        case .open:
            return "Log SPF - \(uvText)"
        case .logged:
            return reapplyText ?? "\(subtitle)"
        case .reapplyDue:
            return reapplyText ?? "SPF due - \(streak)d streak"
        }
    }

    private static func circularText(
        for state: SunclubLogTodayWidgetState,
        snapshot: SunclubWidgetSnapshot,
        streak: Int
    ) -> String {
        switch state {
        case .needsSetup:
            return "Open"
        case .open:
            return snapshot.currentUVIndex.map { "UV\($0)" } ?? "Log"
        case .logged, .reapplyDue:
            return "\(streak)d"
        }
    }

    private static func metrics(
        for snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> [SunclubLogTodayWidgetMetric] {
        var metrics = [
            SunclubLogTodayWidgetMetric(
                title: "Streak",
                value: "\(snapshot.streakValue(now: now, calendar: calendar))d",
                systemImageName: "checkmark.seal.fill"
            ),
            SunclubLogTodayWidgetMetric(
                title: "This week",
                value: "\(snapshot.currentWeekAppliedValue(now: now, calendar: calendar))/7",
                systemImageName: "calendar"
            ),
            SunclubLogTodayWidgetMetric(
                title: "Best",
                value: "\(max(snapshot.longestStreak, snapshot.streakValue(now: now, calendar: calendar)))d",
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
                    value: "\(peakUVIndex)",
                    systemImageName: "sun.max.fill"
                )
            )
        }

        return metrics
    }

    private static func uvSummary(for snapshot: SunclubWidgetSnapshot) -> String {
        if let peakUVIndex = snapshot.peakUVIndex {
            return "Peak UV \(peakUVIndex)"
        }
        if let currentUVIndex = snapshot.currentUVIndex {
            return "UV \(currentUVIndex)"
        }
        return "Today open"
    }

    private static func reapplyLabel(
        for snapshot: SunclubWidgetSnapshot,
        now: Date,
        calendar: Calendar
    ) -> String? {
        guard let reapplyDeadline = snapshot.reapplyDeadline(now: now, calendar: calendar) else {
            return nil
        }

        return "Reapply \(reapplyDeadline.formatted(date: .omitted, time: .shortened))"
    }
}
