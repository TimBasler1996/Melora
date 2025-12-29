import Foundation
import FirebaseFirestore

// Firestore dictionaries use `[String: Any]`, which is not `Sendable` by default.
// The service runs inside an actor, but the dictionaries need to cross async
// boundaries when talking to Firebase. Marking these specializations as
// `@unchecked Sendable` quiets Swift 6's stricter checks while keeping the
// actor for serialization.
extension Dictionary: @unchecked Sendable where Key == String, Value == Any {}
extension Dictionary: @unchecked Sendable where Key == AnyHashable, Value == Any {}

/// Cloud-based session backend using Firebase Firestore.
/// Stores and loads sessions in the "sessions" collection.
actor SessionApiService {
    
    static let shared = SessionApiService()
    
    private let db = Firestore.firestore()
    private let collectionName = "sessions"
    
    /// Wie lange eine Session ohne Heartbeat "leben" darf,
    /// bevor wir sie als abgelaufen behandeln (z. B. App gekillt).
    private let sessionExpiry: TimeInterval = 60 * 10  // 10 Minuten
    
    // MARK: - Public API
    
    /// Creates a new active session for the given user, track and location.
    func createSession(user: User, track: Track, location: LocationPoint) async throws -> Session {
        let now = Date()
        let session = Session(
            id: UUID().uuidString,
            user: user,
            track: track,
            location: location,
            createdAt: now,
            updatedAt: now,
            isActive: true,
            likeCount: 0
        )
        
        let docRef = db.collection(collectionName).document(session.id)
        try await docRef.setData(encodeSession(session))
        
        return session
    }
    
    /// Updates an existing session or inserts it if it does not exist.
    /// updatedAt wird dabei automatisch auf "jetzt" gesetzt.
    func updateSession(_ session: Session) async throws -> Session {
        let docRef = db.collection(collectionName).document(session.id)
        var updated = session
        updated.updatedAt = Date()
        try await docRef.setData(encodeSession(updated), merge: true)
        return updated
    }
    
    /// Marks the session with the given id as inactive.
    func endSession(id: String) async throws {
        let docRef = db.collection(collectionName).document(id)
        try await docRef.updateData([
            "isActive": false,
            "updatedAt": Date()
        ])
    }
    
    /// Returns all active sessions.
    /// Für den MVP: alle "aktiven" Sessions, deren updatedAt noch frisch genug ist.
    func fetchNearbySessions(around location: LocationPoint, radiusMeters: Double = 500) async throws -> [Session] {
        let snapshot = try await db.collection(collectionName)
            .whereField("isActive", isEqualTo: true)
            .getDocuments()
        
        var result: [Session] = []
        for document in snapshot.documents {
            let data = document.data()
            if let session = decodeSession(from: data, id: document.documentID) {
                result.append(session)
            }
        }
        
        // Client-seitiger Filter: nur Sessions, deren Heartbeat (updatedAt)
        // nicht zu alt ist → verhindert Leichen, wenn App gekillt wurde.
        let now = Date()
        let filtered = result.filter { session in
            let age = now.timeIntervalSince(session.updatedAt)
            return age <= sessionExpiry
        }
        
        return filtered
    }
    
    // MARK: - Encoding / Decoding
    
    /// Encodes a `Session` into a Firestore document dictionary.
    private func encodeSession(_ session: Session) -> [String: Any] {
        var userDict: [String: Any] = [
            "id": session.user.id,
            "displayName": session.user.displayName
        ]
        if let avatarURL = session.user.avatarURL?.absoluteString {
            userDict["avatarURL"] = avatarURL
        }
        if let age = session.user.age {
            userDict["age"] = age
        }
        if let countryCode = session.user.countryCode {
            userDict["countryCode"] = countryCode
        }
        
        var trackDict: [String: Any] = [
            "id": session.track.id,
            "title": session.track.title,
            "artist": session.track.artist
        ]
        if let album = session.track.album {
            trackDict["album"] = album
        }
        if let artworkURL = session.track.artworkURL?.absoluteString {
            trackDict["artworkURL"] = artworkURL
        }
        
        let locationDict: [String: Any] = [
            "latitude": session.location.latitude,
            "longitude": session.location.longitude
        ]
        
        return [
            "user": userDict,
            "track": trackDict,
            "location": locationDict,
            "createdAt": session.createdAt,
            "updatedAt": session.updatedAt,
            "isActive": session.isActive,
            "likeCount": session.likeCount
        ]
    }
    
    /// Decodes a Firestore document dictionary into a `Session` model.
    private func decodeSession(from data: [String: Any], id: String) -> Session? {
        guard
            let userData = data["user"] as? [String: Any],
            let trackData = data["track"] as? [String: Any],
            let locationData = data["location"] as? [String: Any]
        else {
            return nil
        }
        
        let isActive = data["isActive"] as? Bool ?? false
        let likeCount = data["likeCount"] as? Int ?? 0
        
        // createdAt
        let createdDate: Date
        if let ts = data["createdAt"] as? Timestamp {
            createdDate = ts.dateValue()
        } else if let d = data["createdAt"] as? Date {
            createdDate = d
        } else {
            createdDate = Date()
        }
        
        // updatedAt (fallback: createdAt)
        let updatedDate: Date
        if let ts = data["updatedAt"] as? Timestamp {
            updatedDate = ts.dateValue()
        } else if let d = data["updatedAt"] as? Date {
            updatedDate = d
        } else {
            updatedDate = createdDate
        }
        
        // USER
        let user = User(
            id: userData["id"] as? String ?? "",
            displayName: userData["displayName"] as? String ?? "Unknown",
            avatarURL: (userData["avatarURL"] as? String).flatMap { URL(string: $0) },
            age: userData["age"] as? Int,
            countryCode: userData["countryCode"] as? String
        )
        
        // TRACK
        let track = Track(
            id: trackData["id"] as? String ?? "",
            title: trackData["title"] as? String ?? "Unknown Track",
            artist: trackData["artist"] as? String ?? "Unknown Artist",
            album: trackData["album"] as? String,
            artworkURL: (trackData["artworkURL"] as? String).flatMap { URL(string: $0) }
        )
        
        // LOCATION
        let location = LocationPoint(
            latitude: locationData["latitude"] as? Double ?? 0.0,
            longitude: locationData["longitude"] as? Double ?? 0.0
        )
        
        return Session(
            id: id,
            user: user,
            track: track,
            location: location,
            createdAt: createdDate,
            updatedAt: updatedDate,
            isActive: isActive,
            likeCount: likeCount
        )
    }
    
    // MARK: - Track History
    
    /// Firestore-Dokumentstruktur für einen gespielten Track.
    private struct PlayedTrackDTO {
        let trackId: String
        let title: String
        let artist: String
        let album: String?
        let artworkURL: String?
        let startedAt: Date
        let endedAt: Date?
        let durationMs: Int?
        let location: GeoPoint
        
        var asDictionary: [String: Any] {
            var dict: [String: Any] = [
                "trackId": trackId,
                "title": title,
                "artist": artist,
                "startedAt": startedAt,
                "location": location
            ]
            if let album = album {
                dict["album"] = album
            }
            if let artworkURL = artworkURL {
                dict["artworkURL"] = artworkURL
            }
            if let endedAt = endedAt {
                dict["endedAt"] = endedAt
            }
            if let durationMs = durationMs {
                dict["durationMs"] = durationMs
            }
            return dict
        }
    }
    
    /// Hängt einen Eintrag an die Track-History einer Session an.
    func appendPlayedTrack(for sessionId: String, track: Track, location: LocationPoint) async throws {
        let dto = PlayedTrackDTO(
            trackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkURL: track.artworkURL?.absoluteString,
            startedAt: Date(),
            endedAt: nil,
            durationMs: track.durationMs,
            location: GeoPoint(latitude: location.latitude, longitude: location.longitude)
        )
        
        let collectionRef = db.collection(collectionName)
            .document(sessionId)
            .collection("playedTracks")
        
        let docRef = collectionRef.document()
        try await docRef.setData(dto.asDictionary)
    }
    
    /// Setzt beim letzten gespielten Track `endedAt`, falls noch nicht gesetzt.
    func closeLastPlayedTrackIfNeeded(for sessionId: String) async throws {
        let collectionRef = db.collection(collectionName)
            .document(sessionId)
            .collection("playedTracks")
        
        let snapshot = try await collectionRef
            .order(by: "startedAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return }
        
        let data = doc.data()
        if data["endedAt"] == nil {
            try await doc.reference.updateData([
                "endedAt": Date()
            ])
        }
    }
}
