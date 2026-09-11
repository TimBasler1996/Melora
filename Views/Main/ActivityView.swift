import SwiftUI

/// The one place for everything that happened to you: likes on tracks you
/// played, new followers, and a pointer to waiting message requests.
/// Every row opens the person's profile.
struct ActivityView: View {

    @StateObject private var vm = ActivityViewModel()
    @StateObject private var chats = ChatInboxViewModel()
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            content
        }
        .melScreenBackground()
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppColors.surfaceElevated))
                }
                .accessibilityLabel("Close")
            }
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
            vm.markAllAsSeen()
            vm.stop()
            chats.stopListening()
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
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    /// Message requests are answered in Chats; this row just gets you there.
    private func requestsRow(count: Int) -> some View {
        Button {
            dismiss()
            router.openMessageRequests()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(AppColors.primary.opacity(0.25)).frame(width: 44, height: 44)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 1 ? "1 message request" : "\(count) message requests")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Someone wants to chat with you")
                        .font(AppFonts.footnote())
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .melCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private func row(_ item: ActivityItem) -> some View {
        NavigationLink {
            UserProfilePreviewView(userId: item.userId)
        } label: {
            ActivityRow(
                item: item,
                isNew: vm.isNew(item),
                isFollowing: vm.isFollowing(item.userId),
                onFollow: { Task { await vm.toggleFollow(item.userId) } }
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

    var body: some View {
        HStack(spacing: 12) {
            avatar
                .frame(width: 46, height: 46)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) { kindBadge }

            VStack(alignment: .leading, spacing: 3) {
                text
                    .lineLimit(2)
                Text(ChatInboxRowView.relativeLabel(for: item.date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
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
            return (name + Text(" liked ") + Text(title).italic())
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
        case .follow:
            return (name + Text(" started following you"))
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch item.kind {
        case .like(_, _, let artworkURL):
            artwork(artworkURL)
        case .follow:
            Button(action: onFollow) {
                Text(isFollowing ? "Following" : "Follow back")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
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
            Image(systemName: item.kind == .follow ? "person.fill.badge.plus" : "heart.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(item.kind == .follow ? AppColors.primary : .red)
        }
        .offset(x: 3, y: 3)
    }

    private var avatar: some View {
        Group {
            if let urlString = item.avatarURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
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

    private func artwork(_ urlString: String?) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.surface)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AppColors.surface)
                    .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.4)))
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
