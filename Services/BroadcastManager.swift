import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Owns the "I am broadcasting" state: mirrors the user's current Spotify
/// track and location to Firestore while the toggle is on.
///
/// The manager polls Spotify itself while broadcasting, so the broadcast stays
/// accurate no matter which tab is open. `NowPlayingView` additionally pushes
/// track changes it observes for snappier updates while it is on screen.
@MainActor
final class BroadcastManager: ObservableObject {

    // MARK: - Public State

    /// UI binds to this (toggle).
    @Published var isBroadcasting: Bool = false

    /// Track currently being broadcast (last known now-playing track).
    @Published var currentTrack: Track? = nil

    @Published var errorMessage: String? = nil

    // MARK: - Dependencies

    private let userService: UserApiService
    private let db = Firestore.firestore()
    private let broadcastsCollection = "broadcasts"
    private var locationService: LocationService?

    // MARK: - Time tracking

    private var broadcastStartedAt: Date?
    private let broadcastStartKey = "BroadcastManager_startedAt"

    // MARK: - Sync loops

    private var locationSyncTask: Task<Void, Never>?
    private var trackSyncTask: Task<Void, Never>?

    private static let locationSyncInterval: UInt64 = 20 * 1_000_000_000 // 20s
    private static let trackSyncInterval: UInt64 = 15 * 1_000_000_000    // 15s

    /// Consecutive track polls that found nothing playing. When this reaches
    /// `maxIdlePolls` the broadcast is stopped automatically instead of
    /// advertising a song that ended long ago.
    private var idlePolls = 0
    private static let maxIdlePolls = 40 // ≈ 10 minutes at 15s

    // MARK: - Init

    init(userService: UserApiService = .shared) {
        self.userService = userService
        // A stored start date means the app was terminated mid-broadcast.
        // `reconcileAfterLaunch()` cleans that up once auth is available.
        if let saved = UserDefaults.standard.object(forKey: broadcastStartKey) as? Date {
            self.broadcastStartedAt = saved
        }
    }

    deinit {
        locationSyncTask?.cancel()
        trackSyncTask?.cancel()
    }

    // MARK: - Wiring

    /// Call once a LocationService is available (App root).
    func attachLocationService(_ service: LocationService) {
        self.locationService = service
    }

    /// Fed by NowPlayingView while it is on screen; the internal poll covers
    /// the rest of the time.
    func updateCurrentTrack(_ track: Track?) {
        guard let track else { return }
        let changed = track != currentTrack
        currentTrack = track
        idlePolls = 0

        guard isBroadcasting, changed else { return }
        pushTrackNow()
    }

    /// If the app was killed while broadcasting, the server still thinks we
    /// are live. Clear that state; the user can toggle again if they want.
    func reconcileAfterLaunch() {
        guard !isBroadcasting, let startedAt = broadcastStartedAt else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Clear synchronously so a second call (onAppear + onChange) is a no-op.
        broadcastStartedAt = nil
        UserDefaults.standard.removeObject(forKey: broadcastStartKey)

        Task {
            let minutes = Int(Date().timeIntervalSince(startedAt) / 60)
            if minutes > 0 {
                userService.addBroadcastMinutes(uid: uid, minutes: min(minutes, 12 * 60))
            }
            await clearServerState(uid: uid)
        }
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
        idlePolls = 0
        broadcastStartedAt = Date()
        UserDefaults.standard.set(broadcastStartedAt, forKey: broadcastStartKey)

        // 1) Flag the user as broadcasting.
        let startError = await setBroadcastingFlag(uid: uid, isBroadcasting: true)
        if let startError {
            errorMessage = "Broadcast start failed: \(startError.localizedDescription)"
            isBroadcasting = false
            broadcastStartedAt = nil
            UserDefaults.standard.removeObject(forKey: broadcastStartKey)
            return
        }

        // 2) Discover document (needs a track; created as soon as one is known).
        await upsertBroadcast(uid: uid, track: currentTrack, location: locationService?.currentLocation, isNew: true)

        // 3) Periodic sync loops.
        startLocationSync(uid: uid)
        startTrackSync(uid: uid)
    }

