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
                    .foregroundColor(AppColors.live)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Spotify")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.primaryText)

                    Text(statusText)
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                if spotifyAuth.isAuthorized {
                    Button {
                        spotifyAuth.disconnect()
                    } label: {
                        Text("Disconnect")
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppColors.destructive.opacity(0.7), lineWidth: 1)
                            )
                    }

                    Button {
                        spotifyAuth.ensureAuthorized()
                    } label: {
                        Text("Reconnect")
                            .font(AppFonts.subheadline())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppColors.live)
                            )
                            .foregroundColor(.white)
                    }
                } else {
                    Button {
                        spotifyAuth.ensureAuthorized()
                    } label: {
                        Text("Connect Spotify")
                            .font(AppFonts.subheadline())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppColors.live)
                            )
                            .foregroundColor(.white)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .melCard()
    }

    private var statusText: String {
        if spotifyAuth.isAuthorized {
            return "Connected to Spotify"
        } else {
            return "Not connected · Tap to connect"
        }
    }
}
