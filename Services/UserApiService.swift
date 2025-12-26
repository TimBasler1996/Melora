import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UserApiService {

    static let shared = UserApiService()

    private let db = Firestore.firestore()
    private var usersRef: CollectionReference { db.collection("users") }

    private init() {}

    // MARK: - Public: Ensure user exists from Spotify

    /// Ensures a user document exists for the current Firebase UID using Spotify data.
    /// - Important: Document ID is Firebase UID (NOT spotifyId).
    func ensureCurrentUserExistsFromSpotify(
        spotifyId: String,
        displayName: String,
        avatarURL: String?,
        countryCode: String?,
        completion: @escaping (Result<AppUser, Error>) -> Void
    ) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserApiService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "No Firebase user signed in."
            ])))
            return
        }

        // If doc exists -> merge/update Spotify fields
        usersRef.document(uid).getDocument { [weak self] snap, error in
            guard let self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            let now = Date()

            if let data = snap?.data(), let existing = Self.mapToUser(uid: uid, data: data) {
                var updated = existing
                updated.displayName = displayName
                updated.avatarURL = avatarURL
                updated.avatarSource = .spotify
                updated.updatedAt = now
                updated.lastActiveAt = now

                if let countryCode, !countryCode.isEmpty {
                    // If you keep countryCode on user, store it here
                    // (AppUser currently doesn't have it — if you want it, add it.)
                    // We'll still persist it in Firestore for later.
                }

                self.usersRef.document(uid).setData(Self.mapToDict(updated, countryCode: countryCode), merge: true) { err in
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        completion(.success(updated))
                    }
                }
            } else {
                // Create new minimal profile (wizard will fill the rest)
                let newUser = AppUser(
                    id: uid,
                    spotifyId: spotifyId,
                    displayName: displayName,
                    age: nil,
                    hometown: nil,
                    musicTaste: nil,
                    photoURLs: [],
                    avatarURL: avatarURL,
                    avatarSource: .spotify,
                    profileCompleted: false,
                    isBroadcasting: false,
                    lastLocation: nil,
                    lastActiveAt: now,
                    createdAt: now,
                    updatedAt: now
                )

                self.usersRef.document(uid).setData(Self.mapToDict(newUser, countryCode: countryCode), merge: true) { err in
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        completion(.success(newUser))
                    }
                }
            }
        }
    }

    // MARK: - Read

    func getUser(uid: String, completion: @escaping (Result<AppUser?, Error>) -> Void) {
        usersRef.document(uid).getDocument { snap, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = snap?.data() else {
                completion(.success(nil))
                return
            }
            completion(.success(Self.mapToUser(uid: uid, data: data)))
        }
    }

    func getCurrentUser(completion: @escaping (Result<AppUser?, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "UserApiService", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "No Firebase user signed in."
            ])))
            return
        }
        getUser(uid: uid, completion: completion)
    }

    // MARK: - Discover (Realtime)

    func listenToBroadcastingUsers(
        limit: Int = 50,
        onChange: @escaping (Result<[AppUser], Error>) -> Void
    ) -> ListenerRegistration {

        let myUID = Auth.auth().currentUser?.uid

        return usersRef
            .whereField("isBroadcasting", isEqualTo: true)
            .limit(to: limit)
            .addSnapshotListener { snap, error in
                if let error = error {
                    onChange(.failure(error))
                    return
                }

                let docs = snap?.documents ?? []
                let users: [AppUser] = docs.compactMap { doc in
                    if let myUID, doc.documentID == myUID { return nil }
                    return Self.mapToUser(uid: doc.documentID, data: doc.data())
                }

                onChange(.success(users))
            }
    }

    // MARK: - Save / Update

    func saveUser(_ user: AppUser, completion: @escaping (Result<AppUser, Error>) -> Void) {
        usersRef.document(user.id).setData(Self.mapToDict(user, countryCode: nil), merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(user))
            }
        }
    }

    func updateUser(_ user: AppUser, completion: @escaping (Result<Void, Error>) -> Void) {
        var updated = user
        updated.updatedAt = Date()
        updated.lastActiveAt = Date()

        usersRef.document(updated.id).setData(Self.mapToDict(updated, countryCode: nil), merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Mapping

    private static func mapToUser(uid: String, data: [String: Any]) -> AppUser? {
        guard
            let spotifyId = data["spotifyId"] as? String,
            let displayName = data["displayName"] as? String
        else { return nil }

        var user = AppUser(
            id: uid,
            spotifyId: spotifyId,
            displayName: displayName,
            age: data["age"] as? Int,
            hometown: data["hometown"] as? String,
            musicTaste: data["musicTaste"] as? String,
            photoURLs: data["photoURLs"] as? [String],
            avatarURL: data["avatarURL"] as? String,
            avatarSource: (data["avatarSource"] as? String).flatMap(AppUser.AvatarSource.init(rawValue:)),
            profileCompleted: data["profileCompleted"] as? Bool,
            isBroadcasting: data["isBroadcasting"] as? Bool,
            lastLocation: (data["lastLocation"] as? [String: Any]).flatMap(LocationPoint.fromDict),
            lastActiveAt: (data["lastActiveAt"] as? Timestamp)?.dateValue(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )

        if user.profileCompleted == nil {
            user.profileCompleted = user.isCompleteDerived
        }

        return user
    }

    private static func mapToDict(_ user: AppUser, countryCode: String?) -> [String: Any] {
        var dict: [String: Any] = [
            "spotifyId": user.spotifyId,
            "displayName": user.displayName,
            "profileCompleted": user.profileCompleted ?? user.isCompleteDerived,
            "isBroadcasting": user.isBroadcasting ?? false,
            "updatedAt": Timestamp(date: user.updatedAt ?? Date()),
            "lastActiveAt": Timestamp(date: user.lastActiveAt ?? Date())
        ]

        // Optional: keep countryCode in Firestore even if AppUser doesn't store it yet
        if let countryCode, !countryCode.isEmpty {
            dict["countryCode"] = countryCode
        }

        dict["age"] = user.age as Any
        dict["hometown"] = user.hometown as Any
        dict["musicTaste"] = user.musicTaste as Any
        dict["photoURLs"] = user.photoURLs ?? []
        dict["avatarURL"] = user.avatarURL as Any
        dict["avatarSource"] = user.avatarSource?.rawValue as Any
        dict["lastLocation"] = user.lastLocation?.toDict() as Any

        if let createdAt = user.createdAt {
            dict["createdAt"] = Timestamp(date: createdAt)
        } else {
            dict["createdAt"] = Timestamp(date: Date())
        }

        return dict
    }
}

