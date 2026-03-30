import Foundation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

/// Listens to:
/// 1. likesGiven status changes → notifies liker when their like is accepted
/// 2. likesReceived new entries → notifies receiver when they get a new like
@MainActor
final class LikeNotificationService: ObservableObject {

    private let db = Firestore.firestore()
    private var givenListener: ListenerRegistration?
    private var receivedListener: ListenerRegistration?
    private var isRunning = false

    private var notifiedAcceptedIds: Set<String> = []
    private var notifiedReceivedIds: Set<String> = []

    private static let acceptedCacheKey = "likeNotification.notifiedAcceptedIds"
    private static let receivedCacheKey = "likeNotification.notifiedReceivedIds"

    init() {
        loadCache()
    }

    deinit {
        givenListener?.remove()
        receivedListener?.remove()
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isRunning = true
        listenToAcceptedLikes(userId: uid)
        listenToNewLikesReceived(userId: uid)
    }

    func stop() {
        givenListener?.remove()
        givenListener = nil
        receivedListener?.remove()
        receivedListener = nil
        isRunning = false
    }

    // MARK: - Listener: Likes Accepted (for the liker)

    private func listenToAcceptedLikes(userId: String) {
        let ref = db.collection("users")
            .document(userId)
            .collection("likesGiven")
            .whereField("status", isEqualTo: TrackLike.Status.accepted.rawValue)
            .order(by: "respondedAt", descending: true)
            .limit(to: 50)

        givenListener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self, let snapshot else { return }

            Task { @MainActor in
                for change in snapshot.documentChanges where change.type == .modified || change.type == .added {
                    let doc = change.document
                    let likeId = doc.documentID
                    let data = doc.data()

                    guard !self.notifiedAcceptedIds.contains(likeId) else { continue }

                    if let respondedAt = (data["respondedAt"] as? Timestamp)?.dateValue(),
                       Date().timeIntervalSince(respondedAt) < 300 {

                        let toUserId = data["toUserId"] as? String ?? ""
                        let trackTitle = data["trackTitle"] as? String ?? "a track"
                        let likeMessage = data["message"] as? String
                        let displayName = await self.fetchDisplayName(uid: toUserId)

                        let body: String
                        if let msg = likeMessage, !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            body = "Your message on \"\(trackTitle)\" was delivered. Start chatting!"
                        } else {
                            body = "Your like on \"\(trackTitle)\" was accepted. Start chatting now!"
                        }

                        await self.sendLocalNotification(
                            id: "like-accepted-\(likeId)",
                            title: "\(displayName) accepted your interaction!",
                            body: body,
                            userInfo: ["likeId": likeId, "type": "likeAccepted"]
                        )
                    }
                    self.notifiedAcceptedIds.insert(likeId)
                }
                self.saveCache()
            }
        }
    }

    // MARK: - Listener: New Likes Received (for the receiver)

    private func listenToNewLikesReceived(userId: String) {
        let ref = db.collection("users")
            .document(userId)
            .collection("likesReceived")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)

        receivedListener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self, let snapshot else { return }

            Task { @MainActor in
                let notifyEnabled = UserDefaults.standard.object(forKey: "settings.notify.newLikes") as? Bool ?? true
                guard notifyEnabled else { return }

                for change in snapshot.documentChanges where change.type == .added {
                    let doc = change.document
                    let likeId = doc.documentID
                    let data = doc.data()

                    guard !self.notifiedReceivedIds.contains(likeId) else { continue }

                    // Only notify for recent likes (within last 2 minutes)
                    if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                       Date().timeIntervalSince(createdAt) < 120 {

                        let fromUserId = data["fromUserId"] as? String ?? ""
                        let trackTitle = data["trackTitle"] as? String ?? "a track"
                        let displayName: String
                        if let storedName = data["fromUserDisplayName"] as? String {
                            displayName = storedName
                        } else {
                            displayName = await self.fetchDisplayName(uid: fromUserId)
                        }

                        await self.sendLocalNotification(
                            id: "like-received-\(likeId)",
                            title: "\(displayName) liked your track!",
                            body: "\"\(trackTitle)\" got a new like.",
                            userInfo: ["likeId": likeId, "type": "likeReceived"]
                        )
                    }
                    self.notifiedReceivedIds.insert(likeId)
                }
                self.saveCache()
            }
        }
    }

    // MARK: - Notification

    private func sendLocalNotification(id: String, title: String, body: String, userInfo: [String: Any]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helper

    private func fetchDisplayName(uid: String) async -> String {
        guard !uid.isEmpty else { return "Someone" }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            return doc.data()?["displayName"] as? String ?? "Someone"
        } catch {
            return "Someone"
        }
    }

    // MARK: - Cache

    private func loadCache() {
        notifiedAcceptedIds = Set(UserDefaults.standard.stringArray(forKey: Self.acceptedCacheKey) ?? [])
        notifiedReceivedIds = Set(UserDefaults.standard.stringArray(forKey: Self.receivedCacheKey) ?? [])
    }

    private func saveCache() {
        if notifiedAcceptedIds.count > 300 {
            notifiedAcceptedIds = Set(Array(notifiedAcceptedIds.suffix(200)))
        }
        if notifiedReceivedIds.count > 300 {
            notifiedReceivedIds = Set(Array(notifiedReceivedIds.suffix(200)))
        }
        UserDefaults.standard.set(Array(notifiedAcceptedIds), forKey: Self.acceptedCacheKey)
        UserDefaults.standard.set(Array(notifiedReceivedIds), forKey: Self.receivedCacheKey)
    }
}
