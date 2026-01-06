import SwiftUI

/// Root view of the app that shows the main tab bar.
struct MainView: View {

    @StateObject private var currentUserStore = CurrentUserStore()

    var body: some View {
        Group {
            if currentUserStore.isLoading && currentUserStore.user == nil {
                loadingView
            } else if let err = currentUserStore.errorMessage, currentUserStore.user == nil {
                errorView(err)
            } else {
                tabs
                    .environmentObject(currentUserStore)
            }
        }
        .onAppear {
            currentUserStore.startListening()
        }
    }

    private var tabs: some View {
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

    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView("Loading…")
                    .tint(.white)
            }
        }
    }

    private func errorView(_ err: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Couldn’t load user")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(err)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Retry") { currentUserStore.startListening() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        }
    }
}

