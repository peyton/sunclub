import Foundation

/// User-owned, permission-free preferences intended for restore on another device.
/// System authorization is excluded because it is device-specific.
struct SunclubRestorablePreferences: Codable, Equatable, Sendable {
    static let currentVersion = 2

    let version: Int
    let preferredName: String
    let uvBriefing: SunclubUVBriefingPreferences
    let automation: SunclubAutomationPreferences

    init(growthSettings: SunclubGrowthSettings) {
        version = Self.currentVersion
        preferredName = growthSettings.preferredName
        uvBriefing = growthSettings.uvBriefing
        automation = growthSettings.automation
    }

    init(
        version: Int = Self.currentVersion,
        preferredName: String,
        uvBriefing: SunclubUVBriefingPreferences,
        automation: SunclubAutomationPreferences
    ) {
        self.version = version
        self.preferredName = preferredName
        self.uvBriefing = uvBriefing
        self.automation = automation
    }

    func merging(into current: SunclubGrowthSettings) -> SunclubGrowthSettings {
        var merged = current
        if merged.preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            merged.preferredName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        merged.uvBriefing = mergedUVBriefing(current: current.uvBriefing)
        merged.automation = mergedAutomation(current: current.automation)

        return merged
    }

    /// Explicit recovery replaces only restorable fields; device permissions and usage stay local.
    func replacingRestorableFields(in current: SunclubGrowthSettings) -> SunclubGrowthSettings {
        var restored = current
        restored.preferredName = preferredName
        restored.uvBriefing = uvBriefing
        restored.automation = automation
        return restored
    }

    var hasMeaningfulContent: Bool {
        !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || uvBriefing != SunclubUVBriefingPreferences()
            || automation != SunclubAutomationPreferences()
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
