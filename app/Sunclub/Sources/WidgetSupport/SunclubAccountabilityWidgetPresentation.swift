import Foundation

enum SunclubAccountabilityWidgetFamily: String, CaseIterable, Sendable {
    case systemSmall
    case systemMedium
    case systemLarge
    case systemExtraLarge
    case accessoryInline
    case accessoryCircular
    case accessoryRectangular
}

struct SunclubAccountabilityWidgetFriend: Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let status: String
    let streak: String
}

struct SunclubAccountabilityWidgetPresentation: Equatable, Sendable {
    let family: SunclubAccountabilityWidgetFamily
    let title: String
    let subtitle: String
    let detail: String
    let actionText: String
    let iconName: String
    let friendCountText: String
    let openCountText: String
    let loggedCountText: String
    let inlineText: String
    let circularText: String
    let actionURL: URL
    let latestPokeText: String
    let primaryPokeFriendID: UUID?
    let friends: [SunclubAccountabilityWidgetFriend]
    let showsFriendStats: Bool

    private struct Content {
        let title: String
        let subtitle: String
        let detail: String
        let actionText: String
        let iconName: String
    }

    var accessibilityLabel: String {
        "\(title), \(subtitle), \(detail)"
    }

    static func make(
        summary: SunclubAccountabilitySummary,
        family: SunclubAccountabilityWidgetFamily
    ) -> SunclubAccountabilityWidgetPresentation {
        let content = content(summary: summary, family: family)
        let friends = summary.topFriends.map { friend in
            SunclubAccountabilityWidgetFriend(
                id: friend.id,
                name: friend.name,
                status: friend.hasLoggedToday ? "Protected" : "Needs SPF",
                streak: "\(friend.currentStreak)d"
            )
        }

        return SunclubAccountabilityWidgetPresentation(
            family: family,
            title: content.title,
            subtitle: content.subtitle,
            detail: content.detail,
            actionText: content.actionText,
            iconName: content.iconName,
            friendCountText: "\(summary.friendCount)",
            openCountText: "\(summary.openCount)",
            loggedCountText: "\(summary.loggedCount)",
            inlineText: inlineText(summary: summary),
            circularText: circularText(summary: summary),
            actionURL: actionURL(summary: summary),
            latestPokeText: summary.latestPokeText,
            primaryPokeFriendID: summary.primaryPokeFriendID,
            friends: friends,
            showsFriendStats: summary.isActive && summary.friendCount > 0
        )
    }

    private static func content(
        summary: SunclubAccountabilitySummary,
        family: SunclubAccountabilityWidgetFamily
    ) -> Content {
        if !summary.isActive {
            return Content(
                title: "Add a sunscreen buddy",
                subtitle: "Invite a friend",
                detail: "Share check-ins, not streak pressure.",
                actionText: "Set up in app",
                iconName: "person.badge.plus.fill"
            )
        }
        if summary.friendCount == 0 {
            return Content(
                title: "Add a sunscreen buddy",
                subtitle: "Invite a friend",
                detail: "Share check-ins, not streak pressure.",
                actionText: "Set up in app",
                iconName: "person.badge.plus.fill"
            )
        }
        if let topOpenFriend = summary.topFriends.first(where: { !$0.hasLoggedToday }) {
            guard summary.primaryPokeFriendID != nil else {
                return Content(
                    title: family == .systemSmall ? "\(topOpenFriend.name) needs SPF" : "Message \(topOpenFriend.name)",
                    subtitle: "\(summary.openCount) friend\(summary.openCount == 1 ? "" : "s") open",
                    detail: "\(topOpenFriend.name) has not logged sunscreen yet.",
                    actionText: "Open",
                    iconName: "person.2.fill"
                )
            }
            return Content(
                title: family == .systemSmall ? "\(topOpenFriend.name) needs SPF" : "Poke \(topOpenFriend.name)",
                subtitle: "\(summary.openCount) friend\(summary.openCount == 1 ? "" : "s") open",
                detail: "\(topOpenFriend.name) has not logged sunscreen yet.",
                actionText: "Poke",
                iconName: "person.2.fill"
            )
        }
        return Content(
            title: family == .systemSmall ? "Protected" : "All buddies protected",
            subtitle: "\(summary.loggedCount)/\(summary.friendCount) logged",
            detail: "Everyone checked in today.",
            actionText: "View",
            iconName: "checkmark.seal.fill"
        )
    }

    private static func inlineText(summary: SunclubAccountabilitySummary) -> String {
        guard summary.isActive else {
            return "Add a sunscreen buddy"
        }
        guard summary.friendCount > 0 else {
            return "Add a sunscreen buddy"
        }
        if summary.openCount > 0 {
            return "\(summary.openCount) friend\(summary.openCount == 1 ? "" : "s") need SPF"
        }
        return "All buddies protected"
    }

    private static func circularText(summary: SunclubAccountabilitySummary) -> String {
        guard summary.isActive, summary.friendCount > 0 else {
            return "+"
        }
        if summary.openCount > 0 {
            return "\(summary.openCount)"
        }
        return "OK"
    }

    private static func actionURL(summary: SunclubAccountabilitySummary) -> URL {
        if let primaryPokeFriendID = summary.primaryPokeFriendID {
            return SunclubDeepLink.accountabilityPoke(primaryPokeFriendID).url
        }

        return SunclubWidgetRoute.accountability.url
    }
}
