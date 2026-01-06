import Foundation
import UIKit

@MainActor
final class NowPlayingViewModel: ObservableObject {

    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var pollTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() {
        startPolling()
        Task { await refreshNowPlaying() } // sofort beim Start einmal
    }

    func stop() {
        stopPolling()
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

    // MARK: - Refresh

    func refreshNowPlaying() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let state = try await SpotifyService.shared.fetchNowPlayingState()
            currentTrack = state.track
            isPlaying = state.isPlaying
            errorMessage = nil
        } catch SpotifyAPIError.noActiveDevice {
            // Not fatal. User can open Spotify and start playing.
            currentTrack = nil
            isPlaying = false
            errorMessage = "No active Spotify device."
        } catch SpotifyAuthError.notAuthorized {
            currentTrack = nil
            isPlaying = false
            errorMessage = "Spotify not authorized."
        } catch {
            currentTrack = nil
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    /// Wird vom View beim App-Return aufgerufen.
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
            // Immediately refresh to sync UI state
            await refreshNowPlaying()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func next() async {
        do {
            try await SpotifyService.shared.next()
            await refreshNowPlaying()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previous() async {
        do {
            try await SpotifyService.shared.previous()
            await refreshNowPlaying()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

