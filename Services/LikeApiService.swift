import Foundation
import FirebaseAuth
import FirebaseFirestore

actor LikeApiService {

    static let shared = LikeApiService()

    private let db = Firestore.firestore()
    private let usersCollection = "users"

    // MARK: - Create Like (Broadcast)

    func likeBroadcastTrack(
        fromUser: AppUser?,
        toUser: AppUser,
        track: Track,
        sessionLocation: LocationPoint?,
        placeLabel: String? = nil,
        message: String? = nil
    ) async throws -> TrackLike {

        guard let authedUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "LikeApiService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let fromUserId = fromUser?.uid ?? authedUid

        guard fromUserId != toUser.uid else {
            throw NSError(domain: "LikeApiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot like yourself"])
        }

        let receivedCollection = db.collection(usersCollection)
            .document(toUser.uid)
            .collection("likesReceived")

        // Prevent duplicates: same liker + same track
        let dupCheck = try await receivedCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("trackId", isEqualTo: track.id)
            .limit(to: 1)
            .getDocuments()

        if !dupCheck.documents.isEmpty {
            // already liked -> return a local-ish model
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
                fromUserAvatarURL: fromUser?.avatarURL,
                message: message,
                status: .pending
            )
        }

        let now = Date()

        let trackArtworkURLString = track.artworkURL?.absoluteString

        let trimmedMessage: String? = {
            let t = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : String(t.prefix(160))
        }()

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

            // ✅ Important: store display name + avatar directly in like doc
            "fromUserDisplayName": fromUser?.displayName as Any,
            "fromUserAvatarURL": fromUser?.avatarURL as Any,

            "trackArtworkURL": trackArtworkURLString as Any,
            "sessionId": NSNull(),

            "message": trimmedMessage as Any,
            "status": TrackLike.Status.pending.rawValue
        ]

        // likesReceived
        let createdReceivedRef = receivedCollection.document()
        try await createdReceivedRef.setData(payload)

        // likesGiven mirror (owner = liker)
        let givenRef = db.collection(usersCollection)
            .document(fromUserId)
            .collection("likesGiven")
            .document(createdReceivedRef.documentID)
        try await givenRef.setData(payload)

        return TrackLike(
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
            fromUserAvatarURL: fromUser?.avatarURL,
            message: trimmedMessage,
            status: .pending
        )
    }

    // MARK: - Update Like Status (Receiver-side only)

    /// Receiver can reliably update ONLY their own likesReceived due to Firestore rules.
    func setLikeStatusReceivedOnly(
        likeId: String,
        toUserId: String,
        status: TrackLike.Status
    ) async throws {

        let receivedRef = db.collection(usersCollection)
            .document(toUserId)
            .collection("likesReceived")
            .document(likeId)

        try await receivedRef.updateData([
            "status": status.rawValue,
            "respondedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Fetching

    func fetchLikesReceived(for userId: String) async throws -> [TrackLike] {
        let snapshot = try await db.collection(usersCollection)
            .document(userId)
            .collection("likesReceived")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            TrackLike.fromFirestore(id: doc.documentID, data: doc.data())
        }
    }

    func fetchLikesGiven(by userId: String) async throws -> [TrackLike] {
        let snapshot = try await db.collection(usersCollection)
            .document(userId)
            .collection("likesGiven")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            TrackLike.fromFirestore(id: doc.documentID, data: doc.data())
        }
    }
}

