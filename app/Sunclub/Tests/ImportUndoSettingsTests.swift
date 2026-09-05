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

    func testUndoImportDoesNotReplayARevertedSettingsEdit() throws {
        let target = try makeHistory()
        let before = try target.settings().projectionSnapshot
        let session = try importSettings(into: target)
        let edit = try XCTUnwrap(target.applySettingsChange(
            kind: .reminderSettings, summary: "Later edit", changedFields: [.reminderHour]
        ) { $0.reminderHour = 6 })
        _ = try target.undo(batchID: edit.id)
        XCTAssertEqual(try target.settings().reminderHour, 10)

        _ = try target.restoreImportSession(session)

        XCTAssertEqual(try target.settings().projectionSnapshot, before)
    }

    func testUndoImportPreservesARedoneSettingsEdit() throws {
        let target = try makeHistory()
        let session = try importSettings(into: target)
        let edit = try XCTUnwrap(target.applySettingsChange(
            kind: .reminderSettings, summary: "Later edit", changedFields: [.reminderHour]
        ) { $0.reminderHour = 6 })
        _ = try target.undo(batchID: edit.id)
        _ = try target.redo(batchID: edit.id)

        _ = try target.restoreImportSession(session)

        XCTAssertEqual(try target.settings().reminderHour, 6)
        XCTAssertFalse(try target.settings().usesLiveUV)
        XCTAssertNil(try target.settings().sunscreenProfile)
    }

    func testUndoImportPreservesSettingsEditsMadeAfterAnUndo() throws {
        let target = try makeHistory()
        let session = try importSettings(into: target)
        let edit = try XCTUnwrap(target.applySettingsChange(
            kind: .reminderSettings, summary: "Later edit", changedFields: [.reminderHour]
        ) { $0.reminderHour = 6 })
        _ = try target.undo(batchID: edit.id)
        _ = try target.applySettingsChange(
            kind: .reminderSettings, summary: "After undo", changedFields: [.weeklyHour]
        ) { $0.weeklyHour = 22 }

        _ = try target.restoreImportSession(session)

        XCTAssertEqual(try target.settings().reminderHour, 8)
        XCTAssertEqual(try target.settings().weeklyHour, 22)
        XCTAssertFalse(try target.settings().usesLiveUV)
    }

    func testUndoImportPreservesWholeSnapshotUndoAndRedoSemantics() throws {
        for scenario in [(redo: false, hour: 8, weekly: 18), (redo: true, hour: 6, weekly: 22)] {
            let target = try makeHistory()
            let session = try importSettings(into: target)
            let edit = try XCTUnwrap(target.applySettingsChange(
                kind: .reminderSettings, summary: "First edit", changedFields: [.reminderHour]
            ) { $0.reminderHour = 6 })
            _ = try target.applySettingsChange(
                kind: .reminderSettings, summary: "Intervening edit", changedFields: [.weeklyHour]
            ) { $0.weeklyHour = 22 }
            _ = try target.undo(batchID: edit.id)
            XCTAssertEqual(try target.settings().weeklyHour, 18)
            if scenario.redo { _ = try target.redo(batchID: edit.id) }

            _ = try target.restoreImportSession(session)

            XCTAssertEqual(try target.settings().reminderHour, scenario.hour)
            XCTAssertEqual(try target.settings().weeklyHour, scenario.weekly)
            XCTAssertFalse(try target.settings().usesLiveUV)
        }
    }

    func testUndoImportRejectsMissingSettingsInverseTargetAtomically() throws {
        let target = try makeHistory()
        let session = try importSettings(into: target)
        let edit = try XCTUnwrap(target.applySettingsChange(
            kind: .reminderSettings, summary: "Later edit", changedFields: [.reminderHour]
        ) { $0.reminderHour = 6 })
        let inverse = try target.undo(batchID: edit.id)
        inverse.inverseOfBatchID = UUID()
        try target.fetchContext().save()
        let before = try target.settings().projectionSnapshot
        let beforeIDs = Set(try target.changeBatches().map(\.id))

        XCTAssertThrowsError(try target.restoreImportSession(session))

        XCTAssertEqual(try target.settings().projectionSnapshot, before)
        XCTAssertEqual(Set(try target.changeBatches().map(\.id)), beforeIDs)
    }

    func testUndoImportDoesNotAdoptPreferencesFromAnUndoneEdit() throws {
        let target = try makeHistory()
        let before = try target.settings().projectionSnapshot
        let session = try SunclubBackupService().importBackupDocument(
            envelopeBackup(), into: target.fetchContext()
        ).importSessionID
        let imported = try XCTUnwrap(target.settings().restorablePreferences)
        let renamed = SunclubRestorablePreferences(
            preferredName: "My name", uvBriefing: imported.uvBriefing, friends: imported.friends,
            accountability: imported.accountability, automation: imported.automation
        )
        let edit = try XCTUnwrap(target.applySettingsChange(
            kind: .preferenceSettings, summary: "Later name", changedFields: [.restorablePreferences]
        ) { $0.restorablePreferences = renamed })
        _ = try target.undo(batchID: edit.id)
        XCTAssertEqual(try target.settings().restorablePreferences?.preferredName, "Imported name")

        _ = try target.restoreImportSession(session)

        XCTAssertEqual(try target.settings().projectionSnapshot, before)
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

    func testAppUndoImportDoesNotRecaptureAnUndoneNameChange() throws {
        let (target, store) = try makeApp()
        let original = store.load()
        let session = try target.importBackupDocument(envelopeBackup()).importSessionID
        let beforeIDs = Set(target.changeBatches.map(\.id))
        target.updatePreferredDisplayName("My name")
        let edit = try XCTUnwrap(target.changeBatches.first {
            $0.kind == .preferenceSettings && !beforeIDs.contains($0.id)
        })

        _ = try target.undoChange(edit.id).get()

        XCTAssertEqual(target.growthSettings.preferredName, "Imported name")
        XCTAssertEqual(store.load().preferredName, "Imported name")
        let redone = try target.redoChange(edit.id).get()
        XCTAssertEqual(target.growthSettings.preferredName, "My name")
        XCTAssertEqual(store.load().preferredName, "My name")
        _ = try target.undoChange(redone.id).get()
        XCTAssertEqual(target.growthSettings.preferredName, "Imported name")
        XCTAssertEqual(store.load().preferredName, "Imported name")
        _ = try target.restoreImportedChanges(for: session).get()
        target.refresh()
        XCTAssertEqual(target.growthSettings.preferredName, original.preferredName)
        XCTAssertEqual(target.growthSettings.automation, original.automation)
        XCTAssertEqual(target.growthSettings.accountability, original.accountability)
        XCTAssertEqual(target.growthSettings.scannedSPFLevels, original.scannedSPFLevels)
        XCTAssertEqual(target.growthSettings.successPhraseState, original.successPhraseState)
        XCTAssertEqual(store.load(), target.growthSettings)
    }

    func testAppReminderUndoPreservesUnrecordedLocalPreferences() throws {
        for importsBackup in [false, true] {
            let (target, store) = try makeApp()
            if importsBackup { _ = try target.importBackupDocument(envelopeBackup()) }
            let beforeIDs = Set(target.changeBatches.map(\.id))
            target.updateDailyReminder(hour: 6, minute: 0)
            let edit = try XCTUnwrap(target.changeBatches.first {
                $0.kind == .reminderSettings && !beforeIDs.contains($0.id)
            })
            var local = store.load()
            local.preferredName = "On this device"
            store.save(local)

            _ = try target.undoChange(edit.id).get()

            XCTAssertEqual(store.load(), local)
        }
    }

    func testImportedTimelineUndoAndRedoPreserveStoreOnlyPreferences() throws {
        let source = try makeHistory()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_780_000_000))
        _ = try source.applyDayChange(
            for: day, kind: .manualLog, summary: "Log", changedFields: [.verifiedAt, .notes]
        ) { _ in
            DailyRecord(
                startOfDay: day, verifiedAt: day.addingTimeInterval(9 * 3_600),
                method: .manual, notes: "From backup"
            ).projectionSnapshot
        }
        _ = try XCTUnwrap(source.deleteAllRecords())
        let document = try SunclubBackupService().exportDocument(from: source.fetchContext())
        let (target, store) = try makeApp()
        let session = try target.importBackupDocument(
            SunclubBackupDocument(data: document.serializedData())
        ).importSessionID
        let deletion = try XCTUnwrap(target.changeBatches.first {
            $0.importSessionID == session && $0.kind == .deleteRecord && $0.scope == .timeline
        })
        var later = store.load()
        later.automation.shortcutWritesEnabled = false
        later.preferredName = "On this device"
        store.save(later)

        _ = try target.undoChange(deletion.id).get()

        XCTAssertEqual(store.load(), later)
        XCTAssertEqual(target.records.first?.notes, "From backup")
        var latest = later
        latest.automation.shortcutWritesEnabled = true
        latest.preferredName = "Updated on this device"
        store.save(latest)

        _ = try target.redoChange(deletion.id).get()

        XCTAssertEqual(store.load(), latest)
        XCTAssertTrue(target.records.isEmpty)
    }

    func testImportedPreferenceUndoAndRedoAcrossNilPreserveStoreOnlyPreferences() throws {
        let history = try makeHistory()
        let (target, store) = try makeApp(context: history.fetchContext())
        let source = try makeHistory()
        var imported = store.load()
        imported.preferredName = "Backup name"
        let edit = try XCTUnwrap(source.applySettingsChange(
            kind: .preferenceSettings, summary: "Backup name", changedFields: [.restorablePreferences]
        ) { $0.restorablePreferences = SunclubRestorablePreferences(growthSettings: imported) })
        let document = try SunclubBackupService().exportDocument(from: source.fetchContext())
        let session = try target.importBackupDocument(
            SunclubBackupDocument(data: document.serializedData())
        ).importSessionID
        let cloned = try XCTUnwrap(target.changeBatches.first {
            $0.id == edit.id && $0.importSessionID == session
        })
        let beforeUndo = target.settings.projectionSnapshot
        XCTAssertEqual(beforeUndo.restorablePreferences?.preferredName, "Backup name")
        var later = store.load()
        later.automation.shortcutWritesEnabled = false
        later.preferredName = "On this device"
        store.save(later)

        let inverse = try target.undoChange(cloned.id).get()

        XCTAssertEqual(inverse.kind, .undo)
        XCTAssertEqual(target.settings.restorablePreferences?.preferredName, "On this device")
        XCTAssertEqual(target.settings.restorablePreferences?.automation.shortcutWritesEnabled, false)
        XCTAssertEqual(store.load(), later)
        target.refresh()
        XCTAssertEqual(store.load(), later)
        var latest = later
        latest.automation.urlWriteActionsEnabled = false
        latest.preferredName = "Updated on this device"
        store.save(latest)

        _ = try target.redoChange(cloned.id).get()

        XCTAssertEqual(target.settings.restorablePreferences?.preferredName, "Updated on this device")
        XCTAssertEqual(target.settings.restorablePreferences?.automation.shortcutWritesEnabled, false)
        XCTAssertEqual(target.settings.restorablePreferences?.automation.urlWriteActionsEnabled, false)
        XCTAssertEqual(store.load(), latest)
        let (reopened, _) = try makeApp(context: history.fetchContext(), store: store)
        XCTAssertEqual(reopened.growthSettings, latest)
        XCTAssertEqual(store.load(), latest)
    }

    func testImportedPreferenceUndoWithUnchangedEnvelopePreservesStoreOnlyPreferences() throws {
        let history = try makeHistory()
        let (target, store) = try makeApp(context: history.fetchContext())
        let source = try makeHistory()
        var imported = store.load()
        imported.automation.shortcutWritesEnabled = false
        var editedBatchID: UUID?
        // Established source history keeps this edit's predecessor after the destination's restore point.
        for name in ["First name", "Earlier name", "Before edit", "Edited name", "Before edit"] {
            imported.preferredName = name
            let edit = try XCTUnwrap(source.applySettingsChange(
                kind: .preferenceSettings, summary: name, changedFields: [.restorablePreferences]
            ) { $0.restorablePreferences = SunclubRestorablePreferences(growthSettings: imported) })
            if name == "Edited name" { editedBatchID = edit.id }
        }
        let document = try SunclubBackupService().exportDocument(from: source.fetchContext())
        let session = try target.importBackupDocument(
            SunclubBackupDocument(data: document.serializedData())
        ).importSessionID
        let editID = try XCTUnwrap(editedBatchID)
        let cloned = try XCTUnwrap(target.changeBatches.first {
            $0.id == editID && $0.importSessionID == session
        })
        let beforeUndo = target.settings.projectionSnapshot
        XCTAssertEqual(beforeUndo.restorablePreferences?.preferredName, "Before edit")
        XCTAssertEqual(beforeUndo.restorablePreferences?.automation.shortcutWritesEnabled, false)
        var later = store.load()
        later.automation.shortcutWritesEnabled = true
        later.preferredName = "On this device"
        store.save(later)

        let inverse = try target.undoChange(cloned.id).get()

        XCTAssertEqual(inverse.kind, .undo)
        XCTAssertEqual(inverse.inverseOfBatchID, cloned.id)
        XCTAssertEqual(target.settings.restorablePreferences?.preferredName, "On this device")
        XCTAssertEqual(target.settings.restorablePreferences?.automation.shortcutWritesEnabled, true)
        XCTAssertEqual(store.load(), later)
        target.refresh()
        XCTAssertEqual(store.load(), later)
        let (reopened, _) = try makeApp(context: history.fetchContext(), store: store)
        XCTAssertEqual(reopened.growthSettings, later)
        XCTAssertEqual(store.load(), later)
    }

    func testImportedPreferenceUndoPreservesStoreOnlyChangesWhenKnownEnvelopeChanges() throws {
        for scenario in [
            (recordedShortcut: true, localShortcut: false, previousShortcut: true),
            (recordedShortcut: true, localShortcut: false, previousShortcut: false),
            (recordedShortcut: false, localShortcut: true, previousShortcut: false),
            (recordedShortcut: false, localShortcut: true, previousShortcut: true)
        ] {
            let history = try makeHistory()
            let (target, store) = try makeApp(context: history.fetchContext())
            let (session, cloned) = try importPreferenceNameChange(
                into: target, store: store, recordedShortcut: scenario.recordedShortcut, previousShortcut: scenario.previousShortcut
            )
            let beforeUndo = try XCTUnwrap(target.settings.restorablePreferences)
            XCTAssertEqual(beforeUndo.preferredName, "B")
            XCTAssertEqual(beforeUndo.automation.shortcutWritesEnabled, scenario.recordedShortcut)
            target.updateDailyReminder(hour: 6, minute: 0)
            XCTAssertEqual(target.settings.reminderHour, 6)
            var local = store.load()
            local.automation.shortcutWritesEnabled = scenario.localShortcut
            store.save(local)
            var expected = local
            expected.preferredName = "A"

            _ = try target.undoChange(cloned.id).get()

            let restored = try XCTUnwrap(target.settings.restorablePreferences)
            XCTAssertEqual(target.settings.reminderHour, 8)
            XCTAssertEqual(restored.preferredName, "A")
            XCTAssertEqual(restored.automation.shortcutWritesEnabled, scenario.localShortcut)
            XCTAssertEqual(target.growthSettings.preferredName, "A")
            XCTAssertEqual(target.growthSettings.automation.shortcutWritesEnabled, scenario.localShortcut)
            XCTAssertEqual(store.load(), expected)
            target.refresh()
            XCTAssertEqual(store.load(), expected)
            let (reopened, _) = try makeApp(context: history.fetchContext(), store: store)
            XCTAssertEqual(reopened.growthSettings, expected)
            XCTAssertEqual(store.load(), expected)

            _ = try reopened.restoreImportedChanges(for: session).get()

            XCTAssertEqual(reopened.settings.reminderHour, 8)
            XCTAssertEqual(reopened.growthSettings.preferredName, "")
            XCTAssertEqual(reopened.growthSettings.automation.shortcutWritesEnabled, scenario.localShortcut)
            XCTAssertEqual(store.load(), reopened.growthSettings)
        }
    }

    func testImportedPreferenceUndoFailureRollsBackCaptureAndRetryPreservesRedo() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        var rejectsRecovery = false
        let history = SunclubHistoryService(context: ModelContext(container), mutationGuard: {
            if rejectsRecovery { throw CocoaError(.fileWriteUnknown) }
        })
        try history.bootstrapIfNeeded()
        let (target, store) = try makeApp(context: history.fetchContext(), history: history)
        let source = try makeHistory()
        var imported = store.load()
        imported.preferredName = "Backup name"
        let edit = try XCTUnwrap(source.applySettingsChange(
            kind: .preferenceSettings, summary: "Backup name", changedFields: [.restorablePreferences]
        ) { $0.restorablePreferences = SunclubRestorablePreferences(growthSettings: imported) })
        let document = try SunclubBackupService().exportDocument(from: source.fetchContext())
        _ = try target.importBackupDocument(SunclubBackupDocument(data: document.serializedData()))
        var later = store.load()
        later.automation.shortcutWritesEnabled = false
        later.preferredName = "On this device"
        store.save(later)
        let beforeIDs = Set(try history.changeBatches().map(\.id))
        let beforeSnapshot = target.settings.projectionSnapshot
        rejectsRecovery = true

        XCTAssertThrowsError(try target.undoChange(edit.id).get())

        XCTAssertEqual(Set(try history.changeBatches().map(\.id)), beforeIDs)
        XCTAssertEqual(target.settings.projectionSnapshot, beforeSnapshot)
        XCTAssertEqual(store.load(), later)
        XCTAssertNil(try history.fetchBatchForSync(id: edit.id)?.undoneByBatchID)
        rejectsRecovery = false

        _ = try target.undoChange(edit.id).get()
        XCTAssertEqual(store.load(), later)
        _ = try target.redoChange(edit.id).get()
        XCTAssertEqual(store.load(), later)
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

    private func importPreferenceNameChange(
        into target: AppState, store: ImportUndoSettingsStore, recordedShortcut: Bool, previousShortcut: Bool
    ) throws -> (UUID, SunclubChangeBatch) {
        let source = try makeHistory()
        var imported = store.load()
        var editedBatchID: UUID?
        // Put the known A -> B pair after the destination's pre-import settings revisions.
        for name in ["First name", "Earlier name", "A", "B"] {
            imported.preferredName = name
            imported.automation.shortcutWritesEnabled = name == "A" ? previousShortcut : recordedShortcut
            let edit = try XCTUnwrap(source.applySettingsChange(
                kind: .preferenceSettings, summary: name, changedFields: [.restorablePreferences]
            ) { $0.restorablePreferences = SunclubRestorablePreferences(growthSettings: imported) })
            editedBatchID = edit.id
        }
        let document = try SunclubBackupService().exportDocument(from: source.fetchContext())
        let session = try target.importBackupDocument(SunclubBackupDocument(data: document.serializedData())).importSessionID
        let editID = try XCTUnwrap(editedBatchID)
        let cloned = try XCTUnwrap(target.changeBatches.first { $0.id == editID && $0.importSessionID == session })
        return (session, cloned)
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
        context suppliedContext: ModelContext? = nil, store suppliedStore: ImportUndoSettingsStore? = nil,
        history suppliedHistory: SunclubHistoryService? = nil
    ) throws -> (AppState, ImportUndoSettingsStore) {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let store = suppliedStore ?? ImportUndoSettingsStore()
        let app = AppState(
            context: suppliedContext ?? ModelContext(container), notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(), historyService: suppliedHistory, growthFeatureStore: store,
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
