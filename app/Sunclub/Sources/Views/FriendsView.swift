import SwiftUI
import UIKit

struct AccountabilityOnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var step = 1
    @State private var shareSheetItem: ShareSheetItem?

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Accountability", showsBack: true, onBack: {
                    router.goBack()
                })

                SunStepHeader(step: step, total: 3, tint: AppPalette.softInk)

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: symbolName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(AppPalette.sun)

                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(.system(size: 17))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)

                if step == 2 {
                    Button("Send Invite") {
                        appState.activateAccountability()
                        appState.recordShareActionStarted()
                        shareSheetItem = ShareSheetItem(items: [appState.accountabilityInviteShareText])
                    }
                    .buttonStyle(SunPrimaryButtonStyle())
                    .accessibilityIdentifier("accountabilityOnboarding.share")

                    Button("Add Nearby") {
                        appState.activateAccountability()
                        router.replace(with: .friends)
                    }
                    .buttonStyle(SunSecondaryButtonStyle())
                }

                Spacer(minLength: 0)
            }
        } footer: {
            Button(step == 3 ? "Done" : "Next") {
                if step < 3 {
                    if step == 1 {
                        appState.activateAccountability()
                    }
                    step += 1
                } else {
                    router.replace(with: .friends)
                }
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("accountabilityOnboarding.next")
        }
        .sheet(item: $shareSheetItem) { item in
            ActivityShareSheet(items: item.items)
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var title: String {
        switch step {
        case 1:
            return "Keep it optional"
        case 2:
            return "Add one friend"
        default:
            return "You are set"
        }
    }

    private var detail: String {
        switch step {
        case 1:
            return "Friends only see whether today is logged, your current streak, your best streak, and when you last updated."
        case 2:
            return "Bring two phones together with Nearby Add, or send your invite through Messages and the share sheet."
        default:
            return "Your invite link and backup code are always available from Accountability."
        }
    }

    private var symbolName: String {
        switch step {
        case 1:
            return "lock.shield.fill"
        case 2:
            return "person.badge.plus.fill"
        default:
            return "checkmark.seal.fill"
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.72))
    }
}

