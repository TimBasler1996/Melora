import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class BroadcastManager: ObservableObject {

    // MARK: - Public State

    @Published private(set) var currentUser: User = User(
        id: "unknown",
        displayName: "Unknown",
        avatarURL: nil,
        age: nil,
        countryCode: nil
    )

    /// UI bindet daran (Toggle)
    @Published var isBroadcasting: Bool = false

    /// UI kann das anzeigen
    @Published var currentTrack: Track? = nil

    @Published var errorMessage: String? = nil

    // MARK: - Dependencies

    private let userService: UserApiService
    private let db = Firestore.firestore()
    private let broadcastsCollection = "broadcasts"
    private var locationService: LocationService?

    // MARK: - Session tracking (for broadcast hours)

    private let sessionService = SessionApiService.shared
    private var activeSessionId: String?

    // MARK: - Timers (throttle sync)

    private var locationSyncTask: Task<Void, Never>?
    private var trackSyncTask: Task<Void, Never>?

    // MARK: - Init

    init(userService: UserApiService = .shared) {
        self.userService = userService
    }

    deinit {
        locationSyncTask?.cancel()
        trackSyncTask?.cancel()
    }

    // MARK: - Wiring

    /// Call once after you have a LocationService available (e.g. in App / MainView onAppear)
    func attachLocationService(_ service: LocationService) {
        self.locationService = service
    }

    /// Call whenever Profile/User loaded so BroadcastManager knows the correct user displayName/avatar etc.
    func updateCurrentUser(_ user: User) {
        self.currentUser = user
    }

    func updateCurrentTrack(_ track: Track?) {
        self.currentTrack = track

        // If broadcasting, sync track (throttled)
        guard isBroadcasting else { return }
        scheduleTrackSync()
    }

    // MARK: - Toggle helpers

    func setBroadcasting(_ newValue: Bool) async {
        if newValue {
            await startBroadcasting()
        } else {
            await stopBroadcasting()
        }
    }

    // MARK: - Broadcasting

    func startBroadcasting() async {
        errorMessage = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            isBroadcasting = false
            return
        }

        isBroadcasting = true

        // 1) Set broadcasting=true in Firestore
        await withCheckedContinuation { cont in
            userService.setBroadcasting(uid: uid, isBroadcasting: true) { err in
                if let err { self.errorMessage = "Broadcast start failed: \(err.localizedDescription)" }
                cont.resume()
            }
        }

        // 2) Push initial location (if available) + start periodic sync
        scheduleLocationSync(immediate: true)

        // 3) Push initial track (if available) + start periodic sync
        scheduleTrackSync(immediate: true)

        // 4) Create or update broadcast doc for Discover
        await upsertBroadcast(uid: uid, track: currentTrack, location: locationService?.currentLocation, isNew: true)

        // 5) Create a session record for broadcast-hours tracking
        if let track = currentTrack {
            let loc = locationService?.currentLocation ?? LocationPoint(latitude: 0, longitude: 0)
            do {
                let session = try await sessionService.createSession(user: currentUser, track: track, location: loc)
                activeSessionId = session.id
            } catch {
                print("[BroadcastManager] session create failed: \(error.localizedDescription)")
            }
        }
    }

    func stopBroadcasting() async {
        errorMessage = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            isBroadcasting = false
            return
        }

        // stop periodic sync first
        locationSyncTask?.cancel()
        locationSyncTask = nil

        trackSyncTask?.cancel()
        trackSyncTask = nil

        isBroadcasting = false

        // set broadcasting=false and clear currentTrack if you want
        await withCheckedContinuation { cont in
            userService.setBroadcasting(uid: uid, isBroadcasting: false) { err in
                if let err { self.errorMessage = "Broadcast stop failed: \(err.localizedDescription)" }
                cont.resume()
            }
        }

        // Optional: remove currentTrack server-side when stopping
        await withCheckedContinuation { cont in
            userService.updateCurrentTrack(uid: uid, track: nil) { _ in
                cont.resume()
            }
        }

        // Remove Discover broadcast doc
        await removeBroadcast(uid: uid)

        // End session record so broadcast hours are accurate
        if let sessionId = activeSessionId {
            do {
                try await sessionService.endSession(id: sessionId)
            } catch {
                print("[BroadcastManager] session end failed: \(error.localizedDescription)")
            }
            activeSessionId = nil
        }
    }

    // MARK: - Sync scheduling

    private func scheduleLocationSync(immediate: Bool = false) {
        locationSyncTask?.cancel()

        locationSyncTask = Task { [weak self] in
            guard let self else { return }
            guard let uid = Auth.auth().currentUser?.uid else { return }

            if immediate {
                await self.syncLocation(uid: uid)
            }

            // periodic
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20 * 1_000_000_000) // 20s
                await self.syncLocation(uid: uid)
            }
        }
    }

    private func scheduleTrackSync(immediate: Bool = false) {
        // cancel only if not running; otherwise keep running and just do immediate push below
        if trackSyncTask == nil {
            trackSyncTask = Task { [weak self] in
                guard let self else { return }
                guard let uid = Auth.auth().currentUser?.uid else { return }

                if immediate {
                    await self.syncTrack(uid: uid)
                }

                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15 * 1_000_000_000) // 15s
                    await self.syncTrack(uid: uid)
                }
            }
        } else if immediate {
            Task { [weak self] in
                guard let self else { return }
                guard let uid = Auth.auth().currentUser?.uid else { return }
                await self.syncTrack(uid: uid)
            }
        }
    }

    // MARK: - Actual sync

    private func syncLocation(uid: String) async {
        guard isBroadcasting else { return }
        guard let locationService else { return }

        // expects your LocationService to expose currentLocation
        guard let loc = locationService.currentLocation else { return }

        await withCheckedContinuation { cont in
            userService.updateLastLocation(uid: uid, location: loc) { err in
                if let err {
                    self.errorMessage = "Location update failed: \(err.localizedDescription)"
                }
                cont.resume()
            }
        }

        await upsertBroadcast(uid: uid, track: currentTrack, location: loc, isNew: false)
        await touchSession()
    }

    private func syncTrack(uid: String) async {
        guard isBroadcasting else { return }

        await withCheckedContinuation { cont in
            userService.updateCurrentTrack(uid: uid, track: currentTrack) { err in
                if let err {
                    self.errorMessage = "Track update failed: \(err.localizedDescription)"
                }
                cont.resume()
            }
        }

        await upsertBroadcast(uid: uid, track: currentTrack, location: locationService?.currentLocation, isNew: false)
        await touchSession()
    }

    /// Updates the session's updatedAt timestamp so broadcast hours are tracked accurately.
    private func touchSession() async {
        guard let sessionId = activeSessionId else { return }
        do {
            let db = Firestore.firestore()
            try await db.collection("sessions").document(sessionId).updateData([
                "updatedAt": Timestamp(date: Date())
            ])
        } catch {
            print("[BroadcastManager] session heartbeat failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Discover broadcast documents

    private func upsertBroadcast(
        uid: String,
        track: Track?,
        location: LocationPoint?,
        isNew: Bool
    ) async {
        guard let track else { return }

        let now = Timestamp(date: Date())

        var payload: [String: Any] = [
            "userId": uid,
            "trackId": track.id,
            "trackTitle": track.title,
            "trackArtist": track.artist,
            "trackAlbum": track.album as Any,
            "trackArtworkURL": track.artworkURL?.absoluteString as Any,
            "spotifyTrackURL": spotifyTrackURL(for: track.id) as Any,
            "updatedAt": now
        ]

        if let location {
            payload["latitude"] = location.latitude
            payload["longitude"] = location.longitude
        }

        if isNew {
            payload["broadcastedAt"] = now
        }

        do {
            try await db.collection(broadcastsCollection)
                .document(uid)
                .setData(payload, merge: true)
        } catch {
            self.errorMessage = "Broadcast update failed: \(error.localizedDescription)"
        }
    }

    private func removeBroadcast(uid: String) async {
        do {
            try await db.collection(broadcastsCollection).document(uid).delete()
        } catch {
            self.errorMessage = "Broadcast cleanup failed: \(error.localizedDescription)"
        }
    }

    private func spotifyTrackURL(for trackId: String) -> String {
        "https://open.spotify.com/track/\(trackId)"
    }
}
