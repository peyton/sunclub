import Foundation

/// Replays actual user changes, not the imported sibling values carried by full revision snapshots.
enum SettingsImportUndo {
    static func replay(
        before: SettingsProjectionSnapshot,
        after: SettingsProjectionSnapshot,
        onto baseline: SettingsProjectionSnapshot,
        fields: Set<SunclubTrackedField>,
        explicitFieldWrites: Bool = false
    ) throws -> SettingsProjectionSnapshot {
        var result = baseline
        func copy<Value: Equatable>(_ field: SunclubTrackedField, _ key: WritableKeyPath<SettingsProjectionSnapshot, Value>) {
            if fields.contains(field), explicitFieldWrites || before[keyPath: key] != after[keyPath: key] {
                result[keyPath: key] = after[keyPath: key]
            }
        }
        copy(.hasCompletedOnboarding, \.hasCompletedOnboarding)
        copy(.reminderHour, \.reminderHour)
        copy(.reminderMinute, \.reminderMinute)
        copy(.weeklyHour, \.weeklyHour)
        copy(.weeklyWeekday, \.weeklyWeekday)
        copy(.dailyPhraseState, \.dailyPhraseState)
        copy(.weeklyPhraseState, \.weeklyPhraseState)
        copy(.reapplyReminderEnabled, \.reapplyReminderEnabled)
        copy(.reapplyIntervalMinutes, \.reapplyIntervalMinutes)
        copy(.usesLiveUV, \.usesLiveUV)
        copy(.selectedUVPlace, \.selectedUVPlace)
        copy(.sunscreenProfile, \.sunscreenProfile)
        if fields.contains(.smartReminderSettingsData), before.smartReminderSettingsData != after.smartReminderSettingsData {
            if after.smartReminderSettingsData == nil {
                result.smartReminderSettingsData = nil
            } else {
                let old = reminderSettings(before)
                let new = reminderSettings(after)
                var restored = reminderSettings(baseline)
                restored.weekdayTime.hour = value(old.weekdayTime.hour, new.weekdayTime.hour, restored.weekdayTime.hour)
                restored.weekdayTime.minute = value(old.weekdayTime.minute, new.weekdayTime.minute, restored.weekdayTime.minute)
                restored.weekendTime.hour = value(old.weekendTime.hour, new.weekendTime.hour, restored.weekendTime.hour)
                restored.weekendTime.minute = value(old.weekendTime.minute, new.weekendTime.minute, restored.weekendTime.minute)
                restored.followsTravelTimeZone = value(old.followsTravelTimeZone, new.followsTravelTimeZone, restored.followsTravelTimeZone)
                restored.anchoredTimeZoneIdentifier = value(old.anchoredTimeZoneIdentifier, new.anchoredTimeZoneIdentifier, restored.anchoredTimeZoneIdentifier)
                restored.streakRiskEnabled = value(old.streakRiskEnabled, new.streakRiskEnabled, restored.streakRiskEnabled)
                restored.leaveHomeReminder.isEnabled = value(old.leaveHomeReminder.isEnabled, new.leaveHomeReminder.isEnabled, restored.leaveHomeReminder.isEnabled)
                restored.leaveHomeReminder.homeLocation = value(old.leaveHomeReminder.homeLocation, new.leaveHomeReminder.homeLocation, restored.leaveHomeReminder.homeLocation)
                restored.leaveHomeReminder.radiusMeters = value(old.leaveHomeReminder.radiusMeters, new.leaveHomeReminder.radiusMeters, restored.leaveHomeReminder.radiusMeters)
                result.smartReminderSettingsData = try JSONEncoder().encode(restored)
            }
        }
        if fields.contains(.restorablePreferences), before.restorablePreferences != after.restorablePreferences {
            result.restorablePreferences = replayPreferences(
                before.restorablePreferences, after.restorablePreferences, baseline.restorablePreferences
            )
        }
        return result
    }

    private static func reminderSettings(_ snapshot: SettingsProjectionSnapshot) -> SmartReminderSettings {
        let settings = Settings()
        settings.apply(snapshot: snapshot)
        return settings.smartReminderSettings
    }

    private static func replayPreferences(
        _ before: SunclubRestorablePreferences?,
        _ after: SunclubRestorablePreferences?,
        _ baseline: SunclubRestorablePreferences?
    ) -> SunclubRestorablePreferences? {
        guard let after else { return nil }
        let defaults = SunclubRestorablePreferences(growthSettings: SunclubGrowthSettings(
            accountability: SunclubAccountabilitySettings(localProfileID: after.accountability.localProfileID)
        ))
        let old = before ?? defaults
        let base = baseline ?? defaults
        let renewedFriendIDs = Set(after.accountability.connections.filter { connection in
            old.accountability.connections.contains {
                $0.id == connection.id && $0.relationshipToken != connection.relationshipToken
            }
        }.map(\.friendSnapshotID))
        return SunclubRestorablePreferences(
            version: value(old.version, after.version, base.version),
            preferredName: value(old.preferredName, after.preferredName, base.preferredName),
            uvBriefing: SunclubUVBriefingPreferences(
                dailyBriefingEnabled: value(old.uvBriefing.dailyBriefingEnabled, after.uvBriefing.dailyBriefingEnabled, base.uvBriefing.dailyBriefingEnabled),
                extremeAlertEnabled: value(old.uvBriefing.extremeAlertEnabled, after.uvBriefing.extremeAlertEnabled, base.uvBriefing.extremeAlertEnabled),
                morningHour: value(old.uvBriefing.morningHour, after.uvBriefing.morningHour, base.uvBriefing.morningHour),
                morningMinute: value(old.uvBriefing.morningMinute, after.uvBriefing.morningMinute, base.uvBriefing.morningMinute)
            ),
            friends: collection(old.friends, after.friends, base.friends, merge: replayFriend) { _, friend in
                renewedFriendIDs.contains(friend.id)
            },
            accountability: replayAccountability(old.accountability, after.accountability, base.accountability),
            automation: SunclubAutomationPreferences(
                shortcutWritesEnabled: value(old.automation.shortcutWritesEnabled, after.automation.shortcutWritesEnabled, base.automation.shortcutWritesEnabled),
                urlOpenActionsEnabled: value(old.automation.urlOpenActionsEnabled, after.automation.urlOpenActionsEnabled, base.automation.urlOpenActionsEnabled),
                urlWriteActionsEnabled: value(old.automation.urlWriteActionsEnabled, after.automation.urlWriteActionsEnabled, base.automation.urlWriteActionsEnabled),
                callbackResultDetailsEnabled: value(old.automation.callbackResultDetailsEnabled, after.automation.callbackResultDetailsEnabled, base.automation.callbackResultDetailsEnabled)
            )
        )
    }

