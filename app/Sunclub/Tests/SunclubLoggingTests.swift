import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubLoggingTests: SunclubTestCase {
    @MainActor
    func testVerificationSuccessPresentationUsesUpdatedStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual,
            verificationDuration: 1.0
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 2)
        XCTAssertEqual(state.verificationSuccessPresentation?.detail, "2 days logged recently.")
    }

    @MainActor
    func testMarkAppliedTodayUpdatesExistingRecordInsteadOfDuplicating() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, verificationDuration: 1.2)
        state.markAppliedToday(method: .manual, verificationDuration: 2.4)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.verificationDuration, 2.4)
    }

    @MainActor
    func testManualVerificationMethodProperties() {
        let manual = VerificationMethod.manual
        XCTAssertEqual(manual.title, "manual")
        XCTAssertEqual(manual.displayName, "Manual Log")
        XCTAssertEqual(manual.symbolName, "hand.tap")
        XCTAssertEqual(manual.rawValue, 1)

        let quickLog = VerificationMethod.quickLog
        XCTAssertEqual(quickLog.title, "quick log")
        XCTAssertEqual(quickLog.displayName, "Quick Log")
        XCTAssertEqual(quickLog.symbolName, "bolt.fill")
        XCTAssertEqual(quickLog.rawValue, 2)
    }

    @MainActor
    func testVerificationMethodCaseIterable() {
        let allCases = VerificationMethod.allCases
        XCTAssertEqual(allCases, [.manual, .quickLog])
    }

    @MainActor
    func testVerificationMethodRoundTripsThroughRawValue() {
        XCTAssertEqual(VerificationMethod(rawValue: VerificationMethod.manual.rawValue), .manual)
        XCTAssertEqual(VerificationMethod(rawValue: VerificationMethod.quickLog.rawValue), .quickLog)
    }

    @MainActor
    func testMarkAppliedTodayWithManualMethod() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.method, .manual)
        XCTAssertNil(state.records.first?.verificationDuration)
    }

    @MainActor
    func testMarkAppliedTodayWithSPFAndNotes() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, spfLevel: 50, notes: "Before morning run")

        XCTAssertEqual(state.records.first?.spfLevel, 50)
        XCTAssertEqual(state.records.first?.notes, "Before morning run")
    }

    @MainActor
    func testDayPartResolverBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 22)))

        let early = try XCTUnwrap(calendar.date(bySettingHour: 4, minute: 59, second: 0, of: day))
        let morning = try XCTUnwrap(calendar.date(bySettingHour: 5, minute: 0, second: 0, of: day))
        let afternoon = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day))
        let evening = try XCTUnwrap(calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day))
        let night = try XCTUnwrap(calendar.date(bySettingHour: 21, minute: 0, second: 0, of: day))

        XCTAssertEqual(DayPart.resolve(for: early, calendar: calendar), .night)
        XCTAssertEqual(DayPart.resolve(for: morning, calendar: calendar), .morning)
        XCTAssertEqual(DayPart.resolve(for: afternoon, calendar: calendar), .afternoon)
        XCTAssertEqual(DayPart.resolve(for: evening, calendar: calendar), .evening)
        XCTAssertEqual(DayPart.resolve(for: night, calendar: calendar), .night)
    }

    func testDayPartPickerHidesNightByDefault() {
        XCTAssertEqual(DayPart.standardLogParts, [.morning, .afternoon, .evening])
        XCTAssertEqual(DayPart.logPickerParts(including: .morning), [.morning, .afternoon, .evening])
        XCTAssertEqual(DayPart.logPickerParts(including: .night), [.morning, .afternoon, .evening, .night])
    }

    @MainActor
    func testRecordApplicationRejectsFutureDate() throws {
        let state = try makeAppState()
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: state.referenceDate))

        let didWrite = state.recordApplication(
            for: .manual,
            part: .morning,
            on: tomorrow,
            source: .manualLog
        )

        XCTAssertFalse(didWrite.succeeded)
        XCTAssertEqual(state.logActionErrorMessage, "Cannot log future date.")
        XCTAssertTrue(state.records.isEmpty)
    }

    @MainActor
    func testManualLogRouteContextSupportsLegacyFallbackAndExplicitPayload() throws {
        let state = try makeAppState()
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: state.referenceDate))
        state.selectDay(yesterday)

        let fallbackContext = state.consumeManualLogRouteContext()
        XCTAssertTrue(Calendar.current.isDate(fallbackContext.date, inSameDayAs: yesterday))
        XCTAssertEqual(fallbackContext.source, .manualLog)

        state.prepareManualLogRouteContext(targetDate: yesterday, targetDayPart: .night, source: .timeline)
        let explicitContext = state.consumeManualLogRouteContext()
        XCTAssertTrue(Calendar.current.isDate(explicitContext.date, inSameDayAs: yesterday))
        XCTAssertEqual(explicitContext.dayPart, .night)
        XCTAssertEqual(explicitContext.source, .timeline)
    }

    @MainActor
    func testSaveManualRecordBackfillsPastDay() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        state.saveManualRecord(for: yesterday, spfLevel: 70, notes: "After lunch")

        let record = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertEqual(record.spfLevel, 70)
        XCTAssertEqual(record.notes, "After lunch")
        XCTAssertTrue(calendar.isDate(record.startOfDay, inSameDayAs: yesterday))
        XCTAssertTrue(calendar.isDate(record.verifiedAt, inSameDayAs: yesterday))
        XCTAssertEqual(state.dayStatus(for: yesterday), .applied)
    }

    @MainActor
    func testSaveManualRecordPreservesExactTimeAndRejectsFutureTime() throws {
        let calendar = Calendar.current
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 14, minute: 30))
        )
        let state = try makeAppState(clock: { now })
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let exactTime = try XCTUnwrap(calendar.date(bySettingHour: 16, minute: 47, second: 0, of: yesterday))

        let saved = state.saveManualRecord(
            for: yesterday,
            verifiedAt: exactTime,
            spfLevel: 50,
            notes: nil
        )

        XCTAssertTrue(saved.succeeded)
        XCTAssertEqual(try XCTUnwrap(state.record(for: yesterday)).verifiedAt, exactTime)

        let futureTime = now.addingTimeInterval(60)
        let rejected = state.saveManualRecord(
            for: now,
            verifiedAt: futureTime,
            spfLevel: 30,
            notes: nil
        )

        XCTAssertEqual(rejected, .failure(.futureTime))
        XCTAssertNil(state.record(for: now))
    }

    @MainActor
    func testFailedWidgetWriteKeepsDataAndSuppressesSuccessSideEffects() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let seedHistoryService = SunclubHistoryService(context: context)
        try seedHistoryService.bootstrapIfNeeded()
        try seedHistoryService.applySettingsChange(
            kind: .onboarding,
            summary: "Completed setup.",
            changedFields: [.hasCompletedOnboarding, .reapplyReminderEnabled]
        ) { snapshot in
            snapshot.hasCompletedOnboarding = true
            snapshot.reapplyReminderEnabled = true
        }

        let failingHistoryService = SunclubHistoryService(context: context) {
            throw NSError(domain: "SunclubTests", code: 1)
        }
        let notifications = MockNotificationManager()
        let cloudSync = ProbeCloudSyncCoordinator()
        let growthDefaults = try XCTUnwrap(UserDefaults(suiteName: "failed-write-\(UUID().uuidString)"))
        let widgetDefaults = try XCTUnwrap(UserDefaults(suiteName: "failed-widget-\(UUID().uuidString)"))
        let state = AppState(
            context: context,
            notificationManager: notifications,
            uvIndexService: UVIndexService(),
            historyService: failingHistoryService,
            cloudSyncCoordinator: cloudSync,
            widgetSnapshotStore: SunclubWidgetSnapshotStore(userDefaults: widgetDefaults),
            growthFeatureStore: SunclubGrowthFeatureStore(userDefaults: growthDefaults),
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )
        let router = AppRouter()
        let reminderCount = notifications.scheduleReapplyReminderPlans.count
        let widgetStore = SunclubWidgetSnapshotStore(userDefaults: widgetDefaults)
        let widgetSnapshotBeforeWrite = widgetStore.load()

        XCTAssertTrue(SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router))
        await waitForMainActorTasks()

        XCTAssertTrue(state.records.isEmpty)
        XCTAssertEqual(state.logActionErrorMessage, SunclubHistoryMutationError.persistenceFailure.localizedDescription)
        XCTAssertEqual(router.path.last, .manualLog)
        XCTAssertNil(state.verificationSuccessPresentation)
        XCTAssertEqual(notifications.scheduleReapplyReminderPlans.count, reminderCount)
        XCTAssertTrue(cloudSync.queuedBatchIDs.isEmpty)
        XCTAssertEqual(widgetStore.load(), widgetSnapshotBeforeWrite)
    }

    @MainActor
    func testFailedOnboardingWriteDoesNotCompleteSetupOrPublishSideEffects() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let failingHistoryService = SunclubHistoryService(context: context) {
            throw NSError(domain: "SunclubTests", code: 3)
        }
        let cloudSync = ProbeCloudSyncCoordinator()
        let state = AppState(
            context: context,
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            historyService: failingHistoryService,
            cloudSyncCoordinator: cloudSync,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )

        XCTAssertEqual(state.completeOnboarding(), .failure(.persistenceFailure))
        XCTAssertFalse(state.settings.hasCompletedOnboarding)
        XCTAssertTrue(cloudSync.queuedBatchIDs.isEmpty)
        XCTAssertEqual(state.logActionErrorMessage, SunclubHistoryMutationError.persistenceFailure.localizedDescription)
    }

    @MainActor
    func testFailedBulkHistoryDeletionRollsBackEveryRecord() throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let seedHistoryService = SunclubHistoryService(context: context)
        try seedHistoryService.bootstrapIfNeeded()
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        for day in [yesterday, today] {
            try seedHistoryService.applyDayChange(
                for: day,
                kind: .manualLog,
                summary: "Seeded a log.",
                changedFields: [.verifiedAt, .methodRawValue]
            ) { _ in
                DailyRecordProjectionSnapshot(
                    startOfDay: day,
                    verifiedAt: day,
                    methodRawValue: VerificationMethod.manual.rawValue,
                    verificationDuration: nil,
                    spfLevel: nil,
                    notes: nil,
                    reapplyCount: 0,
                    lastReappliedAt: nil
                )
            }
        }

        let failingHistoryService = SunclubHistoryService(context: context) {
            throw NSError(domain: "SunclubTests", code: 2)
        }
        let state = AppState(
            context: context,
            notificationManager: MockNotificationManager(),
            uvIndexService: UVIndexService(),
            historyService: failingHistoryService,
            runtimeEnvironment: RuntimeEnvironmentSnapshot(
                isRunningTests: true,
                isPreviewing: false,
                hasAppGroupContainer: false,
                isPublicAccountabilityTransportEnabled: false
            )
        )

        XCTAssertEqual(state.deleteAllHistory(), .failure(.persistenceFailure))
        XCTAssertEqual(state.records.count, 2)
        XCTAssertNotNil(state.record(for: yesterday))
        XCTAssertNotNil(state.record(for: today))
    }

    @MainActor
    func testUpdateExistingRecordPreservesSPF() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual, spfLevel: 50)
        state.markAppliedToday(method: .manual, verificationDuration: 1.0)

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.spfLevel, 50)
    }

    @MainActor
    func testSaveManualRecordCanClearOptionalFieldsAndPreserveDuration() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let existingVerifiedAt = calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday
        let existing = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: existingVerifiedAt,
            method: .manual,
            verificationDuration: 1.5,
            spfLevel: 50,
            notes: "Before run"
        )
        state.modelContext.insert(existing)
        state.refresh()

        state.saveManualRecord(for: yesterday, spfLevel: nil, notes: "")

        let updated = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertNil(updated.spfLevel)
        XCTAssertNil(updated.notes)
        XCTAssertEqual(updated.verificationDuration, 1.5)
        XCTAssertEqual(updated.verifiedAt, existingVerifiedAt)
    }

    @MainActor
    func testManualLogSuggestionStatePrefillsLastSPFAndRecentNoteSnippets() {
        let records = [
            makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: 50, notes: "Morning beach walk"),
            makeDailyRecord(dayOffset: 2, hour: 8, spfLevel: 30, notes: "Before lunch"),
            makeDailyRecord(dayOffset: 3, hour: 7, spfLevel: 50, notes: "Morning beach walk")
        ]

        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: Date(),
            calendar: Calendar.current
        )

        XCTAssertEqual(suggestions.defaultSPF, 50)
        XCTAssertEqual(suggestions.sameAsLastTime?.spfLevel, 50)
        XCTAssertEqual(suggestions.sameAsLastTime?.note, "Morning beach walk")
        XCTAssertEqual(suggestions.noteSnippets, ["Before lunch"])
    }

    @MainActor
    func testManualLogSuggestionStateDeduplicatesNotesCaseInsensitively() {
        let records = [
            makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: nil, notes: "Morning Beach Walk"),
            makeDailyRecord(dayOffset: 2, hour: 8, spfLevel: nil, notes: "morning beach walk"),
            makeDailyRecord(dayOffset: 3, hour: 7, spfLevel: nil, notes: "Before lunch")
        ]

        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: Date(),
            calendar: Calendar.current
        )

        XCTAssertEqual(suggestions.sameAsLastTime?.note, "Morning Beach Walk")
        XCTAssertEqual(suggestions.noteSnippets, ["Before lunch"])
    }

    @MainActor
    func testManualLogSuggestionStatePrefillsMostRecentSPFEvenAfterNoteOnlyLog() {
        let records = [
            makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: nil, notes: "Hat day"),
            makeDailyRecord(dayOffset: 2, hour: 8, spfLevel: 45, notes: nil)
        ]

        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: records,
            excluding: Date(),
            calendar: Calendar.current
        )

        XCTAssertEqual(suggestions.defaultSPF, 45)
        XCTAssertNil(suggestions.sameAsLastTime?.spfLevel)
        XCTAssertEqual(suggestions.sameAsLastTime?.note, "Hat day")
    }

    @MainActor
    func testManualLogSuggestionStateIncludesScannedSPFLevels() {
        let suggestions = ManualLogSuggestionEngine.suggestions(
            from: [],
            scannedSPFLevels: [45, 80, 45]
        )

        XCTAssertEqual(suggestions.scannedSPFLevels, [45, 80])
    }

    @MainActor
    func testOneTapDefaultsReuseLastSPFAndOnlyStructuredCoveredAreas() throws {
        let yesterdayNotes = SunManualLogInput.notesWithCoveredAreas(
            "Morning beach walk",
            areas: Set(["Ears", "Body"])
        )
        let records = [
            makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: 50, notes: yesterdayNotes),
            makeDailyRecord(dayOffset: 2, hour: 8, spfLevel: 30, notes: "Before lunch")
        ]

        let defaults = SunManualLogDefaultResolver.oneTapDefaults(
            from: records,
            excluding: Date(),
            calendar: Calendar.current
        )

        XCTAssertEqual(defaults.spfLevel, 50)
        XCTAssertEqual(defaults.coveredAreas, Set(["Ears", "Body"]))
        XCTAssertEqual(defaults.oneTapNotes, "Areas: Ears, Body")
    }

    @MainActor
    func testOneTapDefaultsDoNotCopyFreeFormNotesWithoutAreaMetadata() {
        let records = [
            makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: 45, notes: "Hat day")
        ]

        let defaults = SunManualLogDefaultResolver.oneTapDefaults(
            from: records,
            excluding: Date(),
            calendar: Calendar.current
        )

        XCTAssertEqual(defaults.spfLevel, 45)
        XCTAssertTrue(defaults.coveredAreas.isEmpty)
        XCTAssertNil(defaults.oneTapNotes)
    }

    @MainActor
    func testOneTapDefaultsUseProfileSPFWhenHistoryHasNoSPF() {
        let defaults = SunManualLogDefaultResolver.oneTapDefaults(
            from: [makeDailyRecord(dayOffset: 1, hour: 9, spfLevel: nil, notes: "Hat day")],
            profileSPF: 40
        )

        XCTAssertEqual(defaults.spfLevel, 40)
        XCTAssertTrue(defaults.coveredAreas.isEmpty)
    }

    @MainActor
    func testRememberScannedSPFStoresMostRecentLevels() throws {
        let state = try makeAppState()

        state.rememberScannedSPF(45)
        state.rememberScannedSPF(80)
        state.rememberScannedSPF(45)

        XCTAssertEqual(state.growthSettings.scannedSPFLevels, [45, 80])
        XCTAssertEqual(state.manualLogSuggestionState(for: Date()).scannedSPFLevels, [45, 80])
    }

    func testGrowthSettingsDecodesOlderPayloadWithoutScannedSPFLevels() throws {
        let data = Data("""
        {
            "preferredName": "Peyton",
            "healthKit": {
                "isEnabled": false,
                "importedSampleCount": 0
            },
            "uvBriefing": {
                "dailyBriefingEnabled": true,
                "extremeAlertEnabled": false,
                "morningHour": 8,
                "morningMinute": 0
            },
            "friends": [
                {
                    "id": "9C9E0C71-0C6B-46C2-8AC0-32E3AC1EE0E5",
                    "name": "Maya",
                    "currentStreak": 4,
                    "longestStreak": 9,
                    "hasLoggedToday": true,
                    "lastSharedAt": 800000000,
                    "seasonStyleRawValue": "summerGlow"
                }
            ],
            "presentedAchievementIDs": []
        }
        """.utf8)

        let settings = try JSONDecoder().decode(SunclubGrowthSettings.self, from: data)

        XCTAssertEqual(settings.preferredName, "Peyton")
        XCTAssertEqual(settings.friends.first?.name, "Maya")
        XCTAssertEqual(settings.friends.first?.currentStreak, 4)
        XCTAssertEqual(settings.scannedSPFLevels, [])
        XCTAssertFalse(settings.accountability.isActive)
        XCTAssertTrue(settings.accountability.connections.isEmpty)
    }

    @MainActor
    func testLongestStreakUpdatesOnNewRecord() throws {
        let state = try makeAppState()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.longestStreak, 1)
    }

    @MainActor
    func testLongestStreakTracksMaximum() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in stride(from: -2, through: 0, by: 1) {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let record = DailyRecord(
                startOfDay: day,
                verifiedAt: calendar.date(byAdding: .hour, value: 8, to: day) ?? day,
                method: .manual
            )
            state.modelContext.insert(record)
        }
        state.refresh()
        state.markAppliedToday(method: .manual)

        XCTAssertGreaterThanOrEqual(state.longestStreak, 3)
    }

    @MainActor
    func testLongestStreakRecomputesFromProjectedHistoryInsteadOfUsingStaleCache() throws {
        let state = try makeAppState()
        state.settings.longestStreak = 10
        state.save()

        state.markAppliedToday(method: .manual)

        XCTAssertEqual(state.longestStreak, 1)
        XCTAssertEqual(state.settings.longestStreak, 1)
    }

    @MainActor
    func testRefreshNormalizesLegacyCameraMethodToManual() throws {
        let state = try makeAppState()
        let today = Calendar.current.startOfDay(for: Date())

        let record = DailyRecord(startOfDay: today, verifiedAt: today, method: .manual)
        record.methodRawValue = 0
        state.modelContext.insert(record)

        state.refresh()

        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.records.first?.method, .manual)
        XCTAssertEqual(state.records.first?.methodRawValue, VerificationMethod.manual.rawValue)
    }

    @MainActor
    func testRecordVerificationSuccessSetsPresentation() throws {
        let state = try makeAppState()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 1)
        XCTAssertTrue(state.verificationSuccessPresentation?.isPersonalBest ?? false)
    }

    @MainActor
    func testRecordVerificationSuccessStoresSPFAndTrimmedNotes() throws {
        let midday = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: 13, minute: 0))
        )
        let state = try makeAppState(clock: { midday })

        state.recordVerificationSuccess(
            method: .manual,
            verificationDuration: 0.8,
            spfLevel: 30,
            notes: "  Pool day  "
        )

        let record = try XCTUnwrap(state.record(for: midday))
        XCTAssertEqual(record.spfLevel, 30)
        XCTAssertEqual(record.notes, "Pool day")
    }

    @MainActor
    func testUpdateReapplySettingsPersistsAndClamps() throws {
        let state = try makeAppState()

        state.updateReapplySettings(enabled: true, intervalMinutes: 10)
        XCTAssertTrue(state.settings.reapplyReminderEnabled)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 30)

        state.updateReapplySettings(enabled: true, intervalMinutes: 600)
        XCTAssertEqual(state.settings.reapplyIntervalMinutes, 480)
    }

    @MainActor
    func testLiveActivityPayloadAcceptsFreshCachedAppleWeather() throws {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let peakHour = SunclubUVHourForecast(
            date: now.addingTimeInterval(3_600),
            index: 10,
            sourceLabel: UVReadingSource.cachedWeatherKit.hourlySourceLabel
        )
        let forecast = SunclubUVForecast(
            generatedAt: now,
            sourceLabel: UVReadingSource.cachedWeatherKit.forecastLabel,
            hours: [peakHour],
            peakHour: peakHour,
            recommendation: "Very high UV today."
        )

        let payload = SunclubLiveActivityCoordinator.compactSurfaceUVPayload(
            reading: UVReading(index: 9, timestamp: now, source: .cachedWeatherKit),
            forecast: forecast,
            now: now
        )

        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.currentUVIndex, 9)
        XCTAssertEqual(payload?.peakUVIndex, 10)
    }

    @MainActor
    func testFreshInstallRestoresRemoteSettingsAndRecords() async throws {
        let container = try SunclubModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let historyService = SunclubHistoryService(context: context)
        try historyService.bootstrapIfNeeded()
        let driver = FakeCloudSyncEngineDriver()
        let remoteDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_710_000_000))
        let remoteBatch = SunclubChangeBatch(
            kind: .manualLog,
            scope: .timeline,
            scopeIdentifier: "timeline",
            authorDeviceID: "remote-device",
            summary: "Remote restored history.",
            isLocalOnly: false,
            isPublishedToCloud: true,
            cloudPublishedAt: Date()
        )
        let remoteSettings = SettingsProjectionSnapshot(
            hasCompletedOnboarding: true,
            reminderHour: 9,
            reminderMinute: 15,
            weeklyHour: 18,
            weeklyWeekday: 1,
            dailyPhraseState: nil,
            weeklyPhraseState: nil,
            smartReminderSettingsData: nil,
            reapplyReminderEnabled: false,
            reapplyIntervalMinutes: 120,
            usesLiveUV: false
        )
        let remoteRecord = DailyRecordProjectionSnapshot(
            startOfDay: remoteDay,
            verifiedAt: remoteDay.addingTimeInterval(9 * 60 * 60),
            methodRawValue: VerificationMethod.manual.rawValue,
            verificationDuration: nil,
            spfLevel: 50,
            notes: "Restored from iCloud",
            reapplyCount: 1,
            lastReappliedAt: remoteDay.addingTimeInterval(12 * 60 * 60)
        )
        let settingsRevision = SettingsRevision(
            batch: remoteBatch,
            snapshot: remoteSettings,
            changedFields: [.hasCompletedOnboarding, .reminderHour, .reminderMinute]
        )
        let recordRevision = DailyRecordRevision(
            batch: remoteBatch,
            snapshot: remoteRecord,
            changedFields: [.verifiedAt, .methodRawValue, .spfLevel, .notes, .reapplyCount, .lastReappliedAt]
        )
        driver.fetchHandler = {
            try historyService.upsertRemoteBatch(BatchWire(batch: remoteBatch))
            try historyService.upsertRemoteSettingsRevision(SettingsRevisionWire(revision: settingsRevision))
            try historyService.upsertRemoteRecordRevision(RecordRevisionWire(revision: recordRevision))
        }
        let coordinator = CloudSyncCoordinator(
            historyService: historyService,
            syncEngineDriver: driver
        )

        let result = await coordinator.start()

        XCTAssertEqual(result, .restoredRemoteHistory)
        XCTAssertTrue(try historyService.settings().hasCompletedOnboarding)
        let restoredRecord = try XCTUnwrap(historyService.record(for: remoteDay))
        XCTAssertEqual(restoredRecord.spfLevel, 50)
        XCTAssertEqual(restoredRecord.notes, "Restored from iCloud")
        XCTAssertEqual(driver.operations, [.fetch])
    }

    @MainActor
    func testDailyRecordMethodRoundTrips() {
        let now = Date()
        let record = DailyRecord(startOfDay: now, verifiedAt: now, method: .manual)
        XCTAssertEqual(record.method, .manual)
        XCTAssertEqual(record.methodRawValue, 1)
        XCTAssertEqual(record.reapplyCount, 0)
        XCTAssertNil(record.lastReappliedAt)
        XCTAssertFalse(record.hasReapplied)

        record.method = .quickLog
        XCTAssertEqual(record.method, .quickLog)
        XCTAssertEqual(record.methodRawValue, 2)

        record.methodRawValue = 999
        XCTAssertEqual(record.method, .manual)
    }

    @MainActor
    func testPreferredCheckInRouteIsReapplyCheckIn() throws {
        let state = try makeAppState()
        XCTAssertEqual(state.preferredCheckInRoute, .reapplyCheckIn)
    }

    @MainActor
    func testPersonalBestBannerOnlyShowsOnImprovement() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual
        )
        let todayRecord = DailyRecord(
            startOfDay: today,
            verifiedAt: calendar.date(byAdding: .hour, value: 9, to: today) ?? today,
            method: .manual
        )
        state.modelContext.insert(yesterdayRecord)
        state.modelContext.insert(todayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual, verificationDuration: 0.8)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertFalse(state.verificationSuccessPresentation?.isPersonalBest ?? true)
    }

    @MainActor
    func testManualLogUpdatesStreakAndLongestStreak() throws {
        let state = try makeAppState()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let yesterdayRecord = DailyRecord(
            startOfDay: yesterday,
            verifiedAt: calendar.date(byAdding: .hour, value: 8, to: yesterday) ?? yesterday,
            method: .manual
        )
        state.modelContext.insert(yesterdayRecord)
        state.refresh()

        state.recordVerificationSuccess(method: .manual)

        XCTAssertEqual(state.currentStreak, 2)
        XCTAssertGreaterThanOrEqual(state.longestStreak, 2)
        XCTAssertEqual(state.record(for: today)?.method, .manual)
    }

    @MainActor
    func testSunclubDeepLinkParsesWidgetLogTodayURL() throws {
        let url = try XCTUnwrap(
            URL(string: "\(SunclubRuntimeConfiguration.urlScheme)://widget/log-today")
        )

        XCTAssertEqual(SunclubDeepLink(url: url), .widgetLogToday)
        XCTAssertEqual(SunclubDeepLink.widgetLogToday.url, url)
    }

    @MainActor
    func testWidgetLogTodayDeepLinkRecordsTodayAndRoutesToSuccess() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.record(for: Date())?.method, .quickLog)
        XCTAssertEqual(state.verificationSuccessPresentation?.streak, 1)
        XCTAssertEqual(state.verificationSuccessPresentation?.canAddDetails, true)
        XCTAssertEqual(router.path, [.verifySuccess])
    }

    @MainActor
    func testWidgetLogTodayDeepLinkReusesLastSPFAndCoveredAreas() throws {
        let suiteName = "widget-log-defaults-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetSnapshotStore = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let state = try makeAppState(widgetSnapshotStore: widgetSnapshotStore)
        let router = AppRouter()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        state.completeOnboarding()
        state.saveManualRecord(
            for: yesterday,
            spfLevel: 50,
            notes: SunManualLogInput.notesWithCoveredAreas(
                "Beach walk",
                areas: Set(["Ears", "Body"])
            )
        )

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        XCTAssertTrue(handled)
        let todayRecord = try XCTUnwrap(state.record(for: today))
        XCTAssertEqual(todayRecord.method, .quickLog)
        XCTAssertEqual(todayRecord.spfLevel, 50)
        XCTAssertEqual(SunManualLogInput.coveredAreas(in: todayRecord.notes), Set(["Ears", "Body"]))
        XCTAssertEqual(SunManualLogInput.notesRemovingCoveredAreas(todayRecord.notes), "")
        XCTAssertEqual(widgetSnapshotStore.load().todaySPFLevel, 50)
        XCTAssertEqual(router.path, [.verifySuccess])
    }

    @MainActor
    func testWidgetLogTodayDeepLinkUpdatesExistingRecordAsQuickLog() throws {
        let state = try makeAppState()
        let router = AppRouter()
        state.completeOnboarding()
        state.markAppliedToday(method: .manual)

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertEqual(state.records.count, 1)
        XCTAssertEqual(state.record(for: Date())?.method, .quickLog)
        XCTAssertEqual(router.path, [.verifySuccess])
    }

    @MainActor
    func testWidgetLogTodayDeepLinkPreservesExistingOptionalFields() throws {
        let state = try makeAppState()
        let router = AppRouter()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        state.completeOnboarding()
        state.saveManualRecord(for: yesterday, spfLevel: 70, notes: nil)
        state.saveManualRecord(for: today, spfLevel: 30, notes: "Local entry")

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        XCTAssertTrue(handled)
        let todayRecord = try XCTUnwrap(state.record(for: today))
        XCTAssertEqual(todayRecord.method, .quickLog)
        XCTAssertEqual(todayRecord.spfLevel, 30)
        XCTAssertEqual(todayRecord.notes, "Local entry")
        XCTAssertEqual(router.path, [.verifySuccess])
    }

    @MainActor
    func testWatchLogRecordsQuickLogAndReturnsUpdatedSnapshot() throws {
        let suiteName = "watch-log-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetSnapshotStore = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let state = try makeAppState(widgetSnapshotStore: widgetSnapshotStore)
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        state.completeOnboarding()
        state.saveManualRecord(
            for: yesterday,
            spfLevel: 45,
            notes: SunManualLogInput.notesWithCoveredAreas("", areas: Set(["Face", "Neck"]))
        )

        let snapshot = try state.recordWatchSunscreenLog()

        XCTAssertEqual(state.records.count, 2)
        let todayRecord = try XCTUnwrap(state.record(for: Date()))
        XCTAssertEqual(todayRecord.method, .quickLog)
        XCTAssertEqual(todayRecord.spfLevel, 45)
        XCTAssertEqual(SunManualLogInput.coveredAreas(in: todayRecord.notes), Set(["Face", "Neck"]))
        XCTAssertTrue(snapshot.hasLoggedToday())
        XCTAssertEqual(snapshot.todaySPFLevel, 45)
        XCTAssertEqual(widgetSnapshotStore.load(), snapshot)
    }

    @MainActor
    func testWatchReapplyUsesDurableMutationAndReturnsUpdatedSnapshot() throws {
        let suiteName = "watch-reapply-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let widgetSnapshotStore = SunclubWidgetSnapshotStore(userDefaults: defaults)
        let state = try makeAppState(widgetSnapshotStore: widgetSnapshotStore)
        state.completeOnboarding()
        state.markAppliedToday(method: .quickLog)

        let snapshot = try state.recordWatchReapplication()

        XCTAssertEqual(state.record(for: Date())?.reapplyCount, 1)
        XCTAssertNotNil(state.record(for: Date())?.lastReappliedAt)
        XCTAssertNotNil(snapshot.lastReappliedAt)
        XCTAssertEqual(widgetSnapshotStore.load(), snapshot)
    }

    @MainActor
    func testManualLogsNormalizeSPFAndClampNotes() throws {
        let state = try makeAppState()
        let longNote = String(repeating: "A", count: SunManualLogInput.noteCharacterLimit + 25)

        state.markAppliedToday(method: .manual, spfLevel: -10, notes: "  \(longNote)  ")

        let todayRecord = try XCTUnwrap(state.record(for: Date()))
        XCTAssertEqual(todayRecord.spfLevel, 1)
        XCTAssertEqual(todayRecord.notes?.count, SunManualLogInput.noteCharacterLimit)

        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        state.saveManualRecord(for: yesterday, spfLevel: 500, notes: "  \(longNote)  ")

        let yesterdayRecord = try XCTUnwrap(state.record(for: yesterday))
        XCTAssertEqual(yesterdayRecord.spfLevel, 100)
        XCTAssertEqual(yesterdayRecord.notes?.count, SunManualLogInput.noteCharacterLimit)
    }

    func testManualLogCoveredAreasRoundTripThroughNotes() throws {
        let notes = SunManualLogInput.notesWithCoveredAreas(
            "Morning beach walk",
            areas: ["Neck", "Face", "Unknown"]
        )

        XCTAssertEqual(notes, "Morning beach walk\nAreas: Face, Neck")
        XCTAssertEqual(SunManualLogInput.coveredAreas(in: notes), Set(["Face", "Neck"]))
        XCTAssertEqual(SunManualLogInput.notesRemovingCoveredAreas(notes), "Morning beach walk")
    }

    @MainActor
    func testWidgetLogTodayDeepLinkDoesNotLogBeforeOnboarding() throws {
        let state = try makeAppState()
        let router = AppRouter()

        let handled = SunclubDeepLinkHandler.handle(.widgetLogToday, appState: state, router: router)

        XCTAssertTrue(handled)
        XCTAssertTrue(state.records.isEmpty)
        XCTAssertNil(state.verificationSuccessPresentation)
        XCTAssertTrue(router.path.isEmpty)
    }
}
