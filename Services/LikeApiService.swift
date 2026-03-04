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

        // ✅ IMPROVED: Always fetch complete user data from Firestore to ensure displayName + avatar are set
        var likerUser = fromUser
        
        // Always fetch from Firestore if:
        // - We don't have a user object
        // - The displayName is empty or "Unknown"
        // - The avatarURL is missing
        let needsFetch = likerUser == nil || 
                        likerUser?.displayName.isEmpty == true || 
                        likerUser?.displayName == "Unknown" ||
                        likerUser?.avatarURL == nil
        
        if needsFetch {
            print("🔄 [Like] Fetching complete user data from Firestore for uid=\(fromUserId)...")
            do {
                likerUser = try await fetchUserAsync(uid: fromUserId)
                
                // Check if fetched user still has "Unknown" as display name
                if likerUser?.displayName == "Unknown" || likerUser?.displayName.isEmpty == true {
                    print("⚠️ [Like] WARNING: User \(fromUserId) has incomplete profile (displayName=\(likerUser?.displayName ?? "nil"))")
                    print("   This user should complete their profile to appear correctly in likes.")
                } else {
                    print("✅ [Like] Fetched user: displayName=\(likerUser?.displayName ?? "nil"), avatarURL=\(likerUser?.avatarURL ?? "nil")")
                }
            } catch {
                print("❌ [Like] Failed to fetch user from Firestore: \(error.localizedDescription)")
                // Continue with whatever data we have
            }
        }

        // ✅ Smart avatar URL with fallback to first photo
        let avatarURL: String? = {
            if let avatar = likerUser?.avatarURL, !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return avatar
            }
            // Fallback to first photo
            if let photos = likerUser?.photoURLs, !photos.isEmpty {
                let firstPhoto = photos[0].trimmingCharacters(in: .whitespacesAndNewlines)
                return firstPhoto.isEmpty ? nil : firstPhoto
            }
            return nil
        }()

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
                fromUserDisplayName: likerUser?.displayName,
                fromUserAvatarURL: avatarURL, // ✅ Use smart fallback
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
            "fromUserDisplayName": likerUser?.displayName as Any,
            "fromUserAvatarURL": avatarURL as Any,

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
            fromUserDisplayName: likerUser?.displayName,
            fromUserAvatarURL: avatarURL, // ✅ Use smart fallback
            message: trimmedMessage,
            status: .pending
        )
    }

    // MARK: - Update Like Status (both sides)

    /// Updates like status on both receiver's likesReceived and sender's likesGiven.
    func setLikeStatusReceivedOnly(
        likeId: String,
        toUserId: String,
        status: TrackLike.Status
    ) async throws {

        let statusData: [String: Any] = [
            "status": status.rawValue,
            "respondedAt": Timestamp(date: Date())
        ]

        // Update receiver's likesReceived
        let receivedRef = db.collection(usersCollection)
            .document(toUserId)
            .collection("likesReceived")
            .document(likeId)

        try await receivedRef.updateData(statusData)

        // Also update sender's likesGiven mirror so they can see the status change
        let receivedDoc = try await receivedRef.getDocument()
        if let fromUserId = receivedDoc.data()?["fromUserId"] as? String {
            let givenRef = db.collection(usersCollection)
                .document(fromUserId)
                .collection("likesGiven")
                .document(likeId)
            try? await givenRef.updateData(statusData)
        }
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

    // MARK: - Helper: Fetch User

    private func fetchUserAsync(uid: String) async throws -> AppUser {
        let snapshot = try await db.collection(usersCollection).document(uid).getDocument()
        guard let data = snapshot.data() else {
            throw NSError(domain: "LikeApiService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User \(uid) not found"])
        }
        return AppUser.fromFirestore(uid: uid, data: data)
    }
    
    // MARK: - Enrich Likes with User Data
    
    /// Enriches likes with complete user data (displayName, avatarURL) if missing
    /// This is useful for existing likes that might have incomplete user info
    func enrichLikesWithUserData(_ likes: [TrackLike]) async -> [TrackLike] {
        var enriched = likes
        
        // Find all likes that need user data
        let userIdsNeedingFetch = Set(
            likes.filter { like in
                let hasNoDisplayName = like.fromUserDisplayName == nil || like.fromUserDisplayName?.isEmpty == true
                let hasNoAvatar = like.fromUserAvatarURL == nil || like.fromUserAvatarURL?.isEmpty == true
                return hasNoDisplayName || hasNoAvatar
            }.map { $0.fromUserId }
        )
        
        guard !userIdsNeedingFetch.isEmpty else {
            print("✅ [Like] All \(likes.count) likes already have complete user data")
            return enriched
        }
        
        print("🔄 [Like] Fetching user data for \(userIdsNeedingFetch.count) users...")
        
        // Fetch all needed users in parallel
        var fetchedUsers: [String: AppUser] = [:]
        await withTaskGroup(of: (String, AppUser?).self) { group in
            for userId in userIdsNeedingFetch {
                group.addTask { [self] in
                    do {
                        let user = try await self.fetchUserAsync(uid: userId)
                        print("  ✅ Fetched user: \(user.displayName) (uid: \(userId))")
                        return (userId, user)
                    } catch {
                        print("  ❌ Failed to fetch user \(userId): \(error.localizedDescription)")
                        return (userId, nil)
                    }
                }
            }
            
            for await (userId, user) in group {
                if let user {
                    fetchedUsers[userId] = user
                }
            }
        }
        
        print("📊 [Like] Fetched \(fetchedUsers.count) users successfully")
        
        // Update likes with fetched user data
        for i in enriched.indices {
            let like = enriched[i]
            if let user = fetchedUsers[like.fromUserId] {
                enriched[i].fromUserDisplayName = user.displayName
                
                // ✅ Smart avatar fallback: avatarURL -> first photoURL -> nil
                let avatarURL: String? = {
                    if let avatar = user.avatarURL, !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return avatar
                    }
                    // Fallback to first photo
                    if let photos = user.photoURLs, !photos.isEmpty {
                        let firstPhoto = photos[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        return firstPhoto.isEmpty ? nil : firstPhoto
                    }
                    return nil
                }()
                
                enriched[i].fromUserAvatarURL = avatarURL
                print("  ✨ Enriched like \(like.id): \(user.displayName) -> avatar: \(avatarURL != nil ? "✅" : "❌") (source: \(user.avatarURL != nil ? "avatarURL" : "photoURLs[0]"))")
            } else {
                print("  ⚠️ Could not enrich like \(like.id): user \(like.fromUserId) not found")
            }
        }
        
        print("✅ [Like] Enrichment complete: \(enriched.filter { $0.fromUserDisplayName != nil }.count)/\(enriched.count) likes have display names")
        
        return enriched
    }
}

