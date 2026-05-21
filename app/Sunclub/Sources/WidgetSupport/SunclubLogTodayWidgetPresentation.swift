import Foundation

enum SunclubLogTodayWidgetFamily: String, CaseIterable, Sendable {
    case systemSmall
    case systemMedium
    case systemLarge
    case systemExtraLarge
    case accessoryCircular
    case accessoryRectangular
}

enum SunclubLogTodayWidgetState: String, Sendable {
    case open
    case logged
}

enum SunclubLogTodayWidgetTapAction: Equatable, Sendable {
    case logTodayInPlace
    case logReapplyInPlace
    case open(SunclubWidgetRoute)
    case none
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
        switch state {
        case .open:
            return "Log Sunscreen"
        case .logged:
            return "Sunscreen logged"
        }
    }

    var tapAction: SunclubLogTodayWidgetTapAction {
        switch state {
        case .open:
            return .logTodayInPlace
        case .logged:
            return .none
        }
    }

    static func make(
        snapshot: SunclubWidgetSnapshot,
        now: Date = Date(),
        family: SunclubLogTodayWidgetFamily,
        calendar: Calendar = Calendar.current
    ) -> SunclubLogTodayWidgetPresentation {
        let isLogged = snapshot.hasLoggedToday(now: now, calendar: calendar)
        return SunclubLogTodayWidgetPresentation(
            family: family,
            state: isLogged ? .logged : .open,
            eyebrow: "",
            title: isLogged ? "" : "Log Sunscreen",
            subtitle: "",
            detail: "",
            actionText: isLogged ? "" : "Log Sunscreen",
            iconName: isLogged ? "checkmark" : "sun.max.fill",
            inlineText: isLogged ? "" : "Log Sunscreen",
            circularText: isLogged ? "Done" : "Log",
            metrics: []
        )
    }
}
