import SwiftUI

struct FriendsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var preferredName = ""
    @State private var importCode = ""
    @State private var importErrorMessage: String?
    @State private var shareSheetItem: ShareSheetItem?

    var body: some View {
        SunLightScreen {
            VStack(alignment: .leading, spacing: 24) {
                SunLightHeader(title: "Accountability", showsBack: true, onBack: {
                    router.goBack()
                })

                profileCard

                if let friendImportMessage = appState.friendImportMessage {
                    SunStatusCard(
                        title: "Accountability nudge",
                        detail: friendImportMessage,
                        tint: AppPalette.sun,
                        symbol: "person.2.fill"
                    )
                }

                inviteCard
                importCard
                friendsListSection

                Spacer(minLength: 0)
            }
        }
        .sheet(item: $shareSheetItem) { item in
            ActivityShareSheet(items: item.items)
        }
        .onAppear {
            preferredName = appState.preferredDisplayName
        }
        .onDisappear {
            appState.clearFriendImportMessage()
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactivePopGestureEnabled()
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your share profile")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            TextField("Name friends see", text: $preferredName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    appState.updatePreferredDisplayName(preferredName)
                }

            Button("Save Name") {
                appState.updatePreferredDisplayName(preferredName)
            }
            .buttonStyle(SunSecondaryButtonStyle())
        }
        .padding(18)
        .background(cardBackground)
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share accountability")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            Text("Send a lightweight streak snapshot through iMessage or any share sheet.")
                .font(.system(size: 15))
                .foregroundStyle(AppPalette.softInk)

            if appState.records.isEmpty {
                Text("Log at least one day before sharing your status.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.softInk)
            } else {
                Button("Share My Status") {
                    shareLocalStatus()
                }
                .buttonStyle(SunPrimaryButtonStyle())
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import a code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            TextEditor(text: $importCode)
                .frame(minHeight: 100)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.ink.opacity(0.08), lineWidth: 1)
                )

            if let importErrorMessage {
                SunStatusCard(
                    title: "Code not imported",
                    detail: importErrorMessage,
                    tint: Color.red.opacity(0.72),
                    symbol: "exclamationmark.triangle.fill"
                )
                .accessibilityIdentifier("friends.importError")
            }

            Button("Import Friend") {
                importFriend()
            }
            .buttonStyle(SunPrimaryButtonStyle())
        }
        .padding(18)
        .background(cardBackground)
    }

    private var friendsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared streaks")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppPalette.softInk)

            if appState.friends.isEmpty {
                Text("Import a friend code to see who has logged today and whose streak is rolling.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.softInk)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground)
            } else {
                ForEach(appState.friends) { friend in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(friend.name)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppPalette.ink)

                                Text(friend.hasLoggedToday ? "Logged today" : "Still open today")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(friend.hasLoggedToday ? AppPalette.success : AppPalette.softInk)
                            }

                            Spacer(minLength: 0)

                            Text("\(friend.currentStreak)d")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(AppPalette.sun)
                        }

                        Text("Best streak \(friend.longestStreak). Shared \(friend.lastSharedAt.formatted(date: .abbreviated, time: .shortened)).")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.softInk)

                        Button("Remove") {
                            appState.removeFriend(friend.id)
                        }
                        .buttonStyle(SunSecondaryButtonStyle())
                    }
                    .padding(18)
                    .background(cardBackground)
                }
            }
        }
    }

    private func shareLocalStatus() {
        guard let shareCode = try? appState.friendShareCode() else {
            return
        }
        let intro = "Join me on Sunclub. Import this accountability code:\n\n\(shareCode)"
        appState.recordShareActionStarted()
        shareSheetItem = ShareSheetItem(items: [intro])
    }

    private func importFriend() {
        let trimmedCode = importCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            importErrorMessage = "Paste a friend code first."
            return
        }

        do {
            try appState.importFriendCode(trimmedCode)
            importCode = ""
            importErrorMessage = nil
        } catch {
            importErrorMessage = (error as? LocalizedError)?.errorDescription ?? "That friend code could not be read."
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.72))
    }
}

#Preview {
    SunclubPreviewHost {
        FriendsView()
    }
}