struct FriendsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var preferredName = ""
    @State private var importCode = ""
    @State private var importErrorMessage: String?
    @State private var sheet: AccountabilitySheet?

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 22) {
                SunLightHeader(title: "Accountability", showsBack: true, onBack: {
                    router.goBack()
                })

                SunAssetHero(
                    asset: .illustrationFriendsPair,
                    height: 154,
                    glowColor: AppPalette.pool
                )

                statusCard
                addFriendsCard
                inviteCard
                importCard
                friendsListSection

                Spacer(minLength: 0)
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .share(items):
                ActivityShareSheet(items: items)
            case .nearby:
                NearbyAccountabilitySheet()
            }
        }
        .onAppear {
            preferredName = appState.preferredDisplayName
            appState.prepareAccountabilityInvite()
            appState.refreshAccountabilityFriends()
        }
        .onDisappear {
            appState.clearFriendImportMessage()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Accountability is optional", systemImage: "person.2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)

                Spacer(minLength: 0)

                Text(appState.growthSettings.accountability.isActive ? "On" : "Off")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(appState.growthSettings.accountability.isActive ? AppPalette.success : AppPalette.softInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.8)))
            }

            Text("Friends see only your display name, logged-today status, streaks, and last update.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Name friends see", text: $preferredName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("friends.preferredNameField")
                .onSubmit {
                    savePreferredName()
                }

            HStack(spacing: 10) {
                Button(appState.growthSettings.accountability.isActive ? "Save Name" : "Turn On") {
                    appState.activateAccountability(displayName: preferredName)
                    savePreferredName()
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("friends.activate")

                Button("Refresh") {
                    appState.refreshAccountabilityFriends()
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("friends.refresh")
            }

            if let friendImportMessage = appState.friendImportMessage {
                SunStatusCard(
                    title: "Accountability",
                    detail: friendImportMessage,
                    tint: AppPalette.sun,
                    symbol: "person.2.fill"
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var addFriendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add friends")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            accountabilityAction(
                title: "Nearby phones",
                detail: "Both people open this and bring phones together.",
                symbol: "wave.3.right.circle.fill"
            ) {
                appState.activateAccountability(displayName: preferredName)
                sheet = .nearby
            }
            .accessibilityIdentifier("friends.add.nearby")

            accountabilityAction(
                title: "Messages or share sheet",
                detail: "Send an invite link with a backup code.",
                symbol: "message.fill"
            ) {
                appState.activateAccountability(displayName: preferredName)
                appState.recordShareActionStarted()
                sheet = .share([appState.accountabilityInviteShareText])
            }
            .accessibilityIdentifier("friends.add.share")

            accountabilityAction(
                title: "Paste a code",
                detail: "Use the backup code from a friend's invite.",
                symbol: "doc.on.clipboard.fill"
            ) {
                importCode = UIPasteboard.general.string ?? importCode
            }
            .accessibilityIdentifier("friends.add.paste")
        }
        .padding(18)
        .background(cardBackground)
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your invite link")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            if let url = appState.accountabilityInviteURL {
                Text(url.absoluteString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppPalette.softInk)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("friends.inviteLink")
            }

            Text("Backup code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text(appState.accountabilityInviteCode)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppPalette.ink)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .textSelection(.enabled)
                .accessibilityIdentifier("friends.backupCode")

            HStack(spacing: 10) {
                Button("Copy") {
                    UIPasteboard.general.string = appState.accountabilityInviteShareText
                }
                .buttonStyle(SunSecondaryButtonStyle())
                .accessibilityIdentifier("friends.copyInvite")

                Button("Share") {
                    appState.recordShareActionStarted()
                    sheet = .share([appState.accountabilityInviteShareText])
                }
                .buttonStyle(SunPrimaryButtonStyle())
                .accessibilityIdentifier("friends.shareInvite")
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste invite or backup code")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            TextEditor(text: $importCode)
                .frame(minHeight: 92)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.ink.opacity(0.08), lineWidth: 1)
                )
                .accessibilityIdentifier("friends.importCode")

            if let importErrorMessage {
                SunStatusCard(
                    title: "Invite not imported",
                    detail: importErrorMessage,
                    tint: Color.red.opacity(0.72),
                    symbol: "exclamationmark.triangle.fill"
                )
                .accessibilityIdentifier("friends.importError")
            }

            Button("Add Friend") {
                importFriend()
            }
            .buttonStyle(SunPrimaryButtonStyle())
            .accessibilityIdentifier("friends.import")
        }
        .padding(18)
        .background(cardBackground)
    }

    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Friends")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            if appState.friends.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SunclubVisualAsset.illustrationFriendsPair.image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 104)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityHidden(true)

                    Text("Add a friend to see who has logged today and who needs a sunscreen poke.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.softInk)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
                .accessibilityIdentifier("friends.empty")
            } else {
                ForEach(appState.friends) { friend in
                    FriendAccountabilityRow(
                        friend: friend,
                        onRefresh: {
                            appState.refreshAccountabilityFriends()
                        },
                        onPoke: {
                            appState.sendDirectPoke(to: friend.id)
                        },
                        onSharePoke: {
                            appState.recordShareActionStarted()
                            sheet = .share([appState.sharePokeText(for: friend)])
                        },
                        onRemove: {
                            appState.removeFriend(friend.id)
                        }
                    )
                }
            }
        }
    }

    private func savePreferredName() {
        appState.updatePreferredDisplayName(preferredName)
    }

    private func importFriend() {
        let trimmedCode = importCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            importErrorMessage = "Paste an invite or backup code first."
            return
        }

        do {
            try appState.importAccountabilityInviteCode(trimmedCode)
            importCode = ""
            importErrorMessage = nil
        } catch {
            do {
                try appState.importFriendCode(trimmedCode)
                importCode = ""
                importErrorMessage = nil
            } catch {
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? "That invite could not be read."
            }
        }
    }

    private func accountabilityAction(
        title: String,
        detail: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.sun)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.softInk)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.72))
            .shadow(color: AppPalette.ink.opacity(0.055), radius: 18, x: 0, y: 10)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            }
    }
}

private enum AccountabilitySheet: Identifiable {
    case share([Any])
    case nearby

