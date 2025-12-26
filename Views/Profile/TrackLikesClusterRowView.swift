//
//  TrackLikesClusterRowView.swift
//  SocialSound
//
//  Created by Tim Basler on 26.12.2025.
//


//
//  TrackLikesClusterRowView.swift
//  SocialSound
//

import SwiftUI

struct TrackLikesClusterRowView: View {

    let cluster: TrackLikesCluster

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.trackTitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(cluster.trackArtist)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                Text("\(cluster.likeCount) like\(cluster.likeCount == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.mutedText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppColors.mutedText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    private var artwork: some View {
        Group {
            if let urlString = cluster.trackArtworkURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12).fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 12).fill(AppColors.tintedBackground)
                            .overlay(Image(systemName: "music.note").foregroundColor(.white))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12).fill(AppColors.tintedBackground)
                    .overlay(Image(systemName: "music.note").foregroundColor(.white))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
