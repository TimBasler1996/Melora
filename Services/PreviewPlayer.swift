import AVFoundation
import Combine
import Foundation
import UIKit

/// Plays the 30 s snippet of one track at a time.
///
/// Starting a preview interrupts whatever else is playing — usually the
/// user's own Spotify. That is deliberate: two songs at once would be
/// unusable. Two rules keep that honest:
///
/// 1. The audio session is handed back (`.notifyOthersOnDeactivation`, which
///    asks Spotify to resume) only when Melora is really done making sound —
///    not while switching from one snippet to the next, and not when the app
///    is about to start the full song on Spotify itself.
/// 2. The player state follows the *audio*, not the lookup: `playingTrackId`
///    is set once the item is ready to play, and anything that takes the
///    sound away — an interruption, the app going to the background, a
///    failed load, a stalled connection — ends the preview and clears the
///    badge. A lit pause mark always means sound is coming out.
///
/// A 30 s pause does not end a live broadcast: Spotify keeps reporting the
/// track while paused, and `BroadcastManager` only ends a session when the
/// player reports nothing at all for several polls.
@MainActor
final class PreviewPlayer: ObservableObject {

    static let shared = PreviewPlayer()

    /// Sound is coming out for this track.
    @Published private(set) var playingTrackId: String?
    /// Looked up or buffering — no sound yet.
    @Published private(set) var loadingTrackId: String?
    /// 0…1 while a preview runs, for the ring around the artwork.
    @Published private(set) var progress: Double = 0
    /// Set briefly when a preview could not be played, so a view can say so.
    @Published private(set) var failedTrackId: String?

    /// How long a tap may stay silent before we admit defeat. Matches the
    /// lookup timeout in `TrackPreviewService`.
    private static let readyTimeout: TimeInterval = 8

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var watchdog: Task<Void, Never>?

    /// Bumped on every toggle; callbacks from an older attempt are ignored.
    private var generation = 0

    private init() {
        let center = NotificationCenter.default

        // A call, Siri, another app taking the stage: the sound is gone, so
        // the badge must not keep claiming otherwise.
        center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, self.player != nil else { return }
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
                // The interrupting app owns the session now; don't poke it.
                self.stop(notifyOthers: false)
            }
        }

        // Leaving the app ends the snippet: a preview is a glance, not a
        // background player, and Spotify should get its stage back.
        center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    func isPlaying(trackId: String) -> Bool { playingTrackId == trackId }
    func isLoading(trackId: String) -> Bool { loadingTrackId == trackId }
    /// True while this track is either buffering or audible.
    func isActive(trackId: String) -> Bool { isPlaying(trackId: trackId) || isLoading(trackId: trackId) }

    /// Starts the preview, or stops it when the same track is already active.
    /// Returns `false` only when no catalogue has a snippet — a network
    /// failure returns `true` and surfaces through `failedTrackId`, so a
    /// caller never mistakes "offline" for "this song has none".
    @discardableResult
    func toggle(trackId: String, title: String, artist: String) async -> Bool {
        if isActive(trackId: trackId) {
            stop()
            return true
        }

        // We are about to take the stage ourselves: tear the old player down
        // without inviting Spotify back for the length of the lookup.
        stop(notifyOthers: false)

        generation += 1
        let gen = generation
        loadingTrackId = trackId
        failedTrackId = nil

        let outcome = await TrackPreviewService.shared.preview(trackId: trackId, title: title, artist: artist)
        guard gen == generation else { return true }   // superseded by a newer tap

        switch outcome {
        case .none:
            loadingTrackId = nil
            // Nothing to play: give Spotify its stage back.
            deactivateSession()
            return false
        case .failed:
            fail(trackId: trackId)
            return true
        case .url(let url):
            start(url: url, trackId: trackId, generation: gen)
            return true
        }
    }

    // MARK: - Playback

    private func start(url: URL, trackId: String, generation gen: Int) {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback so the snippet is audible with the silent switch on.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("⚠️ [Preview] audio session: \(error.localizedDescription)")
            fail(trackId: trackId)
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        // The badge flips to "playing" only when there is actually sound.
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            // KVO arrives on an unspecified queue.
            Task { @MainActor [weak self] in
                guard let self, gen == self.generation else { return }
                switch item.status {
                case .readyToPlay:
                    self.watchdog?.cancel()
                    self.watchdog = nil
                    self.loadingTrackId = nil
                    self.playingTrackId = trackId
                    self.progress = 0
                    self.player?.play()
                case .failed:
                    // A cached URL can expire (Deezer signs them); let the
                    // next tap look it up again instead of staying broken.
                    await TrackPreviewService.shared.invalidate(trackId: trackId)
                    self.fail(trackId: trackId)
                default:
                    break
                }
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let duration = item.duration.seconds
            guard duration.isFinite, duration > 0 else { return }
            MainActor.assumeIsolated {
                // A streamed duration can be refined mid-play; never step back.
                self.progress = max(self.progress, min(1, time.seconds / duration))
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }

        // A connection that neither succeeds nor fails must not hold the tap.
        watchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.readyTimeout * 1_000_000_000))
            guard !Task.isCancelled, let self, gen == self.generation else { return }
            if self.loadingTrackId == trackId { self.fail(trackId: trackId) }
        }
    }

    private func fail(trackId: String) {
        stop()
        failedTrackId = trackId
    }

    /// Ends the preview. `notifyOthers` is false only when the caller is
    /// about to make sound itself (a new snippet, or Spotify taking over).
    func stop(notifyOthers: Bool = true) {
        let wasMakingSound = player != nil

        watchdog?.cancel()
        watchdog = nil
        statusObservation?.invalidate()
        statusObservation = nil
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
        failedTrackId = nil
        progress = 0

        if notifyOthers, wasMakingSound { deactivateSession() }
    }

    /// Stops only if this track is the one running — a view leaving the
    /// screen must not kill a preview someone else started.
    func stopIfActive(trackId: String) {
        guard isActive(trackId: trackId) else { return }
        stop()
    }

    /// Hands the stage back: Spotify resumes on this notification.
    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
