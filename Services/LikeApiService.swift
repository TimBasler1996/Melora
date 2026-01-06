import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles "likes" on tracks between users.
/// Structure in Firestore:
///
/// users/{userId}/likesReceived/{likeId}
/// users/{userId}/likesGiven/{likeId}
///
/// Beide Collections enthalten im Prinzip die gleichen Felder,
/// nur aus Sicht des jeweiligen Users.
actor LikeApiService {

    static let shared = LikeApiService()

    private let db = Firestore.firestore()

    private let usersCollection = "users"

    // MARK: - Public API (Broadcast use-case)

    /// Creates a like from the current Firebase user to `toUser` for the currently broadcasted track.
    ///
    /// - Important:
    ///   - Uses likesReceived/likesGiven collections (compatible with LikesInboxViewModel).
    ///   - Prevents self-like.
    ///   - Prevents duplicate likes (same fromUserId + same trackId) with a small query.
    ///
    func likeBroadcastTrack(
        fromUser: AppUser?,                 // optional (if you have it)
        toUser: AppUser,                    // broadcaster
        track: Track,
        sessionLocation: LocationPoint?,
        placeLabel: String? = nil
    ) async throws -> TrackLike {

        guard let authedUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "LikeApiService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // If fromUser not provided, we still can write with authed uid
        let fromUserId = fromUser?.uid ?? authedUid

        // Prevent self-like
        guard fromUserId != toUser.uid else {
            throw NSError(domain: "LikeApiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot like yourself"])
        }

        // Anti-duplicate: check if user already liked this track for this broadcaster
        let receivedRef = db.collection(usersCollection)
            .document(toUser.uid)
            .collection("likesReceived")

        let dupCheck = try await receivedRef
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("trackId", isEqualTo: track.id)
            .limit(to: 1)
            .getDocuments()

        if !dupCheck.documents.isEmpty {
            // Already liked this track
            // Return a lightweight model (or throw). We'll return a synthetic TrackLike for UI.
            return TrackLike(
                id: dupCheck.documents.first?.documentID ?? UUID().uuidString,
                fromUserId: fromUserId,
                toUserId: toUser.uid,
                trackId: track.id,
                trackTitle: track.title,
                trackArtist: track.artist,
                trackAlbum: track.album,
                trackArtworkURL: track.artworkURL?.absoluteString,
                sessionId: nil,
                createdAt: Date(),
                placeLabel: placeLabel,
                latitude: sessionLocation?.latitude,
                longitude: sessionLocation?.longitude,
                fromUserDisplayName: fromUser?.displayName,
                fromUserAvatarURL: fromUser?.avatarURL
            )
        }

        let now = Date()

        // Firestore kann keine URL speichern → wir speichern Strings.
        let trackArtworkURLString = track.artworkURL?.absoluteString
        let fromUserAvatarURLString = fromUser?.avatarURL

        let payload: [String: Any] = [
            "fromUserId": fromUserId,
            "toUserId": toUser.uid,

            "trackId": track.id,
            "trackTitle": track.title,
            "trackArtist": track.artist,
            "trackAlbum": track.album as Any,

            "createdAt": now,
            "placeLabel": placeLabel as Any,
            "latitude": sessionLocation?.latitude as Any,
            "longitude": sessionLocation?.longitude as Any,

            // Liker-Infos direkt im Like speichern (optional)
            "fromUserDisplayName": fromUser?.displayName as Any,
            "fromUserAvatarURL": fromUserAvatarURLString as Any,

            // Track-Artwork (als String)
            "trackArtworkURL": trackArtworkURLString as Any,

            // sessionId ist im Broadcast-Fall nicht vorhanden
            "sessionId": NSNull()
        ]

        // 1) likesReceived for the target user
        let createdReceivedRef = receivedRef.document()
        try await createdReceivedRef.setData(payload)

        // 2) likesGiven for the liking user (gleicher Payload)
        let givenRef = db.collection(usersCollection)
            .document(fromUserId)
            .collection("likesGiven")
            .document(createdReceivedRef.documentID) // gleiche likeId verwenden
        try await givenRef.setData(payload)

        let like = TrackLike(
            id: createdReceivedRef.documentID,
            fromUserId: fromUserId,
            toUserId: toUser.uid,
            trackId: track.id,
            trackTitle: track.title,
            trackArtist: track.artist,
            trackAlbum: track.album,
            trackArtworkURL: trackArtworkURLString,
            sessionId: nil,
            createdAt: now,
            placeLabel: placeLabel,
            latitude: sessionLocation?.latitude,
            longitude: sessionLocation?.longitude,
            fromUserDisplayName: fromUser?.displayName,
            fromUserAvatarURL: fromUserAvatarURLString
        )

        print("💜 Created broadcast-like from \(fromUserId) → \(toUser.uid) on track \(track.title)")
        return like
    }

    // MARK: - Fetching (unchanged)

    /// Fetches all likes that the given user has received (most recent first).
    func fetchLikesReceived(for userId: String) async throws -> [TrackLike] {
        let snapshot = try await db.collection(usersCollection)
            .document(userId)
            .collection("likesReceived")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Self.decodeTrackLike(from: doc.data(), id: doc.documentID)
        }
    }

    /// Fetches all likes that the given user has given to others.
    func fetchLikesGiven(by userId: String) async throws -> [TrackLike] {
        let snapshot = try await db.collection(usersCollection)
            .document(userId)
            .collection("likesGiven")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Self.decodeTrackLike(from: doc.data(), id: doc.documentID)
        }
    }

    // MARK: - Decoding helper

    private static func decodeTrackLike(from data: [String: Any], id: String) -> TrackLike? {

        guard
            let fromUserId = data["fromUserId"] as? String,
            let toUserId = data["toUserId"] as? String,
            let trackId = data["trackId"] as? String,
            let trackTitle = data["trackTitle"] as? String,
            let trackArtist = data["trackArtist"] as? String
        else {
            return nil
        }

        // createdAt handling: Timestamp oder Date
        let createdAt: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else if let date = data["createdAt"] as? Date {
            createdAt = date
        } else {
            createdAt = Date()
        }

        let trackAlbum = data["trackAlbum"] as? String
        let placeLabel = data["placeLabel"] as? String

        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double

        let fromUserDisplayName = data["fromUserDisplayName"] as? String
        let fromUserAvatarURL = data["fromUserAvatarURL"] as? String

        let trackArtworkURL = data["trackArtworkURL"] as? String

        return TrackLike(
            id: id,
            fromUserId: fromUserId,
            toUserId: toUserId,
            trackId: trackId,
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            trackAlbum: trackAlbum,
            trackArtworkURL: trackArtworkURL,
            sessionId: data["sessionId"] as? String,
            createdAt: createdAt,
            placeLabel: placeLabel,
            latitude: latitude,
            longitude: longitude,
            fromUserDisplayName: fromUserDisplayName,
            fromUserAvatarURL: fromUserAvatarURL
        )
    }
}

