//
//  DiscoverUserCard.swift
//  SocialSound
//
//  Created by Tim Basler on 06.01.2026.
//


import SwiftUI

struct DiscoverUserCard: View {

    let user: AppUser
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                if let track = user.currentTrack {
                    Button {
                        openSpotify(for: track)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.mutedText)

                            Text("\(track.title) · \(track.artist)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.mutedText)
                                .lineLimit(1)

                            Spacer(minLength: 6)

                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.mutedText.opacity(0.9))
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                } else if let taste = user.musicTaste, !taste.isEmpty {
                    Text(taste)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.mutedText)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.live)
                    .frame(width: 8, height: 8)
                Text("LIVE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.live)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColors.tintedBackground))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    private var subtitle: String {
        let age = user.age.map(String.init) ?? "?"
        let town = (user.hometown ?? "").isEmpty ? "Unknown" : (user.hometown ?? "Unknown")
        return "\(age) · \(town)"
    }

    private var avatar: some View {
        let urlString = (user.photoURLs?.first) ?? user.avatarURL

        return Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initials
                    @unknown default:
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var initials: some View {
        ZStack {
            Circle().fill(AppColors.tintedBackground)
            Text(user.initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
        }
    }

    private func openSpotify(for track: Track) {
        let appURL = URL(string: "spotify:track:\(track.id)")!
        let webURL = URL(string: "https://open.spotify.com/track/\(track.id)")!

        openURL(appURL) { success in
            if !success { openURL(webURL) }
        }
    }
}
