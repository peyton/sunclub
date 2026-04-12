import Foundation

enum SunclubDeepLink: Equatable {
    case widgetLogToday
    case widgetRoute(SunclubWidgetRoute)
    case accountabilityInvite(String)
    case accountabilityPoke(UUID?)

    init?(url: URL) {
        guard url.scheme?.caseInsensitiveCompare(SunclubRuntimeConfiguration.urlScheme) == .orderedSame else {
            return nil
        }

        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "widget":
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
        case "accountability":
            if pathComponents == ["invite"],
               let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value {
                self = .accountabilityInvite(code)
                return
            }

            if pathComponents == ["poke"] {
                let friendID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "friend" })?
                    .value
                    .flatMap(UUID.init(uuidString:))
                self = .accountabilityPoke(friendID)
                return
            }
        default:
            break
        }

        return nil
    }

    var url: URL {
        switch self {
        case .widgetLogToday:
            return URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://widget/log-today")!
        case let .widgetRoute(route):
            return route.url
        case let .accountabilityInvite(code):
            var components = URLComponents()
            components.scheme = SunclubRuntimeConfiguration.urlScheme
            components.host = "accountability"
            components.path = "/invite"
            components.queryItems = [URLQueryItem(name: "code", value: code)]
            return components.url!
        case let .accountabilityPoke(friendID):
            var components = URLComponents()
            components.scheme = SunclubRuntimeConfiguration.urlScheme
            components.host = "accountability"
            components.path = "/poke"
            if let friendID {
                components.queryItems = [URLQueryItem(name: "friend", value: friendID.uuidString)]
            }
            return components.url!
        }
    }
}
