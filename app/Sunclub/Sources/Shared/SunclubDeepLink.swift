import Foundation

enum SunclubDeepLink: Equatable {
    case widgetLogToday
    case widgetRoute(SunclubWidgetRoute)
    case accountabilityInvite(String)
    case accountabilityPoke(UUID?)
    case automation(SunclubAutomationRequest)

    init?(url: URL) {
        guard SunclubRuntimeConfiguration.supportsURLScheme(url.scheme) else {
            return nil
        }

        let host = (url.host ?? "").lowercased()
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        let query = SunclubDeepLinkQuery(url: url)

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
        case "automation":
            if let action = Self.automationAction(pathComponents: pathComponents, query: query) {
                self = .automation(
                    SunclubAutomationRequest(
                        action: action,
                        callback: nil
                    )
                )
                return
            }
        case "x-callback-url":
            if let action = Self.automationAction(pathComponents: pathComponents, query: query) {
                self = .automation(
                    SunclubAutomationRequest(
                        action: action,
                        callback: SunclubXCallback(
                            successURL: query.url("x-success"),
                            errorURL: query.url("x-error"),
                            cancelURL: query.url("x-cancel")
                        )
                    )
                )
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
        case let .automation(request):
            return request.url
        }
    }

    private static func automationAction(
        pathComponents: [String],
        query: SunclubDeepLinkQuery
    ) -> SunclubAutomationAction? {
        guard let name = pathComponents.first?.lowercased() else {
            return nil
        }

        switch name {
        case "log-today":
            return .logToday(spfLevel: query.int("spf"), notes: query.string("notes"))
        case "save-log":
            return .saveLog(
                day: query.date("date"),
                time: query.time("time"),
                spfLevel: query.int("spf"),
                notes: query.string("notes")
            )
        case "reapply":
            return .reapply
        case "status":
            return .status
        case "set-reminder":
            guard let kindValue = query.string("kind").flatMap(SunclubAutomationReminderKind.init(rawValue:)),
                  let time = query.time("time") else {
                return nil
            }
            return .setReminder(kind: kindValue, time: time)
        case "set-reapply":
            guard let enabled = query.bool("enabled") else {
                return nil
            }
            return .setReapply(enabled: enabled, intervalMinutes: query.int("interval"))
        case "set-toggle":
            guard let toggle = query.string("name").flatMap(SunclubAutomationToggle.init(rawValue:)),
                  let enabled = query.bool("enabled") else {
                return nil
            }
            return .setToggle(toggle, enabled: enabled)
        case "import-friend":
            guard let code = query.string("code") else {
                return nil
            }
            return .importFriend(code: code)
        case "poke-friend":
            guard let friendID = query.string("id").flatMap(UUID.init(uuidString:)) else {
                return nil
            }
            return .pokeFriend(id: friendID)
        case "open":
            guard let route = query.string("route").flatMap(SunclubAutomationRoute.init(rawValue:)) else {
                return nil
            }
            return .open(route)
        default:
            return nil
        }
    }
}

struct SunclubAutomationRequest: Equatable {
    let action: SunclubAutomationAction
    let callback: SunclubXCallback?

    var url: URL {
        var components = URLComponents()
        components.scheme = SunclubRuntimeConfiguration.urlScheme
        components.host = callback == nil ? "automation" : "x-callback-url"
        components.path = "/\(action.identifier)"
        var items = queryItems(for: action)
        if let callback {
            if let successURL = callback.successURL {
                items.append(URLQueryItem(name: "x-success", value: successURL.absoluteString))
            }
            if let errorURL = callback.errorURL {
                items.append(URLQueryItem(name: "x-error", value: errorURL.absoluteString))
            }
            if let cancelURL = callback.cancelURL {
                items.append(URLQueryItem(name: "x-cancel", value: cancelURL.absoluteString))
            }
        }
        components.queryItems = items.isEmpty ? nil : items
        return components.url!
    }

    private func queryItems(for action: SunclubAutomationAction) -> [URLQueryItem] {
        switch action {
        case let .logToday(spfLevel, notes):
            return optionalItems([
                ("spf", spfLevel.map(String.init)),
                ("notes", notes)
            ])
        case let .saveLog(day, time, spfLevel, notes):
            return optionalItems([
                ("date", day.map(Self.dateString)),
                ("time", time.map(Self.timeString)),
                ("spf", spfLevel.map(String.init)),
                ("notes", notes)
            ])
        case let .setReminder(kind, time):
            return [
                URLQueryItem(name: "kind", value: kind.rawValue),
                URLQueryItem(name: "time", value: Self.timeString(time))
            ]
        case let .setReapply(enabled, intervalMinutes):
            return optionalItems([
                ("enabled", enabled ? "true" : "false"),
                ("interval", intervalMinutes.map(String.init))
            ])
        case let .setToggle(toggle, enabled):
            return [
                URLQueryItem(name: "name", value: toggle.rawValue),
                URLQueryItem(name: "enabled", value: enabled ? "true" : "false")
            ]
        case let .importFriend(code):
            return [URLQueryItem(name: "code", value: code)]
        case let .pokeFriend(id):
            return [URLQueryItem(name: "id", value: id.uuidString)]
        case let .open(route):
            return [URLQueryItem(name: "route", value: route.rawValue)]
        case .reapply, .status, .exportBackup, .createSkinHealthReport, .createStreakCard:
            return []
        }
    }

    private func optionalItems(_ values: [(String, String?)]) -> [URLQueryItem] {
        values.compactMap { name, value in
            value.map { URLQueryItem(name: name, value: $0) }
        }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func timeString(_ time: ReminderTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }
}

struct SunclubXCallback: Equatable {
    let successURL: URL?
    let errorURL: URL?
    let cancelURL: URL?
}

private struct SunclubDeepLinkQuery {
    private let items: [URLQueryItem]

    init(url: URL) {
        items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    func string(_ name: String) -> String? {
        items.first(where: { $0.name == name })?.value
    }

    func int(_ name: String) -> Int? {
        string(name).flatMap(Int.init)
    }

    func bool(_ name: String) -> Bool? {
        guard let value = string(name)?.lowercased() else {
            return nil
        }
        switch value {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }

    func url(_ name: String) -> URL? {
        string(name).flatMap(URL.init(string:))
    }

    func date(_ name: String) -> Date? {
        guard let value = string(name) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    func time(_ name: String) -> ReminderTime? {
        guard let value = string(name) else {
            return nil
        }
        let pieces = value.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count == 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return ReminderTime(hour: hour, minute: minute)
    }
}
