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
            ZStack(alignment: .topTrailing) {
                avatar

                if row.isUnread {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(AppColors.cardBackground, lineWidth: 2))
                        .offset(x: 2, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName ?? "New member")
                    .font(.system(size: 16, weight: row.isUnread ? .bold : .semibold))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(row.lastMessageText ?? "Say hi 👋")
                    .font(.system(size: 13, weight: row.isUnread ? .semibold : .regular))
                    .foregroundColor(row.isUnread ? AppColors.primaryText : AppColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let date = row.lastMessageAt ?? row.updatedAt {
                    Text(Self.relativeLabel(for: date))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(row.isUnread ? AppColors.primary : AppColors.mutedText)
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.mutedText)
            }
        }
        .padding(12)
        .melCard()
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 8)
    }

    private var avatar: some View {
        Group {
            if let urlString = row.avatarURL, let url = URL(string: urlString) {
                RemoteImage(url: url, size: 56) { phase in
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

extension ChatInboxRowView {
    /// "14:05" today, "Tue" within the last week, "12 Mar" otherwise.
    static func relativeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -6, to: Date()), date > weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        return date.formatted(date: .numeric, time: .omitted)
    }
}
