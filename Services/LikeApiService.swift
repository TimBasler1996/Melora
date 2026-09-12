import Foundation
import FirebaseAuth
import FirebaseFirestore

actor LikeApiService {

    static let shared = LikeApiService()

    private let db = Firestore.firestore()
    private let usersCollection = "users"

    enum LikeError: LocalizedError {
        case notAuthenticated
        case cannotLikeSelf
        /// An earlier like or request to this person was declined. The
        /// sender is told neutrally; they are never told about the decline.
        case alreadyReachedOut(name: String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "You’re not signed in."
            case .cannotLikeSelf: return "That’s you."
            case .alreadyReachedOut(let name):
                return "You’ve already reached out to \(name). If they’re interested, they’ll get back to you."
            }
        }
    }

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
            throw LikeError.notAuthenticated
        }

        let fromUserId = fromUser?.uid ?? authedUid

        guard fromUserId != toUser.uid else {
            throw LikeError.cannotLikeSelf
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

        // Prevent duplicates: same liker + same track. These checks read from
        // the server on purpose: offline they fail fast ("You're offline")
        // instead of answering from a stale cache and queueing a write that
        // would go out silently later.
        let dupCheck = try await receivedCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("trackId", isEqualTo: track.id)
            .limit(to: 1)
            .getDocuments(source: .server)

        let trimmedMessage: String? = {
            let t = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : String(t.prefix(160))
        }()

        if let existingDoc = dupCheck.documents.first,
           var existing = TrackLike.fromFirestore(id: existingDoc.documentID, data: existingDoc.data()) {
            // Already liked this track. If a message is added to a plain
            // pending like, attach it so the receiver gets ONE thing to act on
            // (a message request) instead of a like *and* a request.
            if existing.status == .rejected {
                throw LikeError.alreadyReachedOut(name: toUser.displayName)
            }
            let existingMessage = (existing.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmedMessage, existingMessage.isEmpty, (existing.status ?? .pending) == .pending {
                let update: [String: Any] = ["message": trimmedMessage]
                try await existingDoc.reference.updateData(update)
                try? await db.collection(usersCollection)
                    .document(fromUserId)
                    .collection("likesGiven")
                    .document(existing.id)
                    .updateData(update)
                existing.message = trimmedMessage
            }
            return existing
        }

        // A declined (ignored) like or request closes the door: no new likes
        // from this user. The caller shows a neutral message.
        let priorDeclined = try await receivedCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("status", isEqualTo: TrackLike.Status.rejected.rawValue)
            .limit(to: 1)
            .getDocuments(source: .server)
        if !priorDeclined.documents.isEmpty {
            throw LikeError.alreadyReachedOut(name: toUser.displayName)
        }

        // A previously accepted like auto-accepts the new one so the receiver
        // doesn't have to accept the same person twice.
        let priorAccepted = try await receivedCollection
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("status", isEqualTo: TrackLike.Status.accepted.rawValue)
            .limit(to: 1)
            .getDocuments(source: .server)
        let autoAccept = !priorAccepted.documents.isEmpty
        let initialStatus: TrackLike.Status = autoAccept ? .accepted : .pending

        let now = Date()

        let trackArtworkURLString = track.artworkURL?.absoluteString

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
            "status": initialStatus.rawValue
        ]

        // Write likesReceived + the likesGiven mirror atomically so the two
        // sides can never disagree about whether a like exists.
        let createdReceivedRef = receivedCollection.document()
        let givenRef = db.collection(usersCollection)
            .document(fromUserId)
            .collection("likesGiven")
            .document(createdReceivedRef.documentID)

        let batch = db.batch()
        batch.setData(payload, forDocument: createdReceivedRef)
        batch.setData(payload, forDocument: givenRef)
        try await batch.commit()

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
            fromUserAvatarURL: avatarURL,
            message: trimmedMessage,
            status: initialStatus
        )
    }

    // MARK: - Update Like Status (both sides)

    /// Updates the like status on the receiver's `likesReceived` and the
    /// sender's `likesGiven` mirror, then mirrors it onto the linked
    /// conversation (if any) so it leaves the Message Requests inbox.
    func setLikeStatus(
        likeId: String,
        toUserId: String,
        status: TrackLike.Status
    ) async throws {

        let statusData: [String: Any] = [
            "status": status.rawValue,
            "respondedAt": FieldValue.serverTimestamp()
        ]

        let receivedRef = db.collection(usersCollection)
            .document(toUserId)
            .collection("likesReceived")
            .document(likeId)

        let receivedDoc = try await receivedRef.getDocument()
        guard let fromUserId = receivedDoc.data()?["fromUserId"] as? String else {
            throw NSError(domain: "LikeApiService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Like not found"])
        }

        let givenRef = db.collection(usersCollection)
            .document(fromUserId)
            .collection("likesGiven")
            .document(likeId)

        try await receivedRef.updateData(statusData)

        // The mirror may be missing for likes written by older clients, so it
        // must not make the whole accept/decline fail.
        try? await givenRef.updateData(statusData)

        let convoStatus: Conversation.Status? = {
            switch status {
            case .accepted: return .accepted
            case .rejected: return .rejected
            case .pending:  return nil
            }
        }()
        if let convoStatus {
            await ChatApiService.shared.mirrorLikeStatus(convoStatus, between: toUserId, and: fromUserId)
        }
    }

    // MARK: - Fetching

    /// Own profile: exact aggregation over `likesReceived`. Other profiles:
    /// the `likesReceivedCount` counter on the user doc, which the
    /// `onLikeCreated` Cloud Function maintains (rules don't allow listing
    /// someone else's likes).
    func fetchLikesReceivedCount(for userId: String) async throws -> Int {
        if userId == Auth.auth().currentUser?.uid {
            let query = db.collection(usersCollection)
                .document(userId)
                .collection("likesReceived")
            let snapshot = try await query.count.getAggregation(source: .server)
            return Int(truncating: snapshot.count)
        }

        let doc = try await db.collection(usersCollection).document(userId).getDocument()
        let raw = doc.data()?["likesReceivedCount"]
        if let value = raw as? Int { return value }
        if let value = raw as? Int64 { return Int(value) }
        if let value = raw as? Double { return Int(value) }
        return 0
    }

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

