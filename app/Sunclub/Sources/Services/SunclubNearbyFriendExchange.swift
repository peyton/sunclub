import Foundation
import MultipeerConnectivity

@MainActor
final class SunclubNearbyFriendExchange: NSObject, ObservableObject {
    enum ExchangeState: Equatable {
        case idle
        case searching
        case connected(String)
        case received(SunclubAccountabilityInviteEnvelope)
        case failed(String)
    }

    private static let serviceType = "sunclub-peer"

    @Published private(set) var state: ExchangeState = .idle
    @Published private(set) var visiblePeers: [String] = []

    private var localEnvelope: SunclubAccountabilityInviteEnvelope?
    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    func start(displayName: String, envelope: SunclubAccountabilityInviteEnvelope) {
        stop()
        localEnvelope = envelope
        let peerID = MCPeerID(displayName: displayName.isEmpty ? "Sunclub Friend" : displayName)
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()

        self.peerID = peerID
        self.session = session
        self.advertiser = advertiser
        self.browser = browser
        state = .searching
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        peerID = nil
        visiblePeers = []
        if case .received = state {
            return
        }
        state = .idle
    }

    private func sendEnvelopeIfPossible() {
        guard let session,
              !session.connectedPeers.isEmpty,
              let localEnvelope,
              let data = try? JSONEncoder().encode(localEnvelope) else {
            return
        }

        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension SunclubNearbyFriendExchange: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            invitationHandler(true, session)
        }
    }
}

extension SunclubNearbyFriendExchange: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard let session else { return }
            if !visiblePeers.contains(peerID.displayName) {
                visiblePeers.append(peerID.displayName)
            }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            visiblePeers.removeAll { $0 == peerID.displayName }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            state = .failed(error.localizedDescription)
        }
    }
}

extension SunclubNearbyFriendExchange: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.state = .connected(peerID.displayName)
                sendEnvelopeIfPossible()
            case .notConnected:
                if case .received = self.state {
                    return
                }
                self.state = .searching
            case .connecting:
                self.state = .connected(peerID.displayName)
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            do {
                let envelope = try JSONDecoder().decode(SunclubAccountabilityInviteEnvelope.self, from: data)
                state = .received(envelope)
            } catch {
                state = .failed("That nearby invite could not be read.")
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}
