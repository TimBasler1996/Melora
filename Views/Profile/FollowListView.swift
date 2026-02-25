import SwiftUI
import FirebaseFirestore

struct FollowListView: View {

    enum Mode: String {
        case followers = "Followers"
        case following = "Following"
    }

    let userId: String
    let mode: Mode

    @State private var users: [AppUser] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.2),
                    Color.black.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading…").tint(.white)
            } else if users.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: mode == .followers ? "person.2" : "person.badge.plus")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No \(mode.rawValue.lowercased()) yet")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(users) { user in
                            NavigationLink {
                                UserProfilePreviewView(userId: user.uid)
                            } label: {
                                followRow(user: user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await loadUsers() }
    }

    private func followRow(user: AppUser) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Group {
                if let urlString = (user.photoURLs?.first) ?? user.avatarURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let city = user.hometown, !city.isEmpty {
                    Text(city)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.3, green: 0.3, blue: 0.4), Color(red: 0.2, green: 0.2, blue: 0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            )
    }

    private func loadUsers() async {
        let db = Firestore.firestore()
        do {
            let field = mode == .followers ? "followingId" : "followerId"
            let snap = try await db.collection("follows")
                .whereField(field, isEqualTo: userId)
                .getDocuments()

            let otherField = mode == .followers ? "followerId" : "followingId"
            let userIds = snap.documents.compactMap { $0.data()[otherField] as? String }

            var loaded: [AppUser] = []
            for uid in userIds {
                let userSnap = try await db.collection("users").document(uid).getDocument()
                if let data = userSnap.data() {
                    let user = AppUser.fromFirestore(uid: uid, data: data)
                    loaded.append(user)
                }
            }
            users = loaded
        } catch {
            print("❌ [FollowList] failed:", error.localizedDescription)
        }
        isLoading = false
    }
}
