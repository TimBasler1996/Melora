import Foundation
import FirebaseAuth
import FirebaseFirestore

final class DiscoverService {
    static let shared = DiscoverService()

    private let db = Firestore.firestore()
    private let broadcastsCollection = "broadcasts"
    private let usersCollection = "users"

    /// Broadcasts older than this are not loaded at all. Ended broadcasts
    /// inside the window are shown as "recently live".
    static let recentWindow: TimeInterval = 24 * 60 * 60

    struct BroadcastRecord: Identifiable, Equatable {
        let id: String
        let userId: String
        let trackId: String
        let trackTitle: String
        let trackArtist: String
        let trackAlbum: String?
        let trackArtworkURL: String?
        let spotifyTrackURL: String?
        let broadcastedAt: Date
        let updatedAt: Date?
        let endedAt: Date?
        /// Set to `false` when the broadcaster stopped or the sweeper expired it.
        let isLive: Bool
        let location: LocationPoint?
    }

    /// Live + recently ended broadcasts of the last 24 hours.
    func listenToBroadcasts(
        onChange: @escaping (Result<[BroadcastRecord], Error>) -> Void
    ) -> ListenerRegistration {
        return recentQuery().addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }

            let records = (snapshot?.documents ?? []).compactMap { doc in
                Self.broadcastRecord(from: doc)
            }

            onChange(.success(records))
        }
    }

    /// Listens for broadcasts that *go live*: newly added live docs and docs
    /// that flip back to live (a user starting again reuses their document).
    func listenToNewBroadcasts(
        onNew: @escaping (Result<[BroadcastRecord], Error>) -> Void
    ) -> ListenerRegistration {
        var isFirstSnapshot = true
        // Last known live state per document, so heartbeats (which arrive as
        // `.modified` every 15–20 s) are not mistaken for someone going live.
        var lastLive: [String: Bool] = [:]

        return recentQuery().addSnapshotListener { snapshot, error in
            if let error {
                onNew(.failure(error))
                return
            }
            guard let snapshot else { return }

            if isFirstSnapshot {
                isFirstSnapshot = false
                for doc in snapshot.documents {
                    if let record = Self.broadcastRecord(from: doc) {
                        lastLive[record.id] = record.isLive
                    }
                }
                return
            }

            let newRecords: [BroadcastRecord] = snapshot.documentChanges.compactMap { change in
                guard let record = Self.broadcastRecord(from: change.document) else { return nil }
                if change.type == .removed {
                    lastLive[record.id] = nil
                    return nil
                }
                let wasLive = lastLive[record.id] ?? false
                lastLive[record.id] = record.isLive
                return (record.isLive && !wasLive) ? record : nil
            }

            if !newRecords.isEmpty {
                onNew(.success(newRecords))
            }
        }
    }

    /// One-shot fetch (pull-to-refresh).
    func fetchBroadcastsOnce() async throws -> [BroadcastRecord] {
        let snapshot = try await recentQuery().getDocuments()
        return snapshot.documents.compactMap { Self.broadcastRecord(from: $0) }
    }

    private func recentQuery() -> Query {
        let cutoff = Date().addingTimeInterval(-Self.recentWindow)
        return db.collection(broadcastsCollection)
            .whereField("updatedAt", isGreaterThan: Timestamp(date: cutoff))
    }

    func fetchDiscoverUser(userId: String) async throws -> DiscoverUser? {
        let snapshot = try await db.collection(usersCollection).document(userId).getDocument()
        guard let data = snapshot.data() else { return nil }

        func stringValue(_ key: String) -> String { (data[key] as? String) ?? "" }
        func optionalString(_ key: String) -> String? { data[key] as? String }

        // Ghost profiles (onboarding never finished, or a deletion in
        // progress) have nothing to show; treat them as absent.
        guard (data["profileCompleted"] as? Bool) == true,
              !stringValue("firstName").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              data["deletionRequestedAt"] == nil
        else { return nil }

        let birthday: Date? = {
            if let ts = data["birthday"] as? Timestamp { return ts.dateValue() }
            return data["birthday"] as? Date
        }()

        let age: Int? = {
            if let ageValue = data["age"] as? Int { return ageValue }
            if let ageValue = data["age"] as? Double { return Int(ageValue) }
            if let birthday { return birthday.age() }
            return nil
        }()

        let heroPhotoURL = optionalString("heroPhotoURL")
        let photoURLs = (data["photoURLs"] as? [String]) ?? []
        let profilePhotoURL = optionalString("profilePhotoURL")
            ?? photoURLs.first
            ?? optionalString("spotifyAvatarURL")
            ?? optionalString("avatarURL")

        return DiscoverUser(
            id: userId,
            firstName: stringValue("firstName"),
            lastName: stringValue("lastName"),
            age: age,
            city: stringValue("city"),
            gender: optionalString("gender"),
            countryCode: optionalString("countryCode"),
            heroPhotoURL: heroPhotoURL,
            profilePhotoURL: profilePhotoURL,
            photoURLs: photoURLs
        )
    }

    static func broadcastRecord(from doc: QueryDocumentSnapshot) -> BroadcastRecord? {
        let data = doc.data()

        guard let userId = data["userId"] as? String else { return nil }
        guard let trackId = data["trackId"] as? String else { return nil }
        guard let trackTitle = data["trackTitle"] as? String else { return nil }
        guard let trackArtist = data["trackArtist"] as? String else { return nil }

        func date(_ key: String) -> Date? {
            if let ts = data[key] as? Timestamp { return ts.dateValue() }
            if let d = data[key] as? Date { return d }
            return nil
        }

        let location: LocationPoint? = {
            if let geopoint = data["location"] as? GeoPoint {
                return LocationPoint(latitude: geopoint.latitude, longitude: geopoint.longitude)
            }
            if let lat = data["latitude"] as? Double,
               let lng = data["longitude"] as? Double {
                return LocationPoint(latitude: lat, longitude: lng)
            }
            return nil
        }()

        return BroadcastRecord(
            id: doc.documentID,
            userId: userId,
            trackId: trackId,
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            trackAlbum: data["trackAlbum"] as? String,
            trackArtworkURL: data["trackArtworkURL"] as? String,
            spotifyTrackURL: data["spotifyTrackURL"] as? String,
            broadcastedAt: date("broadcastedAt") ?? Date(),
            updatedAt: date("updatedAt"),
            endedAt: date("endedAt"),
            isLive: (data["isLive"] as? Bool) ?? true,
            location: location
        )
    }

    func currentUserId() -> String? {
        Auth.auth().currentUser?.uid
    }
}