    private static func replayAccountability(
        _ old: SunclubAccountabilitySettings,
        _ new: SunclubAccountabilitySettings,
        _ base: SunclubAccountabilitySettings
    ) -> SunclubAccountabilitySettings {
        SunclubAccountabilitySettings(
            localProfileID: value(old.localProfileID, new.localProfileID, base.localProfileID),
            displayName: value(old.displayName, new.displayName, base.displayName),
            inviteTokens: collection(old.inviteTokens, new.inviteTokens, base.inviteTokens),
            activatedAt: value(old.activatedAt, new.activatedAt, base.activatedAt),
            dismissedAt: value(old.dismissedAt, new.dismissedAt, base.dismissedAt),
            pendingInvites: collection(old.pendingInvites, new.pendingInvites, base.pendingInvites),
            connections: collection(old.connections, new.connections, base.connections, merge: replayConnection) {
                $0.relationshipToken != $1.relationshipToken
            },
            pokeHistory: collection(old.pokeHistory, new.pokeHistory, base.pokeHistory),
            lastPublishedAt: base.lastPublishedAt,
            subscriptionsInstalledAt: base.subscriptionsInstalledAt,
            subscriptionInstallVersion: base.subscriptionInstallVersion
        )
    }

    private static func value<Value: Equatable>(_ old: Value, _ new: Value, _ base: Value) -> Value {
        old == new ? base : new
    }

    private static func replayFriend(
        _ old: SunclubFriendSnapshot, _ new: SunclubFriendSnapshot, _ base: SunclubFriendSnapshot
    ) -> SunclubFriendSnapshot {
        var result = base
        result.name = value(old.name, new.name, base.name)
        result.currentStreak = value(old.currentStreak, new.currentStreak, base.currentStreak)
        result.longestStreak = value(old.longestStreak, new.longestStreak, base.longestStreak)
        result.hasLoggedToday = value(old.hasLoggedToday, new.hasLoggedToday, base.hasLoggedToday)
        result.lastSharedAt = value(old.lastSharedAt, new.lastSharedAt, base.lastSharedAt)
        result.seasonStyleRawValue = value(old.seasonStyleRawValue, new.seasonStyleRawValue, base.seasonStyleRawValue)
        return result
    }

    private static func replayConnection(
        _ old: SunclubFriendConnection, _ new: SunclubFriendConnection, _ base: SunclubFriendConnection
    ) -> SunclubFriendConnection {
        var result = base
        result.friendSnapshotID = value(old.friendSnapshotID, new.friendSnapshotID, base.friendSnapshotID)
        result.friendDisplayName = value(old.friendDisplayName, new.friendDisplayName, base.friendDisplayName)
        result.relationshipToken = value(old.relationshipToken, new.relationshipToken, base.relationshipToken)
        result.acceptedAt = value(old.acceptedAt, new.acceptedAt, base.acceptedAt)
        result.lastStatusRefreshAt = value(old.lastStatusRefreshAt, new.lastStatusRefreshAt, base.lastStatusRefreshAt)
        result.lastPokeSentAt = value(old.lastPokeSentAt, new.lastPokeSentAt, base.lastPokeSentAt)
        result.lastPokeReceivedAt = value(old.lastPokeReceivedAt, new.lastPokeReceivedAt, base.lastPokeReceivedAt)
        result.canDirectPoke = value(old.canDirectPoke, new.canDirectPoke, base.canDirectPoke)
        return result
    }

    private static func collection<Value: Identifiable & Equatable>(
        _ old: [Value], _ new: [Value], _ base: [Value],
        merge: (Value, Value, Value) -> Value = { _, new, _ in new },
        adoptsReplacement: (Value, Value) -> Bool = { _, _ in false }
    ) -> [Value] {
        // An imported-only relationship is not adopted merely by a background status refresh.
        let oldIDs = Set(old.map(\.id))
        let newIDs = Set(new.map(\.id))
        var result = base.filter { !oldIDs.contains($0.id) || newIDs.contains($0.id) }
        for item in new {
            let previous = old.first(where: { $0.id == item.id })
            if let index = result.firstIndex(where: { $0.id == item.id }) {
                result[index] = previous.map { merge($0, item, result[index]) } ?? item
            } else if previous.map({ adoptsReplacement($0, item) }) ?? true {
                result.append(item)
            }
        }
        return result
    }
}
