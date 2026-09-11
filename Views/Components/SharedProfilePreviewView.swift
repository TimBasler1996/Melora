import SwiftUI

// MARK: - Shared Profile Preview Data Model

/// Lightweight data model for profile preview display
/// Can be created from UserProfile (your own) or AppUser (others)
struct ProfilePreviewData: Equatable {
    let heroPhotoURL: String?
    let additionalPhotoURLs: [String]
    let fullName: String
    let age: Int?
    let city: String?
    let gender: String?
    let birthday: Date?
    let spotifyId: String?
    let musicTaste: String?
    let lookingFor: String?
    let followerCount: Int?
    let broadcastMinutes: Int?
    let likesReceivedCount: Int?

    /// The profile owner's uid — enables tapping the follower count to open
    /// their followers list. `nil` disables that interaction.
    var userId: String? = nil

    /// Top artists, tracks and playlists from Spotify, when synced.
    var taste: SpotifyTaste? = nil

    var spotifyProfileURL: URL? {
        guard let id = spotifyId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }
        if let url = URL(string: id), url.scheme != nil { return url }
        return URL(string: "https://open.spotify.com/user/\(id)")
    }

    static func from(userProfile: UserProfile) -> ProfilePreviewData {
        let additionalPhotos = Array(userProfile.photoURLs.dropFirst())
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return ProfilePreviewData(
            heroPhotoURL: userProfile.displayHeroPhotoURL,
            additionalPhotoURLs: additionalPhotos,
            fullName: userProfile.fullName,
            age: userProfile.age,
            city: userProfile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userProfile.city,
            gender: userProfile.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : userProfile.gender,
            birthday: userProfile.birthday,
            spotifyId: userProfile.spotifyId,
            musicTaste: nil,
            lookingFor: userProfile.lookingFor?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? userProfile.lookingFor : nil,
            followerCount: nil,
            broadcastMinutes: nil,
            likesReceivedCount: nil,
            userId: userProfile.uid,
            taste: userProfile.spotifyTaste
        )
    }

    static func from(
        appUser: AppUser,
        followerCount: Int? = nil,
        likesReceivedCount: Int? = nil
    ) -> ProfilePreviewData {
        let additionalPhotos = Array((appUser.photoURLs ?? []).dropFirst())
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return ProfilePreviewData(
            heroPhotoURL: appUser.photoURLs?.first,
            additionalPhotoURLs: additionalPhotos,
            fullName: appUser.displayName,
            // Profiles store `birthday` and `city`; `age` / `hometown` are legacy fallbacks.
            age: appUser.birthday?.age() ?? appUser.age,
            city: [appUser.city, appUser.hometown]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty },
            gender: appUser.gender?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? appUser.gender : nil,
            birthday: appUser.birthday,
            spotifyId: appUser.spotifyId,
            musicTaste: appUser.musicTaste?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? appUser.musicTaste : nil,
            lookingFor: appUser.lookingFor?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? appUser.lookingFor : nil,
            followerCount: followerCount,
            broadcastMinutes: appUser.broadcastMinutesTotal,
            likesReceivedCount: likesReceivedCount,
            userId: appUser.uid,
            taste: appUser.spotifyTaste
        )
    }
}

// MARK: - Shared Profile Preview Component

/// ✅ Single shared component for profile preview display
/// Used in both ProfileView (your own) and UserProfilePreviewView (others)
struct SharedProfilePreviewView: View {

    let data: ProfilePreviewData
    /// Own profile: tapping the Likes stat opens the likes inbox.
    var onLikesTap: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            heroSection
            infoCard

            if let taste = data.taste, !taste.isEmpty {
                MusicTasteCard(taste: taste)
            }

