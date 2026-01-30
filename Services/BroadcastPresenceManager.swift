import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class BroadcastPresenceManager: ObservableObject {

    @Published private(set) var isBroadcasting: Bool = false
    @Published var lastError: String?

    private let db = Firestore.firestore()

    func startBroadcast(currentLocation: LocationPoint?, currentTrack: Track?) {
        lastError = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            lastError = "No Firebase user."
            return
        }

        var data: [String: Any] = [
            "isBroadcasting": true,
            "lastActiveAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        if let loc = currentLocation {
            data["lastLocation"] = loc.toDict()
        }

        if let track = currentTrack {
            data["currentTrack"] = Self.trackDict(from: track)
        }

        db.collection("users").document(uid).setData(data, merge: true) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.lastError = "Failed to start broadcast: \(error.localizedDescription)"
                self.isBroadcasting = false
            } else {
                self.isBroadcasting = true
                self.lastError = nil
            }
        }
    }

    /// Call this when the Spotify track changes while broadcasting.
    func updateCurrentTrack(_ track: Track?) {
        lastError = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            lastError = "No Firebase user."
            return
        }

        var data: [String: Any] = [
            "lastActiveAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        if let track = track {
            data["currentTrack"] = Self.trackDict(from: track)
        } else {
            data["currentTrack"] = FieldValue.delete()
        }

        db.collection("users").document(uid).setData(data, merge: true) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.lastError = "Failed to update track: \(error.localizedDescription)"
            } else {
                self.lastError = nil
            }
        }
    }

    func stopBroadcast() {
        lastError = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            lastError = "No Firebase user."
            return
        }

        let data: [String: Any] = [
            "isBroadcasting": false,
            "currentTrack": FieldValue.delete(),
            "lastActiveAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        db.collection("users").document(uid).setData(data, merge: true) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.lastError = "Failed to stop broadcast: \(error.localizedDescription)"
            } else {
                self.isBroadcasting = false
                self.lastError = nil
            }
        }
    }

    private static func trackDict(from track: Track) -> [String: Any] {
        var dict: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "artist": track.artist,
            "updatedAt": Timestamp(date: Date())
        ]

        if let album = track.album { dict["album"] = album }
        if let art = track.artworkURL?.absoluteString { dict["artworkURL"] = art }

        return dict
    }
}

