import SwiftUI

/// Root view of the app that shows the main tab bar.
struct MainView: View {

    var body: some View {
        TabView {
            NowPlayingView()
                .tabItem {
                    Label("Now", systemImage: "music.note")
                }

            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "dot.radiowaves.left.and.right")
                }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .tint(AppColors.primary)
    }
}