    func stopBroadcasting() async {
        errorMessage = nil

        locationSyncTask?.cancel()
        locationSyncTask = nil
        trackSyncTask?.cancel()
        trackSyncTask = nil

        isBroadcasting = false

        let startedAt = broadcastStartedAt
        broadcastStartedAt = nil
        UserDefaults.standard.removeObject(forKey: broadcastStartKey)

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            return
        }

        if let startedAt {
            let minutes = Int(Date().timeIntervalSince(startedAt) / 60)
            if minutes > 0 {
                userService.addBroadcastMinutes(uid: uid, minutes: minutes)
            }
        }

        await clearServerState(uid: uid)
    }

    // MARK: - Sync loops

    private func startLocationSync(uid: String) {
        locationSyncTask?.cancel()
        locationSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.syncLocation(uid: uid)
                try? await Task.sleep(nanoseconds: Self.locationSyncInterval)
            }
        }
    }

    private func startTrackSync(uid: String) {
        trackSyncTask?.cancel()
        trackSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollSpotifyAndSync(uid: uid)
                try? await Task.sleep(nanoseconds: Self.trackSyncInterval)
            }
        }
    }

    /// One-off push after an externally observed track change.
    private func pushTrackNow() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task { [weak self] in
            await self?.syncTrack(uid: uid)
        }
    }

    // MARK: - Actual sync

    private func syncLocation(uid: String) async {
        guard isBroadcasting else { return }
        guard let loc = locationService?.currentLocation else { return }

        await withCheckedContinuation { cont in
            userService.updateLastLocation(uid: uid, location: loc) { err in
                if let err {
                    self.errorMessage = "Location update failed: \(err.localizedDescription)"
                }
                cont.resume()
            }
        }

        await upsertBroadcast(uid: uid, track: currentTrack, location: loc, isNew: false)
    }

    /// Asks Spotify what is playing right now, then syncs it. Transient
    /// errors keep the last known track; a long stretch of "nothing playing"
    /// ends the broadcast.
    private func pollSpotifyAndSync(uid: String) async {
        guard isBroadcasting else { return }

        if let state = try? await SpotifyService.shared.fetchNowPlayingState() {
            if let track = state.track {
                currentTrack = track
                idlePolls = 0
            } else {
                idlePolls += 1
                if idlePolls >= Self.maxIdlePolls {
                    await stopBroadcasting()
                    errorMessage = "Broadcast ended: nothing has been playing for a while."
                    return
                }
            }
        }

        await syncTrack(uid: uid)
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
    }

    // MARK: - Firestore

    private func setBroadcastingFlag(uid: String, isBroadcasting: Bool) async -> Error? {
        await withCheckedContinuation { cont in
            userService.setBroadcasting(uid: uid, isBroadcasting: isBroadcasting) { err in
                cont.resume(returning: err)
            }
        }
    }

    /// Clears everything that marks this user as live: the user flag, the
    /// mirrored track and the Discover document.
    private func clearServerState(uid: String) async {
        if let err = await setBroadcastingFlag(uid: uid, isBroadcasting: false) {
            errorMessage = "Broadcast stop failed: \(err.localizedDescription)"
        }

        await withCheckedContinuation { cont in
            userService.updateCurrentTrack(uid: uid, track: nil) { _ in
                cont.resume()
            }
        }

        do {
            try await db.collection(broadcastsCollection).document(uid).delete()
        } catch {
            errorMessage = "Broadcast cleanup failed: \(error.localizedDescription)"
        }
    }

    private func upsertBroadcast(
        uid: String,
        track: Track?,
        location: LocationPoint?,
        isNew: Bool
    ) async {
        guard let track else { return }

        var payload: [String: Any] = [
            "userId": uid,
            "trackId": track.id,
            "trackTitle": track.title,
            "trackArtist": track.artist,
            "trackAlbum": track.album as Any,
            "trackArtworkURL": track.artworkURL?.absoluteString as Any,
            "spotifyTrackURL": "https://open.spotify.com/track/\(track.id)",
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let location {
            payload["latitude"] = location.latitude
            payload["longitude"] = location.longitude
        }

        if isNew {
            payload["broadcastedAt"] = FieldValue.serverTimestamp()
        }

        do {
            try await db.collection(broadcastsCollection)
                .document(uid)
                .setData(payload, merge: true)
        } catch {
            errorMessage = "Broadcast update failed: \(error.localizedDescription)"
        }
    }
}
