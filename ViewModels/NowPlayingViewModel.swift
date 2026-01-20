import Foundation
import UIKit

@MainActor
final class NowPlayingViewModel: ObservableObject {

    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var progressMs: Int = 0
    
    @Published var isShuffling: Bool = false
    @Published var repeatMode: RepeatMode = .off

    enum RepeatMode: String, CaseIterable { case off, context, track }

    private var pollTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

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
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await SpotifyService.shared.fetchNowPlayingState()
            currentTrack = state.track
            isPlaying = state.isPlaying
            progressMs = state.progressMs ?? 0
            isShuffling = state.isShuffling
            repeatMode = RepeatMode(rawValue: state.repeatMode) ?? .off
            restartProgressTickerIfNeeded(durationMs: currentTrack?.durationMs)
            errorMessage = nil
            await refreshPlayerState()
        } catch SpotifyAPIError.noActiveDevice {
            currentTrack = nil
            isPlaying = false
            progressMs = 0
            isShuffling = false
            repeatMode = .off
            progressTask?.cancel()
            progressTask = nil
            errorMessage = "No active Spotify device."
        } catch {
            currentTrack = nil
            isPlaying = false
            progressMs = 0
            isShuffling = false
            repeatMode = .off
            progressTask?.cancel()
            progressTask = nil
            errorMessage = error.localizedDescription
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

    func handleWillEnterForeground() {
        Task { await refreshNowPlaying() }
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
            errorMessage = error.localizedDescription
        }
    }

    func next() async {
        do {
            try await SpotifyService.shared.next()
            await refreshNowPlaying()
            restartProgressTickerIfNeeded(durationMs: currentTrack?.durationMs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previous() async {
        do {
            try await SpotifyService.shared.previous()
            await refreshNowPlaying()
            restartProgressTickerIfNeeded(durationMs: currentTrack?.durationMs)
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }
    func toggleShuffle() async {
        do {
            isShuffling.toggle()
            try await SpotifyPlaybackService.shared.setShuffle(enabled: isShuffling)
        } catch SpotifyPlaybackError.noActiveDevice {
            errorMessage = "No active Spotify device."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cycleRepeatMode() async {
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
            errorMessage = "No active Spotify device."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

