import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class UserSearchViewModel: ObservableObject {

    @Published var searchText: String = ""
    @Published private(set) var results: [AppUser] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var followingIds: Set<String> = []

    private let db = Firestore.firestore()
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
        followListener = followService.listenToFollowing { [weak self] ids in
            Task { @MainActor in
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
            return
        }

        isSearching = true

        searchTask = Task {
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

        // Merge results, deduplicate, exclude self
        var seen = Set<String>()
        var users: [AppUser] = []

        for doc in firstNameSnap.documents + displayNameSnap.documents {
            let uid = doc.documentID
            guard uid != currentUid, !seen.contains(uid) else { continue }
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
        if isFollowing(userId) {
            try? await followService.unfollow(userId: userId)
            followingIds.remove(userId)
        } else {
            try? await followService.follow(userId: userId)
            followingIds.insert(userId)
        }
    }
}
