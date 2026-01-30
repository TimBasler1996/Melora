import Foundation
import FirebaseAuth
import FirebaseFirestore

final class DiscoverService {
    static let shared = DiscoverService()

    private let db = Firestore.firestore()
    private let broadcastsCollection = "broadcasts"
    private let usersCollection = "users"
    private let likesCollection = "likes"

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
        let location: LocationPoint?
    }

    func listenToBroadcasts(
        onChange: @escaping (Result<[BroadcastRecord], Error>) -> Void
    ) -> ListenerRegistration {
        let query = db.collection(broadcastsCollection)
        return query.addSnapshotListener { snapshot, error in
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

    func fetchDiscoverUser(userId: String) async throws -> DiscoverUser? {
        let snapshot = try await db.collection(usersCollection).document(userId).getDocument()
        guard let data = snapshot.data() else { return nil }

        func stringValue(_ key: String) -> String { (data[key] as? String) ?? "" }
        func optionalString(_ key: String) -> String? { data[key] as? String }

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

    func writeLikeEvent(
        senderId: String,
        receiverId: String,
        track: DiscoverTrack,
        message: String?,
        broadcastId: String?
    ) async throws {
        let trimmedMessage: String? = {
            let trimmed = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(160))
        }()

        let payload: [String: Any] = [
            "senderId": senderId,
            "receiverId": receiverId,
            "trackId": track.id,
            "trackTitle": track.title,
            "message": trimmedMessage as Any,
            "createdAt": Timestamp(date: Date()),
            "broadcastId": broadcastId as Any
        ]

        _ = try await db.collection(likesCollection).addDocument(data: payload)
    }

    static func broadcastRecord(from doc: QueryDocumentSnapshot) -> BroadcastRecord? {
        let data = doc.data()

        guard let userId = data["userId"] as? String else { return nil }
        guard let trackId = data["trackId"] as? String else { return nil }
        guard let trackTitle = data["trackTitle"] as? String else { return nil }
        guard let trackArtist = data["trackArtist"] as? String else { return nil }

        let trackAlbum = data["trackAlbum"] as? String
        let trackArtworkURL = data["trackArtworkURL"] as? String
        let spotifyTrackURL = data["spotifyTrackURL"] as? String

        let broadcastedAt: Date = {
            if let ts = data["broadcastedAt"] as? Timestamp { return ts.dateValue() }
            if let date = data["broadcastedAt"] as? Date { return date }
            return Date()
        }()

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
            trackAlbum: trackAlbum,
            trackArtworkURL: trackArtworkURL,
            spotifyTrackURL: spotifyTrackURL,
            broadcastedAt: broadcastedAt,
            location: location
        )
    }

    func currentUserId() -> String? {
        Auth.auth().currentUser?.uid
    }

    func fetchNearbyBroadcasts(around location: LocationPoint, radiusMeters: Double) async throws -> [DiscoverBroadcast] {
        // Fetch all broadcasts
        let snapshot = try await db.collection(broadcastsCollection).getDocuments()
        
        // Parse to BroadcastRecords
        let records = snapshot.documents.compactMap { doc in
            Self.broadcastRecord(from: doc)
        }
        
        // Filter by distance and convert to DiscoverBroadcast
        var broadcasts: [DiscoverBroadcast] = []
        
        for record in records {
            // Skip broadcasts without location
            guard let broadcastLocation = record.location else { continue }
            
            // Calculate distance
            let distance = location.distance(to: broadcastLocation)
            
            // Skip if outside radius
            guard distance <= radiusMeters else { continue }
            
            // Fetch user data
            guard let user = try await fetchDiscoverUser(userId: record.userId) else { continue }
            
            // Create track
            let track = DiscoverTrack(
                id: record.trackId,
                title: record.trackTitle,
                artist: record.trackArtist,
                album: record.trackAlbum,
                artworkURL: record.trackArtworkURL,
                spotifyTrackURL: record.spotifyTrackURL
            )
            
            // Create broadcast
            let broadcast = DiscoverBroadcast(
                id: record.id,
                user: user,
                track: track,
                broadcastedAt: record.broadcastedAt,
                location: broadcastLocation,
                distanceMeters: Int(distance)
            )
            
            broadcasts.append(broadcast)
        }
        
        // Sort by distance (closest first)
        return broadcasts.sorted { ($0.distanceMeters ?? Int.max) < ($1.distanceMeters ?? Int.max) }
    }
}
