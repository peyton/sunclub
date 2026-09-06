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
        let defaults = SunclubRestorablePreferences(growthSettings: SunclubGrowthSettings())
        let old = before ?? defaults
        let base = baseline ?? defaults
        return SunclubRestorablePreferences(
            version: value(old.version, after.version, base.version),
            preferredName: value(old.preferredName, after.preferredName, base.preferredName),
            uvBriefing: SunclubUVBriefingPreferences(
                dailyBriefingEnabled: value(old.uvBriefing.dailyBriefingEnabled, after.uvBriefing.dailyBriefingEnabled, base.uvBriefing.dailyBriefingEnabled),
                extremeAlertEnabled: value(old.uvBriefing.extremeAlertEnabled, after.uvBriefing.extremeAlertEnabled, base.uvBriefing.extremeAlertEnabled),
                morningHour: value(old.uvBriefing.morningHour, after.uvBriefing.morningHour, base.uvBriefing.morningHour),
                morningMinute: value(old.uvBriefing.morningMinute, after.uvBriefing.morningMinute, base.uvBriefing.morningMinute)
            ),
            automation: SunclubAutomationPreferences(
                shortcutWritesEnabled: value(old.automation.shortcutWritesEnabled, after.automation.shortcutWritesEnabled, base.automation.shortcutWritesEnabled),
                urlOpenActionsEnabled: value(old.automation.urlOpenActionsEnabled, after.automation.urlOpenActionsEnabled, base.automation.urlOpenActionsEnabled),
                urlWriteActionsEnabled: value(old.automation.urlWriteActionsEnabled, after.automation.urlWriteActionsEnabled, base.automation.urlWriteActionsEnabled),
                callbackResultDetailsEnabled: value(old.automation.callbackResultDetailsEnabled, after.automation.callbackResultDetailsEnabled, base.automation.callbackResultDetailsEnabled)
            )
        )
    }

    private static func value<Value: Equatable>(_ old: Value, _ new: Value, _ base: Value) -> Value {
        old == new ? base : new
    }

}
