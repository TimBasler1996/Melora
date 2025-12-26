//
//  SpotifyPlaybackError.swift
//  SocialSound
//
//  Created by Tim Basler on 20.11.2025.
//


import Foundation

/// Errors specific to Spotify playback control.
enum SpotifyPlaybackError: Error {
    /// There is no active Spotify device to control.
    case noActiveDevice
}

/// Service for controlling Spotify playback (play/pause/next/prev/shuffle).
/// Uses the same OAuth token as `SpotifyService`.
final class SpotifyPlaybackService {
    
    static let shared = SpotifyPlaybackService()
    
    private init() {}
    
    private let baseURL = URL(string: "https://api.spotify.com/v1")!
    
    // MARK: - Public API
    
    /// Pause current playback.
    func pausePlayback() async throws {
        try await sendCommand(path: "me/player/pause", method: "PUT")
    }
    
    /// Resume playback on the active device.
    func resumePlayback() async throws {
        try await sendCommand(path: "me/player/play", method: "PUT")
    }
    
    /// Skip to the next track in the queue.
    func skipToNext() async throws {
        try await sendCommand(path: "me/player/next", method: "POST")
    }
    
    /// Skip back to previous track.
    func skipToPrevious() async throws {
        try await sendCommand(path: "me/player/previous", method: "POST")
    }
    
    /// Toggle shuffle state for the active device.
    func setShuffle(enabled: Bool) async throws {
        let query = [URLQueryItem(name: "state", value: enabled ? "true" : "false")]
        try await sendCommand(path: "me/player/shuffle", method: "PUT", queryItems: query)
    }
    
    // MARK: - Internal
    
    private func sendCommand(
        path: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws {
        let accessToken = try await SpotifyAuthManager.shared.getValidAccessToken()
        
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if let queryItems {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw SpotifyAPIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }
        
        // 204 = no content, is OK for many player endpoints
        if http.statusCode == 204 || (200..<300).contains(http.statusCode) {
            return
        }
        
        // 404 = no active device
        if http.statusCode == 404 {
            throw SpotifyPlaybackError.noActiveDevice
        }
        
        print("❌ Spotify playback HTTP \(http.statusCode)")
        throw SpotifyAPIError.invalidResponse
    }
}
