import SwiftUI

/// The bell in every tab's top bar. Shows how many likes and followers are
/// unseen and opens the Activity feed. One instance per tab; only the one
/// on the selected tab answers a request from the router (push tap, profile
/// stat), so the sheet always appears on screen.
struct ActivityButton: View {

    let user: AppUser
    let tab: AppRouter.Tab

    @StateObject private var badgeVM = LikesBadgeViewModel()
    @EnvironmentObject private var router: AppRouter
    @State private var showActivity = false

    var body: some View {
        Button {
            showActivity = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.surfaceElevated))

                if badgeVM.unreadCount > 0 {
                    Text(badgeText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.live))
                        .offset(x: 10, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Activity")
        .onAppear {
            badgeVM.startListening(userId: user.uid)
            consumeRouterRequest()
        }
        .onChange(of: router.showActivity) { _, _ in
            consumeRouterRequest()
        }
        .onChange(of: router.selectedTab) { _, _ in
            consumeRouterRequest()
        }
        .onDisappear {
            badgeVM.stopListening()
        }
        .fullScreenCover(isPresented: $showActivity) {
            NavigationStack {
                ActivityView()
            }
            .onDisappear {
                badgeVM.markAllAsSeenNow()
            }
        }
    }

    private func consumeRouterRequest() {
        guard router.showActivity, router.selectedTab == tab else { return }
        router.showActivity = false
        showActivity = true
    }

    private var badgeText: String {
        badgeVM.unreadCount > 99 ? "99+" : "\(badgeVM.unreadCount)"
    }
}
