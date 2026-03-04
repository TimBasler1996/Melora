import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FollowersListView: View {

    @StateObject private var vm = FollowersListViewModel()
    @State private var searchText = ""

    private var filteredFollowers: [FollowerUser] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return vm.followers }
        return vm.followers.filter { follower in
            follower.displayName.lowercased().contains(trimmed)
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if vm.followers.count > 5 {
                    searchBar
                }

                if vm.isLoading && vm.followers.isEmpty {
                    Spacer()
                    ProgressView().tint(AppColors.primary)
                    Text("Loading followers…")
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.top, 8)
                    Spacer()
                } else if vm.followers.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No followers yet")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Text("When someone follows you, they'll appear here")
                            .font(AppFonts.footnote())
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else if filteredFollowers.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.slash.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No results")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredFollowers) { follower in
                                NavigationLink {
                                    UserProfilePreviewView(userId: follower.id)
                                } label: {
                                    followerRow(follower)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, AppLayout.screenPadding)
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadFollowers()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 16, weight: .medium))

            TextField("Search followers…", text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Follower Row

    private func followerRow(_ follower: FollowerUser) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Group {
                if let urlString = follower.avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle().fill(Color.white.opacity(0.1))
                                .overlay(ProgressView().tint(.white))
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            followerPlaceholder(follower)
                        }
                    }
                } else {
                    followerPlaceholder(follower)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(follower.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let subtitle = follower.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFonts.footnote())
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()

            if follower.followChecked {
                Button {
                    Task { await vm.toggleFollow(follower: follower) }
                } label: {
                    Text(follower.isFollowingBack ? "Following" : "Follow")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(follower.isFollowingBack ? .white.opacity(0.7) : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(follower.isFollowingBack ? Color.white.opacity(0.12) : AppColors.primary)
                        )
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func followerPlaceholder(_ follower: FollowerUser) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.15))
            Text(follower.initials)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Model

struct FollowerUser: Identifiable {
    let id: String // uid
    let displayName: String
    let avatarURL: String?
    let age: Int?
    let city: String?
    var isFollowingBack: Bool
    var followChecked: Bool

    var initials: String {
        let parts = displayName.split(separator: " ")
        if let first = parts.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }

    var subtitle: String? {
        let parts: [String] = [
            age.map { "\($0)" },
            city
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - ViewModel

@MainActor
final class FollowersListViewModel: ObservableObject {

    @Published var followers: [FollowerUser] = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    func loadFollowers() async {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        do {
            let followerIds = try await FollowApiService.shared.fetchFollowerIds(of: myUid)

            // Fetch user data for all followers
            var users: [FollowerUser] = []
            await withTaskGroup(of: FollowerUser?.self) { group in
                for uid in followerIds {
                    group.addTask {
                        let user = try? await self.fetchUser(uid: uid)
                        return user
                    }
                }
                for await user in group {
                    if let user { users.append(user) }
                }
            }

            // Sort alphabetically
            followers = users.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            isLoading = false

            // Check follow-back status in background
            await checkFollowStatus()
        } catch {
            isLoading = false
            print("❌ [FollowersList] failed to load:", error.localizedDescription)
        }
    }

    func toggleFollow(follower: FollowerUser) async {
        guard let index = followers.firstIndex(where: { $0.id == follower.id }) else { return }
        do {
            if follower.isFollowingBack {
                try await FollowApiService.shared.unfollow(userId: follower.id)
                followers[index].isFollowingBack = false
            } else {
                try await FollowApiService.shared.follow(userId: follower.id)
                followers[index].isFollowingBack = true
            }
        } catch {
            print("❌ [FollowersList] toggle follow failed:", error.localizedDescription)
        }
    }

    private func fetchUser(uid: String) async throws -> FollowerUser {
        return try await withCheckedThrowingContinuation { continuation in
            UserApiService.shared.fetchUser(uid: uid) { result in
                switch result {
                case .success(let user):
                    let follower = FollowerUser(
                        id: user.uid,
                        displayName: user.displayName,
                        avatarURL: user.photoURLs?.first ?? user.avatarURL,
                        age: user.age,
                        city: user.city ?? user.hometown,
                        isFollowingBack: false,
                        followChecked: false
                    )
                    continuation.resume(returning: follower)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func checkFollowStatus() async {
        for index in followers.indices {
            let uid = followers[index].id
            let isFollowing = (try? await FollowApiService.shared.isFollowing(userId: uid)) ?? false
            followers[index].isFollowingBack = isFollowing
            followers[index].followChecked = true
        }
    }
}
