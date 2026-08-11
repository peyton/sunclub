import Foundation

/// User-owned, permission-free preferences intended for restore on another device.
/// The envelope includes private relationship credentials; backup UI must tell people to
/// store exported files securely. System authorization is excluded because it is device-specific.
struct SunclubRestorablePreferences: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let preferredName: String
    let uvBriefing: SunclubUVBriefingPreferences
    let friends: [SunclubFriendSnapshot]
    let accountability: SunclubAccountabilitySettings
    let automation: SunclubAutomationPreferences

    init(growthSettings: SunclubGrowthSettings) {
        version = Self.currentVersion
        preferredName = growthSettings.preferredName
        uvBriefing = growthSettings.uvBriefing
        friends = growthSettings.friends
        accountability = growthSettings.accountability.restorableProjection
        automation = growthSettings.automation
    }

    init(
        version: Int = Self.currentVersion,
        preferredName: String,
        uvBriefing: SunclubUVBriefingPreferences,
        friends: [SunclubFriendSnapshot],
        accountability: SunclubAccountabilitySettings,
        automation: SunclubAutomationPreferences
    ) {
        self.version = version
        self.preferredName = preferredName
        self.uvBriefing = uvBriefing
        self.friends = friends
        self.accountability = accountability
        self.automation = automation
    }

    func merging(into current: SunclubGrowthSettings) -> SunclubGrowthSettings {
        var merged = current
        if merged.preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.preferredName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        merged.uvBriefing = mergedUVBriefing(current: current.uvBriefing)
        merged.automation = mergedAutomation(current: current.automation)
        merged.friends = mergedFriends(current: current.friends, imported: friends)

        if !current.accountability.hasRestorableContent,
           accountability.hasRestorableContent {
            merged.accountability = accountability
        }

        return merged
    }

    var hasMeaningfulContent: Bool {
        !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || uvBriefing != SunclubUVBriefingPreferences()
            || !friends.isEmpty
            || accountability.hasRestorableContent
            || automation != SunclubAutomationPreferences()
    }

    private func mergedFriends(
        current: [SunclubFriendSnapshot],
        imported: [SunclubFriendSnapshot]
    ) -> [SunclubFriendSnapshot] {
        var byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        for friend in imported {
            if let existing = byID[friend.id], existing.lastSharedAt >= friend.lastSharedAt {
                continue
            }
            byID[friend.id] = friend
        }
        return byID.values.sorted { lhs, rhs in
            if lhs.name != rhs.name {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func mergedUVBriefing(
        current: SunclubUVBriefingPreferences
    ) -> SunclubUVBriefingPreferences {
        let defaults = SunclubUVBriefingPreferences()
        return SunclubUVBriefingPreferences(
            dailyBriefingEnabled: importedValue(
                uvBriefing.dailyBriefingEnabled,
                current: current.dailyBriefingEnabled,
                default: defaults.dailyBriefingEnabled
            ),
            extremeAlertEnabled: importedValue(
                uvBriefing.extremeAlertEnabled,
                current: current.extremeAlertEnabled,
                default: defaults.extremeAlertEnabled
            ),
            morningHour: importedValue(
                uvBriefing.morningHour,
                current: current.morningHour,
                default: defaults.morningHour
            ),
            morningMinute: importedValue(
                uvBriefing.morningMinute,
                current: current.morningMinute,
                default: defaults.morningMinute
            )
        )
    }

    private func mergedAutomation(
        current: SunclubAutomationPreferences
    ) -> SunclubAutomationPreferences {
        let defaults = SunclubAutomationPreferences()
        return SunclubAutomationPreferences(
            shortcutWritesEnabled: importedValue(
                automation.shortcutWritesEnabled,
                current: current.shortcutWritesEnabled,
                default: defaults.shortcutWritesEnabled
            ),
            urlOpenActionsEnabled: importedValue(
                automation.urlOpenActionsEnabled,
                current: current.urlOpenActionsEnabled,
                default: defaults.urlOpenActionsEnabled
            ),
            urlWriteActionsEnabled: importedValue(
                automation.urlWriteActionsEnabled,
                current: current.urlWriteActionsEnabled,
                default: defaults.urlWriteActionsEnabled
            ),
            callbackResultDetailsEnabled: importedValue(
                automation.callbackResultDetailsEnabled,
                current: current.callbackResultDetailsEnabled,
                default: defaults.callbackResultDetailsEnabled
            )
        )
    }

    private func importedValue<Value: Equatable>(
        _ imported: Value,
        current: Value,
        default defaultValue: Value
    ) -> Value {
        imported == defaultValue && current != defaultValue ? current : imported
    }
}

private extension SunclubAccountabilitySettings {
    var restorableProjection: SunclubAccountabilitySettings {
        SunclubAccountabilitySettings(
            localProfileID: localProfileID,
            displayName: displayName,
            inviteTokens: inviteTokens,
            activatedAt: activatedAt,
            dismissedAt: dismissedAt,
            pendingInvites: pendingInvites,
            connections: connections,
            pokeHistory: pokeHistory,
            lastPublishedAt: nil,
            subscriptionsInstalledAt: nil,
            subscriptionInstallVersion: 0
        )
    }

    var hasRestorableContent: Bool {
        !displayName.isEmpty
            || !inviteTokens.isEmpty
            || activatedAt != nil
            || dismissedAt != nil
            || !pendingInvites.isEmpty
            || !connections.isEmpty
            || !pokeHistory.isEmpty
    }
}
