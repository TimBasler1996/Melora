import SwiftUI

/// Lädt zu allen `fromUserId`s die passenden AppUser-Daten,
/// damit wir in der Like-Liste Namen + Avatar anzeigen können.
@MainActor
final class TrackLikesDetailUsersLoader: ObservableObject {
    
    @Published var usersById: [String: AppUser] = [:]
    
    private let service = UserApiService.shared
    
    /// Lädt für alle Likes (distinct by fromUserId) die Nutzerprofile.
    /// Wichtig: fromUserId ist bei dir jetzt die Firebase UID.
    func loadUsers(for likes: [TrackLike]) {
        let ids = Set(likes.map { $0.fromUserId })
        
        for id in ids {
            if usersById[id] != nil { continue }
            
            service.getUser(uid: id) { [weak self] result in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let user):
                        if let user {
                            self.usersById[id] = user
                        }
                    case .failure:
                        break
                    }
                }
            }
        }
    }
}

struct TrackLikesDetailView: View {
    
    let track: Track
    let likes: [TrackLike]
    
    @StateObject private var loader = TrackLikesDetailUsersLoader()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                
                HStack {
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("Likes")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // spacer to balance layout
                    Color.clear.frame(width: 60, height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track.artist)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(likes, id: \.id) { like in
                            row(for: like)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            loader.loadUsers(for: likes)
        }
    }
    
    private func row(for like: TrackLike) -> some View {
        let user = loader.usersById[like.fromUserId]
        
        return HStack(spacing: 12) {
            avatar(user: user)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(user?.displayName ?? "Unknown")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                
                Text(formattedDate(for: like))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }
    
    /// Versucht automatisch das richtige Date-Feld zu finden.
    /// Häufige Varianten: `createdAt`, `timestamp`, `likedAt`.
    private func formattedDate(for like: TrackLike) -> String {
        // ✅ Falls dein TrackLike ein Date-Feld hat, trage es hier ein:
        // return format(like.createdAt)
        //
        // Ich mache es robust: wir versuchen bekannte Namen via Mirror.
        
        let mirror = Mirror(reflecting: like)
        
        for key in ["createdAt", "likedAt", "timestamp", "date"] {
            if let value = mirror.children.first(where: { $0.label == key })?.value {
                if let d = value as? Date { return format(d) }
                // Firestore Timestamp?
                if let ts = value as? AnyObject,
                   let date = ts.value(forKey: "dateValue") as? () -> Date {
                    return format(date())
                }
            }
        }
        
        return "—"
    }
    
    private func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    private func avatar(user: AppUser?) -> some View {
        let urlString = (user?.photoURLs?.first) ?? user?.avatarURL
        
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
                        initials(user: user)
                    @unknown default:
                        initials(user: user)
                    }
                }
            } else {
                initials(user: user)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
    }
    
    private func initials(user: AppUser?) -> some View {
        ZStack {
            Circle().fill(AppColors.tintedBackground)
            Text(user?.initials ?? "?")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
        }
    }
}

