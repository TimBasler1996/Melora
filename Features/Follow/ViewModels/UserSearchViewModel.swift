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
                print("❌ [UserSearch] Error: \(error)")
                print("❌ [UserSearch] \(error.localizedDescription)")
                self.results = []
            }
            self.isSearching = false
        }
    }

    private func searchUsers(query: String) async throws -> [AppUser] {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("⚠️ [UserSearch] No authenticated user – search aborted")
            return []
        }

        let lowered = query.lowercased()
        let end = lowered + "\u{f8ff}"
        print("🔍 [UserSearch] Searching for '\(lowered)' (uid: \(currentUid))")

        // Search by firstName (prefix match)
        let firstNameSnap = try await db.collection("users")
            .whereField("firstNameLower", isGreaterThanOrEqualTo: lowered)
            .whereField("firstNameLower", isLessThan: end)
            .limit(to: 20)
            .getDocuments()

        print("🔍 [UserSearch] firstNameLower hits: \(firstNameSnap.documents.count)")

        // Search by lastName (prefix match)
        let lastNameSnap = try await db.collection("users")
            .whereField("lastNameLower", isGreaterThanOrEqualTo: lowered)
            .whereField("lastNameLower", isLessThan: end)
            .limit(to: 20)
            .getDocuments()

        print("🔍 [UserSearch] lastNameLower hits: \(lastNameSnap.documents.count)")

        // Merge results, deduplicate, exclude self
        var seen = Set<String>()
        var users: [AppUser] = []

        for doc in firstNameSnap.documents + lastNameSnap.documents {
            let uid = doc.documentID
            guard uid != currentUid, !seen.contains(uid) else { continue }
            seen.insert(uid)
            users.append(AppUser.fromFirestore(uid: uid, data: doc.data()))
        }

        print("🔍 [UserSearch] Total unique results: \(users.count)")
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
