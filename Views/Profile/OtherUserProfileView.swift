import SwiftUI

struct OtherUserProfileView: View {

    let user: AppUser
    @State private var isFollowing: Bool = false
    @State private var isLoadingFollow: Bool = true
    @State private var followerCount: Int = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    headerCard

                    // Unified profile preview using shared component
                    let previewData = ProfilePreviewData(
                        heroPhotoURL: nil,
                        additionalPhotoURLs: [],
                        fullName: user.displayName,
                        age: user.age,
                        city: user.hometown?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? user.hometown : (user.city ?? nil),
                        gender: user.gender,
                        birthday: user.birthday,
                        spotifyId: user.spotifyId,
                        musicTaste: user.musicTaste?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? user.musicTaste : nil,
                        followerCount: followerCount,
                        broadcastMinutes: user.broadcastMinutesTotal,
                        likesReceivedCount: nil
                    )

                    // About section (reusing shared pattern)
                    aboutCard(data: previewData)

                    photosCard
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            isFollowing = (try? await FollowApiService.shared.isFollowing(userId: user.uid)) ?? false
            isLoadingFollow = false
            let followers = (try? await FollowApiService.shared.fetchFollowerIds(of: user.uid)) ?? []
            followerCount = followers.count
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)

                Text(subtitle)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if !isLoadingFollow {
                Button {
                    Task {
                        if isFollowing {
                            try? await FollowApiService.shared.unfollow(userId: user.uid)
                            isFollowing = false
                            followerCount = max(0, followerCount - 1)
                        } else {
                            try? await FollowApiService.shared.follow(userId: user.uid)
                            isFollowing = true
                            followerCount += 1
                        }
                    }
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(isFollowing ? AppColors.primaryText : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(isFollowing ? Color.gray.opacity(0.2) : AppColors.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    @ViewBuilder
    private func aboutCard(data: ProfilePreviewData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let city = data.city, !city.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    Text(city)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                }
            }

            if let taste = data.musicTaste, !taste.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    Text(taste)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Stats row
            HStack(spacing: 0) {
                statItem(value: "\(data.followerCount ?? 0)", label: "Followers")
                Spacer()
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 32)
                Spacer()
                statItem(value: formatBroadcastTime(data.broadcastMinutes), label: "Broadcast")
                Spacer()
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 32)
                Spacer()
                statItem(value: "\(data.likesReceivedCount ?? 0)", label: "Likes")
            }

            if let spotifyURL = data.spotifyProfileURL {
                Divider().background(Color.white.opacity(0.1))
                Button {
                    if let url = data.spotifyProfileURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Spotify Profile")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.mutedText)
        }
        .frame(minWidth: 60)
    }

    private func formatBroadcastTime(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "0min" }
        if minutes < 60 { return "\(minutes)min" }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 { return "\(hours)h" }
        return "\(hours)h \(remaining)m"
    }

    private var photosCard: some View {
        let urls = user.photoURLs ?? []

        return VStack(alignment: .leading, spacing: 10) {
            Text("Photos")
                .font(.caption)
                .foregroundColor(AppColors.mutedText)

            if urls.isEmpty {
                Text("No photos uploaded yet.")
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(urls, id: \.self) { u in
                            if let url = URL(string: u) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(AppColors.tintedBackground)
                                            .overlay(ProgressView().tint(.white))
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(AppColors.tintedBackground)
                                            .overlay(Image(systemName: "photo").foregroundColor(.white))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    // MARK: - Helpers

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
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        ZStack {
            Circle().fill(AppColors.tintedBackground)
            Text(user.initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
        }
    }
}

