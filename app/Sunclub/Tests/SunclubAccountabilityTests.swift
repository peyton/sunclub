import Foundation
import CloudKit
import CoreLocation
import SwiftData
import XCTest
@testable import Sunclub

@MainActor
final class SunclubAccountabilityTests: SunclubTestCase {
    func testGrowthSettingsDecodesPartialAccountabilityPayloadWithDefaults() throws {
        let data = Data("""
        {
            "preferredName": "Peyton",
            "accountability": {
                "displayName": " Peyton ",
                "activatedAt": 800000000
            }
        }
        """.utf8)

        let settings = try JSONDecoder().decode(SunclubGrowthSettings.self, from: data)

        XCTAssertEqual(settings.preferredName, "Peyton")
        XCTAssertEqual(settings.accountability.displayName, "Peyton")
        XCTAssertTrue(settings.accountability.isActive)
        XCTAssertTrue(settings.accountability.inviteTokens.isEmpty)
        XCTAssertTrue(settings.accountability.pendingInvites.isEmpty)
        XCTAssertTrue(settings.accountability.connections.isEmpty)
        XCTAssertTrue(settings.accountability.pokeHistory.isEmpty)
    }

    @MainActor
    func testPreferredDisplayNameStoresTrimmedShareProfileName() throws {
        let state = try makeAppState()

        state.updatePreferredDisplayName("  Peyton Appleseed  ")

        XCTAssertEqual(state.preferredDisplayName, "Peyton Appleseed")
        XCTAssertEqual(state.growthSettings.preferredName, "Peyton Appleseed")
    }

    @MainActor
    func testFriendShareCodeUsesPreferredDisplayName() throws {
        let state = try makeAppState()
        state.updatePreferredDisplayName("Peyton Appleseed")

        let shareCode = try state.friendShareCode()
        let snapshot = try SunclubFriendCodeCodec.decode(shareCode)

        XCTAssertEqual(snapshot.name, "Peyton Appleseed")
    }

    @MainActor
    func testAccountabilityInviteCodeRoundTripsAndDeepLinkParses() throws {
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        let code = try SunclubAccountabilityCodec.backupCode(for: envelope)
        let decoded = try SunclubAccountabilityCodec.envelope(from: code)
        let inviteURL = try SunclubAccountabilityCodec.inviteURL(for: envelope)

        XCTAssertEqual(decoded, envelope)
        guard case let .accountabilityInvite(parsedCode) = SunclubDeepLink(url: inviteURL) else {
            return XCTFail("Expected accountability invite deep link.")
        }
        XCTAssertEqual(try SunclubAccountabilityCodec.envelope(from: parsedCode), envelope)
        XCTAssertThrowsError(try SunclubAccountabilityCodec.envelope(from: "not-a-sunclub-code"))
    }

    @MainActor
    func testQueuedAccountabilityInviteImportsAfterOnboarding() throws {
        let state = try makeAppState()
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        let code = try SunclubAccountabilityCodec.backupCode(for: envelope)

        try state.queuePendingAccountabilityInviteCode(code)

        XCTAssertFalse(state.growthSettings.accountability.isActive)
        XCTAssertTrue(state.friends.isEmpty)

        state.completeOnboarding()
        XCTAssertTrue(state.importPendingAccountabilityInvitesIfNeeded())

        XCTAssertTrue(state.growthSettings.accountability.isActive)
        XCTAssertEqual(state.friends.map(\.name), ["Maya"])
        XCTAssertTrue(state.growthSettings.accountability.pendingInvites.isEmpty)
    }

    @MainActor
    func testReleaseDefaultDisablesPublicAccountabilityTransport() throws {
        let runtimeEnvironment = RuntimeEnvironmentSnapshot(
            isRunningTests: false,
            isPreviewing: false,
            hasAppGroupContainer: true,
            isPublicAccountabilityTransportEnabled: false
        )
        let growthStore = SunclubGrowthFeatureStore(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)
        )
        let state = try makeAppState(
            growthFeatureStore: growthStore,
            runtimeEnvironment: runtimeEnvironment
        )
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")

        state.importAccountabilityInvite(envelope)
        state.sendDirectPoke(to: try XCTUnwrap(state.friends.first?.id))

