//
//  BroadcastToggleCard.swift
//  SocialSound
//
//  Created by Tim Basler on 03.01.2026.
//


import SwiftUI

struct BroadcastToggleCard: View {

    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Broadcast")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text(broadcast.isBroadcasting ? "ON" : "OFF")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(broadcast.isBroadcasting ? .green : .white.opacity(0.75))
            }

            Toggle(isOn: Binding(
                get: { broadcast.isBroadcasting },
                set: { newValue in
                    Task {
                        // Optional: ask for location permission when user turns it on
                        if newValue {
                            locationService.requestAuthorizationIfNeeded()
                            broadcast.attachLocationService(locationService)
                        }
                        await broadcast.setBroadcasting(newValue)
                    }
                }
            )) {
                Text(broadcast.isBroadcasting ? "You are live nearby" : "Go live nearby")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .tint(.green)
            .disabled(!spotifyAuth.isAuthorized)
            .opacity(!spotifyAuth.isAuthorized ? 0.5 : 1)

            if !spotifyAuth.isAuthorized {
                Text("Spotify connection required to broadcast.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let err = broadcast.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}
