import SwiftUI

/// Beautiful profile view for viewing other users' profiles
/// Uses the same clean layout as the main Profile tab's Preview mode
struct UserProfilePreviewView: View {
    
    let userId: String
    
    @StateObject private var vm = UserProfilePreviewViewModel()
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - (AppLayout.screenPadding * 2)
            
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                if vm.isLoading {
                    loadingState
                } else if let error = vm.errorMessage {
                    errorState(error)
                } else if let model = vm.previewModel {
                    ScrollView {
                        VStack(spacing: 16) {
                            // ✅ Hero section with profile photo + name + age
                            heroSection(model: model)
                            
                            // ✅ Details table (City, Gender, Country, etc.)
                            detailsSection(model: model)
                            
                            // ✅ Photos section - vertical fullscreen
                            if !model.photoURLs.isEmpty {
                                photosSection(urls: model.photoURLs)
                            }
                            
                            // ✅ Spotify button (if available)
                            if let spotifyURL = model.spotifyProfileURL {
                                spotifyButton(url: spotifyURL)
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .frame(width: contentWidth, alignment: .center)
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadUser(userId: userId)
        }
    }
    
    // MARK: - Hero Section
    
    private func heroSection(model: ProfilePreviewModel) -> some View {
        let heroURL = model.heroPhotoURL
        let name = model.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = name.isEmpty ? "User" : name
        let ageText = model.age.map { ", \($0)" } ?? ""
        let city = (model.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let gender = (model.gender ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        return ZStack(alignment: .bottomLeading) {
            // Hero Image
            if let heroURL, let url = URL(string: heroURL), !heroURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        heroPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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
            
            // Gradient overlay for text readability
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0.2), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
            
            // Name and info overlay
            VStack(alignment: .leading, spacing: 4) {
                Text("\(safeName)\(ageText)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                if !city.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(city)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                if !gender.isEmpty {
                    Text(gender.capitalized)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            .padding(20)
        }
        .frame(height: 420)
        .frame(maxWidth: .infinity)
        .clipped()
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
                Text("No profile photo")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
    
    // MARK: - Details Section (Table)
    
    private func detailsSection(model: ProfilePreviewModel) -> some View {
        var rows: [DetailRow] = []
        
        if let city = model.city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(DetailRow(title: "City", value: city))
        }
        
        if let gender = model.gender, !gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rows.append(DetailRow(title: "Gender", value: gender.capitalized))
        }
        
        // ✅ Birthday with formatted date (like "7 Sep 1996")
        if let birthday = model.birthday {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM yyyy"
            let formattedDate = formatter.string(from: birthday)
            rows.append(DetailRow(title: "Birthday", value: formattedDate))
        }
        
        guard !rows.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                Text("About")
                    .font(AppFonts.sectionTitle())
                    .foregroundColor(AppColors.primaryText)
                
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
            .padding(AppLayout.cardPadding)
            .background(cardBackground)
        )
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
    
    // MARK: - Photos Section (Vertical Fullscreen)
    
    private func photosSection(urls: [String]) -> some View {
        let cleanURLs = urls
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !cleanURLs.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("More Photos")
                        .font(AppFonts.sectionTitle())
                        .foregroundColor(AppColors.primaryText)
                    
                    Spacer()
                    
                    Text("\(cleanURLs.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.mutedText)
                }
                
                // ✅ Vertical fullscreen photos
                LazyVStack(spacing: 16) {
                    ForEach(Array(cleanURLs.enumerated()), id: \.offset) { index, url in
                        fullscreenPhoto(urlString: url, index: index)
                    }
                }
            }
            .padding(AppLayout.cardPadding)
            .background(cardBackground)
        )
    }
    
    private func fullscreenPhoto(urlString: String, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
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
                        image
                            .resizable()
                            .scaledToFill()
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
            
            // Photo number badge
            Text("\(index + 2)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                )
                .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 480) // ✅ Vertical fullscreen height
        .clipped()
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
            Image(systemName: "photo.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(AppColors.secondaryText.opacity(0.5))
        }
    }
    
    // MARK: - Card Background
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
            .fill(AppColors.cardBackground)
            .shadow(
                color: Color.black.opacity(AppLayout.shadowOpacity),
                radius: AppLayout.shadowRadius,
                x: 0,
                y: 6
            )
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppColors.primary)
                .scaleEffect(1.2)
            
            Text("Loading profile…")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.secondaryText)
        }
    }
    
    // MARK: - Error State
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(AppColors.secondaryText.opacity(0.4))
            
            Text("Couldn't load profile")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
            
            Text(error)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await vm.loadUser(userId: userId)
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(AppColors.primary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppLayout.screenPadding)
    }
    
    // MARK: - Spotify Button
    
    private func spotifyButton(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 14) {
                // Spotify icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotify Profile")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                    
                    Text("View on Spotify")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DetailRow Model

private struct DetailRow: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

// MARK: - ViewModel

@MainActor
final class UserProfilePreviewViewModel: ObservableObject {
    
    @Published var previewModel: ProfilePreviewModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadUser(userId: String) async {
        isLoading = true
        errorMessage = nil
        previewModel = nil
        
        do {
            // Fetch user from Firestore
            let user = try await fetchUser(uid: userId)
            
            // Helper to clean strings
            func clean(_ s: String?) -> String? {
                guard let s = s else { return nil }
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            
            // Clean photo URLs
            let cleanedPhotos = (user.photoURLs ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Determine hero photo (avatar or first photo)
            let heroPhoto = clean(user.avatarURL) ?? cleanedPhotos.first
            
            // Determine first name with fallback
            let firstName: String = {
                if let name = clean(user.firstName) { return name }
                if let displayName = clean(user.displayName) { return displayName }
                return "User"
            }()
            
            // Determine city with fallback
            let city = clean(user.hometown) ?? clean(user.city)
            
            // Convert to ProfilePreviewModel
            let model = ProfilePreviewModel(
                firstName: firstName,
                age: user.age,
                birthday: user.birthday, // ✅ Pass birthday
                city: city,
                gender: clean(user.gender),
                countryCode: clean(user.countryCode),
                heroPhotoURL: heroPhoto,
                photoURLs: cleanedPhotos,
                spotifyIdOrURL: clean(user.spotifyId)
            )
            
            previewModel = model
            isLoading = false
            
            print("✅ [ProfilePreview] Loaded profile for \(firstName)")
            print("   - Age: \(user.age?.description ?? "nil")")
            print("   - City: \(city ?? "nil")")
            print("   - Gender: \(model.gender ?? "nil")")
            print("   - Country: \(model.countryCode ?? "nil")")
            print("   - Hero Photo: \(heroPhoto != nil ? "✅" : "❌")")
            print("   - Additional Photos: \(cleanedPhotos.count)")
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ [ProfilePreview] Failed to load user: \(error)")
        }
    }
    
    private func fetchUser(uid: String) async throws -> AppUser {
        return try await withCheckedThrowingContinuation { continuation in
            UserApiService.shared.fetchUser(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
}
