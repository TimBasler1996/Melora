//
//  LikesInboxView.swift
//  SocialSound
//

import SwiftUI

struct LikesInboxView: View {

    let user: AppUser
    @StateObject private var vm = LikesInboxViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .navigationTitle("Likes")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            vm.loadLikes(for: user.uid)
        }
        .refreshable {
            vm.loadLikes(for: user.uid)
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.clusters.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading likes…").tint(.white)
                Spacer()
            }
        } else if let err = vm.errorMessage {
            VStack(spacing: 10) {
                Text("Couldn’t load likes")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(err)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Retry") { vm.loadLikes(for: user.uid) }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if vm.clusters.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Text("No likes yet")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("When someone likes a track you broadcast, it will show up here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.clusters) { cluster in
                        NavigationLink {
                            TrackLikesDetailView(user: user, track: cluster.track, likes: cluster.likes)
                        } label: {
                            TrackLikesClusterRowView(cluster: cluster)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }
}

