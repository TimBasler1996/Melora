import SwiftUI

struct OnboardingStepSpotifyView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect Spotify")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Connect your Spotify account to share your music taste with matches.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Connection status card
            VStack(spacing: 20) {
                // Spotify icon/status
                ZStack {
                    Circle()
                        .fill(viewModel.spotifyConnected ? Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.15) : Color.white.opacity(0.08))
                        .frame(width: 100, height: 100)
                    
                    if viewModel.spotifyConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.top, 16)
                
                // Status message
                VStack(spacing: 8) {
                    if viewModel.spotifyConnected {
                        Text("Connected")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Your Spotify account is connected")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Not Connected")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Connect your account to continue")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "music.note.list",
                        title: "Share your music taste",
                        description: "Let matches see what you're listening to"
                    )
                    
                    FeatureRow(
                        icon: "person.2.fill",
                        title: "Find music compatibility",
                        description: "Match with people who share your taste"
                    )
                    
                    FeatureRow(
                        icon: "lock.fill",
                        title: "Your data is private",
                        description: "We only access your basic profile info"
                    )
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

#Preview {
    OnboardingStepSpotifyView(viewModel: OnboardingViewModel())
        .padding()
}
