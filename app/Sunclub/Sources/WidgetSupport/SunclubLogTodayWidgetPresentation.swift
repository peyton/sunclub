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
    let homeAction: HomeDailyPlanAction

    var accessibilityLabel: String {
        switch homeAction {
        case .logToday:
            return "Log Sunscreen"
        case .logReapply:
            return "Reapply sunscreen now"
        case .viewProgress:
            return "Sunscreen logged"
        case .openSettings:
            return "Open Sunclub to finish setup"
        default:
            return actionText
        }
    }

    var tapAction: SunclubLogTodayWidgetTapAction {
        switch homeAction {
        case .logToday:
            return .logTodayInPlace
        case .logReapply:
            return .logReapplyInPlace
        case .viewProgress:
            return .open(.summary)
        case .openSettings:
            return .open(.updateToday)
        default:
            return .open(.updateToday)
        }
    }

    static func make(
        snapshot: SunclubWidgetSnapshot,
        now: Date = Date(),
        family: SunclubLogTodayWidgetFamily,
        calendar: Calendar = Calendar.current
    ) -> SunclubLogTodayWidgetPresentation {
        let action = snapshot.homeDailyPlanAction(now: now, calendar: calendar)
        let isReapply = action == .logReapply
        let isLogged = action == .viewProgress
        let title: String
        let actionText: String
        let iconName: String
        let inlineText: String
        let circularText: String
        switch action {
        case .logToday:
            title = "Log Sunscreen"
            actionText = "Log Sunscreen"
            iconName = "sun.max.fill"
            inlineText = "Log Sunscreen"
            circularText = "Log"
        case .logReapply:
            title = "Reapply now"
            actionText = "Reapply now"
            iconName = "timer"
            inlineText = "Reapply"
            circularText = "Again"
        case .viewProgress:
            title = ""
            actionText = ""
            iconName = "checkmark"
            inlineText = ""
            circularText = "Done"
        default:
            title = "Open Sunclub"
            actionText = "Open Sunclub"
            iconName = "arrow.up.forward.app.fill"
            inlineText = "Open Sunclub"
            circularText = "Open"
        }
        return SunclubLogTodayWidgetPresentation(
            family: family,
            state: isLogged && !isReapply ? .logged : .open,
            eyebrow: "",
            title: title,
            subtitle: "",
            detail: "",
            actionText: actionText,
            iconName: iconName,
            inlineText: inlineText,
            circularText: circularText,
            metrics: [],
            homeAction: action
        )
    }
}
