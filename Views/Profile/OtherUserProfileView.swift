import SwiftUI

struct OtherUserProfileView: View {

    let user: AppUser
    @State private var isFollowing: Bool = false
    @State private var isLoadingFollow: Bool = true

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
                    aboutCard
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

                if (user.profileCompleted ?? false) {
                    HStack(spacing: 6) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("Profile complete")
                            .font(AppFonts.footnote())
                            .foregroundColor(AppColors.mutedText)
                    }
                }
            }

            Spacer()

            if !isLoadingFollow {
                Button {
                    Task {
                        if isFollowing {
                            try? await FollowApiService.shared.unfollow(userId: user.uid)
                            isFollowing = false
                        } else {
                            try? await FollowApiService.shared.follow(userId: user.uid)
                            isFollowing = true
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
    
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Music taste")
                .font(.caption)
                .foregroundColor(AppColors.mutedText)
            
            Text((user.musicTaste ?? "").isEmpty ? "—" : (user.musicTaste ?? "—"))
                .font(AppFonts.body())
                .foregroundColor(AppColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
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
        let urlString =
            (user.photoURLs?.first) ??
            user.avatarURL
        
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
}

