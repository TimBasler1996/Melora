import SwiftUI
import FirebaseAuth
import FirebaseFirestore

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

    // Distance & broadcasting (only relevant for other users)
    let distanceMeters: Double?
    let isBroadcasting: Bool
    
    var spotifyProfileURL: URL? {
        guard let id = spotifyId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }
        
        // If already a full URL
        if let url = URL(string: id), url.scheme != nil {
            return url
        }
        
        // Otherwise treat as Spotify user ID
        return URL(string: "https://open.spotify.com/user/\(id)")
    }
    
    /// Create from UserProfile (your own profile)
    static func from(userProfile: UserProfile) -> ProfilePreviewData {
        // Get all photos except the first one (hero)
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
            distanceMeters: nil,
            isBroadcasting: false
        )
    }

    /// Create from AppUser (someone else's profile)
    static func from(
        appUser: AppUser,
        distanceMeters: Double? = nil
    ) -> ProfilePreviewData {
        // Get all photos except the first one (hero)
        let additionalPhotos = Array((appUser.photoURLs ?? []).dropFirst())
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return ProfilePreviewData(
            heroPhotoURL: appUser.photoURLs?.first,
            additionalPhotoURLs: additionalPhotos,
            fullName: appUser.displayName,
            age: appUser.age,
            city: appUser.hometown?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? appUser.hometown : nil,
            gender: appUser.gender?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? appUser.gender : nil,
            birthday: appUser.birthday,
            spotifyId: appUser.spotifyId,
            distanceMeters: (appUser.isBroadcasting == true) ? distanceMeters : nil,
            isBroadcasting: appUser.isBroadcasting == true
        )
    }
}

// MARK: - Shared Profile Preview Component

/// ✅ Single shared component for profile preview display
/// Used in both ProfileView (your own) and UserProfilePreviewView (others)
struct SharedProfilePreviewView: View {

    let data: ProfilePreviewData
    var userId: String? = nil

    @Environment(\.openURL) private var openURL
    @State private var followingCount: Int = 0
    @State private var followerCount: Int = 0
    @State private var followStatsLoaded = false

    var body: some View {
        VStack(spacing: 16) {
            heroSection

            if userId != nil, followStatsLoaded {
                followStatsSection
            }

            detailsSection

            if let spotifyURL = data.spotifyProfileURL {
                spotifyButton(url: spotifyURL)
            }

            if !data.additionalPhotoURLs.isEmpty {
                photosSection
            }
        }
        .task(id: userId) {
            guard let uid = userId else { return }
            do {
                let db = Firestore.firestore()

                async let followingSnap = db.collection("follows")
                    .whereField("followerId", isEqualTo: uid)
                    .getDocuments()
                async let followerSnap = db.collection("follows")
                    .whereField("followingId", isEqualTo: uid)
                    .getDocuments()

                followingCount = try await followingSnap.documents.count
                followerCount = try await followerSnap.documents.count
                followStatsLoaded = true
            } catch {
                print("Failed to load follow stats: \(error)")
            }
        }
    }

    // MARK: - Follow Stats Section

    private var followStatsSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(followerCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                Text("Followers")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(AppColors.secondaryText.opacity(0.2))
                .frame(width: 1, height: 36)

            VStack(spacing: 4) {
                Text("\(followingCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                Text("Following")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(cardBackground)
    }
    
    // MARK: - Spotify Button
    
    private func spotifyButton(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Open Spotify Profile")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.73, blue: 0.33),
                                Color(red: 0.09, green: 0.65, blue: 0.29)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        let ageText = data.age.map { ", \($0)" } ?? ""
        let city = data.city ?? ""
        let gender = data.gender ?? ""
        
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
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        if !city.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(city)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        
                        if !gender.isEmpty {
                            Text(gender)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
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
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        let rows = buildDetailRows()
        
        return VStack(alignment: .leading, spacing: 14) {
            Text("About")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)
            
            if rows.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary.opacity(0.7))
                    
                    Text("No additional details available.")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.secondaryText)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 14) {
                    ForEach(rows) { row in
                        detailRow(title: row.title, value: row.value)
                        
                        if row.id != rows.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.mutedText)
                .frame(width: 90, alignment: .leading)
            
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
    
    private func buildDetailRows() -> [DetailRow] {
        var rows: [DetailRow] = []

        if let city = data.city, !city.isEmpty {
            rows.append(DetailRow(title: "City", value: city))
        }

        if let gender = data.gender, !gender.isEmpty {
            rows.append(DetailRow(title: "Gender", value: gender))
        }

        if let age = data.age {
            rows.append(DetailRow(title: "Age", value: "\(age) years old"))
        }

        // Distance: only shown when user is actively broadcasting
        if data.isBroadcasting, let meters = data.distanceMeters {
            rows.append(DetailRow(title: "Distance", value: formattedDistance(meters)))
        }

        return rows
    }

    /// Formats distance: > 100 m → km, otherwise m
    private func formattedDistance(_ meters: Double) -> String {
        if meters > 100 {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return "\(Int(meters)) m"
        }
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ✅ Changed "More Photos" to "Photos"
            Text("Photos")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)
            
            // ✅ Vertical fullscreen photos with consistent sizing (no count, no numbering)
            LazyVStack(spacing: 16) {
                ForEach(Array(data.additionalPhotoURLs.enumerated()), id: \.offset) { index, url in
                    photoTile(urlString: url, index: index)
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }
    
    private func photoTile(urlString: String, index: Int) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            // ✅ Removed photo number badge - just the photo
            ZStack {
                // ✅ Force explicit frame constraints
                Group {
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    photoPlaceholder
                                    ProgressView()
                                        .tint(AppColors.primary)
                                }
                            case .success(let image):
                                // ✅ Force frame INSIDE the image modifier
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: width, height: 480)
                                    .clipped()
                                    .transaction { t in t.animation = nil }
                            case .failure:
                                ZStack {
                                    photoPlaceholder
                                    VStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(AppColors.secondaryText.opacity(0.6))
                                        Text("Failed to load")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(AppColors.secondaryText.opacity(0.6))
                                    }
                                }
                            @unknown default:
                                photoPlaceholder
                            }
                        }
                    } else {
                        photoPlaceholder
                    }
                }
                .frame(width: width, height: 480)
                .clipped()
            }
            .frame(width: width, height: 480)
        }
        .frame(height: 480) // ✅ Fixed vertical height - consistent across all photos
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var photoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.tintedBackground.opacity(0.5), AppColors.tintedBackground.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "photo")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(AppColors.secondaryText.opacity(0.6))
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
            .fill(AppColors.cardBackground)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

// MARK: - Supporting Types

struct DetailRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}
