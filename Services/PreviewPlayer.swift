import AVFoundation
import Combine
import Foundation

/// Plays the 30 s snippet of one track at a time.
///
/// Starting a preview interrupts whatever else is playing — on this app's
/// users that is usually their own Spotify. That is deliberate: two songs at
/// once would be unusable. When the snippet ends the audio session is
/// deactivated with `.notifyOthersOnDeactivation`, which asks Spotify to pick
/// up where it left off. A pause of half a minute does not end a live
/// broadcast: Spotify keeps reporting the track while paused, and
/// `BroadcastManager` only ends a session when the player reports nothing
/// at all for several polls.
@MainActor
final class PreviewPlayer: ObservableObject {

    static let shared = PreviewPlayer()

    /// Spotify id of the track playing right now, if any.
    @Published private(set) var playingTrackId: String?
    /// 0…1 while a preview runs, for the ring around the artwork.
    @Published private(set) var progress: Double = 0
    /// The track whose preview is being looked up.
    @Published private(set) var loadingTrackId: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    private init() {}

    func isPlaying(trackId: String) -> Bool { playingTrackId == trackId }
    func isLoading(trackId: String) -> Bool { loadingTrackId == trackId }

    /// Starts the preview, or stops it when the same track is already playing.
    /// Returns `false` when no catalogue has a snippet for this track.
    @discardableResult
    func toggle(trackId: String, title: String, artist: String) async -> Bool {
        if playingTrackId == trackId {
            stop()
            return true
        }
        stop()

        loadingTrackId = trackId
        defer { if loadingTrackId == trackId { loadingTrackId = nil } }

        guard let url = await TrackPreviewService.shared.previewURL(trackId: trackId, title: title, artist: artist) else {
            return false
        }
        // The user may have tapped something else while we were looking.
        guard loadingTrackId == trackId else { return true }

        do {
            let session = AVAudioSession.sharedInstance()
            // .playback so the snippet is audible with the silent switch on.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("⚠️ [Preview] audio session: \(error.localizedDescription)")
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        playingTrackId = trackId
        progress = 0

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let duration = item.duration.seconds
            guard duration.isFinite, duration > 0 else { return }
            MainActor.assumeIsolated {
                self.progress = min(1, time.seconds / duration)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }

        player.play()
        return true
    }

    func stop() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        playingTrackId = nil
        loadingTrackId = nil
        progress = 0

        // Hands the stage back: Spotify resumes on this notification.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
