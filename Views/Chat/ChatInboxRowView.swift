//
//  ChatInboxRowView.swift
//  SocialSound
//
//  Created by Tim Basler on 07.01.2026.
//


import SwiftUI

struct ChatInboxRowView: View {

    let row: ChatInboxRow

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName ?? "Unknown user")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(row.lastMessageText ?? "Say hi 👋")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let date = row.lastMessageAt ?? row.updatedAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var avatar: some View {
        Group {
            if let urlString = row.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(AppColors.tintedBackground)
            Image(systemName: "person.fill")
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
