import SwiftUI

/// Zeigt alle erhaltenen Likes der aktuellen Person,
/// geclustert nach Track und gruppiert in "Today" und "Earlier".
struct LikesInboxView: View {
    
    @EnvironmentObject private var broadcast: BroadcastManager
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = LikesInboxViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    
                    // Back
                    HStack {
                        Button { dismiss() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 12)
                    
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Likes received")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Grouped by track · sorted by time")
                            .font(AppFonts.footnote())
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppLayout.screenPadding)
                    
                    // Content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                        
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        Text(error)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                        
                    } else if viewModel.clusters.isEmpty {
                        Spacer()
                        Text("No likes yet.\nGo broadcast some music ✨")
                            .foregroundColor(.white.opacity(0.85))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                        
                    } else {
                        let groups = groupedClusters()
                        
                        List {
                            if !groups.today.isEmpty {
                                Section("Today") {
                                    ForEach(groups.today) { cluster in
                                        NavigationLink {
                                            TrackLikesDetailView(
                                                track: makeTrack(from: cluster),
                                                likes: cluster.likes
                                            )
                                        } label: {
                                            clusterRow(cluster: cluster, isNew: isClusterNew(cluster))
                                        }
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                            
                            if !groups.earlier.isEmpty {
                                Section("Earlier") {
                                    ForEach(groups.earlier) { cluster in
                                        NavigationLink {
                                            TrackLikesDetailView(
                                                track: makeTrack(from: cluster),
                                                likes: cluster.likes
                                            )
                                        } label: {
                                            clusterRow(cluster: cluster, isNew: isClusterNew(cluster))
                                        }
                                        .listRowBackground(Color.clear)
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.plain)
                    }
                }
            }
            .onAppear {
                viewModel.loadLikes(for: broadcast.currentUser.id)
            }
            .onDisappear {
                viewModel.markAllAsSeen()
            }
        }
    }
    
    // MARK: - Row UI
    
    @ViewBuilder
    private func clusterRow(cluster: TrackLikesCluster, isNew: Bool) -> some View {
        HStack(spacing: 12) {
            artwork(cluster: cluster)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(cluster.trackTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)
                    
                    if isNew {
                        Text("NEW")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.live)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppColors.tintedBackground))
                    }
                }
                
                Text(cluster.trackArtist)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
                
                Text("\(cluster.likes.count) like\(cluster.likes.count == 1 ? "" : "s") · \(format(cluster.lastLikeAt))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.mutedText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.mutedText)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }
    
    private func artwork(cluster: TrackLikesCluster) -> some View {
        Group {
            if let s = cluster.trackArtworkURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        artworkPlaceholder
                    @unknown default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(AppColors.tintedBackground)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.primaryText)
            )
    }
    
    // MARK: - Helpers
    
    private func makeTrack(from cluster: TrackLikesCluster) -> Track {
        Track(
            id: cluster.id,
            title: cluster.trackTitle,
            artist: cluster.trackArtist,
            album: cluster.trackAlbum,
            artworkURL: cluster.trackArtworkURL.flatMap { URL(string: $0) },
            durationMs: nil
        )
    }
    
    private func groupedClusters() -> (today: [TrackLikesCluster], earlier: [TrackLikesCluster]) {
        let cal = Calendar.current
        let today = viewModel.clusters.filter { cal.isDateInToday($0.lastLikeAt) }
        let earlier = viewModel.clusters.filter { !cal.isDateInToday($0.lastLikeAt) }
        return (today, earlier)
    }
    
    private func isClusterNew(_ cluster: TrackLikesCluster) -> Bool {
        guard let lastSeen = viewModel.lastSeenDate else { return true }
        return cluster.lastLikeAt > lastSeen
    }
    
    private func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