        XCTAssertFalse(state.supportsDirectAccountabilityTransport)
        XCTAssertFalse(state.growthSettings.accountability.connections.first?.canDirectPoke ?? true)
        XCTAssertTrue(state.growthSettings.accountability.pokeHistory.isEmpty)
        XCTAssertEqual(state.friendImportMessage, "Use Message to remind Maya.")
    }

    @MainActor
    func testAddingByInviteStoresFriendSendsResponseAndUpdatesByProfileID() async throws {
        let service = FakeAccountabilityService()
        let state = try makeAppState(accountabilityService: service)
        let profileID = UUID(uuidString: "391D15FD-475F-4EE5-9A85-E68E27980EA8") ?? UUID()
        let initialEnvelope = makeAccountabilityInviteEnvelope(
            profileID: profileID,
            snapshotID: UUID(uuidString: "9C9E0C71-0C6B-46C2-8AC0-32E3AC1EE0E5") ?? UUID(),
            displayName: "Maya",
            currentStreak: 1
        )

        state.importAccountabilityInvite(initialEnvelope)
        await waitForMainActorTasks()

        XCTAssertEqual(state.friends.count, 1)
        XCTAssertEqual(state.friends.first?.name, "Maya")
        XCTAssertEqual(state.growthSettings.accountability.connections.first?.friendProfileID, profileID)
        XCTAssertEqual(service.sentInviteResponses.count, 1)
        XCTAssertEqual(service.sentInviteResponses.first?.recipientProfileID, profileID)

        let existingFriendID = try XCTUnwrap(state.friends.first?.id)
        let updatedEnvelope = makeAccountabilityInviteEnvelope(
            profileID: profileID,
            snapshotID: UUID(uuidString: "1EDBD356-6014-4B58-B2B4-ED4F6258E2F7") ?? UUID(),
            displayName: "Maya",
            currentStreak: 4
        )

        state.importAccountabilityInvite(updatedEnvelope, sendsResponse: false)

        XCTAssertEqual(state.friends.count, 1)
        XCTAssertEqual(state.friends.first?.id, existingFriendID)
        XCTAssertEqual(state.friends.first?.currentStreak, 4)
    }

    @MainActor
    func testAccountabilityMessagingCatalogsAreVariedAndStatusAware() throws {
        XCTAssertGreaterThanOrEqual(
            SunclubAccountabilityMessaging.openDayPokeMessages.count
                + SunclubAccountabilityMessaging.alreadyLoggedPokeMessages.count,
            20
        )

        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let openBody = SunclubAccountabilityMessaging.incomingNotificationBody(
            from: "Maya",
            recipientHasLoggedToday: false,
            recentPokes: [],
            now: now
        )
        let loggedBody = SunclubAccountabilityMessaging.incomingNotificationBody(
            from: "Maya",
            recipientHasLoggedToday: true,
            recentPokes: [],
            now: now
        )

        XCTAssertNotEqual(openBody, loggedBody)
        XCTAssertFalse(openBody.isEmpty)
        XCTAssertFalse(loggedBody.isEmpty)

        let accountabilityCopy = (
            SunclubAccountabilityMessaging.openDayPokeMessages
                + SunclubAccountabilityMessaging.alreadyLoggedPokeMessages
                + SunclubAccountabilityMessaging.incomingOpenNotificationBodies
                + SunclubAccountabilityMessaging.incomingLoggedNotificationBodies
        )
        .joined(separator: " ")
        .lowercased()
        XCTAssertFalse(accountabilityCopy.contains("coated"))
        XCTAssertFalse(accountabilityCopy.contains("coating"))
    }

    @MainActor
    func testAccountabilityMessagingAvoidsRecentPokeRepeat() throws {
        let profileID = UUID(uuidString: "07F5E424-2D67-44FB-8F46-EAC9F4D6A63D") ?? UUID()
        let friend = SunclubFriendSnapshot(
            id: UUID(uuidString: "33A0D8B2-3E8E-4C4C-A2BB-B06AE2756A47") ?? UUID(),
            name: "Maya",
            currentStreak: 2,
            longestStreak: 5,
            hasLoggedToday: false,
            lastSharedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            seasonStyle: .summerGlow
        )
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let firstMessage = SunclubAccountabilityMessaging.outgoingPokeMessage(
            for: friend,
            friendProfileID: profileID,
            recentPokes: [],
            now: now
        )
        let recentPokes = [
            SunclubAccountabilityPoke(
                friendProfileID: profileID,
                friendName: friend.name,
                direction: .sent,
                channel: .direct,
                status: .sent,
                message: firstMessage,
                createdAt: now
            )
        ]

        let nextMessage = SunclubAccountabilityMessaging.outgoingPokeMessage(
            for: friend,
            friendProfileID: profileID,
            recentPokes: recentPokes,
            now: now
        )

        XCTAssertNotEqual(firstMessage, nextMessage)
    }

    @MainActor
    func testDirectPokeUsesServiceAndFailureLeavesShareFallback() async throws {
        let service = FakeAccountabilityService()
        let state = try makeAppState(accountabilityService: service)
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        state.importAccountabilityInvite(envelope, sendsResponse: false)
        let friendID = try XCTUnwrap(state.friends.first?.id)

        state.sendDirectPoke(to: friendID)
        await waitForMainActorTasks()

        XCTAssertEqual(service.sentPokes.count, 1)
        XCTAssertEqual(service.sentPokes.first?.receiverProfileID, envelope.profileID)
        XCTAssertNotEqual(service.sentPokes.first?.message, "Sunscreen check?")
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.status, .sent)
        XCTAssertEqual(state.friendImportMessage, "Sent Maya a sunscreen reminder.")

        service.sendPokeError = FakeAccountabilityError.sendFailed
        state.sendDirectPoke(to: friendID)
        await waitForMainActorTasks()

        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.status, .failed)
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.channel, .direct)
        XCTAssertEqual(state.friendImportMessage, "Reminder did not send to Maya. Use Message instead.")
        XCTAssertTrue(state.sharePokeText(for: try XCTUnwrap(state.friends.first)).contains("Time to log sunscreen"))
    }

    @MainActor
    func testDirectPokeUsesSenderTokenAndReceiverAcceptsReciprocalPokes() async throws {
        let peytonService = FakeAccountabilityService()
        let mayaService = FakeAccountabilityService()
        let peytonNotifications = MockNotificationManager()
        let mayaNotifications = MockNotificationManager()
        let peytonState = try makeAppState(
            notificationManager: peytonNotifications,
            accountabilityService: peytonService
        )
        let mayaState = try makeAppState(
            notificationManager: mayaNotifications,
            accountabilityService: mayaService
        )

        peytonState.activateAccountability(displayName: "Peyton")
        mayaState.activateAccountability(displayName: "Maya")
        let peytonEnvelope = peytonState.preparedAccountabilityInviteEnvelope()
        let mayaEnvelope = mayaState.preparedAccountabilityInviteEnvelope()
        mayaState.importAccountabilityInvite(peytonEnvelope, sendsResponse: false)
        peytonState.importAccountabilityInvite(mayaEnvelope, sendsResponse: false)

        peytonState.sendDirectPoke(to: try XCTUnwrap(peytonState.friends.first?.id))
        mayaState.sendDirectPoke(to: try XCTUnwrap(mayaState.friends.first?.id))
        await waitForMainActorTasks()

        let pokeToMaya = try XCTUnwrap(peytonService.sentPokes.first)
        XCTAssertEqual(pokeToMaya.relationshipToken, peytonEnvelope.relationshipToken)
        let pokeToPeyton = try XCTUnwrap(mayaService.sentPokes.first)
        XCTAssertEqual(pokeToPeyton.relationshipToken, mayaEnvelope.relationshipToken)

        await mayaState.handleIncomingPoke(pokeToMaya)?.value
        await peytonState.handleIncomingPoke(pokeToPeyton)?.value

        XCTAssertEqual(mayaNotifications.accountabilityPokeNotifications.count, 1)
        XCTAssertEqual(mayaNotifications.accountabilityPokeNotifications.first?.friendName, "Peyton")
        XCTAssertEqual(peytonNotifications.accountabilityPokeNotifications.count, 1)
        XCTAssertEqual(peytonNotifications.accountabilityPokeNotifications.first?.friendName, "Maya")
    }

    @MainActor
    func testDirectPokeUnavailableShowsFreshInviteMessage() async throws {
        let service = FakeAccountabilityService()
        let state = try makeAppState(accountabilityService: service)
        let legacyFriend = SunclubFriendSnapshot(
            name: "Maya",
            currentStreak: 1,
            longestStreak: 2,
            hasLoggedToday: false,
            lastSharedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
            seasonStyle: .summerGlow
        )
        try state.importFriendCode(SunclubFriendCodeCodec.encode(legacyFriend))
        let friendID = try XCTUnwrap(state.friends.first?.id)

        state.sendDirectPoke(to: friendID)
        await waitForMainActorTasks()

        XCTAssertTrue(service.sentPokes.isEmpty)
        XCTAssertEqual(state.friendImportMessage, "Use Message to remind Maya.")
    }

    @MainActor
    func testIncomingPokeValidatesRelationshipBeforeNotifying() async throws {
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(
            notificationManager: notificationManager,
            accountabilityService: FakeAccountabilityService()
        )
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        state.importAccountabilityInvite(envelope, sendsResponse: false)

        let validPoke = SunclubAccountabilityPokeEnvelope(
            senderProfileID: envelope.profileID,
            senderName: "Maya",
            receiverProfileID: state.growthSettings.accountability.localProfileID,
            relationshipToken: envelope.relationshipToken,
            message: "Sunscreen check?",
            createdAt: Date()
        )
        state.handleIncomingPoke(validPoke)
        await waitForMainActorTasks()

        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.count, 1)
        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.first?.friendName, "Maya")
        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.first?.route, .friends)
        XCTAssertNotEqual(notificationManager.accountabilityPokeNotifications.first?.message, "Sunscreen check?")
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.status, .received)

        let invalidPoke = SunclubAccountabilityPokeEnvelope(
            senderProfileID: envelope.profileID,
            senderName: "Maya",
            receiverProfileID: state.growthSettings.accountability.localProfileID,
            relationshipToken: "wrong-token",
            message: "Sunscreen check?",
            createdAt: Date()
        )
        state.handleIncomingPoke(invalidPoke)
        await waitForMainActorTasks()

        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.count, 1)
    }

    @MainActor
    func testIncomingPokeNotificationCopyChangesWhenRecipientAlreadyLogged() async throws {
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        let openNotificationManager = MockNotificationManager()
        let openState = try makeAppState(
            notificationManager: openNotificationManager,
            accountabilityService: FakeAccountabilityService(),
            clock: { Date(timeIntervalSinceReferenceDate: 800_000_000) }
        )
        openState.importAccountabilityInvite(envelope, sendsResponse: false)

        let loggedNotificationManager = MockNotificationManager()
        let loggedState = try makeAppState(
            notificationManager: loggedNotificationManager,
            accountabilityService: FakeAccountabilityService(),
            clock: { Date(timeIntervalSinceReferenceDate: 800_000_000) }
        )
        loggedState.importAccountabilityInvite(envelope, sendsResponse: false)
        loggedState.saveManualRecord(
            for: Date(timeIntervalSinceReferenceDate: 800_000_000),
            spfLevel: 50,
            notes: "Already logged"
        )

        let poke = SunclubAccountabilityPokeEnvelope(
            senderProfileID: envelope.profileID,
            senderName: "Maya",
            receiverProfileID: openState.growthSettings.accountability.localProfileID,
            relationshipToken: envelope.relationshipToken,
            message: "Incoming",
            createdAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
        )
        openState.handleIncomingPoke(poke)

        let loggedPoke = SunclubAccountabilityPokeEnvelope(
            senderProfileID: envelope.profileID,
            senderName: "Maya",
            receiverProfileID: loggedState.growthSettings.accountability.localProfileID,
            relationshipToken: envelope.relationshipToken,
            message: "Incoming",
            createdAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
        )
        loggedState.handleIncomingPoke(loggedPoke)
        await waitForMainActorTasks()

        XCTAssertNotEqual(
            openNotificationManager.accountabilityPokeNotifications.first?.message,
            loggedNotificationManager.accountabilityPokeNotifications.first?.message
        )
        XCTAssertEqual(loggedNotificationManager.accountabilityPokeNotifications.first?.route, .friends)
    }

    @MainActor
    func testForegroundAccountabilityRefreshFetchesRemotePokes() async throws {
        let notificationManager = MockNotificationManager()
        let service = FakeAccountabilityService()
        let state = try makeAppState(
            notificationManager: notificationManager,
            accountabilityService: service
        )
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        state.importAccountabilityInvite(envelope, sendsResponse: false)
        service.remoteEvents = SunclubAccountabilityRemoteEvents(
            inviteResponses: [],
            pokes: [
                SunclubAccountabilityPokeEnvelope(
                    senderProfileID: envelope.profileID,
                    senderName: "Maya",
                    receiverProfileID: state.growthSettings.accountability.localProfileID,
                    relationshipToken: envelope.relationshipToken,
                    message: "Remote poke",
                    createdAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
                )
            ]
        )

        let refreshTask = state.refreshAccountabilityForForeground()
        await refreshTask?.value

        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.count, 1)
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.message, "Remote poke")
    }

    @MainActor
    func testAccountabilitySubscriptionsRetryUntilInstallSucceeds() async throws {
        let service = FakeAccountabilityService()
        service.installSubscriptionsError = FakeAccountabilityError.sendFailed
        let state = try makeAppState(accountabilityService: service)

        state.activateAccountability(displayName: "Peyton")
        await waitForMainActorTasks()

        XCTAssertNil(state.growthSettings.accountability.subscriptionsInstalledAt)
        XCTAssertEqual(state.growthSettings.accountability.subscriptionInstallVersion, 0)

        service.installSubscriptionsError = nil
        state.refreshAccountabilityFriends()
        await waitForMainActorTasks()

        XCTAssertNotNil(state.growthSettings.accountability.subscriptionsInstalledAt)
        XCTAssertEqual(state.growthSettings.accountability.subscriptionInstallVersion, 2)
        XCTAssertGreaterThanOrEqual(service.installedSubscriptionProfileIDs.count, 1)
    }

    @MainActor
    func testRemoteNotificationBridgeWaitsForAccountabilityProcessing() async throws {
        let service = FakeAccountabilityService()
        let notificationManager = MockNotificationManager()
        let state = try makeAppState(
            notificationManager: notificationManager,
            accountabilityService: service
        )
        let envelope = makeAccountabilityInviteEnvelope(displayName: "Maya")
        state.importAccountabilityInvite(envelope, sendsResponse: false)
        service.remoteEvents = SunclubAccountabilityRemoteEvents(
            inviteResponses: [],
            pokes: [
                SunclubAccountabilityPokeEnvelope(
                    senderProfileID: envelope.profileID,
                    senderName: "Maya",
                    receiverProfileID: state.growthSettings.accountability.localProfileID,
                    relationshipToken: envelope.relationshipToken,
                    message: "Remote poke",
                    createdAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
                )
            ]
        )
        SunclubRemoteNotificationBridge.shared.setHandler { _ in
            let didProcessEvent = await state.processRemoteAccountabilityEventsNow()
            return didProcessEvent ? .newData : .noData
        }

        let result = await SunclubRemoteNotificationBridge.shared.handle([:])

        XCTAssertEqual(result, .newData)
        XCTAssertEqual(notificationManager.accountabilityPokeNotifications.count, 1)
        XCTAssertEqual(state.growthSettings.accountability.pokeHistory.first?.message, "Remote poke")
    }

    @MainActor
    func testCloudKitAccountabilityServiceFetchesBeforeSavingStableRecords() async throws {
        let database = FakeAccountabilityDatabase()
        let service = SunclubAccountabilityService(database: database)
        let profileID = UUID(uuidString: "391D15FD-475F-4EE5-9A85-E68E27980EA8") ?? UUID()
        let profile = SunclubAccountabilityProfile(
            profileID: profileID,
            displayName: "Peyton",
            snapshot: SunclubFriendSnapshot(
                name: "Peyton",
                currentStreak: 3,
                longestStreak: 5,
                hasLoggedToday: true,
                lastSharedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
                seasonStyle: .summerGlow
            ),
            updatedAt: Date(timeIntervalSinceReferenceDate: 800_000_000)
        )

        try await service.publishProfile(profile)
        try await service.publishProfile(profile)

        let recordName = "profile-\(profileID.uuidString)"
        XCTAssertEqual(database.fetchedRecordNames, [recordName, recordName])
        XCTAssertEqual(database.savedRecordNames, [recordName, recordName])
    }

    @MainActor
    func testCloudKitAccountabilityDatabaseRejectsMissingCloudKitEntitlementBeforeContainerAccess() async throws {
        let database = CloudKitAccountabilityDatabase(
            containerIdentifier: "iCloud.app.peyton.sunclub",
            cloudKitEntitlementProvider: StaticCloudKitEntitlementProvider(entitlements: [:])
        )
        let query = CKQuery(
            recordType: "AccountabilityProfile",
            predicate: NSPredicate(format: "TRUEPREDICATE")
        )

        do {
            _ = try await database.records(matching: query, limit: 1)
            XCTFail("Expected missing CloudKit entitlement error.")
        } catch {
            XCTAssertEqual(
                error as? SunclubCloudKitConfigurationError,
                .missingContainerEntitlement("iCloud.app.peyton.sunclub")
            )
        }
    }
}
