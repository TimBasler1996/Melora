import SwiftUI

/// The Activity segment of the Inbox tab: likes on tracks you played, new
/// followers, and a pointer to waiting message requests. Every row opens
/// the person's profile; every row offers the next step (say hi, follow back).
struct ActivityView: View {

    @StateObject private var vm = ActivityViewModel()
    @StateObject private var chats = ChatInboxViewModel()
    @EnvironmentObject private var router: AppRouter

    /// Navigation is driven by state rather than nested links, so the row
    /// tap and the button on the row never fight over the gesture.
    @State private var profileUserId: String?
    @State private var chatTarget: ChatTarget?

    private struct ChatTarget: Identifiable, Hashable {
        let conversationId: String
        let peerId: String
        var id: String { conversationId }
    }

    var body: some View {
        ZStack {
            content
        }
        .melScreenBackground()
        .navigationDestination(item: $profileUserId) { userId in
            UserProfilePreviewView(userId: userId)
        }
        .navigationDestination(item: $chatTarget) { target in
            ChatView(conversationId: target.conversationId, peerUserId: target.peerId)
        }
        .alert(
            "Couldn’t do that",
            isPresented: Binding(get: { vm.actionError != nil }, set: { if !$0 { vm.actionError = nil } })
        ) {
            Button("OK", role: .cancel) { vm.actionError = nil }
        } message: {
            Text(vm.actionError ?? "")
        }
        .onAppear {
            vm.start()
            chats.startListening()
        }
        .onDisappear {
            // Also fires when a row pushes a profile; listeners stay attached
            // (the view model removes them when it goes away).
            vm.markAllAsSeen()
        }
        .refreshable { vm.reload() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.items.isEmpty {
            VStack {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            }
        } else if let error = vm.errorMessage, vm.items.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Text("Couldn’t load your activity")
                    .font(AppFonts.headline())
                    .foregroundColor(.white)
                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                Button("Retry") { vm.start() }
                    .font(AppFonts.subheadline())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.surfaceElevated)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
            .padding(.horizontal, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if !chats.pendingRequestRows.isEmpty {
                        requestsRow(count: chats.pendingRequestRows.count)
                    }

                    if vm.items.isEmpty {
                        emptyState
                    } else {
                        if !vm.newItems.isEmpty {
                            sectionHeader("New")
                            ForEach(vm.newItems) { item in row(item) }
                        }
                        if !vm.earlierItems.isEmpty {
                            sectionHeader("Earlier")
                            ForEach(vm.earlierItems) { item in row(item) }
                        }
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.white.opacity(0.35))
                .padding(.top, 60)
            Text("Nothing yet")
                .font(AppFonts.title())
                .foregroundColor(.white)
            Text("Go live and people nearby can like what you play or follow you. It all shows up here.")
                .font(AppFonts.body())
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    /// Message requests are answered in Chats; this row just gets you there.
    private func requestsRow(count: Int) -> some View {
        Button {
            router.openMessageRequests()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppColors.primary.opacity(0.25)).frame(width: 44, height: 44)
                    MIcon("send", size: 20, color: AppColors.live)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 1 ? "1 message request" : "\(count) message requests")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Someone wants to chat with you")
                        .font(AppFonts.footnote())
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                MIcon("chev-right", size: 18, color: AppColors.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                    .stroke(AppColors.live.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
    }

    private func row(_ item: ActivityItem) -> some View {
        Button {
            profileUserId = item.userId
        } label: {
            ActivityRow(
                item: item,
                isNew: vm.isNew(item),
                isFollowing: vm.isFollowing(item.userId),
                onFollow: { Task { await vm.toggleFollow(item.userId) } },
                onSayHi: {
                    guard let me = vm.myUserId else { return }
                    chatTarget = ChatTarget(
                        conversationId: ChatApiService.shared.conversationId(for: me, and: item.userId),
                        peerId: item.userId
                    )
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct ActivityRow: View {
    let item: ActivityItem
    let isNew: Bool
    let isFollowing: Bool
    let onFollow: () -> Void
    let onSayHi: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) { kindBadge }

            VStack(alignment: .leading, spacing: 3) {
                text
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if case .like(_, let artist, _) = item.kind, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                        Text("·")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Text(ChatInboxRowView.relativeLabel(for: item.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(12)
        .melCard(cornerRadius: 14)
        .overlay(alignment: .topLeading) {
            if isNew {
                Circle()
                    .fill(AppColors.live)
                    .frame(width: 8, height: 8)
                    .padding(8)
            }
        }
    }

    private var text: Text {
        let name = Text(item.displayName ?? "Someone").bold()
        switch item.kind {
        case .like(let title, _, _):
            return (name + Text(" liked ") + Text(title).font(AppFonts.song(size: 18)))
                .font(.system(size: 15))
                .foregroundColor(.white)
        case .follow:
            return (name + Text(" started following you"))
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
    }

    /// The next step, right on the row: a like invites a hello, a follow
    /// invites a follow back.
    @ViewBuilder
    private var trailing: some View {
        switch item.kind {
        case .like:
            Button(action: onSayHi) {
                Text("Say hi")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(AppColors.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.pressable)
        case .follow:
            Button(action: onFollow) {
                Text(isFollowing ? "Following" : "Follow back")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isFollowing ? .white.opacity(0.7) : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(isFollowing ? AppColors.surfaceElevated : AppColors.primary))
            }
            .buttonStyle(.plain)
        }
    }

    private var kindBadge: some View {
        ZStack {
            Circle().fill(AppColors.surfaceElevated).frame(width: 20, height: 20)
            MIcon(item.kind == .follow ? "person-plus" : "heart-fill", size: 11, color: AppColors.live)
        }
        .offset(x: 3, y: 3)
    }

    private var avatar: some View {
        Group {
            if let urlString = item.avatarURL, let url = URL(string: urlString) {
                RemoteImage(url: url, size: 48) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(AppColors.surface)
            Image(systemName: "person.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
    }

}
