//
//  UserApiService.swift
//  SocialSound
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UserApiService {

    static let shared = UserApiService()
    private init() {}

    private let db = Firestore.firestore()
    private var broadcastingListener: ListenerRegistration?

    // MARK: - Create / Ensure User

    /// Ensures a Firestore user doc exists for the current Firebase user (uid).
    /// If missing -> creates it using Spotify fields.
    func ensureCurrentUserExistsFromSpotify(
        spotifyId: String,
        displayName: String,
        countryCode: String?,
        avatarURL: String?,
        completion: @escaping (Result<AppUser, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No Firebase user."])))
            return
        }

        let ref = db.collection("users").document(uid)

        ref.getDocument { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            if let snap = snapshot, snap.exists, let data = snap.data() {
                completion(.success(AppUser.fromFirestore(uid: uid, data: data)))
                return
            }

            // Create fresh doc
            var payload: [String: Any] = [
                "spotifyId": spotifyId,
                "displayName": displayName,
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date()),
                "lastActiveAt": Timestamp(date: Date()),
                "isBroadcasting": false,
                "profileCompleted": false,
                "avatarSource": "spotify"
            ]

            if let countryCode { payload["countryCode"] = countryCode }
            if let avatarURL { payload["avatarURL"] = avatarURL }

            ref.setData(payload, merge: true) { err in
                if let err {
                    completion(.failure(err))
                    return
                }
                completion(.success(AppUser.fromFirestore(uid: uid, data: payload)))
            }
        }
    }

    // MARK: - Fetch

    func fetchUser(uid: String, completion: @escaping (Result<AppUser, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { snap, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data = snap?.data() else {
                completion(.failure(NSError(domain: "User", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found."])))
                return
            }
            completion(.success(AppUser.fromFirestore(uid: uid, data: data)))
        }
    }

    /// Convenience wrapper used by view models (aliases `fetchUser`).
    func getUser(uid: String, completion: @escaping (Result<AppUser, Error>) -> Void) {
        fetchUser(uid: uid, completion: completion)
    }

    // MARK: - Discover (Broadcasting users)

    /// Live list of broadcasting users (excluding my own uid).
    func listenToBroadcastingUsers(
        excludeUID: String?,
        onChange: @escaping (Result<[AppUser], Error>) -> Void
    ) -> ListenerRegistration {
        var q: Query = db.collection("users")
            .whereField("isBroadcasting", isEqualTo: true)

        if let excludeUID {
            // Firestore can't "where != uid" reliably for doc id here, so we filter client-side
            // (fine for MVP).
            // no-op on query
        }

        return q.addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }

            let docs = snapshot?.documents ?? []
            let users: [AppUser] = docs.map { doc in
                AppUser.fromFirestore(uid: doc.documentID, data: doc.data())
            }.filter { u in
                if let excludeUID { return u.uid != excludeUID }
                return true
            }

            onChange(.success(users))
        }
    }

    /// Observe broadcasting users and retain the listener for later teardown.
    func observeBroadcastingUsers(_ onChange: @escaping (Result<[AppUser], Error>) -> Void) {
        stopListening()
        let myUID = Auth.auth().currentUser?.uid
        broadcastingListener = listenToBroadcastingUsers(excludeUID: myUID, onChange: onChange)
    }

    // MARK: - Presence / Broadcasting state

    func setBroadcasting(uid: String, isBroadcasting: Bool, completion: ((Error?) -> Void)? = nil) {
        db.collection("users").document(uid).setData([
            "isBroadcasting": isBroadcasting,
            "lastActiveAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], merge: true, completion: completion)
    }

    func stopListening() {
        broadcastingListener?.remove()
        broadcastingListener = nil
    }

    func updateLastLocation(uid: String, location: LocationPoint, completion: ((Error?) -> Void)? = nil) {
        db.collection("users").document(uid).setData([
            "lastLocation": [
                "latitude": location.latitude,
                "longitude": location.longitude
            ],
            "lastActiveAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], merge: true, completion: completion)
    }

    func updateCurrentTrack(uid: String, track: Track?, completion: ((Error?) -> Void)? = nil) {
        var payload: [String: Any] = [
            "lastActiveAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        if let track {
            payload["currentTrack"] = [
                "id": track.id,
                "title": track.title,
                "artist": track.artist,
                "album": track.album as Any,
                "artworkURL": track.artworkURL?.absoluteString as Any,
                "durationMs": track.durationMs as Any
            ]
        } else {
            // remove currentTrack
            payload["currentTrack"] = FieldValue.delete()
        }

        db.collection("users").document(uid).setData(payload, merge: true, completion: completion)
    }
    
    // MARK: - Broadcast Stats

    func addBroadcastMinutes(uid: String, minutes: Int, completion: ((Error?) -> Void)? = nil) {
        guard minutes > 0 else {
            completion?(nil)
            return
        }
        db.collection("users").document(uid).setData([
            "broadcastMinutesTotal": FieldValue.increment(Int64(minutes)),
            "updatedAt": Timestamp(date: Date())
        ], merge: true, completion: completion)
    }

    // MARK: - Profile Updates
    
    /// Updates the user's display name in Firestore
    func updateDisplayName(uid: String, displayName: String, completion: ((Error?) -> Void)? = nil) {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion?(NSError(domain: "UserApiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Display name cannot be empty"]))
            return
        }
        
        db.collection("users").document(uid).setData([
            "displayName": displayName,
            "updatedAt": Timestamp(date: Date())
        ], merge: true, completion: completion)
    }
    
    /// Updates multiple profile fields at once
    func updateProfile(uid: String, updates: [String: Any], completion: ((Error?) -> Void)? = nil) {
        var payload = updates
        payload["updatedAt"] = Timestamp(date: Date())
        
        db.collection("users").document(uid).setData(payload, merge: true, completion: completion)
    }
}

