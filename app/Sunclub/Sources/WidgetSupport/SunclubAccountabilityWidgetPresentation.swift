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
                status: friend.hasLoggedToday ? "Logged" : "Needs SPF",
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
            circularText: summary.openCount > 0 ? "\(summary.openCount)" : "\(summary.loggedCount)",
            actionURL: actionURL(summary: summary),
            latestPokeText: summary.latestPokeText,
            primaryPokeFriendID: summary.primaryPokeFriendID,
            friends: friends
        )
    }

    private static func content(
        summary: SunclubAccountabilitySummary,
        family: SunclubAccountabilityWidgetFamily
    ) -> Content {
        if !summary.isActive {
            return Content(
                title: family == .systemSmall ? "Invite" : "Add accountability",
                subtitle: "Optional",
                detail: "Share an invite when you want SPF witnesses.",
                actionText: "Set up",
                iconName: "person.badge.plus.fill"
            )
        }
        if summary.friendCount == 0 {
            return Content(
                title: family == .systemSmall ? "Add" : "Add a friend",
                subtitle: "No friends yet",
                detail: "Recruit one SPF accomplice.",
                actionText: "Invite",
                iconName: "person.badge.plus.fill"
            )
        }
        if let topOpenFriend = summary.topFriends.first(where: { !$0.hasLoggedToday }) {
            return Content(
                title: family == .systemSmall ? "Poke" : "Poke \(topOpenFriend.name)",
                subtitle: "\(summary.openCount) open sunscreen day\(summary.openCount == 1 ? "" : "s")",
                detail: "\(topOpenFriend.name) has not logged sunscreen yet.",
                actionText: summary.primaryPokeFriendID == nil ? "Open" : "Poke",
                iconName: "hand.tap.fill"
            )
        }
        return Content(
            title: family == .systemSmall ? "Logged" : "All logged",
            subtitle: "\(summary.loggedCount)/\(summary.friendCount) logged",
            detail: "The circle is suspiciously responsible today.",
            actionText: "View",
            iconName: "checkmark.seal.fill"
        )
    }

    private static func inlineText(summary: SunclubAccountabilitySummary) -> String {
        guard summary.isActive else {
            return "Sunclub accountability"
        }
        guard summary.friendCount > 0 else {
            return "Invite a Sunclub friend"
        }
        if summary.openCount > 0 {
            return "\(summary.openCount) open sunscreen day\(summary.openCount == 1 ? "" : "s")"
        }
        return "All friends logged"
    }

    private static func actionURL(summary: SunclubAccountabilitySummary) -> URL {
        if let primaryPokeFriendID = summary.primaryPokeFriendID {
            return SunclubDeepLink.accountabilityPoke(primaryPokeFriendID).url
        }

        return SunclubWidgetRoute.accountability.url
    }
}
