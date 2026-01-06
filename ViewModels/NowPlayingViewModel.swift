import Foundation
import UIKit

@MainActor
final class NowPlayingViewModel: ObservableObject {

    @Published var currentTrack: Track?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var pollTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() {
        startPolling()
        Task { await fetchCurrentTrack() } // sofort beim Start einmal
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
                await self.fetchCurrentTrack()
                let ns = UInt64(intervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Fetch

    func fetchCurrentTrack() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let track = try await SpotifyService.shared.fetchCurrentlyPlaying()
            currentTrack = track
            errorMessage = nil
        } catch SpotifyAPIError.noTrackPlaying {
            // 204 ist normal → nicht als Fehler darstellen
            currentTrack = nil
            errorMessage = nil
        } catch SpotifyAuthError.notAuthorized {
            currentTrack = nil
            errorMessage = "Spotify not authorized."
        } catch {
            currentTrack = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Wird vom View beim App-Return aufgerufen.
    func handleWillEnterForeground() {
        Task { await fetchCurrentTrack() }
    }
}