    var id: String {
        switch self {
        case .share:
            return "share"
        case .nearby:
            return "nearby"
        }
    }
}

private struct FriendAccountabilityRow: View {
    let friend: SunclubFriendSnapshot
    let onRefresh: () -> Void
    let onPoke: () -> Void
    let onSharePoke: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                FriendAvatar(name: friend.name, isLogged: friend.hasLoggedToday)

                VStack(alignment: .leading, spacing: 5) {
                    Text(friend.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppPalette.ink)

                    Text(friend.hasLoggedToday ? "Logged today" : "Still open today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(friend.hasLoggedToday ? AppPalette.success : AppPalette.softInk)
                }

                Spacer(minLength: 0)

                Text("\(friend.currentStreak)d")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppPalette.sun)
            }

            Text("Best streak \(friend.longestStreak). Updated \(friend.lastSharedAt.formatted(date: .abbreviated, time: .shortened)).")
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.softInk)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    friendActions
                }

                VStack(spacing: 8) {
                    friendActions
                }
            }

            Button("Remove") {
                onRemove()
            }
            .buttonStyle(SunSecondaryButtonStyle())
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var friendActions: some View {
        Button("Refresh") {
            onRefresh()
        }
        .buttonStyle(SunSecondaryButtonStyle())
        .accessibilityIdentifier("friends.rowRefresh.\(friend.id.uuidString)")

        Button("Poke") {
            onPoke()
        }
        .buttonStyle(SunPrimaryButtonStyle())
        .accessibilityIdentifier("friends.poke.\(friend.id.uuidString)")

        Button("Poke by Message") {
            onSharePoke()
        }
        .buttonStyle(SunSecondaryButtonStyle())
        .accessibilityIdentifier("friends.sharePoke.\(friend.id.uuidString)")
    }
}

private struct FriendAvatar: View {
    let name: String
    let isLogged: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isLogged
                            ? [AppPalette.aloe, AppPalette.sun]
                            : [AppPalette.pool.opacity(0.8), AppPalette.warmGlow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(initial)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            if isLogged {
                SunclubVisualAsset.motifShieldGlow.image
                    .resizable()
                    .scaledToFit()
                    .opacity(0.28)
            }
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }

    private var initial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "S"
    }
}

private struct NearbyAccountabilitySheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exchange = SunclubNearbyFriendExchange()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Nearby Add")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(AppPalette.ink)

                Text("Both people open this screen and keep the phones close. Sunclub exchanges the same invite link and backup code you can share by Messages.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppPalette.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                statusContent

                Spacer(minLength: 0)
            }
            .padding(24)
            .background {
                SunBackdrop()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        exchange.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                appState.activateAccountability()
                exchange.start(
                    displayName: appState.preferredDisplayName,
                    envelope: appState.preparedAccountabilityInviteEnvelope()
                )
            }
            .onDisappear {
                exchange.stop()
            }
            .onChange(of: exchange.state) { _, newState in
                if case let .received(envelope) = newState {
                    appState.importAccountabilityInvite(envelope)
                }
            }
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch exchange.state {
        case .idle:
            nearbyStatus("Ready", detail: "Starting nearby search.", symbol: "dot.radiowaves.left.and.right")
        case .searching:
            nearbyStatus("Searching", detail: peerDetail, symbol: "dot.radiowaves.left.and.right")
        case let .connected(name):
            nearbyStatus("Connected to \(name)", detail: "Sending invite.", symbol: "iphone.gen3.radiowaves.left.and.right")
        case let .received(envelope):
            nearbyStatus("Added \(envelope.displayName)", detail: "You can close Nearby Add.", symbol: "checkmark.seal.fill")
        case let .failed(message):
            nearbyStatus("Nearby stopped", detail: message, symbol: "exclamationmark.triangle.fill")
        }
    }

    private var peerDetail: String {
        exchange.visiblePeers.isEmpty
            ? "Ask your friend to open Nearby Add."
            : "Found \(exchange.visiblePeers.joined(separator: ", "))."
    }

    private func nearbyStatus(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppPalette.sun)

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppPalette.ink)

            Text(detail)
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }
}

#Preview {
    SunclubPreviewHost {
        FriendsView()
    }
}
