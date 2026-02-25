import SwiftUI
import FirebaseAuth

/// Root view of the app that shows the main tab bar.
struct MainView: View {

    @StateObject private var chatBadge = ChatBadgeViewModel()

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

            ChatInboxView()
                .tabItem {
                    Label("Chats", systemImage: "message")
                }
                .badge(chatBadge.unreadCount)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
        }
        .tint(AppColors.primary)
        .onAppear { chatBadge.startListening() }
        .onDisappear { chatBadge.stopListening() }
    }
}

