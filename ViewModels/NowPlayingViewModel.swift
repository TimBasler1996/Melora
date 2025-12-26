import Foundation

/// View model for the "Now Playing" screen.
/// Responsible for loading the current track from Spotify.
@MainActor
final class NowPlayingViewModel: ObservableObject {
    
    @Published var currentTrack: Track?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let spotifyService: SpotifyService
    private var autoRefreshTask: Task<Void, Never>?
    
    init(spotifyService: SpotifyService = .shared) {
        self.spotifyService = spotifyService
        // Start automatic refresh as soon as the view model is created
        startAutoRefresh(intervalSeconds: 2)
    }
    
    /// Manually triggers a refresh of the currently playing track from Spotify.
    func refresh(showLoadingIndicator: Bool = true) {
        Task {
            await loadNowPlaying(showLoadingIndicator: showLoadingIndicator)
        }
    }
    
    /// Starts periodic auto-refresh of the current track.
    /// If already running, this does nothing.
    func startAutoRefresh(intervalSeconds: UInt64 = 10) {
        guard autoRefreshTask == nil else { return }
        
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.loadNowPlaying(showLoadingIndicator: false)
                try? await Task.sleep(nanoseconds: intervalSeconds * 1_000_000_000)
            }
        }
    }
    
    /// Stops the auto-refresh task if it is running.
    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }
    
    /// Internal async function that performs the API call.
    private func loadNowPlaying(showLoadingIndicator: Bool) async {
        if showLoadingIndicator {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            let track = try await spotifyService.fetchCurrentlyPlaying()
            self.currentTrack = track
        } catch {
            print("❌ Failed to load currently playing track: \(error)")
            self.errorMessage = "Failed to load current track."
        }
        
        if showLoadingIndicator {
            isLoading = false
        }
    }
}
