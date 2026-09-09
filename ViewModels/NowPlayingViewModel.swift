import Foundation
import UIKit

@MainActor
final class NowPlayingViewModel: ObservableObject {

    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var progressMs: Int = 0
    @Published var isScrubbing: Bool = false
    
    @Published var isShuffling: Bool = false
    @Published var repeatMode: RepeatMode = .off

    enum RepeatMode: String, CaseIterable { case off, context, track }

    private var pollTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var hasLoadedOnce = false

    // MARK: - Lifecycle

    func start() {
        startPolling()
        Task { await refreshNowPlaying() }
        Task { await refreshPlayerState() }
    }

    func stop() {
        stopPolling()
        progressTask?.cancel()
        progressTask = nil
    }

    // MARK: - Polling

    func startPolling(intervalSeconds: Double = 4.0) {
        guard pollTask == nil else { return }

        pollTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.refreshNowPlaying()
                let ns = UInt64(intervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Now Playing

    func refreshNowPlaying() async {
        if !hasLoadedOnce { isLoading = true }
        defer { isLoading = false; hasLoadedOnce = true }

        do {
            let state = try await SpotifyService.shared.fetchNowPlayingState()
            currentTrack = state.track
            isPlaying = state.isPlaying
            progressMs = state.progressMs ?? 0
            restartProgressTickerIfNeeded(durationMs: currentTrack?.durationMs)
            errorMessage = nil
            // Note: shuffle/repeat state is fetched on start() and on foreground,
            // and updated locally on user action — no need to poll it every tick.
        } catch SpotifyAPIError.noActiveDevice {
            currentTrack = nil
            isPlaying = false
            progressMs = 0
            isShuffling = false
            repeatMode = .off
            progressTask?.cancel()
            progressTask = nil
            errorMessage = "Open Spotify and play something first."
        } catch {
            // Transient failure (network blip, token refresh in flight): keep
            // the last known track so the UI and the live broadcast don't flap
            // to "nothing playing" every few seconds. The next poll recovers.
            errorMessage = "Couldn’t reach Spotify. Retrying…"
        }
    }

    private func refreshPlayerState() async {
        do {
            let state = try await SpotifyService.shared.fetchPlayerState()
            self.isShuffling = state.shuffle
            self.repeatMode = RepeatMode(rawValue: state.repeatMode) ?? .off
        } catch SpotifyAPIError.noActiveDevice {
            // Keep defaults when no device
        } catch {
            // silent fail to avoid noisy UI
        }
    }

    // MARK: - Controls

    func togglePlayPause() async {
        do {
            if isPlaying {
                try await SpotifyService.shared.pause()
            } else {
                try await SpotifyService.shared.play()
            }
            await refreshNowPlaying()
            restartProgressTickerIfNeeded(durationMs: currentTrack?.durationMs)
        } catch {
            errorMessage = UserFacingError.message(for: error, fallback: "Spotify didn’t respond. Please try again.")
        }
    }

    func next() async {
        do {
            try await SpotifyService.shared.next()
            await refreshNowPlaying()
            restartProgressTickerIfNeeded(durationMs: currentTrack?.durationMs)
        } catch {
            errorMessage = UserFacingError.message(for: error, fallback: "Spotify didn’t respond. Please try again.")
        }
    }

    func previous() async {
        do {
            try await SpotifyService.shared.previous()
            await refreshNowPlaying()
            restartProgressTickerIfNeeded(durationMs: currentTrack?.durationMs)
        } catch {
            errorMessage = UserFacingError.message(for: error, fallback: "Spotify didn’t respond. Please try again.")
        }
    }

    private func restartProgressTickerIfNeeded(durationMs: Int?) {
        progressTask?.cancel()
        progressTask = nil
        guard isPlaying, let durationMs else { return }

        progressTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard self.isPlaying else { return }
                    if self.progressMs + 1000 <= durationMs {
                        self.progressMs += 1000
                    } else {
                        self.progressMs = durationMs
                    }
                }
            }
        }
    }

    func seek(to positionMs: Int) async {
        progressMs = positionMs
        do {
            try await SpotifyService.shared.seek(to: positionMs)
        } catch {
            errorMessage = UserFacingError.message(for: error, fallback: "Spotify didn’t respond. Please try again.")
        }
    }
    func toggleShuffle() async {
        let previous = isShuffling
        isShuffling.toggle()
        do {
            try await SpotifyService.shared.setShuffle(enabled: isShuffling)
        } catch SpotifyAPIError.noActiveDevice {
            isShuffling = previous // device didn't accept it
            errorMessage = "Open Spotify and play something first."
        } catch {
            isShuffling = previous
            errorMessage = UserFacingError.message(for: error, fallback: "Spotify didn’t respond. Please try again.")
        }
    }

    func cycleRepeatMode() async {
        let previous = repeatMode
        let next: RepeatMode
        switch repeatMode {
        case .off: next = .context
        case .context: next = .track
        case .track: next = .off
        }
        repeatMode = next
        do {
            try await SpotifyService.shared.setRepeat(mode: next.rawValue)
        } catch SpotifyAPIError.noActiveDevice {
            repeatMode = previous
            errorMessage = "Open Spotify and play something first."
        } catch {
            repeatMode = previous
            errorMessage = UserFacingError.message(for: error, fallback: "Spotify didn’t respond. Please try again.")
        }
    }
}
