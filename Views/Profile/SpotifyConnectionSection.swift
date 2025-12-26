//
//  SpotifyConnectionSection.swift
//  SocialSound
//
//  Created by Tim Basler on 21.11.2025.
//


import SwiftUI

/// Kleiner Abschnitt für das Profil:
/// Zeigt den aktuellen Spotify-Status + Button zum Verbinden/Trennen.
struct SpotifyConnectionSection: View {
    
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Image(systemName: "music.note")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spotify")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    
                    Text(statusText)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                if spotifyAuth.isAuthorized {
                    Button {
                        spotifyAuth.disconnect()
                    } label: {
                        Text("Disconnect")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.red.opacity(0.7), lineWidth: 1)
                            )
                    }
                    
                    Button {
                        spotifyAuth.ensureAuthorized()
                    } label: {
                        Text("Reconnect")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.green.opacity(0.9))
                            )
                            .foregroundColor(.white)
                    }
                } else {
                    Button {
                        spotifyAuth.ensureAuthorized()
                    } label: {
                        Text("Connect Spotify")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.green.opacity(0.9))
                            )
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var statusText: String {
        if spotifyAuth.isAuthorized {
            return "Connected to Spotify"
        } else {
            return "Not connected · Tap to connect"
        }
    }
}