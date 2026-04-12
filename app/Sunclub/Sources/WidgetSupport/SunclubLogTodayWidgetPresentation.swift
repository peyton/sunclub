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

        return SunclubLogTodayWidgetPresentation(
            family: family,
            state: state,
            eyebrow: eyebrow(for: state),
            title: title(for: state, family: family),
            subtitle: subtitle(for: state, streak: streak, uvText: uvText),
            detail: detail,
            actionText: actionText(for: state, family: family),
            iconName: iconName(for: state),
            inlineText: inlineText(for: state, streak: streak, uvText: uvText, reapplyText: reapplyText),
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

        return snapshot.hasLoggedToday(now: now, calendar: calendar) ? .logged : .open
    }

    private static func eyebrow(for state: SunclubLogTodayWidgetState) -> String {
        switch state {
        case .needsSetup:
            return "Sunclub"
        case .open, .logged:
            return "Today"
        }
    }

    private static func title(
        for state: SunclubLogTodayWidgetState,
        family: SunclubLogTodayWidgetFamily
    ) -> String {
        switch state {
        case .needsSetup:
            return family == .systemSmall ? "Open" : "Set up Sunclub"
        case .open:
            return family == .systemSmall ? "Log" : "Log sunscreen"
        case .logged:
            return family == .systemSmall ? "Done" : "Logged today"
        }
    }

    private static func subtitle(
        for state: SunclubLogTodayWidgetState,
        streak: Int,
        uvText: String
    ) -> String {
        switch state {
        case .needsSetup:
            return "Start tracking"
        case .open:
            return uvText
        case .logged:
            return "\(streak)d streak"
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
            if family == .systemSmall {
                return "Tap to add SPF"
            }
            if let mostUsedSPF = snapshot.mostUsedSPF {
                return "Usual SPF \(mostUsedSPF)"
            }
            return uvText == "Today open" ? "Add sunscreen in one tap." : "Add sunscreen before peak sun."
        case .logged:
            return reapplyText ?? "You're covered for today."
        }
    }

    private static func actionText(
        for state: SunclubLogTodayWidgetState,
        family: SunclubLogTodayWidgetFamily
    ) -> String {
        switch state {
        case .needsSetup:
            return "Open"
        case .open:
            return family == .systemSmall ? "Tap" : "Tap to log"
        case .logged:
            return "Update"
        }
    }

    private static func iconName(for state: SunclubLogTodayWidgetState) -> String {
        switch state {
        case .needsSetup:
            return "sun.horizon.fill"
        case .open:
            return "sun.max.fill"
        case .logged:
            return "checkmark.seal.fill"
        }
    }

    private static func inlineText(
        for state: SunclubLogTodayWidgetState,
        streak: Int,
        uvText: String,
        reapplyText: String?
    ) -> String {
        switch state {
        case .needsSetup:
            return "Open Sunclub"
        case .open:
            return "Log SPF - \(uvText)"
        case .logged:
            return reapplyText ?? "Logged - \(streak)d streak"
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
        case .logged:
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
                systemImageName: "flame.fill"
            ),
            SunclubLogTodayWidgetMetric(
                title: "Week",
                value: "\(snapshot.weeklyValue(now: now, calendar: calendar))/7",
                systemImageName: "calendar"
            ),
            SunclubLogTodayWidgetMetric(
                title: "Month",
                value: "\(snapshot.monthlyAppliedValue(now: now, calendar: calendar))/\(snapshot.monthlyDayValue(now: now, calendar: calendar))",
                systemImageName: "chart.bar.fill"
            )
        ]

        if let peakUVIndex = snapshot.peakUVIndex ?? snapshot.currentUVIndex {
            metrics.append(
                SunclubLogTodayWidgetMetric(
                    title: "UV",
                    value: "\(peakUVIndex)",
                    systemImageName: "sun.max.fill"
                )
            )
        } else if let mostUsedSPF = snapshot.mostUsedSPF {
            metrics.append(
                SunclubLogTodayWidgetMetric(
                    title: "SPF",
                    value: "\(mostUsedSPF)",
                    systemImageName: "drop.fill"
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
