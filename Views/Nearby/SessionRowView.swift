import SwiftUI
import CoreLocation

/// One card representing a single broadcast session in the Nearby screen.
struct SessionRowView: View {
    
    @Binding var session: Session
    let userLocation: LocationPoint?
    
    var body: some View {
        NavigationLink {
            // ✅ FIX 3: use uid (your current Firestore document id)
            UserProfilePreviewView(userId: session.user.id)
        } label: {
            HStack(spacing: 12) {
                
                artwork
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(session.user.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.live)
                                .frame(width: 6, height: 6)
                            
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.live)
                        }
                    }
                    
                    Text(session.track.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)
                    
                    Text(session.track.artist)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                    
                    if let distanceText {
                        Text(distanceText)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.mutedText)
                            .lineLimit(1)
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
    }
    
    // MARK: - Artwork
    
    private var artwork: some View {
        Group {
            // ✅ FIX 1: artworkURL is URL?
            if let url = session.track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        fallbackArtwork
                    @unknown default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.tintedBackground)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.primaryText)
            )
    }
    
    // MARK: - Distance
    
    private var distanceText: String? {
        guard let userLoc = userLocation else { return nil }
        
        // ✅ FIX 2: session.location is NOT optional
        let sessionLoc = session.location
        
        let a = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let b = CLLocation(latitude: sessionLoc.latitude, longitude: sessionLoc.longitude)
        let meters = a.distance(from: b)
        
        if meters < 1000 {
            return "\(Int(meters)) m away"
        } else {
            return String(format: "%.1f km away", meters / 1000.0)
        }
    }
}