            if !data.additionalPhotoURLs.isEmpty {
                photosStack
            }
        }
    }

    // MARK: - Info Card (chips + stats + Spotify)

    private var hasChips: Bool {
        [data.gender, data.lookingFor, data.musicTaste].contains { ($0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if hasChips {
                chipsRow
            }

            statsStrip

            if let spotifyURL = data.spotifyProfileURL {
                spotifyLink(url: spotifyURL)
            }
        }
        .padding(AppLayout.cardPadding)
        .melCard(cornerRadius: AppLayout.cornerRadiusLarge)
    }

    /// A tidy, horizontally-scrollable row of the profile's defining chips.
    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let g = data.gender, !g.isEmpty {
                    ProfileChip(text: g, icon: "person.fill")
                }
                if let lf = data.lookingFor, !lf.isEmpty {
                    // Profiles saved before the label change still say "for".
                    ProfileChip(text: lf == "Open for all" ? "Open to all" : lf, icon: "sparkles")
                }
                if let mt = data.musicTaste, !mt.isEmpty {
                    ProfileChip(text: mt, icon: "music.note")
                }
            }
        }
    }

    /// Three evenly-weighted stats, no divider bars.
    /// The follower count is tappable when a userId is available.
    private var statsStrip: some View {
        HStack(spacing: 0) {
            followersStat
            statItem(value: formatBroadcastTime(data.broadcastMinutes), label: "Live time")
            likesStat
        }
    }

    @ViewBuilder
    private var likesStat: some View {
        let value = data.likesReceivedCount.map(String.init) ?? "—"
        if let onLikesTap {
            Button(action: onLikesTap) {
                statItem(value: value, label: "Likes")
            }
            .buttonStyle(.plain)
        } else {
            statItem(value: value, label: "Likes")
        }
    }

    @ViewBuilder
    private var followersStat: some View {
        let value = data.followerCount.map(String.init) ?? "—"
        if let uid = data.userId {
            NavigationLink {
                FollowersListView(userId: uid)
            } label: {
                statItem(value: value, label: "Followers")
            }
            .buttonStyle(.plain)
        } else {
            statItem(value: value, label: "Followers")
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.primaryText)
            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.mutedText)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatBroadcastTime(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "0min" }
        if minutes < 60 { return "\(minutes)min" }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 { return "\(hours)h" }
        return "\(hours)h \(remaining)m"
    }

    private func spotifyLink(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                Text("Spotify Profile")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(AppColors.live)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(AppColors.live.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero Section
    
    private var heroSection: some View {
        let ageText = data.age.map { ", \($0)" } ?? ""
        let city = data.city ?? ""

        return GeometryReader { geometry in
            let width = geometry.size.width
            
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    // ✅ Hero image with explicit frame constraints
                    Group {
                        if let heroURL = data.heroPhotoURL, let url = URL(string: heroURL), !heroURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    heroPlaceholder
                                case .success(let image):
                                    // ✅ Force frame constraints INSIDE the image modifier
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: width, height: 420)
                                        .clipped()
                                        .transaction { t in t.animation = nil }
                                case .failure:
                                    heroPlaceholder
                                @unknown default:
                                    heroPlaceholder
                                }
                            }
                        } else {
                            heroPlaceholder
                        }
                    }
                    .frame(width: width, height: 420)
                    .clipped()
                    
                    // Gradient overlay for text readability
                    LinearGradient(
                        colors: [Color.black.opacity(0.7), Color.black.opacity(0.2), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(width: width, height: 420)
                    
                    // Name and info overlay
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(data.fullName)\(ageText)")
                            .font(AppFonts.largeTitle())
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        if !city.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(city)
                                    .font(AppFonts.body())
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: width, height: 420)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 420)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
    }
    
    private var heroPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundColor(AppColors.secondaryText.opacity(0.6))
                Text("No photo")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
    
    // MARK: - Photos (clean edge-to-edge 3:4 stack, no card / no heading)

    private var photosStack: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(data.additionalPhotoURLs.enumerated()), id: \.offset) { _, url in
                photoTile(urlString: url)
            }
        }
    }

    private func photoTile(urlString: String) -> some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack { photoPlaceholder; ProgressView().tint(AppColors.primary) }
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .transaction { t in t.animation = nil }
                        case .failure:
                            photoPlaceholder
                        @unknown default:
                            photoPlaceholder
                        }
                    }
                } else {
                    photoPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                    .stroke(AppColors.stroke, lineWidth: 1)
            )
    }

    private var photoPlaceholder: some View {
        ZStack {
            AppColors.surface
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(AppColors.mutedText)
        }
    }
}

// MARK: - Supporting Types

struct DetailRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

// MARK: - Followers List

/// A simple, tappable list of the users who follow a given profile.
/// Opened by tapping the "Followers" stat on a profile.
struct FollowersListView: View {

