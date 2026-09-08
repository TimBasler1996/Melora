import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class UserSearchViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published private(set) var results: [AppUser] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var followingIds: Set<String> = []

    private lazy var db = Firestore.firestore()
    private let followService: FollowApiService
    private var followListener: ListenerRegistration?
    private var searchTask: Task<Void, Never>?

    init(followService: FollowApiService = .shared) {
        self.followService = followService
    }

    deinit {
        followListener?.remove()
    }

    // MARK: - Lifecycle

    func startListening() {
        followListener = followService.listenToFollowing { [weak self] (ids: Set<String>) in
            Task { @MainActor [weak self] in
                self?.followingIds = ids
            }
        }
    }

    func stopListening() {
        followListener?.remove()
        followListener = nil
    }

    // MARK: - Search

    func search() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce so fast typing doesn't fire two Firestore queries per keystroke.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            do {
                let users = try await searchUsers(query: query)
                guard !Task.isCancelled else { return }
                self.results = users
            } catch {
                guard !Task.isCancelled else { return }
                self.results = []
            }
            self.isSearching = false
        }
    }

    private func searchUsers(query: String) async throws -> [AppUser] {
        guard let currentUid = Auth.auth().currentUser?.uid else { return [] }

        let lowered = query.lowercased()
        let end = lowered + "\u{f8ff}"

        // Search by firstName (prefix match)
        let firstNameSnap = try await db.collection("users")
            .whereField("firstNameLower", isGreaterThanOrEqualTo: lowered)
            .whereField("firstNameLower", isLessThan: end)
            .limit(to: 20)
            .getDocuments()

        // Search by displayName (prefix match)
        let displayNameSnap = try await db.collection("users")
            .whereField("displayNameLower", isGreaterThanOrEqualTo: lowered)
            .whereField("displayNameLower", isLessThan: end)
            .limit(to: 20)
            .getDocuments()

        // Merge results, deduplicate, exclude self and blocked users
        let blockedIds = (try? await BlockService.shared.fetchBlockedIds()) ?? []
        var seen = Set<String>()
        var users: [AppUser] = []

        for doc in firstNameSnap.documents + displayNameSnap.documents {
            let uid = doc.documentID
            guard uid != currentUid, !seen.contains(uid), !blockedIds.contains(uid) else { continue }
            seen.insert(uid)
            users.append(AppUser.fromFirestore(uid: uid, data: doc.data()))
        }

        return users
    }

    // MARK: - Follow actions

    func isFollowing(_ userId: String) -> Bool {
        followingIds.contains(userId)
    }

    func toggleFollow(userId: String) async {
        let wasFollowing = isFollowing(userId)
        // Optimistic update with rollback so a failed write doesn't leave the
        // button showing a state the server never reached.
        if wasFollowing {
            followingIds.remove(userId)
        } else {
            followingIds.insert(userId)
        }
        do {
            if wasFollowing {
                try await followService.unfollow(userId: userId)
            } else {
                try await followService.follow(userId: userId)
            }
        } catch {
            if wasFollowing {
                followingIds.insert(userId)
            } else {
                followingIds.remove(userId)
            }
        }
    }
}
