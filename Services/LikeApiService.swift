import Foundation
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
    private let sessionsCollection = "sessions"
    
    // MARK: - Public API
    
    /// Creates a like from `fromUser` to `toUser` on a specific track (with session + location context).
    ///
    /// - Parameters:
    ///   - fromUser: The user who likes (current user).
    ///   - toUser:   The user who is being liked (session owner).
    ///   - sessionId: The session in which the track was playing.
    ///   - track: The track that was liked.
    ///   - sessionLocation: The location of the session at the time of the like.
    ///   - placeLabel: Optional human readable label for the place (e.g. "Gym A").
    ///
    /// - Returns: A `TrackLike` representing the created like.
    /// 
    func likeTrack(
        fromUser: User,
        toUser: User,
        sessionId: String,
        track: Track,
        sessionLocation: LocationPoint?,
        placeLabel: String? = nil
    ) async throws -> TrackLike {
        
        let now = Date()
        
        // Firestore kann keine URL speichern → wir speichern Strings.
        let trackArtworkURLString = track.artworkURL?.absoluteString
        let fromUserAvatarURLString = fromUser.avatarURL?.absoluteString
        
        let payload: [String: Any] = [
            "fromUserId": fromUser.id,
            "toUserId": toUser.id,
            "trackId": track.id,
            "trackTitle": track.title,
            "trackArtist": track.artist,
            "trackAlbum": track.album as Any,
            "sessionId": sessionId,
            "createdAt": now,
            "placeLabel": placeLabel as Any,
            "latitude": sessionLocation?.latitude as Any,
            "longitude": sessionLocation?.longitude as Any,
            
            // Liker-Infos direkt im Like speichern
            "fromUserDisplayName": fromUser.displayName as Any,
            "fromUserAvatarURL": fromUserAvatarURLString as Any,
            
            // Track-Artwork (als String)
            "trackArtworkURL": trackArtworkURLString as Any
        ]
        
        // 1) likesReceived for the target user
        let receivedRef = db.collection(usersCollection)
            .document(toUser.id)
            .collection("likesReceived")
            .document()
        
        try await receivedRef.setData(payload)
        
        // 2) likesGiven for the liking user (gleicher Payload)
        let givenRef = db.collection(usersCollection)
            .document(fromUser.id)
            .collection("likesGiven")
            .document(receivedRef.documentID) // gleiche likeId verwenden
        try await givenRef.setData(payload)
        
        // 3) likeCount in der Session hochzählen
        try await incrementSessionLikeCount(sessionId: sessionId)
        
        // 4) Lokales Modell bauen
        let like = TrackLike(
            id: receivedRef.documentID,
            fromUserId: fromUser.id,
            toUserId: toUser.id,
            trackId: track.id,
            trackTitle: track.title,
            trackArtist: track.artist,
            trackAlbum: track.album,
            sessionId: sessionId,
            createdAt: now,
            placeLabel: placeLabel,
            latitude: sessionLocation?.latitude,
            longitude: sessionLocation?.longitude,
            fromUserDisplayName: fromUser.displayName,
            fromUserAvatarURL: fromUserAvatarURLString,
            trackArtworkURL: trackArtworkURLString
        )
        
        print("💜 Created like from \(fromUser.id) → \(toUser.id) on track \(track.title)")
        return like
    }
    
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
    
    // MARK: - Session likeCount
    
    /// Erhöht den `likeCount` einer Session atomar um 1.
    private func incrementSessionLikeCount(sessionId: String) async throws {
        let sessionRef = db.collection(sessionsCollection).document(sessionId)
        try await sessionRef.updateData([
            "likeCount": FieldValue.increment(Int64(1))
        ])
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
            sessionId: data["sessionId"] as? String ?? "",
            createdAt: createdAt,
            placeLabel: placeLabel,
            latitude: latitude,
            longitude: longitude,
            fromUserDisplayName: fromUserDisplayName,
            fromUserAvatarURL: fromUserAvatarURL,
            trackArtworkURL: trackArtworkURL
        )
    }
}