    let userId: String
    @StateObject private var vm = FollowersListViewModel()

    var body: some View {
        ZStack {
            if vm.isLoading {
                ProgressView().tint(AppColors.primary)
            } else if vm.followers.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "person.2")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundColor(AppColors.mutedText)
                    Text("No followers yet")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.secondaryText)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.followers) { user in
                            NavigationLink {
                                UserProfilePreviewView(userId: user.uid)
                            } label: {
                                FollowerListRow(user: user)
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
        .melScreenBackground()
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await vm.load(userId: userId) }
    }
}

private struct FollowerListRow: View {
    let user: AppUser

    var body: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                if let city = (user.city ?? user.hometown)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !city.isEmpty {
                    Text(city)
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.mutedText)
        }
        .padding(12)
        .melCard()
    }

    private var avatar: some View {
        Group {
            if let s = user.avatarURL ?? user.photoURLs?.first, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1))
    }

    private var avatarPlaceholder: some View {
        ZStack {
            AppColors.surfaceElevated
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.mutedText)
        }
    }
}

@MainActor
final class FollowersListViewModel: ObservableObject {

    @Published var followers: [AppUser] = []
    @Published var isLoading: Bool = true

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    func load(userId: String) async {
        guard !isRunningInPreview else { isLoading = false; return }
        guard followers.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let ids: [String]
        do {
            ids = Array(try await FollowApiService.shared.fetchFollowerIds(of: userId))
        } catch {
            print("❌ [Followers] fetch ids failed:", error.localizedDescription)
            return
        }

        var loaded: [AppUser] = []
        for id in ids {
            // Unfinished or deleted profiles have nothing to show.
            if let user = try? await fetchUser(uid: id), user.profileCompleted == true {
                loaded.append(user)
            }
        }

        followers = loaded.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private func fetchUser(uid: String) async throws -> AppUser {
        try await withCheckedThrowingContinuation { continuation in
            UserApiService.shared.fetchUser(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - Music taste

/// What someone actually listens to: their Spotify top artists, top tracks
/// and public playlists. Tapping opens Spotify.
struct MusicTasteCard: View {
    let taste: SpotifyTaste
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Music taste")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)

            if !taste.topArtists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    caption("Top artists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(taste.topArtists) { artist in
                                Button { open(artist) } label: {
                                    VStack(spacing: 6) {
                                        image(artist.imageURL, size: 56, circle: true)
                                        Text(artist.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppColors.primaryText)
                                            .lineLimit(1)
                                            .frame(width: 64)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if !taste.topTracks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    caption("On repeat")
                    ForEach(taste.topTracks.prefix(3)) { track in
                        Button { open(track) } label: {
                            HStack(spacing: 10) {
                                image(track.imageURL, size: 40, circle: false)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.name)
                                        .font(AppFonts.song(size: 18))
                                        .foregroundColor(AppColors.primaryText)
                                        .lineLimit(1)
                                    if let subtitle = track.subtitle {
                                        Text(subtitle)
                                            .font(AppFonts.caption())
                                            .foregroundColor(AppColors.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.mutedText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !taste.playlists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    caption("Playlists")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(taste.playlists) { playlist in
                                Button { open(playlist) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        image(playlist.imageURL, size: 96, circle: false)
                                        Text(playlist.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppColors.primaryText)
                                            .lineLimit(1)
                                        if let subtitle = playlist.subtitle {
                                            Text(subtitle)
                                                .font(AppFonts.caption())
                                                .foregroundColor(AppColors.mutedText)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(width: 96, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .melCard(cornerRadius: AppLayout.cornerRadiusLarge)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(AppFonts.caption())
            .foregroundColor(AppColors.mutedText)
    }

    private func open(_ item: SpotifyTaste.Item) {
        guard let urlString = item.url, let url = URL(string: urlString) else { return }
        openURL(url)
    }

    private func image(_ urlString: String?, size: CGFloat, circle: Bool) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(AppColors.surface)
                    }
                }
            } else {
                Rectangle().fill(AppColors.surface)
                    .overlay(Image(systemName: "music.note").foregroundColor(AppColors.mutedText))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: circle ? size / 2 : 8, style: .continuous))
    }
}
