import SwiftUI

struct UserProfileDetailView: View {
    
    let userId: String
    
    @StateObject private var vm = UserProfileDetailViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if vm.isLoading && vm.user == nil {
                ProgressView("Loading…").tint(.white)
            } else if let error = vm.errorMessage {
                VStack(spacing: 10) {
                    Text("Couldn’t load profile")
                        .foregroundColor(.white)
                    Text(error)
                        .font(AppFonts.footnote())
                        .foregroundColor(.white.opacity(0.85))
                    Button("Retry") { vm.load(userId: userId) }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, AppLayout.screenPadding)
            } else if let user = vm.user {
                ScrollView {
                    VStack(spacing: 14) {
                        // reuse same layout as Profile tab
                        // (simple duplicate for now, fast)
                        Text(user.displayName)
                            .font(AppFonts.title())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Photos
                        if let urls = user.photoURLs, !urls.isEmpty {
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(urls, id: \.self) { u in
                                        if let url = URL(string: u) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(Color.white.opacity(0.12))
                                                        .overlay(ProgressView().tint(.white))
                                                case .success(let img):
                                                    img.resizable().scaledToFill()
                                                case .failure:
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .fill(Color.white.opacity(0.12))
                                                        .overlay(Image(systemName: "photo").foregroundColor(.white))
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                            .frame(width: 220, height: 220)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .scrollIndicators(.hidden)
                        }
                        
                        // Basics
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(user.age.map(String.init) ?? "?") · \(user.hometown ?? "Unknown")")
                                .font(AppFonts.body())
                                .foregroundColor(.white.opacity(0.9))
                            
                            if let taste = user.musicTaste, !taste.isEmpty {
                                Text("Music taste")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.75))
                                Text(taste)
                                    .font(AppFonts.body())
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.load(userId: userId) }
    }
}
