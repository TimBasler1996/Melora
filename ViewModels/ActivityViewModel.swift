import Foundation
import FirebaseAuth
import FirebaseFirestore

/// One row in the Activity feed: someone liked a track you played, or
/// someone started following you.
struct ActivityItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case like(trackTitle: String, trackArtist: String, artworkURL: String?)
        case follow
    }

    let id: String
    let userId: String
    var displayName: String?
    var avatarURL: String?
    let kind: Kind
    let date: Date
}

/// Loads likes and new followers into one timeline. Likes that carry a
/// message are message requests and live in Chats, so they are left out.
@MainActor
final class ActivityViewModel: ObservableObject {

    @Published private(set) var items: [ActivityItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// Who I follow, so follow rows can offer "Follow back" / "Following".
    @Published private(set) var followingIds: Set<String> = []
    @Published var actionError: String?

    /// The last visit, kept per source so the badge logic stays unchanged.
    private let likesSeenKey = "LikesInboxView_lastSeenDate"
    private let followersSeenKey = "FollowersInbox_lastSeenDate"
    private(set) var lastSeenDate: Date?

    private let db = Firestore.firestore()
    private var followersListener: ListenerRegistration?
    private var followingListener: ListenerRegistration?
    private var likesTask: Task<Void, Never>?
    private var likeItems: [ActivityItem] = []
    private var followItems: [ActivityItem] = []
    private var userCache: [String: AppUser] = [:]

    init() {
        let defaults = UserDefaults.standard
        let likesSeen = defaults.object(forKey: likesSeenKey) as? Date
        let followersSeen = defaults.object(forKey: followersSeenKey) as? Date
        // A row is "new" when it is newer than the visit that could have shown it.
        switch (likesSeen, followersSeen) {
        case let (a?, b?): lastSeenDate = min(a, b)
        case let (a?, nil): lastSeenDate = a
        case let (nil, b?): lastSeenDate = b
        default: lastSeenDate = nil
        }
    }

    deinit {
        followersListener?.remove()
        followingListener?.remove()
    }

    func isNew(_ item: ActivityItem) -> Bool {
        guard let seen = lastSeenDate else { return true }
        return item.date > seen
    }

    var newItems: [ActivityItem] { items.filter { isNew($0) } }
    var earlierItems: [ActivityItem] { items.filter { !isNew($0) } }

    // MARK: - Lifecycle

    func start() {
        guard let myUid = Auth.auth().currentUser?.uid else {
            errorMessage = "You’re not signed in yet. Try again in a moment."
            return
        }
        errorMessage = nil
        if items.isEmpty { isLoading = true }

        loadLikes(for: myUid)

        followersListener?.remove()
        followersListener = db.collection("follows")
            .whereField("followingId", isEqualTo: myUid)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = UserFacingError.message(for: error, fallback: "Check your connection and try again.")
                    self.isLoading = false
                    return
                }
                let docs = snap?.documents ?? []
                self.followItems = docs.compactMap { doc in
                    let data = doc.data()
                    guard let followerId = data["followerId"] as? String else { return nil }
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    return ActivityItem(
                        id: "follow_\(doc.documentID)",
                        userId: followerId,
                        displayName: self.userCache[followerId]?.displayName,
                        avatarURL: self.userCache[followerId].flatMap { $0.photoURLs?.first ?? $0.avatarURL },
                        kind: .follow,
                        date: createdAt
                    )
                }
                self.merge()
                self.enrichUsers()
            }

        followingListener?.remove()
        followingListener = FollowApiService.shared.listenToFollowing { [weak self] ids in
            Task { @MainActor [weak self] in self?.followingIds = ids }
        }
    }

    func stop() {
        followersListener?.remove()
        followersListener = nil
        followingListener?.remove()
        followingListener = nil
        likesTask?.cancel()
    }

    func reload() {
        guard let myUid = Auth.auth().currentUser?.uid else { return }
        loadLikes(for: myUid)
    }

    /// Everything shown counts as seen once the feed was on screen.
    func markAllAsSeen() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: likesSeenKey)
        UserDefaults.standard.set(now, forKey: followersSeenKey)
        // Keep the current "New" section until the next visit.
    }

    // MARK: - Follow back

    func isFollowing(_ userId: String) -> Bool { followingIds.contains(userId) }

    func toggleFollow(_ userId: String) async {
        let was = isFollowing(userId)
        if was { followingIds.remove(userId) } else { followingIds.insert(userId) }
        do {
            if was {
                try await FollowApiService.shared.unfollow(userId: userId)
            } else {
                try await FollowApiService.shared.follow(userId: userId)
            }
        } catch {
            if was { followingIds.insert(userId) } else { followingIds.remove(userId) }
            actionError = UserFacingError.message(
                for: error,
                fallback: was ? "Couldn’t unfollow. Please try again." : "Couldn’t follow back. Please try again."
            )
        }
    }

    // MARK: - Likes

    private func loadLikes(for myUid: String) {
        likesTask?.cancel()
        likesTask = Task {
            do {
                var likes = try await LikeApiService.shared.fetchLikesReceived(for: myUid)
                likes = likes.filter { ($0.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                likes = await LikeApiService.shared.enrichLikesWithUserData(likes)
                if Task.isCancelled { return }
                likeItems = likes.map { like in
                    ActivityItem(
                        id: "like_\(like.id)",
                        userId: like.fromUserId,
                        displayName: like.fromUserDisplayName,
                        avatarURL: like.fromUserAvatarURL,
                        kind: .like(trackTitle: like.trackTitle, trackArtist: like.trackArtist, artworkURL: like.trackArtworkURL),
                        date: like.createdAt
                    )
                }
                merge()
                isLoading = false
            } catch {
                if Task.isCancelled { return }
                errorMessage = UserFacingError.message(for: error, fallback: "Couldn’t load your activity. Please try again.")
                isLoading = false
            }
        }
    }

    private func merge() {
        items = (likeItems + followItems).sorted { $0.date > $1.date }
        if !followItems.isEmpty || !likeItems.isEmpty { isLoading = false }
    }

    /// Follow rows come without names; fetch each follower once.
    private func enrichUsers() {
        let missing = Set(followItems.filter { $0.displayName == nil }.map(\.userId))
            .subtracting(userCache.keys)
        for uid in missing {
            UserApiService.shared.getUser(uid: uid) { [weak self] result in
                guard case .success(let user) = result else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.userCache[uid] = user
                    for index in self.followItems.indices where self.followItems[index].userId == uid {
                        self.followItems[index].displayName = user.displayName
                        self.followItems[index].avatarURL = user.photoURLs?.first ?? user.avatarURL
                    }
                    self.merge()
                }
            }
        }
    }
}
