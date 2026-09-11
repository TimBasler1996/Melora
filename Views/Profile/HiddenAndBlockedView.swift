import SwiftUI

/// Settings → Blocked and hidden. Everything the user hid or blocked, with
/// a way back for each entry.
struct HiddenAndBlockedView: View {

    @ObservedObject private var hidden = HiddenContentStore.shared
    @State private var blocked: [BlockedUser] = []
    @State private var isLoadingBlocked = true
    @State private var errorMessage: String?

    private struct BlockedUser: Identifiable {
        let id: String
        var name: String
        var avatarURL: String?
    }

    var body: some View {
        List {
            Section {
                if isLoadingBlocked {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Loading…")
                            .foregroundColor(AppColors.secondaryText)
                    }
                } else if blocked.isEmpty {
                    Text("You haven’t blocked anyone.")
                        .foregroundColor(AppColors.secondaryText)
                } else {
                    ForEach(blocked) { user in
                        HStack(spacing: 12) {
                            avatar(user.avatarURL)
                            Text(user.name)
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                            Button("Unblock") {
                                Task { await unblock(user) }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.bordered)
                            .tint(AppColors.primary)
                        }
                    }
                }
            } header: {
                Text("Blocked people")
            } footer: {
                Text("Blocked people can’t see you in Discover, message you or find you in search.")
            }

            Section {
                if hidden.users.isEmpty {
                    Text("No hidden people.")
                        .foregroundColor(AppColors.secondaryText)
                } else {
                    ForEach(hidden.users) { user in
                        HStack {
                            Text(user.name)
                                .foregroundColor(AppColors.primaryText)
                            Spacer()
                            Button("Show again") {
                                hidden.unhideUser(id: user.id)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.bordered)
                            .tint(AppColors.primary)
                        }
                    }
                }
            } header: {
                Text("Hidden people")
            } footer: {
                Text("Hidden people still see you; they just don’t appear in your Discover feed.")
            }

            Section {
                if hidden.tracks.isEmpty {
                    Text("No hidden songs.")
                        .foregroundColor(AppColors.secondaryText)
                } else {
                    ForEach(hidden.tracks) { track in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .foregroundColor(AppColors.primaryText)
                                    .lineLimit(1)
                                if !track.artist.isEmpty {
                                    Text(track.artist)
                                        .font(AppFonts.caption())
                                        .foregroundColor(AppColors.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Button("Show again") {
                                hidden.unhideTrack(id: track.id)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.bordered)
                            .tint(AppColors.primary)
                        }
                    }
                }
            } header: {
                Text("Hidden songs")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .melScreenBackground()
        .navigationTitle("Blocked and hidden")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await loadBlocked() }
        .task {
            hidden.loadIfNeeded()
            await loadBlocked()
        }
    }

    private func avatar(_ urlString: String?) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Circle().fill(AppColors.surface)
                    }
                }
            } else {
                Circle().fill(AppColors.surface)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func loadBlocked() async {
        isLoadingBlocked = true
        errorMessage = nil
        do {
            let ids = try await BlockService.shared.fetchBlockedIds()
            let rows: [BlockedUser] = await withTaskGroup(of: BlockedUser.self) { group in
                for id in ids {
                    group.addTask {
                        let user: AppUser? = await withCheckedContinuation { cont in
                            UserApiService.shared.fetchUser(uid: id) { result in
                                cont.resume(returning: try? result.get())
                            }
                        }
                        return BlockedUser(
                            id: id,
                            name: user?.displayName ?? "Someone",
                            avatarURL: user?.photoURLs?.first ?? user?.avatarURL
                        )
                    }
                }
                var collected: [BlockedUser] = []
                for await row in group { collected.append(row) }
                return collected.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            blocked = rows
        } catch {
            errorMessage = "Couldn’t load your blocked list. Pull down to try again."
        }
        isLoadingBlocked = false
    }

    private func unblock(_ user: BlockedUser) async {
        let previous = blocked
        blocked.removeAll { $0.id == user.id }
        do {
            try await BlockService.shared.unblockUser(userId: user.id)
        } catch {
            blocked = previous
            errorMessage = "Couldn’t unblock \(user.name). Please try again."
        }
    }
}
