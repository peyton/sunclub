import Foundation

enum SunclubDeepLink: Equatable {
    case widgetLogToday
    case widgetRoute(SunclubWidgetRoute)

    init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare(SunclubRuntimeConfiguration.urlScheme) == .orderedSame else {
            return nil
        }

        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard host == "widget" else {
            return nil
        }

        if pathComponents == ["log-today"] {
            self = .widgetLogToday
            return
        }

        if pathComponents.count == 2,
           pathComponents.first == "open",
           let route = SunclubWidgetRoute(rawValue: pathComponents[1]) {
            self = .widgetRoute(route)
            return
        }

        return nil
    }

    var url: URL {
        switch self {
        case .widgetLogToday:
            return URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://widget/log-today")!
        case let .widgetRoute(route):
            return route.url
        }
    }
}
