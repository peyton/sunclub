import Foundation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class ImportUndoSettingsTests: XCTestCase {
    // Undo must restore explicit false, default numbers, and nil fields, not recover imported values into them.
    func testUndoRestoresDefaultAndEmptySettings() throws {
        let target = try makeHistory()
        let before = try target.settings().projectionSnapshot
        let session = try importSettings(into: target)
        XCTAssertTrue(try target.settings().usesLiveUV)

        _ = try target.restoreImportSession(session)
        try target.refreshProjectedState()

        XCTAssertEqual(try target.settings().projectionSnapshot, before)
    }

    // A later edit must survive without carrying its unchanged imported sibling fields forward.
    func testUndoKeepsOnlyLaterIndependentSettingChanges() throws {
        let target = try makeHistory()
        let session = try importSettings(into: target)
        _ = try target.applySettingsChange(kind: .reminderSettings, summary: "Later edit", changedFields: [.reminderHour]) {
            $0.reminderHour = 6
        }

        _ = try target.restoreImportSession(session)

        XCTAssertEqual(try target.settings().reminderHour, 6)
        XCTAssertFalse(try target.settings().usesLiveUV)
        XCTAssertNil(try target.settings().selectedUVPlace)
        XCTAssertNil(try target.settings().sunscreenProfile)
    }

    func testUndoKeepsLaterClearedSettingAndRepeatedUndoKeepsNewEdits() throws {
        let target = try makeHistory()
        let session = try importSettings(into: target)
        _ = try target.applySettingsChange(kind: .reminderSettings, summary: "Clear", changedFields: [.usesLiveUV]) {
            $0.usesLiveUV = false
        }
        _ = try target.restoreImportSession(session)
        _ = try target.applySettingsChange(kind: .reminderSettings, summary: "New edit", changedFields: [.reminderHour]) {
            $0.reminderHour = 5
        }

        _ = try target.restoreImportSession(session)

        XCTAssertEqual(try target.settings().reminderHour, 5)
        XCTAssertFalse(try target.settings().usesLiveUV)
    }

    // Clearing only the SwiftData projection must also clear the active and persisted preference copies.
    func testAppUndoRemovesEnvelopePreferencesFromEveryCopy() throws {
        let (target, store) = try makeApp()
        let original = store.load()
        let session = try target.importBackupDocument(envelopeBackup()).importSessionID
        XCTAssertFalse(target.growthSettings.automation.shortcutWritesEnabled)
        XCTAssertFalse(target.growthSettings.accountability.inviteTokens.isEmpty)

        _ = try target.restoreImportedChanges(for: session).get()
        target.refresh()

        XCTAssertEqual(target.growthSettings.preferredName, original.preferredName)
        XCTAssertEqual(target.growthSettings.automation, original.automation)
        XCTAssertEqual(target.growthSettings.uvBriefing, original.uvBriefing)
        XCTAssertEqual(target.growthSettings.accountability, original.accountability)
        XCTAssertEqual(store.load(), target.growthSettings)
        XCTAssertEqual(target.settings.restorablePreferences?.automation, original.automation)
    }

    // Editing the name must not legitimize imported automation flags or credentials in the same envelope.
    func testAppUndoPreservesLaterNameWithoutImportedSiblingPreferences() throws {
        let (target, store) = try makeApp()
        let original = store.load()
        let session = try target.importBackupDocument(envelopeBackup()).importSessionID
        target.updatePreferredDisplayName("My name")

        _ = try target.restoreImportedChanges(for: session).get()
        target.refresh()

        XCTAssertEqual(target.growthSettings.preferredName, "My name")
        XCTAssertEqual(target.growthSettings.automation, original.automation)
        XCTAssertEqual(target.growthSettings.uvBriefing, original.uvBriefing)
        XCTAssertTrue(target.growthSettings.accountability.inviteTokens.isEmpty)
        XCTAssertEqual(target.growthSettings.accountability.localProfileID, original.accountability.localProfileID)
        XCTAssertEqual(store.load(), target.growthSettings)
    }

    func testUndoPreservesDirectStoreEditWithoutImportedSiblingPreferences() throws {
        let (target, store) = try makeApp()
        let session = try target.importBackupDocument(envelopeBackup()).importSessionID
        var later = store.load()
        later.uvBriefing.extremeAlertEnabled = true
        store.save(later)

        _ = try target.restoreImportedChanges(for: session).get()

        XCTAssertTrue(target.growthSettings.uvBriefing.extremeAlertEnabled)
        XCTAssertTrue(target.growthSettings.uvBriefing.dailyBriefingEnabled)
        XCTAssertEqual(target.growthSettings.uvBriefing.morningHour, 8)
        XCTAssertTrue(target.growthSettings.automation.shortcutWritesEnabled)
        XCTAssertEqual(target.growthSettings.preferredName, "")
        XCTAssertEqual(store.load(), target.growthSettings)
    }

    func testUndoReplaysOnlyChangedLeavesOfSmartReminders() throws {
        let (source, _) = try makeApp()
        source.updateReminderTime(for: .weekend, hour: 11, minute: 30)
        source.updateTravelTimeZoneHandling(followsTravelTimeZone: false)
        let (target, _) = try makeApp()
        let session = try target.importBackupDocument(source.exportBackupDocument()).importSessionID
        target.updateReminderTime(for: .weekday, hour: 6, minute: 15)

        _ = try target.restoreImportedChanges(for: session).get()

        XCTAssertEqual(target.settings.smartReminderSettings.weekdayTime, ReminderTime(hour: 6, minute: 15))
        XCTAssertEqual(target.settings.smartReminderSettings.weekendTime, ReminderTime(hour: 8, minute: 0))
        XCTAssertTrue(target.settings.smartReminderSettings.followsTravelTimeZone)
        XCTAssertEqual(target.settings.reminderHour, 6)
        XCTAssertEqual(target.settings.reminderMinute, 15)
    }

    func testUndoPreferencesStayRestoredAfterRelaunchAndPreserveDeviceOnlyData() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let (target, store) = try makeApp(context: context)
        let original = store.load()
        let session = try target.importBackupDocument(envelopeBackup()).importSessionID
        _ = try target.restoreImportedChanges(for: session).get()

        let (reopened, _) = try makeApp(context: context, store: store)

        XCTAssertEqual(reopened.growthSettings.accountability.localProfileID, original.accountability.localProfileID)
        XCTAssertTrue(reopened.growthSettings.accountability.inviteTokens.isEmpty)
        XCTAssertEqual(reopened.growthSettings.automation, original.automation)
        XCTAssertEqual(reopened.growthSettings.scannedSPFLevels, original.scannedSPFLevels)
        XCTAssertEqual(reopened.growthSettings.successPhraseState, original.successPhraseState)
        XCTAssertEqual(reopened.growthSettings.healthKit, original.healthKit)
    }

    func testImportUndoAndRedoPreserveCurrentProfileSyncMetadata() throws {
        let store = ImportUndoSettingsStore()
        var original = store.load()
        original.accountability.displayName = "Local"
        original.accountability.lastPublishedAt = Date(timeIntervalSince1970: 1_780_000_100)
        original.accountability.subscriptionsInstalledAt = Date(timeIntervalSince1970: 1_780_000_200)
        original.accountability.subscriptionInstallVersion = 2
        store.save(original)
        let (target, _) = try makeApp(store: store)
        let session = try target.importBackupDocument(envelopeBackup()).importSessionID
        let batch = try XCTUnwrap(target.changeBatches.first { $0.kind == .importLocal })

        _ = try target.restoreImportedChanges(for: session).get()

        XCTAssertEqual(target.growthSettings.accountability, original.accountability)
        XCTAssertEqual(store.load().accountability, original.accountability)
        let projection = try XCTUnwrap(target.settings.restorablePreferences).accountability
        XCTAssertNil(projection.lastPublishedAt)
        XCTAssertNil(projection.subscriptionsInstalledAt)
        XCTAssertEqual(projection.subscriptionInstallVersion, 0)

        _ = try target.redoChange(batch.id).get()

        XCTAssertEqual(target.growthSettings.accountability, original.accountability)
        XCTAssertEqual(store.load().accountability, original.accountability)
    }

    func testRestoringAnotherProfileDoesNotReuseEitherProfilesDeviceMetadata() {
        let current = SunclubGrowthSettings(accountability: SunclubAccountabilitySettings(
            lastPublishedAt: Date(timeIntervalSince1970: 1_780_000_100),
            subscriptionsInstalledAt: Date(timeIntervalSince1970: 1_780_000_200),
            subscriptionInstallVersion: 2
        ))
        let imported = SunclubAccountabilitySettings(
            displayName: "Another profile",
            lastPublishedAt: Date(timeIntervalSince1970: 1_780_000_300),
            subscriptionsInstalledAt: Date(timeIntervalSince1970: 1_780_000_400),
            subscriptionInstallVersion: 2
        )
        let preferences = SunclubRestorablePreferences(
            preferredName: "", uvBriefing: SunclubUVBriefingPreferences(), friends: [],
            accountability: imported, automation: SunclubAutomationPreferences()
        )

        let restored = preferences.replacingRestorableFields(in: current)

        XCTAssertEqual(restored.accountability.localProfileID, imported.localProfileID)
        XCTAssertEqual(restored.accountability.displayName, "Another profile")
        XCTAssertNil(restored.accountability.lastPublishedAt)
        XCTAssertNil(restored.accountability.subscriptionsInstalledAt)
        XCTAssertEqual(restored.accountability.subscriptionInstallVersion, 0)
    }

    // Older envelope-only imports lack an ownership marker; do not pretend a selective inverse is known.
    func testUnattributedOlderEnvelopeFailsWithoutChangingSettings() throws {
        let target = try makeHistory()
        let source = try makeHistory()
        let session = try target.importDomainData(from: source.fetchContext(), sourceDescription: "Older import")
        let importBatch = try XCTUnwrap(target.changeBatches().first { $0.kind == .importLocal })
        importBatch.inverseOfBatchID = nil
        try target.fetchContext().save()
        let preferences = try XCTUnwrap(envelopeBackup().payload.restorablePreferences)
        _ = try target.applySettingsChange(kind: .preferenceSettings, summary: "Updated private restorable preferences.", changedFields: [.restorablePreferences]) {
            $0.restorablePreferences = preferences
        }
        let before = try target.settings().projectionSnapshot
        let beforeIDs = Set(try target.changeBatches().map(\.id))

        XCTAssertThrowsError(try target.restoreImportSession(session.importSessionID)) { error in
            guard case HistoryServiceError.importPreferencesUnavailable = error else {
                return XCTFail("Expected an attribution error, received \(error)")
            }
        }

        XCTAssertEqual(try target.settings().projectionSnapshot, before)
        XCTAssertEqual(Set(try target.changeBatches().map(\.id)), beforeIDs)
    }

    func testHistoryUndoImportBatchUsesTheImportRestorePoint() throws {
        let target = try makeHistory()
        _ = try importSettings(into: target)
        let batch = try XCTUnwrap(target.changeBatches().first { $0.kind == .importLocal })
        _ = try target.applySettingsChange(kind: .reminderSettings, summary: "Later edit", changedFields: [.reminderHour]) {
            $0.reminderHour = 6
        }

        _ = try target.undo(batchID: batch.id)

        XCTAssertEqual(try target.settings().reminderHour, 6)
        XCTAssertFalse(try target.settings().usesLiveUV)
        XCTAssertNil(try target.settings().sunscreenProfile)
    }

    func testImportUndoRedoUndoRemovesImportedSettingsAgain() throws {
        let history = try makeHistory()
        let session = try importSettings(into: history)
        let batch = try XCTUnwrap(history.changeBatches().first { $0.kind == .importLocal })
        _ = try history.undo(batchID: batch.id)
        _ = try history.redo(batchID: batch.id)
        XCTAssertTrue(try history.settings().usesLiveUV)

        _ = try history.restoreImportSession(session)

        XCTAssertFalse(try history.settings().usesLiveUV)
        XCTAssertNil(try history.settings().sunscreenProfile)
    }

    func testPublishingImportDoesNotPublishLocalUndo() throws {
        let history = try makeHistory()
        let session = try importSettings(into: history)
        let originalIDs = try XCTUnwrap(history.importSession(id: session)).importedBatchIDs
        let undo = try history.restoreImportSession(session)

        let published = try history.publishImportedChanges(for: session)

        XCTAssertTrue(undo.isLocalOnly)
        XCTAssertEqual(published.publishedBatchCount, originalIDs.count)
    }

    func testAmbiguousRemotePreferenceLeavesFailAtomically() throws {
        let history = try makeHistory()
        let summary = try SunclubBackupService().importBackupDocument(envelopeBackup(), into: history.fetchContext())
        var snapshot = try history.settings().projectionSnapshot
        let imported = try XCTUnwrap(snapshot.restorablePreferences)
        var changed = imported.replacingRestorableFields(in: SunclubGrowthSettings())
        changed.preferredName = "Remote name"
        snapshot.restorablePreferences = SunclubRestorablePreferences(growthSettings: changed)
        let next = (try history.changeBatches().compactMap(\.logicalOrder).max() ?? 0) + 1
        let remote = SunclubChangeBatch(
            logicalOrder: next, kind: .preferenceSettings, scope: .settings, scopeIdentifier: "settings",
            authorDeviceID: "independent-device", summary: "Remote preferences"
        )
        history.fetchContext().insert(remote)
        history.fetchContext().insert(SettingsRevision(batch: remote, snapshot: snapshot, changedFields: [.restorablePreferences]))
        try history.fetchContext().save()
        try history.refreshProjectedState()
        let before = try history.settings().projectionSnapshot
        let beforeIDs = Set(try history.changeBatches().map(\.id))

        XCTAssertThrowsError(try history.restoreImportSession(summary.importSessionID)) { error in
            guard case HistoryServiceError.importUndoAmbiguous = error else {
                return XCTFail("Expected an ambiguous-Undo error, received \(error)")
            }
        }

        XCTAssertEqual(try history.settings().projectionSnapshot, before)
        XCTAssertEqual(Set(try history.changeBatches().map(\.id)), beforeIDs)
    }

    func testAppUndoImportBatchClearsEveryPreferenceCopy() throws {
        let (target, store) = try makeApp()
        let original = store.load()
        let summary = try target.importBackupDocument(envelopeBackup())
        let batch = try XCTUnwrap(target.changeBatches.first {
            $0.kind == .importLocal && $0.importSessionID == summary.importSessionID
        })

        _ = try target.undoChange(batch.id).get()
        target.refresh()

        XCTAssertEqual(target.growthSettings.automation, original.automation)
        XCTAssertEqual(target.growthSettings.accountability, original.accountability)
        XCTAssertEqual(store.load(), target.growthSettings)
    }

    func testUndoKeepsLaterFriendChangeWithoutImportedSiblingFields() throws {
        let original = SunclubFriendSnapshot(
            name: "Original", currentStreak: 1, longestStreak: 1, hasLoggedToday: false,
            lastSharedAt: Date(timeIntervalSince1970: 1_780_000_000), seasonStyle: .summerGlow
        )
        let store = ImportUndoSettingsStore()
        store.save(SunclubGrowthSettings(friends: [original]))
        let (target, _) = try makeApp(store: store)
        var imported = original
        imported.name = "Imported"
        imported.currentStreak = 99
        imported.longestStreak = 99
        imported.hasLoggedToday = true
        imported.lastSharedAt = original.lastSharedAt.addingTimeInterval(60)
        let preferences = SunclubRestorablePreferences(growthSettings: SunclubGrowthSettings(friends: [imported]))
        let session = try target.importBackupDocument(envelopeBackup(preferences: preferences)).importSessionID
        XCTAssertEqual(target.growthSettings.friends.first?.name, "Imported")
        var later = store.load()
        later.friends[0].currentStreak = 2
        store.save(later)

        _ = try target.restoreImportedChanges(for: session).get()

        let friend = try XCTUnwrap(target.growthSettings.friends.first)
        XCTAssertEqual(friend.currentStreak, 2)
        XCTAssertEqual(friend.name, "Original")
        XCTAssertEqual(friend.longestStreak, 1)
        XCTAssertFalse(friend.hasLoggedToday)
    }

    private func makeHistory() throws -> SunclubHistoryService {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let history = SunclubHistoryService(context: ModelContext(container))
        try history.bootstrapIfNeeded()
        return history
    }

    func testOlderEmbeddedPreferencesAreClearedWhenRestorePointIsNil() throws {
        let history = try makeHistory()
        let source = try makeHistory()
        let preferences = try XCTUnwrap(envelopeBackup().payload.restorablePreferences)
        _ = try source.applySettingsChange(kind: .preferenceSettings, summary: "Saved preferences", changedFields: [.restorablePreferences]) {
            $0.restorablePreferences = preferences
        }
        let session = try history.importDomainData(from: source.fetchContext(), sourceDescription: "Older embedded import")
        let importBatch = try XCTUnwrap(history.changeBatches().first { $0.kind == .importLocal })
        importBatch.inverseOfBatchID = nil
        try history.fetchContext().save()
        let store = ImportUndoSettingsStore()
        store.save(preferences.replacingRestorableFields(in: SunclubGrowthSettings()))
        let (target, _) = try makeApp(context: history.fetchContext(), store: store)

        _ = try target.restoreImportedChanges(for: session.importSessionID).get()
        let (reopened, _) = try makeApp(context: history.fetchContext(), store: store)

        XCTAssertTrue(target.growthSettings.accountability.inviteTokens.isEmpty)
        XCTAssertEqual(target.growthSettings.automation, SunclubAutomationPreferences())
        XCTAssertTrue(reopened.growthSettings.accountability.inviteTokens.isEmpty)
        XCTAssertEqual(reopened.growthSettings.automation, SunclubAutomationPreferences())
    }

    func testUndoPreservesAnIndependentRemoteChoiceEqualToImportedValue() throws {
        let history = try makeHistory()
        let session = try importSettings(into: history)
        let next = (try history.changeBatches().compactMap(\.logicalOrder).max() ?? 0) + 1
        let remote = SunclubChangeBatch(
            logicalOrder: next, kind: .reminderSettings, scope: .settings, scopeIdentifier: "settings",
            authorDeviceID: "independent-device", summary: "Changed reminder from 8 to 10"
        )
        history.fetchContext().insert(remote)
        history.fetchContext().insert(SettingsRevision(
            batch: remote, snapshot: try history.settings().projectionSnapshot, changedFields: [.reminderHour]
        ))
        try history.fetchContext().save()
        try history.refreshProjectedState()

        _ = try history.restoreImportSession(session)

        XCTAssertEqual(try history.settings().reminderHour, 10)
        XCTAssertFalse(try history.settings().usesLiveUV)
    }

    func testUndoKeepsAnExplicitlyReplacedRelationshipCredential() throws {
        let friend = SunclubFriendSnapshot(
            name: "Friend", currentStreak: 1, longestStreak: 1, hasLoggedToday: false,
            lastSharedAt: Date(timeIntervalSince1970: 1_780_000_000), seasonStyle: .summerGlow
        )
        let profileID = UUID()
        let preferences = SunclubRestorablePreferences(growthSettings: SunclubGrowthSettings(
            friends: [friend], accountability: SunclubAccountabilitySettings(connections: [SunclubFriendConnection(
                friendProfileID: profileID, friendSnapshotID: friend.id, friendDisplayName: "Friend",
                relationshipToken: "imported-token", acceptedAt: friend.lastSharedAt
            )])
        ))
        let (target, _) = try makeApp()
        let session = try target.importBackupDocument(envelopeBackup(preferences: preferences)).importSessionID
        target.importAccountabilityInvite(SunclubAccountabilityInviteEnvelope(
            profileID: profileID, displayName: "Friend", relationshipToken: "replacement-token",
            issuedAt: friend.lastSharedAt.addingTimeInterval(60), snapshot: friend
        ), sendsResponse: false)
        XCTAssertEqual(target.growthSettings.accountability.connections.first?.relationshipToken, "replacement-token")

        _ = try target.restoreImportedChanges(for: session).get()

        XCTAssertEqual(target.growthSettings.accountability.connections.first?.relationshipToken, "replacement-token")
    }

    func testLegacyRecoveryUndoDoesNotResetALaterLocalName() throws {
        let history = try makeHistory()
        let store = ImportUndoSettingsStore()
        store.save(SunclubGrowthSettings(preferredName: "Before"))
        let (target, _) = try makeApp(context: history.fetchContext(), store: store)
        let source = try makeHistory()
        _ = try source.applySettingsChange(kind: .reminderSettings, summary: "Recovered reminder", changedFields: [.reminderHour]) {
            $0.reminderHour = 7
        }
        let session = try XCTUnwrap(history.recoverLegacyDomainData(from: source.fetchContext(), sourceDescription: "Original store"))
        target.refresh()
        target.updatePreferredDisplayName("After")

        _ = try target.restoreImportedChanges(for: session.importSessionID).get()

        XCTAssertEqual(target.growthSettings.preferredName, "After")
        XCTAssertEqual(store.load().preferredName, "After")
    }

    private func importSettings(into target: SunclubHistoryService) throws -> UUID {
        let source = try makeHistory()
        _ = try source.applySettingsChange(
            kind: .reminderSettings, summary: "Backup values",
            changedFields: [.reminderHour, .usesLiveUV, .selectedUVPlace, .sunscreenProfile]
        ) {
            $0.reminderHour = 10
            $0.usesLiveUV = true
            $0.selectedUVPlace = SunclubSelectedUVPlace(displayName: "Backup city", latitude: 30, longitude: 40)
            $0.sunscreenProfile = SunclubSunscreenProfile(name: "Backup sunscreen", spf: 50)
        }
        let service = SunclubBackupService()
        let document = try service.exportDocument(from: source.fetchContext())
        return try service.importBackupDocument(
            SunclubBackupDocument(data: document.serializedData()), into: target.fetchContext()
        ).importSessionID
    }

    private func envelopeBackup(preferences suppliedPreferences: SunclubRestorablePreferences? = nil) throws -> SunclubBackupDocument {
        let source = try makeHistory()
        let preferences = suppliedPreferences ?? SunclubRestorablePreferences(growthSettings: SunclubGrowthSettings(
            preferredName: "Imported name",
            uvBriefing: SunclubUVBriefingPreferences(dailyBriefingEnabled: false, morningHour: 11),
            accountability: SunclubAccountabilitySettings(inviteTokens: [
                SunclubAccountabilityInviteToken(token: "test-import-token", createdAt: Date(timeIntervalSince1970: 1_780_000_000))
            ]),
            automation: SunclubAutomationPreferences(shortcutWritesEnabled: false, urlWriteActionsEnabled: false)
        ))
        let document = try SunclubBackupService().exportDocument(
            from: source.fetchContext(), restorablePreferences: preferences
        )
        return try SunclubBackupDocument(data: document.serializedData())
    }

    private func makeApp(
        context suppliedContext: ModelContext? = nil, store suppliedStore: ImportUndoSettingsStore? = nil
    ) throws -> (AppState, ImportUndoSettingsStore) {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let store = suppliedStore ?? ImportUndoSettingsStore()
        let app = AppState(
            context: suppliedContext ?? ModelContext(container), notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(), growthFeatureStore: store,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: false, isPreviewing: true, hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )
        return (app, store)
    }
}

private final class ImportUndoSettingsStore: SunclubGrowthFeatureStoring {
    private var settings = SunclubGrowthSettings(scannedSPFLevels: [15, 30], successPhraseState: Data("Local phrases".utf8))
    func load() -> SunclubGrowthSettings { settings }
    func save(_ settings: SunclubGrowthSettings) { self.settings = settings }
}
