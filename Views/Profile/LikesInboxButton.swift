//
//  LikesInboxButton.swift
//  SocialSound
//
//  Created by Tim Basler on 05.01.2026.
//


import SwiftUI

struct LikesInboxButton: View {

    let user: AppUser

    @StateObject private var badgeVM = LikesBadgeViewModel()
    @EnvironmentObject private var router: AppRouter
    @State private var showInbox = false

    var body: some View {
        Button {
            showInbox = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(AppColors.surfaceElevated)
                    )

                if badgeVM.unreadCount > 0 {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.live))
                        .offset(x: 10, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            badgeVM.startListening(userId: user.uid)
            consumeRouterRequest()
        }
        .onChange(of: router.showLikesInbox) { _, _ in
            consumeRouterRequest()
        }
        .onDisappear {
            badgeVM.stopListening()
        }
        .fullScreenCover(isPresented: $showInbox) {
            NavigationStack {
                LikesInboxView(user: user)
                    .onDisappear {
                        // When leaving inbox: mark as seen (and reset badge)
                        badgeVM.markAllAsSeenNow()
                    }
            }
        }
        .accessibilityLabel("Likes inbox")
    }

    /// A notification tap (or a profile stat) asked for the inbox.
    private func consumeRouterRequest() {
        guard router.showLikesInbox else { return }
        router.showLikesInbox = false
        showInbox = true
    }

    private var badgeText: String {
        if badgeVM.unreadCount > 99 { return "99+" }
        return "\(badgeVM.unreadCount)"
    }
}
